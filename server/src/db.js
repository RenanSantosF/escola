'use strict';
// Banco de dados PostgreSQL (Railway). Liga sozinho quando existe a variável
// DATABASE_URL — no Railway ela vem do serviço Postgres por referência
// (${{Postgres.DATABASE_URL}}); ninguém precisa copiar senha.
// Sem DATABASE_URL o servidor funciona em memória (como antes).
//
// O que fica salvo:
//   accounts  — contas (token guardado só como hash), nome gerado, idade, nível, visual
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
  async findAccount(token) {
    if (!this.ready || !token) return null;
    const r = await this.pool.query('select * from accounts where token_hash = $1', [hashToken(token)]);
    if (!r.rows.length) return null;
    const a = r.rows[0];
    return { token, id: a.id, name: a.name, age: a.age, level: a.level, look: a.look || {}, freeChat: a.free_chat, createdAt: a.created_at };
  }

  async saveAccount(acc) {
    if (!this.ready) return;
    await this.pool.query(
      `insert into accounts (id, token_hash, name, age, level, look, free_chat, last_seen)
       values ($1,$2,$3,$4,$5,$6,$7, now())
       on conflict (id) do update set age = excluded.age, level = excluded.level, look = excluded.look,
         free_chat = excluded.free_chat, last_seen = now()`,
      [acc.id, hashToken(acc.token), acc.name, acc.age, acc.level, JSON.stringify(acc.look || {}), !!acc.freeChat]);
  }

  async setFreeChat(id, allow) {
    if (!this.ready) return false;
    const r = await this.pool.query('update accounts set free_chat = $2 where id = $1', [id, !!allow]);
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

  async saveBlock(id, other) {
    if (!this.ready) return;
    await this.pool.query('insert into blocks (account_id, blocked_id) values ($1,$2) on conflict do nothing', [id, other]);
  }

  async loadBlocks() {
    if (!this.ready) return [];
    const r = await this.pool.query('select account_id, blocked_id from blocks');
    return r.rows.map((x) => [x.account_id, x.blocked_id]);
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
