'use strict';
// Pique-pega online, decidido pelo servidor (ninguém trapaceia o "peguei").
// Fluxo: alguém CHAMA (convite para a sala toda) -> quem quiser ENTRA ->
// depois de 20 s (ou quando quem chamou toca em Começar) sorteia o pegador ->
// 2 minutos de jogo -> quem passou MENOS tempo como pegador ganha.
// Regras: encostar (< 1,4 m) passa o pegador; quem acabou de ser pego tem
// 3 s de imunidade de volta ("não vale pegar de volta").

const LOBBY_MS = 20000;
const GAME_MS = 120000;
const TAG_DIST = 1.4;
const BACK_IMMUNITY_MS = 3000;
const TAG_COOLDOWN_MS = 1200;
const MIN_PLAYERS = 2;

class TagGame {
  constructor(room, now = Date.now()) {
    this.room = room;
    this.state = 'lobby';
    this.host = null;
    this.players = new Set();
    this.it = null;
    this.lastTagger = null;
    this.lastTagAt = 0;
    this.itSince = 0;
    this.timeIt = new Map();
    this.tags = new Map();
    this.lobbyEnds = now + LOBBY_MS;
    this.ends = 0;
  }

  invite(id, now = Date.now()) {
    this.host = id;
    this.players.add(id);
    this.lobbyEnds = now + LOBBY_MS;
  }

  join(id) {
    if (this.state !== 'lobby' && this.state !== 'playing') return false;
    this.players.add(id);
    if (!this.timeIt.has(id)) this.timeIt.set(id, 0);
    return true;
  }

  leave(id, now = Date.now()) {
    this.players.delete(id);
    if (this.state === 'playing' && this.it === id) this._pickIt(now, null);
    if (this.state === 'playing' && this.players.size < MIN_PLAYERS) this.ends = now; // acaba
  }

  start(now = Date.now()) {
    if (this.players.size < MIN_PLAYERS) return false;
    this.state = 'playing';
    this.ends = now + GAME_MS;
    for (const id of this.players) {
      this.timeIt.set(id, 0);
      this.tags.set(id, 0);
    }
    this._pickIt(now, null);
    return true;
  }

  _pickIt(now, exclude) {
    const list = [...this.players].filter((p) => p !== exclude);
    if (list.length === 0) { this.it = null; return; }
    this.it = list[Math.floor(Math.random() * list.length)];
    this.itSince = now;
    this.lastTagger = null;
    this.lastTagAt = now;
  }

  /**
   * Avança o jogo. `pos(id)` devolve [x,y,z] do jogador.
   * Retorna eventos: {kind:'start'|'tagged'|'end'|'cancel', ...}
   */
  tick(pos, now = Date.now()) {
    const ev = [];
    if (this.state === 'lobby') {
      if (now >= this.lobbyEnds) {
        if (this.start(now)) ev.push({ kind: 'start', it: this.it });
        else { this.state = 'over'; ev.push({ kind: 'cancel', text: 'Pique-pega cancelado: precisa de pelo menos 2 jogadores.' }); }
      }
      return ev;
    }
    if (this.state !== 'playing') return ev;
    // tempo como pegador
    if (this.it && this.timeIt.has(this.it)) {
      this.timeIt.set(this.it, this.timeIt.get(this.it) + (now - this.itSince));
      this.itSince = now;
    }
    if (now >= this.ends) {
      this.state = 'over';
      ev.push({ kind: 'end', results: this.results() });
      return ev;
    }
    if (!this.it || now - this.lastTagAt < TAG_COOLDOWN_MS) return ev;
    const a = pos(this.it);
    if (!a) return ev;
    let best = null;
    let bestD = TAG_DIST;
    for (const id of this.players) {
      if (id === this.it) continue;
      if (id === this.lastTagger && now - this.lastTagAt < BACK_IMMUNITY_MS) continue;
      const b = pos(id);
      if (!b) continue;
      const d = Math.hypot(a[0] - b[0], a[2] - b[2]);
      if (Math.abs(a[1] - b[1]) < 1.5 && d < bestD) { bestD = d; best = id; }
    }
    if (best) {
      const from = this.it;
      this.tags.set(from, (this.tags.get(from) || 0) + 1);
      this.it = best;
      this.itSince = now;
      this.lastTagger = from;
      this.lastTagAt = now;
      ev.push({ kind: 'tagged', from, to: best });
    }
    return ev;
  }

  results() {
    return [...this.players].map((id) => ({ id, secondsIt: Math.round((this.timeIt.get(id) || 0) / 1000), tags: this.tags.get(id) || 0 }))
      .sort((x, y) => x.secondsIt - y.secondsIt || y.tags - x.tags);
  }

  snapshot(now = Date.now()) {
    return {
      state: this.state, host: this.host, players: [...this.players], it: this.it,
      lobbyLeft: this.state === 'lobby' ? Math.max(0, Math.ceil((this.lobbyEnds - now) / 1000)) : 0,
      left: this.state === 'playing' ? Math.max(0, Math.ceil((this.ends - now) / 1000)) : 0,
    };
  }
}

module.exports = { TagGame, LOBBY_MS, GAME_MS, TAG_DIST, MIN_PLAYERS };
