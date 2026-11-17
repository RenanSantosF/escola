'use strict';
// Métricas dos JOGOS (todos os jogos da casa num painel só).
//
// Cada jogo manda, pelo autoload `telemetry.gd`, um lote para
// POST /api/games/events  {game, uid, events:[{type, at, data}]}
//   session_start {sid, version, platform, lang}
//   heartbeat     {sid, seconds}      (a cada minuto, segundos com o app aberto)
//   session_end   {sid, seconds}
//   level         {level, won, score} (fase / partida terminada)
//   event         {name, ...}         (qualquer coisa específica do jogo)
// O id do aparelho (uid) é aleatório: nada de nome, e-mail ou ID de publicidade.
//
// O servidor não guarda cada heartbeat: junta tudo numa linha por SESSÃO
// (início, último sinal, segundos jogados). Assim cabem meses de dados.
// O Recess Club (escola) continua no analytics.js de sempre; as sessões dele
// são montadas a partir daqueles eventos (sessionsFromEscola).

const fs = require('fs');
const path = require('path');

const DAY = 86400000;
const TZ = -3 * 3600000; // Brasília (sem horário de verão desde 2019)
const MAX_SESSION_SEC = 6 * 3600;
const ONLINE_MS = 150000; // sinal nos últimos 2,5 min = jogando agora

/** Jogos conhecidos. A cor segue o jogo (nunca a posição no ranking). */
const GAMES = [
  { id: 'escola', name: 'Recess Club', emoji: '🏫', color: 1 },
  { id: 'aqua-caos', name: 'Aqua Caos', emoji: '🌊', color: 2 },
  { id: 'arrow-survival', name: 'Arrow Survival', emoji: '🏹', color: 3 },
  { id: 'gross-to-glow', name: 'Gross to Glow', emoji: '🧴', color: 4 },
  { id: 'road-rush', name: 'Road Rush 3D', emoji: '🚗', color: 5 },
  { id: 'lanche-em-panico', name: 'Lanche em Pânico', emoji: '🍔', color: 6 },
];
const GAME_IDS = new Set(GAMES.map((g) => g.id));
const EXTERNAL_TYPES = new Set(['session_start', 'heartbeat', 'session_end', 'level', 'event']);

const dayIndex = (ms) => Math.floor((ms + TZ) / DAY);
const dayKey = (idx) => new Date(idx * DAY).toISOString().slice(0, 10);
const r1 = (v) => Math.round(v * 10) / 10;
const pct = (a, b) => (b > 0 ? Math.round((a / b) * 1000) / 10 : null);

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

class GameAnalytics {
  /** opts: {dataDir, onSession(s), onEvent(e), onPlayer(p)} */
  constructor(opts = {}) {
    this.sessions = new Map(); // game|sid -> {game, sid, uid, start, last, seconds, version, platform}
    this.players = new Map(); // game|uid -> {game, uid, first, last}
    this.events = []; // level / event
    this.maxEvents = opts.maxEvents || 200000;
    this.dir = opts.dataDir ?? process.env.DATA_DIR ?? '';
    this.file = this.dir ? path.join(this.dir, 'games.jsonl') : '';
    this.onSession = opts.onSession || null;
    this.onEvent = opts.onEvent || null;
    this.onPlayer = opts.onPlayer || null;
    this._buffer = [];
    if (this.file) this._load();
  }

  _load() {
    try {
      if (!fs.existsSync(this.file)) return;
      for (const l of fs.readFileSync(this.file, 'utf8').split('\n')) {
        if (!l) continue;
        try {
          const b = JSON.parse(l);
          this._apply(b.game, b.uid, b.e, b.now, false);
        } catch { /* linha corrompida */ }
      }
    } catch (e) {
      console.error('game analytics: falha ao carregar', e.message);
    }
  }

  flush() {
    if (!this.file || this._buffer.length === 0) return;
    try {
      fs.mkdirSync(this.dir, { recursive: true });
      fs.appendFileSync(this.file, this._buffer.map((x) => JSON.stringify(x)).join('\n') + '\n');
    } catch (e) {
      console.error('game analytics: falha ao gravar', e.message);
    }
    this._buffer = [];
  }

  /** Carrega o que veio do banco. */
  load({ sessions = [], players = [], events = [] }) {
    for (const s of sessions) this.sessions.set(s.game + '|' + s.sid, s);
    for (const p of players) this.players.set(p.game + '|' + p.uid, p);
    this.events = events.slice(-this.maxEvents);
  }

