'use strict';
// Investimento em divulgação (Google Ads) x retorno (AdMob) de cada jogo.
//
// O administrador lança, pelo painel, quanto investiu num jogo num período
// (de/até) e, se já souber, quanto o AdMob pagou desse jogo no mesmo período.
// O servidor cruza com as estatísticas anônimas que o próprio jogo manda:
//   - quantos jogadores NOVOS chegaram no período (custo por jogador)
//   - quanto tempo eles jogam e se voltam no dia seguinte (D1)
// Quando a receita de um lançamento não foi informada, ela é ESTIMADA pelo
// valor de cada minuto jogado nos lançamentos que têm receita (média da casa).
// No fim, cada jogo recebe um veredito e uma fatia sugerida do próximo orçamento.

const fs = require('fs');
const path = require('path');
const { dayIndex } = require('./game_stats');

const DAY = 86400000;
const MAX_ENTRIES = 500;
const r2 = (v) => Math.round(v * 100) / 100;

/** 'AAAA-MM-DD' -> índice do dia (mesma escala de dayIndex), ou null. */
function parseDay(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || ''));
  if (!m) return null;
  const t = Date.UTC(+m[1], +m[2] - 1, +m[3]);
  return Number.isFinite(t) ? Math.floor(t / DAY) : null;
}
const money = (v) => {
  if (v === '' || v == null) return null;
  const n = Number(String(v).replace(',', '.'));
  return Number.isFinite(n) && n >= 0 ? r2(Math.min(n, 1e8)) : null;
};

/** Valida um lançamento vindo do painel. Devolve {entry} ou {error}. */
function cleanEntry(b, gameIds) {
  b = b || {};
  const game = String(b.game || '');
  if (!gameIds.has(game)) return { error: 'Escolha o jogo.' };
  const a = parseDay(b.from);
  const z = parseDay(b.to);
  if (a == null || z == null) return { error: 'Informe as datas (de / até).' };
  if (z < a) return { error: 'A data final vem antes da inicial.' };
  if (z - a > 366) return { error: 'Use períodos de até 1 ano.' };
  const spend = money(b.spend);
  if (spend == null) return { error: 'Informe quanto investiu (pode ser 0).' };
  const id = String(b.id || '').replace(/[^a-z0-9]/gi, '').slice(0, 16) || Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  return {
    entry: {
      id, game, from: String(b.from), to: String(b.to), spend,
      revenue: money(b.revenue),
      installs: b.installs === '' || b.installs == null ? null : Math.max(0, Math.round(Number(b.installs) || 0)),
      note: String(b.note || '').slice(0, 80),
    },
  };
}

/** Jogadores que chegaram / jogaram entre os dias a..b (inclusive). */
function measure({ sessions, firsts }, a, b, today) {
  const activeDays = new Map();
  let seconds = 0;
  const active = new Set();
  for (const s of sessions) {
    const d = dayIndex(s.start);
    if (!activeDays.has(s.uid)) activeDays.set(s.uid, new Set());
    activeDays.get(s.uid).add(d);
    if (d >= a && d <= b) { active.add(s.uid); seconds += s.seconds; }
  }
  let newPlayers = 0;
  let base = 0;
  let back = 0;
  let newSeconds = 0;
  const news = new Set();
  for (const [uid, f] of firsts) {
    const d0 = dayIndex(f);
    if (d0 < a || d0 > b) continue;
    newPlayers++;
    news.add(uid);
    if (d0 + 1 > today) continue;
    base++;
    const set = activeDays.get(uid);
    if (set && set.has(d0 + 1)) back++;
  }
  for (const s of sessions) if (news.has(s.uid)) newSeconds += s.seconds; // tudo que os novos jogaram até hoje
  return {
    newPlayers, activePlayers: active.size, minutes: Math.round(seconds / 60),
    newMinutes: Math.round(newSeconds / 60), d1: base ? Math.round((back / base) * 1000) / 10 : null, d1Base: base,
  };
}

const VERDICTS = {
  investir_mais: { label: 'Investir mais', emoji: '🚀', tone: 'up' },
  manter: { label: 'Manter', emoji: '✅', tone: 'ok' },
  ajustar: { label: 'Ajustar antes', emoji: '🛠️', tone: 'warn' },
  pausar: { label: 'Pausar', emoji: '⛔', tone: 'down' },
  testar: { label: 'Testar com pouco', emoji: '🧪', tone: 'info' },
  sem_receita: { label: 'Falta a receita', emoji: '❓', tone: 'flat' },
  aguardar: { label: 'Aguardar', emoji: '⏳', tone: 'flat' },
};

