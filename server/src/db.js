'use strict';
// Banco de dados PostgreSQL (Railway). Liga sozinho quando existe a variável
// DATABASE_URL — no Railway ela vem do serviço Postgres por referência
// (${{Postgres.DATABASE_URL}}); ninguém precisa copiar senha.
// Sem DATABASE_URL o servidor funciona em memória (como antes).
//
// O que fica salvo:
//   accounts  — contas (token e código de recuperação só como hash), apelido,
//               idade, nível, visual e o PROGRESSO do jogo (moedas, itens...)
//   events    — estatísticas anônimas do painel
//   reports   — denúncias (com as últimas mensagens do denunciado)
//   mutes     — silenciamentos com prazo
//   blocks    — quem bloqueou quem

const crypto = require('crypto');

const SCHEMA = `
create table if not exists accounts (
  id text primary key,
  token_hash text unique not null,
  name text not null,
  age smallint not null default 9,
  level int not null default 1,
  look jsonb not null default '{}',
  free_chat boolean not null default false,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now()
);
alter table accounts add column if not exists registered boolean not null default false;
alter table accounts add column if not exists recovery_hash text;
alter table accounts add column if not exists progress jsonb;
alter table accounts add column if not exists progress_at bigint not null default 0;
create unique index if not exists accounts_recovery_idx on accounts (recovery_hash);
alter table accounts add column if not exists username_key text;
alter table accounts add column if not exists pass_hash text;
alter table accounts add column if not exists chat_restricted boolean not null default false;
create unique index if not exists accounts_username_idx on accounts (username_key);
create table if not exists events (
  id bigserial primary key,
  at timestamptz not null,
  uid text not null,
  type text not null,
  data jsonb not null default '{}'
);
create index if not exists events_at_idx on events (at);
create table if not exists reports (
  id bigserial primary key,
  at timestamptz not null default now(),
  reporter_id text not null,
  target_id text not null,
  reason text not null,
  context jsonb not null default '{}',
  status text not null default 'aberta'
);
create table if not exists mutes (
  account_id text primary key,
  until timestamptz not null
);
create table if not exists friends (
  a text not null,
  b text not null,
  a_name text not null,
  b_name text not null,
  from_id text not null,
  status text not null default 'pending',
  primary key (a, b)
);
create table if not exists settings (
  key text primary key,
  value jsonb not null
);
create table if not exists blocks (
  account_id text not null,
  blocked_id text not null,
  primary key (account_id, blocked_id)
);
`;

const hashToken = (t) => crypto.createHash('sha256').update(String(t)).digest('hex');

class Database {
  /** @param {object} opts {url, Pool} — Pool injetável nos testes */
  constructor(opts = {}) {
    this.url = opts.url ?? process.env.DATABASE_URL ?? '';
    this.pool = null;
    this.ready = false;
    if (!this.url) return;
    const { Pool } = opts.Pool ? { Pool: opts.Pool } : require('pg');
    const internal = /railway\.internal|localhost|127\.0\.0\.1/.test(this.url);
    this.pool = new Pool({ connectionString: this.url, max: 5, ssl: internal ? false : { rejectUnauthorized: false } });
    this.pool.on('error', (e) => console.error('db: erro na conexão', e.message));
  }

  get enabled() { return this.pool !== null; }

  async init() {
    if (!this.pool) return false;
    await this.pool.query(SCHEMA);
    this.ready = true;
    return true;
  }

  async close() {
    if (this.pool) await this.pool.end();
  }

  // ---------------------------------------------------------- contas
  _row(a, token) {
    return {
      token, id: a.id, name: a.name, age: a.age, level: a.level, look: a.look || {}, freeChat: a.chat_restricted ? false : null,
      nameKey: a.username_key || undefined, passHash: a.pass_hash || undefined,
      registered: a.registered, recoveryHash: a.recovery_hash || undefined, progress: a.progress || null,
      progressAt: Number(a.progress_at) || 0, createdAt: a.created_at,
    };
  }

