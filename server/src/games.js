'use strict';
// Brincadeiras compartilhadas de uma sala. Três jeitos de brincar junto:
//
//  round  — RODADA: cada um joga a própria partida ao mesmo tempo e o placar
//           é da rodada inteira (aviãozinho, pontaria, basquete, gude,
//           corrida, guerra de papel). Quem chega com a rodada rolando entra
//           na hora; a rodada termina quando todos acabaram.
//  turn   — VEZ: um joga de cada vez, com fila (amarelinha, pular corda).
//           Quem chega entra no fim da fila e assiste.
//  team   — TIME: uma partida só, simulada pelo celular do "anfitrião" (host)
//           e repassada aos outros (futebol, cabo de guerra). Quem chega
//           entra no time menor; quem sai é trocado por bot; se o anfitrião
//           sair, outro assume de onde parou.
//
// Só no recreio: quando o sinal toca, tudo termina com resultado.

const LOBBY_MS = 12000;
const RESULTS_MS = 6000;
const RELAY_MAX = 1800;

const CATALOG = {
  aviao: { kind: 'round', max: 8, maxMs: 150000 },
  pontaria: { kind: 'round', max: 8, maxMs: 120000 },
  basquete: { kind: 'round', max: 8, maxMs: 120000 },
  gude: { kind: 'round', max: 6, maxMs: 180000 },
  guerra: { kind: 'round', max: 8, maxMs: 120000 },
  corrida: { kind: 'round', max: 4, maxMs: 90000, lower: true },
  queimada: { kind: 'round', max: 6, maxMs: 200000 },
  esconde: { kind: 'round', max: 6, maxMs: 200000 },
  amarelinha: { kind: 'turn', max: 8, turnMs: 120000 },
  corda: { kind: 'turn', max: 8, turnMs: 120000 },
  futebol: { kind: 'team', max: 10, maxMs: 240000 },
  cabo: { kind: 'team', max: 8, maxMs: 90000 },
};

class GameSession {
  constructor(gid, host, now, wait) {
    const c = CATALOG[gid];
    this.gid = gid;
    this.kind = c.kind;
    this.max = c.max;
    this.host = host;
    this.players = [];
    this.teams = {};
    this.queue = [];
    this.current = null;
    this.turnStarted = 0;
    this.scores = {};
    this.finals = new Set();
    this.opts = {};
    this.state = 'lobby';
    this.lobbyEnds = now + (wait ? LOBBY_MS : 0);
    this.startedAt = 0;
    this.endsAt = 0;
    this.resultsUntil = 0;
    this.hostState = null;
    this.ranking = null;
  }

  has(id) { return this.players.includes(id); }

  teamCount(t) { return this.players.filter((p) => this.teams[p] === t).length; }

  snapshot(now = Date.now()) {
    return {
      gid: this.gid, kind: this.kind, state: this.state, host: this.host, players: this.players.slice(),
      teams: { ...this.teams }, queue: this.queue.slice(), current: this.current, scores: { ...this.scores },
      opts: this.opts, max: this.max, startedAt: this.startedAt,
      lobbyLeft: this.state === 'lobby' ? Math.max(0, Math.ceil((this.lobbyEnds - now) / 1000)) : 0,
      turnLeft: this.kind === 'turn' && this.current ? Math.max(0, Math.ceil((this.turnStarted + CATALOG[this.gid].turnMs - now) / 1000)) : 0,
      ranking: this.ranking,
    };
  }
}

class GameHub {
  constructor(room) {
    this.room = room;
    this.sessions = new Map(); // gid -> GameSession
    this.dirty = new Set();
    this.events = []; // {gid, kind, ...} para o servidor transmitir
  }

  static catalog() { return CATALOG; }

  _ev(gid, kind, extra = {}) { this.events.push({ gid, kind, ...extra }); this.dirty.add(gid); }

  /** Em qual brincadeira o jogador está (ou null). */
  sessionOf(id) {
    for (const s of this.sessions.values()) if (s.has(id) && s.state !== 'results') return s;
    return null;
  }

