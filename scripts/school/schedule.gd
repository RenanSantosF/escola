class_name Schedule
extends RefCounted
## Grade do dia (igual a server/src/schedule.js). Online quem sorteia é o
## SERVIDOR e manda no relógio; sozinho, o jogo sorteia do mesmo jeito.
## { rooms: [sala da Turma A, B, C], classes: [[{subj, room}, {subj, room}] x3] }
## room == "" -> na sala da própria turma.

const CLASSROOMS := ["Sala 1", "Sala 2", "Sala 3", "Sala 4", "Sala 5", "Sala 6", "Sala 7",
	"Sala 8", "Sala 9", "Sala 10", "Sala 11", "Sala 12", "Sala 13", "Sala 14"]

const SUBJECT_ROOMS := {
	"Matemática": ["", "", "Sala de Informática"],
	"Português": ["", "Sala de Leitura", "Biblioteca"],
	"Ciências": ["Laboratório de Ciências", "", "Sala de Vídeo"],
	"Geografia": ["", "Sala de Vídeo", "Biblioteca"],
	"História": ["Sala de Vídeo", "", "Auditório", "Biblioteca"],
	"Inglês": ["Sala de Idiomas", ""],
	"Artes": ["Sala de Artes", "Ateliê Maker"],
	"Música": ["Sala de Música", "Auditório"],
	"Informática": ["Sala de Informática", "Sala de Robótica"],
	"Educação Física": ["Quadra Poliesportiva", "Sala de Dança"],
	"Física": ["Laboratório de Física"],
	"Química": ["Laboratório de Química"],
}
const TURMAS := 3

## Baralhos de matérias por turma (todas passam antes de repetir).
static var _decks: Array = []


static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


static func _draw(t: int, rng: RandomNumberGenerator, avoid: Array) -> String:
	while _decks.size() <= t:
		_decks.append([])
	var deck: Array = _decks[t]
	if deck.is_empty():
		deck.append_array(_shuffled(SUBJECT_ROOMS.keys(), rng))
	var i := 0
	for k in deck.size():
		if not deck[k] in avoid:
			i = k
			break
	var s: String = deck[i]
	deck.remove_at(i)
	return s


static func make(rng: RandomNumberGenerator) -> Dictionary:
	var rooms := _shuffled(CLASSROOMS, rng).slice(0, TURMAS)
	var classes := []
	var used := [{}, {}]
	for t in TURMAS:
		var day := []
		for c in 2:
			var subj := _draw(t, rng, day.map(func(d): return d.subj))
			var room := ""
			for r in _shuffled(SUBJECT_ROOMS[subj], rng):
				if r == "" or not used[c].has(r):
					room = r
					break
			if room != "":
				used[c][room] = true
			day.append({"subj": subj, "room": room})
		classes.append(day)
	return {"rooms": rooms, "classes": classes}


## Confere se a grade que veio do servidor é usável.
static func valid(s: Variant) -> bool:
	if not (s is Dictionary):
		return false
	var rooms: Variant = s.get("rooms")
	var classes: Variant = s.get("classes")
	return rooms is Array and classes is Array and (rooms as Array).size() >= TURMAS and (classes as Array).size() >= TURMAS