  async findAccount(token) {
    if (!this.ready || !token) return null;
    const r = await this.pool.query('select * from accounts where token_hash = $1', [hashToken(token)]);
    return r.rows.length ? this._row(r.rows[0], token) : null;
  }

  /** Recuperação em outro aparelho: gera um token NOVO (o antigo para de valer). */
  async findByRecovery(recoveryHash, newToken) {
    if (!this.ready) return null;
    const r = await this.pool.query('update accounts set token_hash = $2, last_seen = now() where recovery_hash = $1 returning *',
      [recoveryHash, hashToken(newToken)]);
    return r.rows.length ? this._row(r.rows[0], newToken) : null;
  }

  async saveAccount(acc) {
    if (!this.ready) return;
    await this.pool.query(
      `insert into accounts (id, token_hash, name, age, level, look, chat_restricted, registered, recovery_hash,
         username_key, pass_hash, last_seen)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now())
       on conflict (id) do update set token_hash = excluded.token_hash, age = excluded.age, level = excluded.level,
         look = excluded.look, chat_restricted = excluded.chat_restricted, registered = excluded.registered,
         recovery_hash = coalesce(excluded.recovery_hash, accounts.recovery_hash),
         username_key = coalesce(excluded.username_key, accounts.username_key),
         pass_hash = coalesce(excluded.pass_hash, accounts.pass_hash), last_seen = now()`,
      [acc.id, hashToken(acc.token), acc.name, acc.age, acc.level, JSON.stringify(acc.look || {}), acc.freeChat === false,
        !!acc.registered, acc.recoveryHash || null, acc.nameKey || null, acc.passHash || null]);
  }

  /** Nome já usado? (checagem ao vivo e cadastro) */
  async nameTaken(key) {
    if (!this.ready) return false;
    const r = await this.pool.query('select 1 from accounts where username_key = $1', [key]);
    return r.rows.length > 0;
  }

  /** Login: carrega a conta pelo nome e troca o token (o aparelho antigo sai). */
  async findByName(key, newToken) {
    if (!this.ready) return null;
    const r = await this.pool.query('select * from accounts where username_key = $1', [key]);
    if (!r.rows.length) return null;
    const acc = this._row(r.rows[0], newToken);
    return acc;
  }

  async saveProgress(acc) {
    if (!this.ready) return;
    await this.pool.query('update accounts set progress = $2, progress_at = $3, level = $4, look = $5 where id = $1',
      [acc.id, JSON.stringify(acc.progress || {}), acc.progressAt || 0, acc.level, JSON.stringify(acc.look || {})]);
  }

  /** LGPD: apagar conta e dados ligados a ela. */
  async deleteAccount(id) {
    if (!this.ready) return;
    await this.pool.query('delete from accounts where id = $1', [id]);
    await this.pool.query('delete from mutes where account_id = $1', [id]);
    await this.pool.query('delete from blocks where account_id = $1 or blocked_id = $1', [id]);
    await this.pool.query('delete from friends where a = $1 or b = $1', [id]);
  }

  async setFreeChat(id, allow) {
    if (!this.ready) return false;
    const r = await this.pool.query('update accounts set chat_restricted = $2 where id = $1', [id, !allow]);
    return r.rowCount > 0;
  }

  // ---------------------------------------------------------- estatísticas
  async insertEvents(list) {
    if (!this.ready || !list.length) return;
    const values = [];
    const params = [];
    list.forEach((e, i) => {
      values.push(`($${i * 4 + 1}, $${i * 4 + 2}, $${i * 4 + 3}, $${i * 4 + 4})`);
      params.push(new Date(e.at), e.uid, e.type, JSON.stringify(e.data || {}));
    });
    await this.pool.query(`insert into events (at, uid, type, data) values ${values.join(',')}`, params);
  }

