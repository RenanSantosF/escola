'use strict';
// Grade do dia: o SERVIDOR organiza as turmas — em qual sala cada turma fica
// (sorteada entre as 14 salas de aula), quais matérias tem em cada aula
// (sorteadas, sem repetir até passar por todas) e ONDE cada aula acontece
// (na sala da turma ou numa sala especial: informática, laboratórios,
// sala de vídeo/cinema, quadra, música...). Duas turmas nunca usam a mesma
// sala especial ao mesmo tempo.
//
// make(rng, decks) -> { rooms: [3 salas], classes: [[{subj, room}, {subj, room}] x3] }
// room === '' significa "na sala da própria turma".

const CLASSROOMS = [
  'Sala 1', 'Sala 2', 'Sala 3', 'Sala 4', 'Sala 5', 'Sala 6', 'Sala 7',
  'Sala 8', 'Sala 9', 'Sala 10', 'Sala 11', 'Sala 12', 'Sala 13', 'Sala 14',
];

// matéria -> lugares possíveis ('' = sala da turma). Mesma tabela do jogo
// (scripts/school/schedule.gd).
const SUBJECT_ROOMS = {
  'Matemática': ['', '', 'Sala de Informática'],
  'Português': ['', 'Sala de Leitura', 'Biblioteca'],
  'Ciências': ['Laboratório de Ciências', '', 'Sala de Vídeo'],
  'Geografia': ['', 'Sala de Vídeo', 'Biblioteca'],
  'História': ['Sala de Vídeo', '', 'Auditório', 'Biblioteca'],
  'Inglês': ['Sala de Idiomas', ''],
  'Artes': ['Sala de Artes', 'Ateliê Maker'],
  'Música': ['Sala de Música', 'Auditório'],
  'Informática': ['Sala de Informática', 'Sala de Robótica'],
  'Educação Física': ['Quadra Poliesportiva', 'Sala de Dança'],
  'Física': ['Laboratório de Física'],
  'Química': ['Laboratório de Química'],
};
const SUBJECTS = Object.keys(SUBJECT_ROOMS);
const TURMAS = 3;

function shuffle(arr, rng) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** Tira a próxima matéria do "baralho" da turma (todas passam antes de repetir). */
function draw(deck, rng, avoid) {
  if (deck.length === 0) deck.push(...shuffle(SUBJECTS.slice(), rng));
  let i = deck.findIndex((s) => !avoid.includes(s));
  if (i < 0) i = 0;
  return deck.splice(i, 1)[0];
}

function make(rng = Math.random, decks = []) {
  const rooms = shuffle(CLASSROOMS.slice(), rng).slice(0, TURMAS);
  const classes = [];
  const used = [new Set(), new Set()]; // salas especiais ocupadas em cada aula
  for (let t = 0; t < TURMAS; t++) {
    if (!decks[t]) decks[t] = [];
    const day = [];
    for (let c = 0; c < 2; c++) {
      const subj = draw(decks[t], rng, day.map((d) => d.subj));
      const opts = shuffle(SUBJECT_ROOMS[subj].slice(), rng);
      let room = opts.find((r) => r === '' || !used[c].has(r));
      if (room === undefined) room = '';
      if (room !== '') used[c].add(room);
      day.push({ subj, room });
    }
    classes.push(day);
  }
  return { rooms, classes };
}

module.exports = { make, CLASSROOMS, SUBJECT_ROOMS, SUBJECTS };