  /** Recebe um lote de um jogo. Retorna quantos eventos foram aceitos. */
  ingest(game, uid, list, now = Date.now()) {
    if (!GAME_IDS.has(game) || game === 'escola') return 0;
    if (typeof uid !== 'string' || !/^[a-f0-9]{8,40}$/.test(uid) || !Array.isArray(list)) return 0;
    let ok = 0;
    const touched = new Set();
    for (const raw of list.slice(0, 100)) {
      if (!raw || !EXTERNAL_TYPES.has(raw.type)) continue;
      let at = Number(raw.at) || now;
      if (at > now + 60000 || at < now - 7 * DAY) at = now;
      const e = { type: raw.type, at, data: cleanData(raw.data) };
      const changed = this._apply(game, uid, e, now, true);
      if (changed) touched.add(changed);
      if (this.file) this._buffer.push({ game, uid, e, now });
      ok++;
    }
    if (ok) {
      const p = this.players.get(game + '|' + uid);
      if (p && this.onPlayer) this.onPlayer(p);
      if (this.onSession) for (const k of touched) this.onSession(this.sessions.get(k));
    }
    return ok;
  }

  /** Aplica um evento; devolve a chave da sessão alterada (se houver). */
  _apply(game, uid, e, now, live) {
    const pk = game + '|' + uid;
    let p = this.players.get(pk);
    if (!p) { p = { game, uid, first: e.at, last: e.at }; this.players.set(pk, p); }
    p.first = Math.min(p.first, e.at);
    p.last = Math.max(p.last, e.at);
    const d = e.data || {};
    if (e.type === 'level' || e.type === 'event') {
      const ev = { game, uid, at: e.at, type: e.type, data: d };
      this.events.push(ev);
      if (this.events.length > this.maxEvents) this.events.splice(0, this.events.length - this.maxEvents);
      if (live && this.onEvent) this.onEvent(ev);
      return null;
    }
    const sid = String(d.sid || '').replace(/[^a-z0-9]/gi, '').slice(0, 24);
    if (!sid) return null;
    const key = game + '|' + sid;
    const secs = Math.max(0, Math.min(Number(d.seconds) || 0, MAX_SESSION_SEC));
    let s = this.sessions.get(key);
    if (!s) {
      s = { game, sid, uid, start: e.at - secs * 1000, last: e.at, seconds: 0, version: '', platform: '' };
      this.sessions.set(key, s);
    }
    if (s.uid !== uid) return null; // sid de outro aparelho: ignora
    if (e.type === 'session_start') {
      s.start = Math.min(s.start, e.at);
      if (d.version) s.version = String(d.version);
      if (d.platform) s.platform = String(d.platform);
    }
    s.last = Math.max(s.last, e.at);
    s.seconds = Math.max(s.seconds, secs);
    if (e.type === 'session_end') s.ended = true;
    return key;
  }

  /** Sessões, primeiro acesso e eventos de um jogo. */
  dataFor(game) {
    const sessions = [];
    for (const s of this.sessions.values()) if (s.game === game) sessions.push(s);
    const firsts = new Map();
    for (const p of this.players.values()) if (p.game === game) firsts.set(p.uid, p.first);
    return { sessions, firsts, events: this.events.filter((e) => e.game === game) };
  }
}

/** Monta sessões a partir dos eventos do Recess Club (analytics.js). */
function sessionsFromEscola(events) {
  const open = new Map(); // uid -> sessão aberta
  const sessions = [];
  const firsts = new Map();
  const extra = [];
  let n = 0;
  for (const e of events) {
    if (!firsts.has(e.uid) || e.at < firsts.get(e.uid)) firsts.set(e.uid, e.at);
    const d = e.data || {};
    const secs = Math.max(0, Math.min(Number(d.seconds) || 0, MAX_SESSION_SEC));
    if (e.type === 'session_start') {
      const s = { game: 'escola', sid: 'e' + n++, uid: e.uid, start: e.at, last: e.at, seconds: 0, version: String(d.version || ''), platform: String(d.platform || '') };
      sessions.push(s);
      open.set(e.uid, s);
    } else if (e.type === 'heartbeat' || e.type === 'session_end') {
      let s = open.get(e.uid);
      if (!s || e.at - s.last > 30 * 60000) {
        s = { game: 'escola', sid: 'e' + n++, uid: e.uid, start: e.at - secs * 1000, last: e.at, seconds: 0, version: '', platform: '' };
        sessions.push(s);
        open.set(e.uid, s);
      }
      s.last = Math.max(s.last, e.at);
      s.seconds = Math.max(s.seconds, secs);
      if (e.type === 'session_end') open.delete(e.uid);
    } else if (e.type === 'minigame') {
      extra.push({ game: 'escola', uid: e.uid, at: e.at, type: 'level', data: { level: d.id || '?', won: !!d.won } });
    } else if (e.type === 'level_up') {
      extra.push({ game: 'escola', uid: e.uid, at: e.at, type: 'event', data: { name: 'level_up', level: d.level } });
    }
  }
  return { sessions, firsts, events: extra };
}