/**
 * entries: lançamentos; dataFor(game) -> {sessions, firsts}; quality: {gameId: nota 0-100}
 * games: [{id, name, emoji, color}]
 */
function analyze(entries, games, dataFor, quality = {}, now = Date.now()) {
  const today = dayIndex(now);
  const cache = new Map();
  const data = (g) => { if (!cache.has(g)) cache.set(g, dataFor(g)); return cache.get(g); };
  const rows = entries.map((e) => {
    const m = measure(data(e.game), parseDay(e.from), Math.min(parseDay(e.to), today), today);
    return { ...e, ...m, days: parseDay(e.to) - parseDay(e.from) + 1, future: parseDay(e.from) > today };
  });
  // valor médio de 1 minuto jogado (só lançamentos com receita e minutos)
  let revKnown = 0;
  let minKnown = 0;
  for (const r of rows) if (r.revenue != null && r.minutes > 0) { revKnown += r.revenue; minKnown += r.minutes; }
  const revPerMin = minKnown > 0 ? revKnown / minKnown : null;
  for (const r of rows) {
    r.estimated = r.revenue == null;
    r.rev = r.revenue != null ? r.revenue : (revPerMin != null ? r2(r.minutes * revPerMin) : null);
    r.cpi = r.newPlayers > 0 ? r2(r.spend / r.newPlayers) : null;
    r.roi = r.rev != null && r.spend > 0 ? Math.round(((r.rev - r.spend) / r.spend) * 1000) / 10 : null;
  }

  const summary = games.map((g) => {
    const mine = rows.filter((r) => r.game === g.id);
    const sum = (k) => mine.reduce((a, r) => a + (Number(r[k]) || 0), 0);
    const spend = r2(sum('spend'));
    const known = mine.filter((r) => r.rev != null);
    const rev = known.length ? r2(known.reduce((a, r) => a + r.rev, 0)) : null;
    const estimated = mine.some((r) => r.estimated && r.rev != null);
    const newPlayers = sum('newPlayers');
    const minutes = sum('minutes');
    const activePlayers = sum('activePlayers');
    const d1Base = sum('d1Base');
    const d1 = d1Base ? Math.round((mine.reduce((a, r) => a + (r.d1 || 0) * r.d1Base, 0) / d1Base) * 10) / 10 : null;
    const cpi = newPlayers > 0 && spend > 0 ? r2(spend / newPlayers) : null;
    const spendKnown = known.reduce((a, r) => a + r.spend, 0);
    const roi = rev != null && spendKnown > 0 ? Math.round(((rev - spendKnown) / spendKnown) * 1000) / 10 : null;
    const profit = rev != null ? r2(rev - spendKnown) : null;
    const revPerPlayer = rev != null && activePlayers > 0 ? Math.round((rev / activePlayers) * 1000) / 1000 : null;
    const minPerPlayer = activePlayers > 0 ? Math.round((minutes / activePlayers) * 10) / 10 : null;
    const q = quality[g.id] || 0;
    let verdict;
    let why;
    if (!mine.length || spend === 0) {
      if (q >= 50) { verdict = 'testar'; why = `Joga bem sem divulgação (nota ${q}/100). Vale testar um valor pequeno.`; }
      else { verdict = 'aguardar'; why = mine.length ? 'Sem investimento lançado ainda.' : 'Nenhum investimento lançado para este jogo.'; }
    } else if (newPlayers === 0) {
      verdict = 'pausar';
      why = 'Investiu e nenhum jogador novo apareceu nas estatísticas. Confira se a campanha está rodando e se esta versão do jogo envia estatísticas.';
    } else if (roi == null) {
      verdict = 'sem_receita';
      why = 'Informe quanto o AdMob pagou neste período para calcular o retorno.';
    } else if (roi >= 30) {
      verdict = 'investir_mais'; why = `Cada R$ 1 investido voltou R$ ${(1 + roi / 100).toFixed(2).replace('.', ',')}.`;
    } else if (roi >= 0) {
      verdict = 'manter'; why = 'Já se paga, mas ainda com pouca sobra. Mantenha e melhore os anúncios.';
    } else if (roi >= -50 || (d1 != null && d1 >= 30)) {
      verdict = 'ajustar';
      why = roi >= -50 ? 'Recupera parte do que investe. Melhore a retenção e os anúncios do jogo antes de colocar mais.'
        : 'Ainda dá prejuízo, mas os jogadores voltam bem: o problema pode ser poucos anúncios no jogo.';
    } else {
      verdict = 'pausar'; why = 'Recupera menos da metade do que investe.';
    }
    return {
      ...g, entries: mine.length, spend, revenue: rev, estimated, profit, roi, cpi, newPlayers, activePlayers, minutes,
      minPerPlayer, revPerPlayer, d1, quality: q, verdict, ...VERDICTS[verdict], why,
    };
  });

  // fatia sugerida do próximo orçamento
  const weight = (s) => {
    const roiF = s.roi == null ? 1 : Math.max(0, 1 + s.roi / 100);
    const ret = 0.6 + (s.d1 || 0) / 100;
    if (s.verdict === 'investir_mais') return 2 * roiF * ret;
    if (s.verdict === 'manter') return roiF * ret;
    if (s.verdict === 'ajustar') return 0.25;
    if (s.verdict === 'testar') return 0.35;
    if (s.verdict === 'sem_receita') return 0.3;
    return 0;
  };
  const total = summary.reduce((a, s) => a + weight(s), 0);
  for (const s of summary) s.share = total > 0 ? Math.round((weight(s) / total) * 1000) / 10 : 0;
  const order = ['investir_mais', 'manter', 'testar', 'sem_receita', 'ajustar', 'pausar', 'aguardar'];
  summary.sort((a, b) => order.indexOf(a.verdict) - order.indexOf(b.verdict) || (b.roi ?? -1e9) - (a.roi ?? -1e9) || b.share - a.share);

  const spend = r2(rows.reduce((a, r) => a + r.spend, 0));
  const revRows = rows.filter((r) => r.rev != null);
  const revenue = revRows.length ? r2(revRows.reduce((a, r) => a + r.rev, 0)) : null;
  const spendR = revRows.reduce((a, r) => a + r.spend, 0);
  return {
    generatedAt: new Date(now).toISOString(),
    totals: {
      spend, revenue, profit: revenue != null ? r2(revenue - spendR) : null,
      roi: revenue != null && spendR > 0 ? Math.round(((revenue - spendR) / spendR) * 1000) / 10 : null,
      newPlayers: rows.reduce((a, r) => a + r.newPlayers, 0),
      revPerMin: revPerMin != null ? Math.round(revPerMin * 10000) / 10000 : null,
      anyEstimated: rows.some((r) => r.estimated && r.rev != null),
    },
    games: summary,
    entries: rows.sort((a, b) => (b.from > a.from ? 1 : b.from < a.from ? -1 : 0)),
  };
}

