'use strict';
// Estatísticas ANÔNIMAS do jogo para o painel do administrador.
// Cada aparelho tem um id aleatório (sem nome, e-mail, telefone ou
// localização). Eventos: session_start, session_end, purchase, level_up,
// minigame, quest_done, day_done.
// Persistência: se DATA_DIR existir (volume do Railway), grava em
// DATA_DIR/events.jsonl e recarrega ao reiniciar. Sem volume, fica em memória.

const fs = require('fs');
const path = require('path');

const TYPES = new Set(['session_start', 'session_end', 'purchase', 'level_up', 'minigame', 'quest_done', 'day_done', 'heartbeat']);
const MAX_EVENTS = 300000;
const DAY = 86400000;

function cleanData(d) {
  const out = {};
  if (!d || typeof d !== 'object') return out;
  let n = 0;
  for (const [k, v] of Object.entries(d)) {
    if (n++ > 12) break;
    const key = String(k).slice(0, 24);
    if (typeof v === 'number' && Number.isFinite(v)) out[key] = Math.round(v * 100) / 100;
    else if (typeof v === 'boolean') out[key] = v;
    else if (typeof v === 'string') out[key] = v.slice(0, 48);
  }
  return out;
}

class Analytics {
  constructor(opts = {}) {
    this.events = [];
    this.dir = opts.dataDir ?? process.env.DATA_DIR ?? '';
    this.file = this.dir ? path.join(this.dir, 'events.jsonl') : '';
    this._buffer = [];
    if (this.file) this._load();
  }

  _load() {
    try {
      if (!fs.existsSync(this.file)) return;
      const lines = fs.readFileSync(this.file, 'utf8').split('\n');
      for (const l of lines.slice(-MAX_EVENTS)) {
        if (!l) continue;
        try { this.events.push(JSON.parse(l)); } catch { /* linha corrompida */ }
      }
    } catch (e) {
      console.error('analytics: falha ao carregar', e.message);
    }
  }

  flush() {
    if (!this.file || this._buffer.length === 0) return;
    try {
      fs.mkdirSync(this.dir, { recursive: true });
      fs.appendFileSync(this.file, this._buffer.map((e) => JSON.stringify(e)).join('\n') + '\n');
    } catch (e) {
      console.error('analytics: falha ao gravar', e.message);
    }
    this._buffer = [];
  }

  /** Recebe um lote do aparelho. Retorna quantos eventos foram aceitos. */
  ingest(uid, list, now = Date.now()) {
    if (typeof uid !== 'string' || !/^[a-f0-9]{8,40}$/.test(uid) || !Array.isArray(list)) return 0;
    let ok = 0;
    for (const e of list.slice(0, 100)) {
      if (!e || !TYPES.has(e.type)) continue;
      // horário do aparelho só é aceito se plausível (até 7 dias atrás)
      let at = Number(e.at) || now;
      if (at > now + 60000 || at < now - 7 * DAY) at = now;
      const ev = { at, uid, type: e.type, data: cleanData(e.data) };
      this.events.push(ev);
      this._buffer.push(ev);
      ok++;
    }
    if (this.events.length > MAX_EVENTS) this.events.splice(0, this.events.length - MAX_EVENTS);
    return ok;
  }

