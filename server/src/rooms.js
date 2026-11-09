'use strict';
// Salas ("turmas"): cada sala tem até MAX jogadores; quem entra no meio da
// partida recebe o estado atual (jogadores, fase do dia) imediatamente.

const MAX_PER_ROOM = 20;

class Room {
  constructor(id) {
    this.id = id;
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
}

class RoomManager {
  constructor() {
    this.rooms = new Map();
  }
  /** Entra numa sala com vaga (ou cria). Prefere a sala pedida. */
  join(player, wanted) {
    let room = wanted ? this.rooms.get(wanted) : null;
    if (!room || room.players.size >= MAX_PER_ROOM) {
      room = null;
      for (const r of this.rooms.values()) {
        if (r.players.size < MAX_PER_ROOM) { room = r; break; }
      }
    }
    if (!room) {
      const id = wanted && !this.rooms.has(wanted) ? wanted : 'sala-' + (this.rooms.size + 1);
      room = new Room(id);
      this.rooms.set(id, room);
    }
    room.players.set(player.id, player);
    player.roomId = room.id;
    return room;
  }
  leave(player) {
    const room = this.rooms.get(player.roomId);
    if (!room) return null;
    room.players.delete(player.id);
    if (room.players.size === 0) this.rooms.delete(room.id);
    return room;
  }
  get(id) { return this.rooms.get(id); }
}

module.exports = { RoomManager, Room, MAX_PER_ROOM };