/**
 * Métricas de um jogo para um período de `days` dias (até hoje).
 * Compara com o período anterior do mesmo tamanho.
 */
function computeGameStats({ sessions, firsts, events = [] }, now = Date.now(), days = 30) {
  days = Math.max(1, Math.min(180, days | 0 || 30));
  const today = dayIndex(now);
  const from = today - days + 1; // primeiro dia do período
  const prevFrom = from - days;

  // dias ativos de cada jogador
  const activeDays = new Map(); // uid -> Set(dayIdx)
  const byDay = new Map(); // dayIdx -> {players:Set, sessions, seconds}
  const hours = Array.from({ length: 7 }, () => new Array(24).fill(0)); // [dia da semana][hora]
  const lens = [];
  const prevLens = [];
  let online = 0;
  const onlineNow = [];
  const versions = new Map();
  const platforms = new Map();
  const perPlayer = new Map(); // uid -> {seconds, sessions} no período
  const firstOf = (uid) => firsts.get(uid) ?? Infinity;

  for (const s of sessions) {
    const di = dayIndex(s.start);
    if (!activeDays.has(s.uid)) activeDays.set(s.uid, new Set());
    activeDays.get(s.uid).add(di);
    const dl = dayIndex(s.last);
    if (dl !== di) activeDays.get(s.uid).add(dl);
    if (now - s.last < ONLINE_MS && !s.ended) { online++; onlineNow.push(s); }
    if (di >= from && di <= today) {
      if (!byDay.has(di)) byDay.set(di, { players: new Set(), sessions: 0, seconds: 0 });
      const b = byDay.get(di);
      b.players.add(s.uid);
      b.sessions++;
      b.seconds += s.seconds;
      lens.push(s.seconds);
      const local = new Date(s.start + TZ);
      hours[local.getUTCDay()][local.getUTCHours()]++;
      const pp = perPlayer.get(s.uid) || { seconds: 0, sessions: 0 };
      pp.seconds += s.seconds;
      pp.sessions++;
      perPlayer.set(s.uid, pp);
      if (s.version) versions.set(s.version, (versions.get(s.version) || 0) + 1);
      if (s.platform) platforms.set(s.platform, (platforms.get(s.platform) || 0) + 1);
    } else if (di >= prevFrom && di < from) {
      prevLens.push(s.seconds);
    }
  }

  const activeIn = (a, b) => {
    let n = 0;
    for (const set of activeDays.values()) { for (const d of set) { if (d >= a && d <= b) { n++; break; } } }
    return n;
  };
  const newIn = (a, b) => {
    let n = 0;
    for (const f of firsts.values()) { const d = dayIndex(f); if (d >= a && d <= b) n++; }
    return n;
  };
  const median = (arr) => { if (!arr.length) return 0; const s = [...arr].sort((x, y) => x - y); return s[Math.floor(s.length / 2)]; };
  const avg = (arr) => (arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : 0);

  // Retenção clássica: % dos novos do dia D que voltaram no dia D+N.
  // `cohortFrom..cohortTo` = dias em que os jogadores entraram pela primeira vez.
  function retention(n, cohortFrom, cohortTo) {
    let base = 0;
    let back = 0;
    for (const [uid, f] of firsts) {
      const d0 = dayIndex(f);
      if (d0 < cohortFrom || d0 > cohortTo || d0 + n > today) continue;
      base++;
      const set = activeDays.get(uid);
      if (set && set.has(d0 + n)) back++;
    }
    return { pct: pct(back, base), base };
  }
  // para D1, a coorte é quem entrou no período (até ontem); período anterior idem
  const ret = {};
  for (const n of [1, 3, 7, 14, 30]) {
    const cur = retention(n, from - n, today - n);
    const prev = retention(n, prevFrom - n, from - 1 - n);
    ret['d' + n] = { pct: cur.pct, base: cur.base, prev: prev.pct };
  }
  // curva de retenção D0..D30 (todos os jogadores conhecidos)
  const curve = [];
  for (let n = 0; n <= 30; n++) {
    const r = retention(n, -Infinity, today);
    curve.push({ day: n, pct: n === 0 ? (r.base ? 100 : null) : r.pct, base: r.base });
  }

  // série diária
  const daily = [];
  const newByDay = new Map();
  for (const f of firsts.values()) { const d = dayIndex(f); newByDay.set(d, (newByDay.get(d) || 0) + 1); }
  for (let d = from; d <= today; d++) {
    const b = byDay.get(d);
    const active = b ? b.players.size : 0;
    const nw = newByDay.get(d) || 0;
    const r = retention(1, d, d);
    daily.push({
      day: dayKey(d), active, new: Math.min(nw, active), returning: Math.max(0, active - nw),
      sessions: b ? b.sessions : 0, minutes: b ? Math.round(b.seconds / 60) : 0,
      avgMin: b && b.sessions ? r1(b.seconds / b.sessions / 60) : 0, d1: r.pct,
    });
  }

  // coortes semanais (8 semanas): % ativo em cada semana seguinte
  const cohorts = [];
  for (let w = 7; w >= 0; w--) {
    const a = today - (w + 1) * 7 + 1;
    const b = a + 6;
    const members = [];
    for (const [uid, f] of firsts) { const d = dayIndex(f); if (d >= a && d <= b) members.push(uid); }
    const weeks = [];
    for (let k = 1; k <= 7 && a + k * 7 <= today; k++) {
      let back = 0;
      for (const uid of members) {
        const set = activeDays.get(uid);
        if (!set) continue;
        for (let d = a + k * 7; d <= Math.min(b + k * 7, today); d++) { if (set.has(d)) { back++; break; } }
      }
      weeks.push(members.length ? Math.round((back / members.length) * 100) : null);
    }
    cohorts.push({ week: dayKey(a), size: members.length, weeks });
  }

  // duração das sessões
  const buckets = [['< 1 min', 60], ['1–3 min', 180], ['3–5 min', 300], ['5–10 min', 600], ['10–20 min', 1200], ['20–40 min', 2400], ['40+ min', Infinity]];
  const lenBuckets = buckets.map(([label]) => ({ label, count: 0 }));
  for (const s of lens) lenBuckets[buckets.findIndex(([, max]) => s < max)].count++;

  // sessões recentes (quem entrou e que horas)
  const sessionsSoFar = new Map();
  const sorted = [...sessions].sort((x, y) => x.start - y.start);
  const nth = new Map();
  for (const s of sorted) { const k = (sessionsSoFar.get(s.uid) || 0) + 1; sessionsSoFar.set(s.uid, k); nth.set(s, k); }
  const recent = sorted.slice(-60).reverse().map((s) => ({
    who: s.uid.slice(0, 6), start: s.start, minutes: r1(s.seconds / 60), version: s.version, platform: s.platform,
    nth: nth.get(s), firstDay: dayIndex(firstOf(s.uid)) === dayIndex(s.start), online: now - s.last < ONLINE_MS && !s.ended,
  }));

  // jogadores mais dedicados no período
  const top = [...perPlayer.entries()].sort((a, b) => b[1].seconds - a[1].seconds).slice(0, 15).map(([uid, v]) => ({
    who: uid.slice(0, 6), minutes: Math.round(v.seconds / 60), sessions: v.sessions,
    days: [...(activeDays.get(uid) || [])].filter((d) => d >= from).length, since: firstOf(uid),
  }));

  // fases / partidas
  const levels = new Map();
  const custom = new Map();
  for (const e of events) {
    if (dayIndex(e.at) < from) continue;
    if (e.type === 'level') {
      const id = String(e.data.level ?? '?');
      const l = levels.get(id) || { level: id, plays: 0, wins: 0, players: new Set(), score: 0 };
      l.plays++;
      if (e.data.won) l.wins++;
      l.players.add(e.uid);
      l.score += Number(e.data.score) || 0;
      levels.set(id, l);
    } else {
      const name = String(e.data.name || '?');
      custom.set(name, (custom.get(name) || 0) + 1);
    }
  }
  const levelList = [...levels.values()].map((l) => ({ level: l.level, plays: l.plays, players: l.players.size, winPct: Math.round((l.wins / l.plays) * 100), avgScore: Math.round(l.score / l.plays) }))
    .sort((a, b) => (isNaN(a.level) || isNaN(b.level) ? b.plays - a.plays : Number(a.level) - Number(b.level)));

  const active = activeIn(from, today);
  const prevActive = activeIn(prevFrom, from - 1);
  const totalSec = lens.reduce((a, b) => a + b, 0);
  const prevSec = prevLens.reduce((a, b) => a + b, 0);
  const dau = activeIn(today, today);
  const mau = activeIn(today - 29, today);
  const avgDau = avg(daily.map((d) => d.active));

  return {
    days,
    from: dayKey(from),
    online,
    players: {
      total: firsts.size,
      active, prevActive,
      new: newIn(from, today), prevNew: newIn(prevFrom, from - 1),
      dau, wau: activeIn(today - 6, today), mau,
      stickiness: mau ? Math.round((avgDau / mau) * 100) : 0,
    },
    sessions: {
      count: lens.length, prevCount: prevLens.length,
      avgMin: r1(avg(lens) / 60), prevAvgMin: r1(avg(prevLens) / 60),
      medianMin: r1(median(lens) / 60),
      hours: r1(totalSec / 3600), prevHours: r1(prevSec / 3600),
      perPlayer: active ? r1(lens.length / active) : 0,
      minPerPlayer: active ? r1(totalSec / 60 / active) : 0,
    },
    retention: ret,
    curve,
    daily,
    hours,
    cohorts,
    lenBuckets,
    recent,
    top,
    online_now: onlineNow.slice(0, 30).map((s) => ({ who: s.uid.slice(0, 6), start: s.start, minutes: r1(s.seconds / 60) })),
    versions: [...versions.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8),
    platforms: [...platforms.entries()].sort((a, b) => b[1] - a[1]),
    levels: levelList.slice(0, 40),
    custom: [...custom.entries()].sort((a, b) => b[1] - a[1]).slice(0, 20),
  };
}