/** Guarda os lançamentos (banco, ou arquivo em DATA_DIR, ou memória). */
class InvestStore {
  constructor({ db = null, dataDir = '' } = {}) {
    this.db = db;
    this.file = dataDir ? path.join(dataDir, 'invest.json') : '';
    this.entries = [];
    if (this.file) { try { this.entries = JSON.parse(fs.readFileSync(this.file, 'utf8')); } catch { this.entries = []; } }
  }
  load(list) { if (Array.isArray(list)) this.entries = list.slice(-MAX_ENTRIES); }
  async _save() {
    if (this.file) { try { fs.writeFileSync(this.file, JSON.stringify(this.entries)); } catch (e) { console.error('invest:', e.message); } }
    if (this.db && this.db.ready) return this.db.saveKey('invest', this.entries).catch(() => false);
    return !!this.file;
  }
  async upsert(entry) {
    const i = this.entries.findIndex((e) => e.id === entry.id);
    if (i >= 0) this.entries[i] = entry; else this.entries.push(entry);
    if (this.entries.length > MAX_ENTRIES) this.entries = this.entries.slice(-MAX_ENTRIES);
    return this._save();
  }
  async remove(id) {
    const n = this.entries.length;
    this.entries = this.entries.filter((e) => e.id !== id);
    if (this.entries.length === n) return null;
    return this._save();
  }
}

module.exports = { analyze, cleanEntry, measure, parseDay, InvestStore, VERDICTS };
