'use strict';
// Segurança online para crianças:
// - limite de mensagens (anti-flood)
// - silenciar automaticamente após mensagens bloqueadas repetidas
// - denúncias com motivo; várias denúncias de pessoas diferentes = silêncio
//   automático + fila de moderação humana
// - bloquear jogador (o bloqueado deixa de ver/ser visto no chat)

const REPORT_REASONS = ['linguagem', 'assedio', 'dados_pessoais', 'trapaca', 'nome_inadequado', 'outro'];

class Safety {
  constructor(opts = {}) {
    this.rateWindowMs = opts.rateWindowMs ?? 10000;
    this.rateMax = opts.rateMax ?? 5;
    this.autoMuteBlocked = opts.autoMuteBlocked ?? 3;
    this.autoMuteReports = opts.autoMuteReports ?? 3;
    this.muteMs = opts.muteMs ?? 10 * 60 * 1000;
    this.sent = new Map(); // id -> [timestamps]
    this.blockedCount = new Map();
    this.mutedUntil = new Map();
    this.reports = []; // fila de moderação
    this.reportsAgainst = new Map(); // id -> Set(reporterId)
    this.blocks = new Map(); // id -> Set(blockedId)
    // ganchos de persistência (banco de dados)
    this.onMute = opts.onMute || null;
    this.onReport = opts.onReport || null;
    this.onBlock = opts.onBlock || null;
  }

  isMuted(id, now = Date.now()) {
    return (this.mutedUntil.get(id) || 0) > now;
  }

  mute(id, ms = this.muteMs, now = Date.now()) {
    this.mutedUntil.set(id, now + ms);
    if (this.onMute) this.onMute(id, now + ms);
  }

  /** Retorna null se pode enviar, ou o motivo. */
  canSend(id, now = Date.now()) {
    if (this.isMuted(id, now)) return 'Você está silenciado por um tempo.';
    const list = (this.sent.get(id) || []).filter((t) => now - t < this.rateWindowMs);
    if (list.length >= this.rateMax) return 'Calma! Espere um pouquinho para mandar outra mensagem.';
    list.push(now);
    this.sent.set(id, list);
    return null;
  }

  onBlockedMessage(id, now = Date.now()) {
    const n = (this.blockedCount.get(id) || 0) + 1;
    this.blockedCount.set(id, n);
    if (n >= this.autoMuteBlocked) {
      this.mute(id, this.muteMs, now);
      this.blockedCount.set(id, 0);
      return true;
    }
    return false;
  }

  report(reporterId, targetId, reason, context = {}) {
    if (reporterId === targetId) return { ok: false, error: 'invalido' };
    if (!REPORT_REASONS.includes(reason)) reason = 'outro';
    const entry = { at: new Date().toISOString(), reporterId, targetId, reason, context };
    this.reports.push(entry);
    if (this.onReport) this.onReport(entry);
    const set = this.reportsAgainst.get(targetId) || new Set();
    set.add(reporterId);
    this.reportsAgainst.set(targetId, set);
    let autoMuted = false;
    if (set.size >= this.autoMuteReports) {
      this.mute(targetId);
      autoMuted = true;
    }
    return { ok: true, autoMuted };
  }

  block(id, otherId, persist = true) {
    const set = this.blocks.get(id) || new Set();
    set.add(otherId);
    this.blocks.set(id, set);
    if (persist && this.onBlock) this.onBlock(id, otherId);
  }

  isBlocked(viewerId, senderId) {
    return (this.blocks.get(viewerId) || new Set()).has(senderId) || (this.blocks.get(senderId) || new Set()).has(viewerId);
  }
}

module.exports = { Safety, REPORT_REASONS };