/** Comparação de todos os jogos (últimos 7 dias contra os 7 anteriores). */
function compareGames(dataByGame, now = Date.now()) {
  const list = GAMES.map((g) => {
    const st = computeGameStats(dataByGame[g.id] || { sessions: [], firsts: new Map() }, now, 7);
    const growth = st.players.prevActive ? Math.round(((st.players.active - st.players.prevActive) / st.players.prevActive) * 100) : (st.players.active ? null : 0);
    return {
      ...g,
      online: st.online,
      total: st.players.total,
      active7: st.players.active, prevActive7: st.players.prevActive, growth,
      new7: st.players.new, dau: st.players.dau,
      avgMin: st.sessions.avgMin, minPerPlayer: st.sessions.minPerPlayer,
      hours7: st.sessions.hours, sessions7: st.sessions.count,
      d1: st.retention.d1.pct, d1prev: st.retention.d1.prev, d7: st.retention.d7.pct,
      daily: st.daily.map((d) => d.active),
    };
  });
  // nota de destaque 0–100: alcance (jogadores ativos), engajamento
  // (minutos por jogador), retenção D1 e crescimento — cada um relativo ao
  // melhor jogo da casa
  const maxOf = (k) => Math.max(1, ...list.map((x) => Number(x[k]) || 0));
  const mA = maxOf('active7');
  const mM = maxOf('minPerPlayer');
  const mD = maxOf('d1');
  for (const x of list) {
    const g = Math.max(-100, Math.min(100, x.growth ?? 0));
    x.score = x.active7 ? Math.round(35 * (x.active7 / mA) + 25 * (x.minPerPlayer / mM) + 25 * ((x.d1 || 0) / mD) + 15 * ((g + 100) / 200)) : 0;
  }
  const days = [];
  for (let d = dayIndex(now) - 13; d <= dayIndex(now); d++) days.push(dayKey(d));
  // série de 14 dias para o gráfico comparativo
  for (const x of list) {
    const st = computeGameStats(dataByGame[x.id] || { sessions: [], firsts: new Map() }, now, 14);
    x.daily14 = st.daily.map((d) => d.active);
    x.minutes14 = st.daily.map((d) => d.minutes);
  }
  return { generatedAt: new Date(now).toISOString(), days, games: list.sort((a, b) => b.score - a.score || b.active7 - a.active7) };
}

module.exports = { GameAnalytics, GAMES, GAME_IDS, computeGameStats, compareGames, sessionsFromEscola, dayIndex };
