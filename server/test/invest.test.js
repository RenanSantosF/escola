'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { analyze, cleanEntry } = require('../src/invest');
const { createServer } = require('../src/server');

const DAY = 86400000;
const NOW = Date.UTC(2026, 10, 19, 15); // 19/11/2026 12h em Brasília
const GAMES = [
  { id: 'a', name: 'A', emoji: '🅰️', color: 1 },
  { id: 'b', name: 'B', emoji: '🅱️', color: 2 },
  { id: 'c', name: 'C', emoji: '©️', color: 3 },
];
// n jogadores novos no dia `day` (Date.UTC), cada um jogando `min` minutos; `back` deles voltam no dia seguinte
function players(prefix, n, day, min, back = 0) {
  const sessions = [];
  const firsts = new Map();
  for (let i = 0; i < n; i++) {
    const uid = prefix + i;
    firsts.set(uid, day);
    sessions.push({ uid, start: day, last: day + min * 60000, seconds: min * 60 });
    if (i < back) sessions.push({ uid, start: day + DAY, last: day + DAY + 60000, seconds: 60 });
  }
  return { sessions, firsts };
}

test('investimento: retorno, custo por jogador, veredito e fatia do orçamento', () => {
  const d = Date.UTC(2026, 10, 10, 15);
  const data = { a: players('a', 100, d, 10, 40), b: players('b', 50, d, 2, 5), c: players('c', 30, d, 8, 15) };
  const entries = [
    { id: '1', game: 'a', from: '2026-11-10', to: '2026-11-12', spend: 100, revenue: 200 },
    { id: '2', game: 'b', from: '2026-11-10', to: '2026-11-12', spend: 100, revenue: 10 },
  ];
  const r = analyze(entries, GAMES, (g) => data[g], { c: 70 }, NOW);
  const by = Object.fromEntries(r.games.map((g) => [g.id, g]));
  assert.equal(by.a.newPlayers, 100);
  assert.equal(by.a.cpi, 1);
  assert.equal(by.a.roi, 100);
  assert.equal(by.a.verdict, 'investir_mais');
  assert.equal(by.a.d1, 40);
  assert.equal(by.b.verdict, 'pausar', 'recupera só 10%');
  assert.equal(by.c.verdict, 'testar', 'boa nota sem investimento');
  assert.equal(r.games[0].id, 'a', 'melhor primeiro');
  assert.ok(by.a.share > by.c.share && by.b.share === 0);
  assert.equal(r.totals.spend, 200);
  assert.equal(r.totals.revenue, 210);
});

test('investimento: sem receita informada estima pelo valor do minuto; sem jogadores = pausar', () => {
  const d = Date.UTC(2026, 10, 10, 15);
  const data = { a: players('a', 10, d, 10), b: players('b', 10, d, 20), c: { sessions: [], firsts: new Map() } };
  const entries = [
    { id: '1', game: 'a', from: '2026-11-10', to: '2026-11-10', spend: 5, revenue: 10 },
    { id: '2', game: 'b', from: '2026-11-10', to: '2026-11-10', spend: 5, revenue: null },
    { id: '3', game: 'c', from: '2026-11-10', to: '2026-11-10', spend: 5, revenue: null },
  ];
  const r = analyze(entries, GAMES, (g) => data[g], {}, NOW);
  const by = Object.fromEntries(r.games.map((g) => [g.id, g]));
  assert.equal(by.b.revenue, 20, '200 min x R$0,10/min');
  assert.ok(by.b.estimated);
  assert.equal(by.c.verdict, 'pausar');
});

test('investimento: validação dos lançamentos', () => {
  const ids = new Set(['a']);
  assert.ok(cleanEntry({ game: 'x', from: '2026-11-01', to: '2026-11-02', spend: 1 }, ids).error);
  assert.ok(cleanEntry({ game: 'a', from: '2026-11-05', to: '2026-11-02', spend: 1 }, ids).error);
  assert.ok(cleanEntry({ game: 'a', from: '2026-11-01', to: '2026-11-02', spend: '' }, ids).error);
  const ok = cleanEntry({ game: 'a', from: '2026-11-01', to: '2026-11-02', spend: '12,50', revenue: '' }, ids).entry;
  assert.equal(ok.spend, 12.5);
  assert.equal(ok.revenue, null);
});

test('servidor: lançar, ver e apagar investimento (protegido)', async () => {
  const srv = createServer({ adminToken: 's', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const base = 'http://127.0.0.1:' + srv.server.address().port;
  const H = { 'x-admin-token': 's', 'content-type': 'application/json' };
  assert.equal((await fetch(base + '/api/admin/invest')).status, 403);
  const p = await (await fetch(base + '/api/admin/invest', { method: 'POST', headers: H, body: JSON.stringify({ game: 'arrow-survival', from: '2026-11-01', to: '2026-11-07', spend: 50, revenue: 20 }) })).json();
  assert.ok(p.ok);
  const g = await (await fetch(base + '/api/admin/invest', { headers: H })).json();
  assert.equal(g.entries.length, 1);
  assert.equal(g.totals.spend, 50);
  assert.ok(g.games.find((x) => x.id === 'arrow-survival'));
  assert.ok((await (await fetch(base + '/api/admin/invest?id=' + p.entry.id, { method: 'DELETE', headers: H })).json()).ok);
  assert.equal((await (await fetch(base + '/api/admin/invest', { headers: H })).json()).entries.length, 0);
  srv.close();
});
