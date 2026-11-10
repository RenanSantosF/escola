'use strict';
// Salas ("turmas"): até MAX jogadores (uma carteira para cada na Sala 5).
// TODAS as salas são abertas: o código de 4 números só serve para os amigos
// caírem na MESMA sala; quem usa a entrada rápida também pode entrar nela.
// A entrada rápida prioriza salas que já existem (a mais cheia com vaga).
// Cada sala tem o relógio da escola (SchoolClock), as carteiras reservadas
// e as brincadeiras compartilhadas (GameHub).

const crypto = require('crypto');
const { SchoolClock } = require('./clock');
const { GameHub } = require('./games');

const MAX_PER_ROOM = 16;
const DESKS = 16;
const DESK_HOLD_MS = 90000; // quem caiu e volta logo recupera a mesma carteira

class Room {
  constructor(id, code, opts = {}) {
    this.id = id;
    this.code = code;
    this.private = false;
    this.players = new Map(); // id -> {id, name, level, look, pos, yaw, anim, ws}
    this.createdAt = Date.now();
    this.clock = new SchoolClock(opts.now ?? Date.now(), opts.clock || {});
    this.games = new GameHub(this);
    this.desks = new Map(); // playerId -> índice da carteira
    this.deskHold = new Map(); // playerId -> {desk, until}
  }

  get phase() { return this.clock.state().phase; }

  /** Carteira do jogador: a mesma de antes (se voltou logo) ou a menor livre. */
  assignDesk(id, now = Date.now()) {
    if (this.desks.has(id)) return this.desks.get(id);
    const taken = new Set(this.desks.values());
    for (const [pid, h] of this.deskHold) {
      if (h.until < now) this.deskHold.delete(pid);
      else if (pid !== id) taken.add(h.desk);
    }
    const held = this.deskHold.get(id);
    let desk = -1;
    if (held && !taken.has(held.desk)) desk = held.desk;
    for (let i = 0; desk < 0 && i < DESKS; i++) if (!taken.has(i)) desk = i;
    this.deskHold.delete(id);
    if (desk >= 0) this.desks.set(id, desk);
    return desk;
  }

  releaseDesk(id, now = Date.now()) {
    if (!this.desks.has(id)) return;
    this.deskHold.set(id, { desk: this.desks.get(id), until: now + DESK_HOLD_MS });
    this.desks.delete(id);
  }

  deskMap() {
    const out = {};
    for (const [id, d] of this.desks) out[id] = d;
    return out;
  }

  snapshot(exceptId) {
    const list = [];
    for (const p of this.players.values()) {
      if (p.id === exceptId) continue;
      list.push({ id: p.id, name: p.name, level: p.level, look: p.look, pos: p.pos, yaw: p.yaw, anim: p.anim });
    }
    return list;
  }

  info() {
    return { code: this.code, players: this.players.size, max: MAX_PER_ROOM, phase: this.phase };
  }
}

class RoomManager {
  constructor(opts = {}) {
    this.rooms = new Map(); // code -> Room
    this.opts = opts;
  }

  _newCode() {
    for (let i = 0; i < 200; i++) {
      const c = String(crypto.randomInt(1000, 9999));
      if (!this.rooms.has(c)) return c;
    }
    return String(Date.now() % 100000);
  }

  /** Cria uma sala NOVA e aberta (os amigos entram pelo código; outros podem cair nela). */
  create(player) {
    const code = this._newCode();
    const room = new Room('sala-' + code, code, this.opts);
    this.rooms.set(code, room);
    return this._enter(room, player);
  }

  /** Entra pelo código; {error} se não existe ou está cheia. */
  joinCode(player, code) {
    const room = this.rooms.get(String(code || '').trim());
    if (!room) return { error: 'Sala não encontrada. Confira o código.' };
    if (room.players.has(player.id)) return this._enter(room, player);
    if (room.players.size >= MAX_PER_ROOM) return { error: 'Essa sala está cheia. Combinem de criar uma sala nova juntos!' };
    return this._enter(room, player);
  }

  /** Entrada rápida: prioriza salas que já existem (a mais cheia com vaga). */
  quick(player) {
    let best = null;
    for (const r of this.rooms.values()) {
      if (r.players.size >= MAX_PER_ROOM || r.players.size === 0) continue;
      if (!best || r.players.size > best.players.size || (r.players.size === best.players.size && r.createdAt < best.createdAt)) best = r;
    }
    if (!best) return this.create(player);
    return this._enter(best, player);
  }

  /** Reconexão: volta para a sala de antes se ela existe; senão, entrada rápida. */
  join(player, wanted) {
    if (wanted && this.rooms.has(wanted)) {
      const r = this.joinCode(player, wanted);
      if (!r.error) return r;
    }
    return this.quick(player);
  }

  _enter(room, player) {
    room.players.set(player.id, player);
    player.roomId = room.code;
    room.assignDesk(player.id);
    return room;
  }

  leave(player) {
    const room = this.rooms.get(player.roomId);
    if (!room) return null;
    if (room.players.get(player.id) !== player) return room; // já reconectou por outra conexão
    room.players.delete(player.id);
    room.releaseDesk(player.id);
    room.games.leaveAll(player.id);
    if (room.players.size === 0) this.rooms.delete(room.code);
    return room;
  }

  get(code) { return this.rooms.get(code); }

  publicList() {
    return [...this.rooms.values()].map((r) => r.info());
  }
}

module.exports = { RoomManager, Room, MAX_PER_ROOM, DESKS };