  /**
   * Entra (ou cria) na brincadeira. wait=true abre a espera de ~12 s para os
   * outros chegarem (o celular pede quando tem colegas por perto).
   * Retorna {ok, session} ou {error}.
   */
  join(gid, id, opts = {}, now = Date.now()) {
    if (!CATALOG[gid]) return { error: 'Brincadeira desconhecida.' };
    if (this.room.phase !== 'recess') return { error: 'As brincadeiras são no recreio!' };
    const other = this.sessionOf(id);
    if (other && other.gid !== gid) this.leave(other.gid, id, now);
    let s = this.sessions.get(gid);
    if (s && s.state === 'results') { this.sessions.delete(gid); s = null; }
    if (!s) {
      s = new GameSession(gid, id, now, !!opts.wait);
      if (opts.opts && typeof opts.opts === 'object') s.opts = sanitizeOpts(opts.opts);
      this.sessions.set(gid, s);
    }
    if (s.has(id)) { this.dirty.add(gid); return { ok: true, session: s }; }
    if (s.players.length >= s.max) return { error: 'Essa brincadeira está lotada. Espere a próxima!' };
    s.players.push(id);
    if (s.kind === 'team') {
      // quem chega entra no time menor (o time do anfitrião é o "a")
      s.teams[id] = s.players.length === 1 ? 'a' : (s.teamCount('a') <= s.teamCount('b') ? 'a' : 'b');
    }
    if (s.kind === 'turn') s.queue.push(id);
    if (s.state === 'playing') {
      if (s.kind === 'turn' && !s.current) this._nextTurn(s, now);
      this._ev(gid, 'joined', { id, late: true, team: s.teams[id] || null });
    }
    this.dirty.add(gid);
    return { ok: true, session: s };
  }

  /** O anfitrião começa antes do fim da espera (e pode mudar as opções). */
  start(gid, id, opts, now = Date.now()) {
    const s = this.sessions.get(gid);
    if (!s || s.state !== 'lobby' || s.host !== id) return false;
    if (opts && typeof opts === 'object') s.opts = sanitizeOpts(opts);
    this._start(s, now);
    return true;
  }

  setOpts(gid, id, opts) {
    const s = this.sessions.get(gid);
    if (!s || s.state !== 'lobby' || s.host !== id || !opts || typeof opts !== 'object') return false;
    s.opts = sanitizeOpts(opts);
    this.dirty.add(gid);
    return true;
  }

  _start(s, now) {
    s.state = 'playing';
    s.startedAt = now;
    const c = CATALOG[s.gid];
    s.endsAt = now + (c.maxMs || c.turnMs * Math.max(1, s.queue.length) + 30000);
    if (s.kind === 'turn') this._nextTurn(s, now);
    this._ev(s.gid, 'start', { players: s.players.slice(), teams: { ...s.teams }, host: s.host, opts: s.opts });
  }

  _nextTurn(s, now) {
    s.current = s.queue.shift() || null;
    s.turnStarted = now;
    if (s.current) {
      s.endsAt = Math.max(s.endsAt, now + CATALOG[s.gid].turnMs + 5000);
      this._ev(s.gid, 'turn', { id: s.current });
    }
  }

  leave(gid, id, now = Date.now()) {
    const s = this.sessions.get(gid);
    if (!s || !s.has(id)) return;
    s.players = s.players.filter((p) => p !== id);
    s.queue = s.queue.filter((p) => p !== id);
    delete s.teams[id];
    this.dirty.add(gid);
    if (s.players.length === 0) { this.sessions.delete(gid); this._ev(gid, 'closed'); return; }
    if (s.host === id) {
      // novo anfitrião; no jogo de time o time dele passa a ser o "a"
      s.host = s.players[0];
      if (s.kind === 'team' && s.teams[s.host] === 'b') {
        for (const p of s.players) s.teams[p] = s.teams[p] === 'a' ? 'b' : 'a';
        if (s.hostState && typeof s.hostState === 'object') s.hostState = { ...s.hostState, swapped: true };
      }
      this._ev(gid, 'host', { id: s.host, teams: { ...s.teams }, hostState: s.hostState });
    } else this._ev(gid, 'left', { id });
    if (s.state === 'playing') {
      if (s.kind === 'turn' && s.current === id) this._nextTurn(s, now);
      this._checkDone(s, now);
    }
  }

  leaveAll(id, now = Date.now()) {
    for (const gid of [...this.sessions.keys()]) this.leave(gid, id, now);
  }

  /** Placar de um jogador. final=true: terminou a partida dele/a vez dele. */
  score(gid, id, score, final, now = Date.now()) {
    const s = this.sessions.get(gid);
    if (!s || !s.has(id) || s.state !== 'playing') return;
    const v = Number(score);
    if (!Number.isFinite(v)) return;
    s.scores[id] = Math.max(-1e6, Math.min(1e6, Math.round(v * 100) / 100));
    this.dirty.add(gid);
    if (!final) return;
    s.finals.add(id);
    if (s.kind === 'turn' && s.current === id) this._nextTurn(s, now);
    this._checkDone(s, now);
  }

