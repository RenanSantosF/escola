'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { GameAnalytics, computeGameStats, compareGames, sessionsFromEscola } = require('../src/game_stats');
const { createServer } = require('../src/server');

const DAY = 86400000;
// meio-dia em Brasília de um dia fixo
const NOW = Date.UTC(2026, 10, 17, 15, 0, 0);

function play(ga, game, uid, sid, at, seconds) {
  ga.ingest(game, uid, [
    { type: 'session_start', at, data: { sid, version: '1.0', platform: 'Android' } },
    { type: 'heartbeat', at: at + 60000, data: { sid, seconds: Math.min(60, seconds) } },
    { type: 'session_end', at: at + seconds * 1000, data: { sid, seconds } },
  ], at + seconds * 1000 + 1000);
}

test('jogos: uma sessão por sid, heartbeats não viram linhas', () => {
  const ga = new GameAnalytics({ dataDir: '' });
  play(ga, 'aqua-caos', 'aaaa1111', 's1', NOW - 3600000, 300);
  assert.equal(ga.sessions.size, 1);
  const s = [...ga.sessions.values()][0];
  assert.equal(s.seconds, 300);
  assert.equal(s.version, '1.0');
  // jogo desconhecido, uid inválido e escola (usa o analytics próprio) são recusados
  assert.equal(ga.ingest('xyz', 'aaaa1111', [{ type: 'heartbeat', data: { sid: 'a' } }]), 0);
  assert.equal(ga.ingest('aqua-caos', 'NOPE', [{ type: 'heartbeat', data: { sid: 'a' } }]), 0);
  assert.equal(ga.ingest('escola', 'aaaa1111', [{ type: 'heartbeat', data: { sid: 'a' } }]), 0);
});

test('jogos: ativos, novos, duração e retenção D1/D7', () => {
  const ga = new GameAnalytics({ dataDir: '' });
  // 4 jogadores entram há 8 dias; 2 voltam no dia seguinte; 1 volta no 7º dia
  for (const [i, uid] of ['a1a1a1a1', 'b2b2b2b2', 'c3c3c3c3', 'd4d4d4d4'].entries()) {
    play(ga, 'road-rush', uid, 'f' + i, NOW - 8 * DAY, 600);
  }
  play(ga, 'road-rush', 'a1a1a1a1', 'r1', NOW - 7 * DAY, 120);
  play(ga, 'road-rush', 'b2b2b2b2', 'r2', NOW - 7 * DAY, 120);
  play(ga, 'road-rush', 'a1a1a1a1', 'r3', NOW - 1 * DAY, 60);
  ga.ingest('road-rush', 'a1a1a1a1', [{ type: 'level', at: NOW - DAY, data: { level: 3, won: true, score: 50 } }], NOW);
  const st = computeGameStats(ga.dataFor('road-rush'), NOW, 30);
  assert.equal(st.players.total, 4);
  assert.equal(st.players.active, 4);
  assert.equal(st.players.new, 4);
  assert.equal(st.sessions.count, 7);
  assert.equal(st.retention.d1.pct, 50);
  assert.equal(st.retention.d7.pct, 25);
  assert.equal(st.curve[1].pct, 50);
  assert.equal(st.levels[0].level, '3');
  assert.equal(st.levels[0].winPct, 100);
  assert.equal(st.recent[0].nth, 3); // terceira sessão do jogador a1
  assert.equal(st.daily.length, 30);
  assert.equal(st.hours.flat().reduce((a, b) => a + b, 0), 7);
});

test('jogos: comparação ordena pelo destaque e Recess Club vem do analytics', () => {
  const ga = new GameAnalytics({ dataDir: '' });
  for (let i = 0; i < 5; i++) play(ga, 'lanche-em-panico', 'ab' + String(i).repeat(6), 'x' + i, NOW - 2 * DAY, 900);
  play(ga, 'aqua-caos', 'cdcdcdcd', 'y', NOW - 2 * DAY, 30);
  const escola = sessionsFromEscola([
    { at: NOW - DAY, uid: 'eeee0000', type: 'session_start', data: { version: '3' } },
    { at: NOW - DAY + 60000, uid: 'eeee0000', type: 'heartbeat', data: { seconds: 60 } },
    { at: NOW - DAY + 120000, uid: 'eeee0000', type: 'session_end', data: { seconds: 118 } },
  ]);
  assert.equal(escola.sessions.length, 1);
  assert.equal(escola.sessions[0].seconds, 118);
  const cmp = compareGames({ escola, 'lanche-em-panico': ga.dataFor('lanche-em-panico'), 'aqua-caos': ga.dataFor('aqua-caos') }, NOW);
  assert.equal(cmp.games.length, 6);
  assert.equal(cmp.games[0].id, 'lanche-em-panico');
  assert.equal(cmp.games[0].active7, 5);
  assert.equal(cmp.games.find((g) => g.id === 'escola').active7, 1);
  assert.equal(cmp.games[0].daily14.length, 14);
});

test('jogos: rotas HTTP (envio com CORS e painel protegido)', async () => {
  const srv = createServer({ adminToken: 'segredo', dataDir: '' });
  await new Promise((r) => srv.server.listen(0, r));
  const base = 'http://127.0.0.1:' + srv.server.address().port;
  const pre = await fetch(base + '/api/games/events', { method: 'OPTIONS' });
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get('access-control-allow-origin'), '*');
  const r = await fetch(base + '/api/games/events', { method: 'POST', body: JSON.stringify({ game: 'arrow-survival', uid: 'abcd1234', events: [{ type: 'session_start', data: { sid: 'q1' } }, { type: 'heartbeat', data: { sid: 'q1', seconds: 42 } }] }) });
  assert.equal((await r.json()).accepted, 2);
  assert.equal((await fetch(base + '/api/admin/games')).status, 403);
  const cmp = await (await fetch(base + '/api/admin/games', { headers: { 'x-admin-token': 'segredo' } })).json();
  assert.equal(cmp.games.find((g) => g.id === 'arrow-survival').online, 1);
  const st = await (await fetch(base + '/api/admin/games/arrow-survival?days=7', { headers: { 'x-admin-token': 'segredo' } })).json();
  assert.equal(st.players.total, 1);
  assert.equal(st.days, 7);
  assert.equal(st.recent[0].online, true);
  assert.equal((await fetch(base + '/api/admin/games/nada', { headers: { 'x-admin-token': 'segredo' } })).status, 404);
  srv.close();
});
