'use strict';
// Configurações do jogo que o administrador muda pelo painel (sem novo APK).
// Ficam salvas no banco (tabela settings) quando ele existe.
//
// bots: completar os times das brincadeiras de time (queimada, futebol) com
//   bots até `perTeam` jogadores por time. Útil no começo, com pouca gente;
//   conforme chegam crianças, os bots saem. perTeam = 0 ou desligado = só gente.

const BOT_GAMES = ['queimada', 'futebol'];
const MAX_PER_TEAM = 5;

const settings = {
  botsEnabled: process.env.BOTS_ENABLED === '1',
  botsPerTeam: Math.max(0, Math.min(MAX_PER_TEAM, Number(process.env.BOTS_PER_TEAM) || 0)),
};

/** Até quantos jogadores por time os bots completam nesta brincadeira (0 = sem bots). */
function botsFor(gid) {
  if (!settings.botsEnabled || !BOT_GAMES.includes(gid)) return 0;
  return settings.botsPerTeam;
}

/** Aplica (com limites) o que veio do painel ou do banco. */
function apply(obj) {
  if (!obj || typeof obj !== 'object') return publicSettings();
  if (typeof obj.botsEnabled === 'boolean') settings.botsEnabled = obj.botsEnabled;
  if (obj.botsPerTeam !== undefined && Number.isFinite(Number(obj.botsPerTeam))) {
    settings.botsPerTeam = Math.max(0, Math.min(MAX_PER_TEAM, Math.round(Number(obj.botsPerTeam))));
  }
  return publicSettings();
}

function publicSettings() {
  return { botsEnabled: settings.botsEnabled, botsPerTeam: settings.botsPerTeam, botGames: BOT_GAMES.slice(), maxPerTeam: MAX_PER_TEAM };
}

module.exports = { settings, botsFor, apply, publicSettings, BOT_GAMES, MAX_PER_TEAM };