  /** Jogo de time: o anfitrião informa o resultado final ({a, b}). */
  teamResult(gid, id, res, now = Date.now()) {
    const s = this.sessions.get(gid);
    if (!s || s.kind !== 'team' || s.host !== id || s.state !== 'playing') return;
    const a = Number(res && res.a) | 0;
    const b = Number(res && res.b) | 0;
    this._finish(s, now, { a, b });
  }

  _checkDone(s, now) {
    if (s.state !== 'playing') return;
    if (s.kind === 'round' && s.players.length > 0 && s.players.every((p) => s.finals.has(p))) this._finish(s, now);
    if (s.kind === 'turn' && !s.current && s.queue.length === 0) this._finish(s, now);
  }

  _finish(s, now, team = null) {
    s.state = 'results';
    s.resultsUntil = now + RESULTS_MS;
    const lowerBetter = !!CATALOG[s.gid].lower;
    const ids = Object.keys(s.scores);
    const ranking = ids.map((id) => ({ id, score: s.scores[id] }))
      .sort((x, y) => (lowerBetter ? x.score - y.score : y.score - x.score));
    s.ranking = team ? { team } : ranking;
    this._ev(s.gid, 'results', { ranking: s.ranking, team, teams: { ...s.teams } });
  }

  /** O sinal tocou: tudo termina com o placar de agora. */
  endAll(now = Date.now()) {
    for (const s of this.sessions.values()) {
      if (s.state === 'lobby') { this.sessions.delete(s.gid); this._ev(s.gid, 'closed', { text: 'O sinal tocou!' }); }
      else if (s.state === 'playing') this._finish(s, now, s.kind === 'team' && s.hostState ? { a: s.hostState.a | 0, b: s.hostState.b | 0 } : null);
    }
  }

  /** Repasse do jogo de time: do anfitrião para todos; dos outros só para o anfitrião. */
  relay(gid, from, data) {
    const s = this.sessions.get(gid);
    if (!s || !s.has(from) || s.state !== 'playing' || data === undefined) return null;
    if (JSON.stringify(data).length > RELAY_MAX) return null;
    if (from === s.host) {
      if (data && typeof data === 'object' && Number.isFinite(data.a) && Number.isFinite(data.b)) {
        s.hostState = { a: data.a | 0, b: data.b | 0, t: Number(data.t) || 0 };
      }
      return { to: s.players.filter((p) => p !== from), session: s };
    }
    return { to: [s.host], session: s };
  }

  tick(now = Date.now()) {
    for (const s of [...this.sessions.values()]) {
      if (s.state === 'lobby' && now >= s.lobbyEnds) this._start(s, now);
      else if (s.state === 'playing') {
        if (s.kind === 'turn' && s.current && now - s.turnStarted > CATALOG[s.gid].turnMs) {
          s.finals.add(s.current);
          this._nextTurn(s, now);
          this._checkDone(s, now);
        }
        if (s.state === 'playing' && now >= s.endsAt) this._finish(s, now, s.kind === 'team' && s.hostState ? { a: s.hostState.a | 0, b: s.hostState.b | 0 } : null);
      } else if (s.state === 'results' && now >= s.resultsUntil) {
        this.sessions.delete(s.gid);
        this._ev(s.gid, 'closed');
      }
    }
  }

  /** Estados que mudaram desde a última chamada. */
  takeDirty(now = Date.now()) {
    const out = [];
    for (const gid of this.dirty) {
      const s = this.sessions.get(gid);
      out.push(s ? s.snapshot(now) : { gid, state: 'none' });
    }
    this.dirty.clear();
    return out;
  }

  all(now = Date.now()) {
    return [...this.sessions.values()].map((s) => s.snapshot(now));
  }

  takeEvents() {
    const e = this.events;
    this.events = [];
    return e;
  }
}

function sanitizeOpts(o) {
  const out = {};
  for (const k of ['size', 'difficulty', 'bots']) {
    if (typeof o[k] === 'number' && Number.isFinite(o[k])) out[k] = Math.max(0, Math.min(10, o[k] | 0));
    else if (typeof o[k] === 'boolean') out[k] = o[k];
  }
  return out;
}

module.exports = { GameHub, CATALOG, LOBBY_MS, RESULTS_MS };
