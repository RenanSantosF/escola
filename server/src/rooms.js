'use strict';
// Salas ("turmas"): até MAX jogadores. Cada sala tem um código de 4 números
// (fácil para criança digitar). Salas criadas por um jogador são PRIVADAS:
// só entra quem tem o código. A entrada rápida usa salas públicas.
// Quem entra no meio da partida recebe o estado atual imediatamente.

const crypto = require('crypto');

const MAX_PER_ROOM = 20;

class Room {
  constructor(id, code, isPrivate = false, owner = null) {
    this.id = id;
    this.code = code;
    this.private = isPrivate;
    this.owner = owner;
    this.players = new Map(); // id -> {id, name, level, look, pos, yaw, anim, ws}
    this.phase = 'recreio';
    this.createdAt = Date.now();
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
    return { code: this.code, players: this.players.size, max: MAX_PER_ROOM, private: this.private };
  }
}

class RoomManager {
  constructor() {
    this.rooms = new Map(); // code -> Room
  }
  _newCode() {
    for (let i = 0; i < 200; i++) {
      const c = String(crypto.randomInt(1000, 9999));
      if (!this.rooms.has(c)) return c;
    }
    return String(Date.now() % 100000);
  }
  /** Cria uma sala (privada por padrão) e coloca o jogador nela. */
  create(player, isPrivate = true) {
    const code = this._newCode();
    const room = new Room('sala-' + code, code, isPrivate, player.id);
    this.rooms.set(code, room);
    return this._enter(room, player);
  }
  /** Entra pelo código; null se não existe ou está cheia. */
  joinCode(player, code) {
    const room = this.rooms.get(String(code || '').trim());
    if (!room) return { error: 'Sala não encontrada. Confira o código.' };
    if (room.players.size >= MAX_PER_ROOM) return { error: 'Essa sala está cheia.' };
    return this._enter(room, player);
  }
  /** Entrada rápida: a sala pública mais cheia com vaga (ou cria uma). */
  quick(player) {
    let best = null;
    for (const r of this.rooms.values()) {
      if (r.private || r.players.size >= MAX_PER_ROOM) continue;
      if (!best || r.players.size > best.players.size) best = r;
    }
    if (!best) return this.create(player, false);
    return this._enter(best, player);
  }
  /** Compatibilidade: join(player, wanted) = código se existir, senão rápida. */
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
    return room;
  }
  leave(player) {
    const room = this.rooms.get(player.roomId);
    if (!room) return null;
    room.players.delete(player.id);
    if (room.players.size === 0) this.rooms.delete(room.code);
    return room;
  }
  get(code) { return this.rooms.get(code); }
  publicList() {
    return [...this.rooms.values()].filter((r) => !r.private).map((r) => r.info());
  }
}

module.exports = { RoomManager, Room, MAX_PER_ROOM };
