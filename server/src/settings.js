'use strict';
// Configurações do jogo que o administrador muda pelo painel (sem novo APK).
// Ficam salvas no banco (tabela settings) quando ele existe.
//
// bots: completar os times das brincadeiras de time (queimada, futebol) com
//   bots até `perTeam` jogadores por time. Útil no começo, com pouca gente;
//   conforme chegam crianças, os bots saem. perTeam = 0 ou desligado = só gente.

// minVersion: versão mínima do app (o "código da versão" do Android: 1, 2, 3...).
//   Quem estiver abaixo vê a tela "Atualize o jogo" e não entra até atualizar.

const BOT_GAMES = ['queimada', 'futebol'];
const STORE_URL = 'https://play.google.com/store/apps/details?id=com.recreio.minhavidanaescola';
const MAX_PER_TEAM = 5;

const settings = {
  botsEnabled: process.env.BOTS_ENABLED === '1',
  botsPerTeam: Math.max(0, Math.min(MAX_PER_TEAM, Number(process.env.BOTS_PER_TEAM) || 0)),
  minVersion: Math.max(0, Number(process.env.MIN_VERSION) || 0),
};

/** Essa versão do app pode jogar? (0 = nunca informou: app antigo) */
function versionOk(v) {
  return settings.minVersion <= 0 || (Number(v) || 0) >= settings.minVersion;
}

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
  if (obj.minVersion !== undefined && Number.isFinite(Number(obj.minVersion))) {
    settings.minVersion = Math.max(0, Math.min(100000, Math.round(Number(obj.minVersion))));
  }
  return publicSettings();
}

function publicSettings() {
  return { botsEnabled: settings.botsEnabled, botsPerTeam: settings.botsPerTeam, botGames: BOT_GAMES.slice(), maxPerTeam: MAX_PER_TEAM,
    minVersion: settings.minVersion, storeUrl: STORE_URL };
}

module.exports = { settings, botsFor, apply, publicSettings, versionOk, BOT_GAMES, MAX_PER_TEAM, STORE_URL };
