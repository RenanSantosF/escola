'use strict';
// Servidor online do Recreio (Railway). HTTP para saúde/moderação +
// WebSocket para o jogo. Protocolo: mensagens JSON {t: tipo, ...}.
//
// Cliente -> servidor
//   {t:'hello', token?, age, level, look, room?}   entra (ou volta) com a conta
//   {t:'state', pos:[x,y,z], yaw, anim}             até ~10x por segundo
//   {t:'quick', i}                                   frase pronta (índice)
//   {t:'chat', text}                                 texto livre (só se liberado)
//   {t:'report', target, reason}                     denuncia jogador
//   {t:'block', target}                              bloqueia jogador
// Servidor -> cliente
//   {t:'welcome', token, id, name, room, freeChat, quick, players, phase}
//   {t:'join', player} {t:'leave', id} {t:'states', list}
//   {t:'chat', id, name, text} {t:'notice', text}

const http = require('http');
const { WebSocketServer } = require('ws');
const { check, QUICK_PHRASES } = require('./chat_filter');
const { Safety } = require('./safety');
const { RoomManager } = require('./rooms');
const { Accounts } = require('./accounts');

const TICK_MS = 100;
const MAX_MSG_BYTES = 2048;

function createServer(opts = {}) {
  const adminToken = opts.adminToken ?? process.env.ADMIN_TOKEN ?? '';
  const accounts = opts.accounts || new Accounts();
  const safety = opts.safety || new Safety();
  const rooms = new RoomManager();
  const recentChat = new Map(); // roomId -> últimas mensagens (contexto p/ denúncia)

  function isAdmin(req) {
    return adminToken !== '' && req.headers['x-admin-token'] === adminToken;
  }

  function readJson(req) {
    return new Promise((resolve) => {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > 4096) req.destroy(); });
      req.on('end', () => { try { resolve(JSON.parse(body || '{}')); } catch { resolve({}); } });
    });
  }

  const server = http.createServer(async (req, res) => {
    const json = (code, obj) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(obj)); };
    if (req.url === '/health' || req.url === '/') {
      let players = 0;
      for (const r of rooms.rooms.values()) players += r.players.size;
      return json(200, { ok: true, rooms: rooms.rooms.size, players });
    }
    // Moderação humana (protegida por ADMIN_TOKEN)
    if (req.url === '/mod/reports' && req.method === 'GET') {
      if (!isAdmin(req)) return json(403, { ok: false });
      return json(200, { reports: safety.reports.slice(-200) });
    }
    if (req.url === '/mod/mute' && req.method === 'POST') {
      if (!isAdmin(req)) return json(403, { ok: false });
      const b = await readJson(req);
      safety.mute(String(b.id || ''), (b.minutes | 0 || 60) * 60000);
      return json(200, { ok: true });
    }
    // Liberação de chat livre por responsável (validado pela moderação)
    if (req.url === '/parent/unlock' && req.method === 'POST') {
      if (!isAdmin(req)) return json(403, { ok: false });
      const b = await readJson(req);
      for (const acc of accounts.byToken.values()) {
        if (acc.id === b.id) { acc.freeChat = !!b.allow; return json(200, { ok: true }); }
      }
      return json(404, { ok: false });
    }
    json(404, { ok: false });
  });

  const wss = new WebSocketServer({ server, maxPayload: MAX_MSG_BYTES });

  function send(ws, obj) {
    if (ws.readyState === 1) ws.send(JSON.stringify(obj));
  }

  function broadcast(room, obj, exceptId, filterFn) {
    const s = JSON.stringify(obj);
    for (const p of room.players.values()) {
      if (p.id === exceptId) continue;
      if (filterFn && !filterFn(p)) continue;
      if (p.ws.readyState === 1) p.ws.send(s);
    }
  }

  function pushChat(room, p, text) {
    const list = recentChat.get(room.id) || [];
    list.push({ id: p.id, text, at: Date.now() });
    if (list.length > 20) list.shift();
    recentChat.set(room.id, list);
    broadcast(room, { t: 'chat', id: p.id, name: p.name, text }, null, (viewer) => !safety.isBlocked(viewer.id, p.id));
  }

  wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });
    let player = null;
    let room = null;
    ws.on('message', (raw) => {
      let m;
      try { m = JSON.parse(raw.toString()); } catch { return; }
      if (!m || typeof m.t !== 'string') return;
      if (!player) {
        if (m.t !== 'hello') return;
        const acc = accounts.getOrCreate(typeof m.token === 'string' ? m.token : '', { age: m.age, level: m.level, look: m.look });
        player = { id: acc.id, name: acc.name, level: acc.level, look: acc.look, pos: [0, 0, 70], yaw: 0, anim: 'idle', ws, acc, dirty: true };
        room = rooms.join(player, typeof m.room === 'string' ? m.room.slice(0, 24) : null);
        send(ws, {
          t: 'welcome', token: acc.token, id: acc.id, name: acc.name, room: room.id,
          freeChat: accounts.canFreeChat(acc), quick: QUICK_PHRASES, players: room.snapshot(acc.id), phase: room.phase,
        });
        broadcast(room, { t: 'join', player: { id: player.id, name: player.name, level: player.level, look: player.look, pos: player.pos, yaw: player.yaw, anim: player.anim } }, player.id);
        return;
      }
      switch (m.t) {
        case 'state': {
          if (Array.isArray(m.pos) && m.pos.length === 3 && m.pos.every(Number.isFinite)) {
            player.pos = m.pos.map((v) => Math.round(v * 100) / 100);
          }
          if (Number.isFinite(m.yaw)) player.yaw = Math.round(m.yaw * 100) / 100;
          if (typeof m.anim === 'string') player.anim = m.anim.slice(0, 16);
          player.dirty = true;
          break;
        }
        case 'quick': {
          const i = m.i | 0;
          if (i < 0 || i >= QUICK_PHRASES.length) return;
          const why = safety.canSend(player.id);
          if (why) return send(ws, { t: 'notice', text: why });
          pushChat(room, player, QUICK_PHRASES[i]);
          break;
        }
        case 'chat': {
          if (!accounts.canFreeChat(player.acc)) {
            return send(ws, { t: 'notice', text: 'Use as frases rápidas. O chat livre precisa ser liberado por um responsável.' });
          }
          const why = safety.canSend(player.id);
          if (why) return send(ws, { t: 'notice', text: why });
          const r = check(m.text);
          if (!r.ok) {
            const muted = safety.onBlockedMessage(player.id);
            return send(ws, { t: 'notice', text: muted ? 'Você foi silenciado por 10 minutos.' : r.reason });
          }
          pushChat(room, player, r.text);
          break;
        }
        case 'report': {
          const target = String(m.target || '');
          const ctx = (recentChat.get(room.id) || []).filter((c) => c.id === target).slice(-5);
          const r = safety.report(player.id, target, String(m.reason || 'outro'), { room: room.id, messages: ctx });
          send(ws, { t: 'notice', text: r.ok ? 'Obrigado! A denúncia foi enviada para a equipe.' : 'Não foi possível denunciar.' });
          if (r.ok) safety.block(player.id, target);
          break;
        }
        case 'block': {
          safety.block(player.id, String(m.target || ''));
          send(ws, { t: 'notice', text: 'Jogador bloqueado.' });
          break;
        }
      }
    });
    ws.on('close', () => {
      if (!player) return;
      const r = rooms.leave(player);
      if (r) broadcast(r, { t: 'leave', id: player.id });
    });
  });

  // envia estados agregados por sala (~10 Hz)
  const timer = setInterval(() => {
    for (const r of rooms.rooms.values()) {
      const list = [];
      for (const p of r.players.values()) {
        if (!p.dirty) continue;
        p.dirty = false;
        list.push({ id: p.id, pos: p.pos, yaw: p.yaw, anim: p.anim });
      }
      if (list.length) broadcast(r, { t: 'states', list });
    }
  }, TICK_MS);
  // mantém a conexão viva no Railway e derruba quem caiu sem avisar
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (ws.isAlive === false) { ws.terminate(); continue; }
      ws.isAlive = false;
      ws.ping();
    }
  }, 25000);
  server.on('close', () => { clearInterval(timer); clearInterval(heartbeat); });

  return { server, wss, rooms, accounts, safety, close: () => { clearInterval(timer); clearInterval(heartbeat); wss.close(); server.close(); } };
}

if (require.main === module) {
  const port = Number(process.env.PORT) || 8080;
  createServer().server.listen(port, () => console.log('Recreio online na porta ' + port));
}

module.exports = { createServer };
