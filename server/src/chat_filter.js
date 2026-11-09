'use strict';
// Filtro de chat para crianças (PT-BR).
// - Normaliza (minúsculas, sem acento, leetspeak, letras repetidas, separadores)
// - Bloqueia palavrões/ofensas (lista base; amplie em produção) e variações
// - Bloqueia dados pessoais: telefone, e-mail, links, @perfis, endereço, idade+cidade
// - Mensagens com dado pessoal são BLOQUEADAS (não só mascaradas)

const BAD_WORDS = [
  'porra', 'caralho', 'merda', 'bosta', 'puta', 'puto', 'foda', 'foder', 'fodase', 'cacete', 'buceta', 'boceta',
  'pinto', 'piroca', 'rola', 'cu', 'cuzao', 'arrombado', 'viado', 'veado', 'bicha', 'otario', 'babaca', 'idiota',
  'imbecil', 'retardado', 'mongol', 'burro', 'lixo', 'feio', 'gordo', 'baleia', 'macaco', 'vagabundo', 'vagabunda',
  'piranha', 'safado', 'safada', 'desgracado', 'desgraca', 'corno', 'trouxa', 'escroto', 'nojento', 'chupa', 'mamar',
  'sexo', 'pelado', 'pelada', 'nude', 'nudes', 'matar', 'morre', 'morra', 'suicidio', 'droga', 'maconha', 'cocaina',
];
// Palavras curtas só contam como palavra inteira (evita bloquear "cuidado", "rolar"...)
const WHOLE_ONLY = new Set(['cu', 'rola', 'puto', 'burro', 'lixo', 'feio', 'gordo', 'pinto', 'chupa', 'droga', 'matar']);

const LEET = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b', '@': 'a', '$': 's', '!': 'i', '|': 'i' };

function stripAccents(s) {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '');
}

function normalize(text) {
  let s = stripAccents(String(text).toLowerCase());
  s = s.replace(/[01345789@$!|]/g, (c) => LEET[c] || c);
  s = s.replace(/(.)\1{2,}/g, '$1$1'); // "poooorra" -> "poorra"
  return s;
}

// Versão sem separadores ("p.o.r.r.a", "p o r r a")
function compact(s) {
  return s.replace(/[^a-z]/g, '').replace(/(.)\1+/g, '$1');
}

const PERSONAL_PATTERNS = [
  { re: /(\+?55)?\s*\(?\d{2}\)?\s*9?\d{4}[-.\s]?\d{4}/, kind: 'telefone' },
  { re: /\d{8,}/, kind: 'numero' },
  { re: /[\w.+-]+@[\w-]+\.[\w.]+/, kind: 'email' },
  { re: /(https?:\/\/|www\.|\.com\b|\.net\b|\.br\b|discord|whats|zap|insta|tiktok|telegram|snap)/i, kind: 'link' },
  { re: /(^|\s)@\w{3,}/, kind: 'perfil' },
  { re: /\b(rua|avenida|av\.|travessa|apto|apartamento|cep)\b/i, kind: 'endereco' },
  { re: /\b(meu|minha)\s+(endereco|telefone|numero|senha|escola fica)\b/i, kind: 'dado pessoal' },
  { re: /\b(onde voce mora|onde vc mora|qual (sua|tua) escola|manda foto|me passa (seu|teu))\b/i, kind: 'pedido de dado pessoal' },
];

function hasBadWord(norm) {
  const words = norm.split(/[^a-z]+/).filter(Boolean);
  for (const w of words) {
    const wc = w.replace(/(.)\1+/g, '$1');
    for (const bad of BAD_WORDS) {
      const bc = bad.replace(/(.)\1+/g, '$1');
      if (WHOLE_ONLY.has(bad)) {
        if (wc === bc) return bad;
      } else if (wc.includes(bc)) {
        return bad;
      }
    }
  }
  // palavras disfarçadas com separadores
  const c = compact(norm);
  for (const bad of BAD_WORDS) {
    if (WHOLE_ONLY.has(bad) || bad.length < 5) continue;
    if (c.includes(bad.replace(/(.)\1+/g, '$1'))) return bad;
  }
  return null;
}

/**
 * Analisa uma mensagem.
 * @returns {{ok: boolean, text: string, reason?: string}}
 */
function check(text, maxLen = 80) {
  const raw = String(text || '').replace(/[\u0000-\u001f​-‏⁠]/g, '').trim().slice(0, maxLen);
  if (!raw) return { ok: false, text: '', reason: 'vazia' };
  const norm = normalize(raw);
  const asDigits = stripAccents(raw.toLowerCase());
  for (const p of PERSONAL_PATTERNS) {
    if (p.re.test(asDigits) || p.re.test(norm)) {
      return { ok: false, text: '', reason: 'Para sua segurança, não compartilhe ' + p.kind + '.' };
    }
  }
  const bad = hasBadWord(norm);
  if (bad) return { ok: false, text: '', reason: 'Mensagem bloqueada: linguagem inadequada.' };
  // gritaria: tudo maiúsculo vira minúsculo
  const letters = raw.replace(/[^A-Za-zÀ-ú]/g, '');
  const text2 = letters.length > 6 && letters === letters.toUpperCase() ? raw.toLowerCase() : raw;
  return { ok: true, text: text2 };
}

// Frases prontas (chat rápido, sempre seguro — padrão para menores de 13)
const QUICK_PHRASES = [
  'Oi! Tudo bem?', 'Bora jogar futebol na quadra?', 'Bora jogar queimada?', 'Vamos pular corda?', 'Bora fazer uma missão juntos?',
  'Boa jogada!', 'Mandou muito bem!', 'Valeu, amigo!', 'Me espera, já tô indo!', 'Vem pra cá!', 'Já volto!',
  'Parabéns!', 'Quase! Tenta de novo!', 'Troca figurinha?', 'Qual skin você tem?', 'Vamos no mirante do Bloco C?',
  'Bora na cantina?', 'Me segue!', 'Que legal!', 'Hahaha!', 'Desculpa!', 'Tchau, até amanhã!',
];

module.exports = { check, normalize, QUICK_PHRASES, BAD_WORDS };