  /** Agregados para o painel. `live` = {online, rooms, reports}. */
  stats(live = {}, now = Date.now()) {
    const players = new Map(); // uid -> {age, level, first, last, sessions, seconds, spent}
    const p = (uid) => {
      if (!players.has(uid)) players.set(uid, { age: 0, level: 1, first: Infinity, last: 0, sessions: 0, seconds: 0, spent: 0, purchases: 0 });
      return players.get(uid);
    };
    const purchases = [];
    const items = new Map();
    const games = new Map();
    const quests = new Map();
    const days = new Map(); // yyyy-mm-dd -> {players:Set, sessions, seconds}
    const sessionLens = [];
    const hours = new Array(24).fill(0);
    for (const e of this.events) {
      const pl = p(e.uid);
      pl.first = Math.min(pl.first, e.at);
      pl.last = Math.max(pl.last, e.at);
      const dkey = new Date(e.at).toISOString().slice(0, 10);
      if (!days.has(dkey)) days.set(dkey, { players: new Set(), sessions: 0, seconds: 0, coins: 0 });
      const dd = days.get(dkey);
      dd.players.add(e.uid);
      const d = e.data || {};
      switch (e.type) {
        case 'session_start':
          pl.sessions++;
          dd.sessions++;
          if (d.age) pl.age = d.age;
          if (d.level) pl.level = Math.max(pl.level, d.level);
          hours[new Date(e.at).getUTCHours()]++;
          break;
        case 'session_end': {
          const s = Math.max(0, Math.min(Number(d.seconds) || 0, 6 * 3600));
          pl.seconds += s;
          dd.seconds += s;
          sessionLens.push(s);
          break;
        }
        case 'level_up':
          if (d.level) pl.level = Math.max(pl.level, d.level);
          break;
        case 'purchase': {
          const price = Number(d.price) || 0;
          pl.spent += price;
          pl.purchases++;
          dd.coins += price;
          purchases.push({ at: e.at, item: d.name || d.item || '?', category: d.category || '', price, age: pl.age });
          const it = items.get(d.item) || { item: d.item, name: d.name || d.item, category: d.category || '', count: 0, coins: 0, price };
          it.count++;
          it.coins += price;
          items.set(d.item, it);
          break;
        }
        case 'minigame': {
          const g = games.get(d.id) || { id: d.id, plays: 0, wins: 0 };
          g.plays++;
          if (d.won) g.wins++;
          games.set(d.id, g);
          break;
        }
        case 'quest_done': {
          quests.set(d.id, (quests.get(d.id) || 0) + 1);
          break;
        }
      }
    }
    const all = [...players.values()];
    const ages = {};
    const levels = {};
    const timeByAge = {};
    for (const pl of all) {
      const a = pl.age || 0;
      ages[a] = (ages[a] || 0) + 1;
      const lb = pl.level >= 10 ? '10+' : String(pl.level);
      levels[lb] = (levels[lb] || 0) + 1;
      if (pl.sessions > 0) {
        timeByAge[a] = timeByAge[a] || { players: 0, seconds: 0 };
        timeByAge[a].players++;
        timeByAge[a].seconds += pl.seconds;
      }
    }
    sessionLens.sort((x, y) => x - y);
    const median = sessionLens.length ? sessionLens[Math.floor(sessionLens.length / 2)] : 0;
    const totalSec = sessionLens.reduce((s, v) => s + v, 0);
    const last14 = [];
    for (let i = 13; i >= 0; i--) {
      const k = new Date(now - i * DAY).toISOString().slice(0, 10);
      const dd = days.get(k);
      last14.push({ day: k, players: dd ? dd.players.size : 0, sessions: dd ? dd.sessions : 0, minutes: dd ? Math.round(dd.seconds / 60) : 0, coins: dd ? dd.coins : 0 });
    }
    const byPrice = [...purchases].sort((a, b) => b.price - a.price);
    const itemList = [...items.values()];
    const active = (ms) => all.filter((x) => now - x.last < ms).length;
    const retained = all.filter((x) => x.last - x.first > DAY).length;
    return {
      generatedAt: new Date(now).toISOString(),
      live: { online: live.online || 0, rooms: live.rooms || 0, reports: live.reports || 0 },
      players: {
        total: all.length,
        active24h: active(DAY),
        active7d: active(7 * DAY),
        new24h: all.filter((x) => now - x.first < DAY).length,
        returning: retained,
        retentionPct: all.length ? Math.round((retained / all.length) * 100) : 0,
      },
      ages,
      levels,
      sessions: {
        count: sessionLens.length,
        avgMinutes: sessionLens.length ? Math.round((totalSec / sessionLens.length / 60) * 10) / 10 : 0,
        medianMinutes: Math.round((median / 60) * 10) / 10,
        totalHours: Math.round((totalSec / 3600) * 10) / 10,
        byHourUTC: hours,
      },
      timeByAge: Object.fromEntries(Object.entries(timeByAge).map(([a, v]) => [a, Math.round(v.seconds / v.players / 60)])),
      days: last14,
      purchases: {
        count: purchases.length,
        coins: purchases.reduce((s, x) => s + x.price, 0),
        buyersPct: all.length ? Math.round((all.filter((x) => x.purchases > 0).length / all.length) * 100) : 0,
        biggest: byPrice.slice(0, 10),
        smallest: byPrice.slice(-10).reverse(),
        recent: purchases.slice(-15).reverse(),
        topItems: [...itemList].sort((a, b) => b.count - a.count).slice(0, 12),
        topCoins: [...itemList].sort((a, b) => b.coins - a.coins).slice(0, 12),
        byCategory: itemList.reduce((acc, it) => { acc[it.category || 'outros'] = (acc[it.category || 'outros'] || 0) + it.coins; return acc; }, {}),
      },
      minigames: [...games.values()].sort((a, b) => b.plays - a.plays),
      quests: [...quests.entries()].map(([id, n]) => ({ id, count: n })).sort((a, b) => b.count - a.count).slice(0, 15),
    };
  }
}

module.exports = { Analytics, TYPES };