  async loadEvents(days = 120, limit = 300000) {
    if (!this.ready) return [];
    const r = await this.pool.query(
      `select at, uid, type, data from events where at > now() - ($1 || ' days')::interval order by at desc limit $2`, [String(days), limit]);
    return r.rows.reverse().map((x) => ({ at: new Date(x.at).getTime(), uid: x.uid, type: x.type, data: x.data || {} }));
  }

  // ---------------------------------------------------------- segurança
  async insertReport(e) {
    if (!this.ready) return;
    await this.pool.query('insert into reports (at, reporter_id, target_id, reason, context) values ($1,$2,$3,$4,$5)',
      [new Date(e.at), e.reporterId, e.targetId, e.reason, JSON.stringify(e.context || {})]);
  }

  async loadReports(limit = 300) {
    if (!this.ready) return [];
    const r = await this.pool.query('select * from reports order by at desc limit $1', [limit]);
    return r.rows.reverse().map((x) => ({ at: new Date(x.at).toISOString(), reporterId: x.reporter_id, targetId: x.target_id, reason: x.reason, context: x.context, status: x.status }));
  }

  async saveMute(id, untilMs) {
    if (!this.ready) return;
    await this.pool.query('insert into mutes (account_id, until) values ($1,$2) on conflict (account_id) do update set until = excluded.until', [id, new Date(untilMs)]);
  }

  async loadMutes() {
    if (!this.ready) return [];
    const r = await this.pool.query('select account_id, until from mutes where until > now()');
    return r.rows.map((x) => [x.account_id, new Date(x.until).getTime()]);
  }

  // ---------------------------------------------------------- amigos
  async saveFriend(p) {
    if (!this.ready) return;
    await this.pool.query(
      `insert into friends (a, b, a_name, b_name, from_id, status) values ($1,$2,$3,$4,$5,$6)
       on conflict (a, b) do update set status = excluded.status, from_id = excluded.from_id`,
      [p.a, p.b, p.aName, p.bName, p.from, p.status]);
  }

  async deleteFriend(a, b) {
    if (!this.ready) return;
    await this.pool.query('delete from friends where a = $1 and b = $2', [a, b]);
  }

  async loadFriends() {
    if (!this.ready) return [];
    const r = await this.pool.query('select * from friends');
    return r.rows.map((x) => ({ a: x.a, b: x.b, aName: x.a_name, bName: x.b_name, from: x.from_id, status: x.status }));
  }

  /** Só id e nome de quem tem esse nome de jogador (para adicionar amigo). */
  async idByName(key) {
    if (!this.ready) return null;
    const r = await this.pool.query('select id, name from accounts where username_key = $1', [key]);
    return r.rows.length ? { id: r.rows[0].id, name: r.rows[0].name } : null;
  }

  async saveBlock(id, other) {
    if (!this.ready) return;
    await this.pool.query('insert into blocks (account_id, blocked_id) values ($1,$2) on conflict do nothing', [id, other]);
  }

  async loadBlocks() {
    if (!this.ready) return [];
    const r = await this.pool.query('select account_id, blocked_id from blocks');
    return r.rows.map((x) => [x.account_id, x.blocked_id]);
  }

  // ---------------------------------------------------------- configurações (painel)
  async loadSettings() {
    if (!this.ready) return null;
    const r = await this.pool.query("select value from settings where key = 'game'");
    return r.rows.length ? r.rows[0].value : null;
  }

  async saveSettings(value) {
    if (!this.ready) return false;
    await this.pool.query("insert into settings (key, value) values ('game', $1) on conflict (key) do update set value = excluded.value", [JSON.stringify(value)]);
    return true;
  }

  async counts() {
    if (!this.ready) return null;
    const r = await this.pool.query(`select (select count(*) from accounts) as accounts, (select count(*) from events) as events,
      (select count(*) from reports) as reports`);
    const c = r.rows[0];
    return { accounts: Number(c.accounts), events: Number(c.events), reports: Number(c.reports) };
  }
}

module.exports = { Database, hashToken, SCHEMA };
