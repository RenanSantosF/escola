class_name NPCRoster
extends RefCounted
## Elenco fixo da escola: alunos com personalidade, adultos e falas.

## Personalidades: futebol, competitivo, engracado, timido, colecionador,
## comilao, estudioso, agitado, comum
const STUDENTS := [
	{"id": "lucas", "name": "Lucas", "personality": "futebol", "seed": 101,
		"look": {"hair_style": "curto", "shirt_trim": "2f6fd0", "cap": true, "cap_color": "e04a3a"}},
	{"id": "bia", "name": "Bia", "personality": "competitivo", "seed": 202,
		"look": {"hair_style": "rabo", "hair_color": "1d1612", "backpack_color": "8e5bd1"}},
	{"id": "pedro", "name": "Pedro", "personality": "engracado", "seed": 303,
		"look": {"hair_style": "espetado", "hair_color": "d9b25f", "glasses": false}},
	{"id": "ana", "name": "Ana", "personality": "timido", "seed": 404,
		"look": {"hair_style": "longo", "hair_color": "6b3e1f", "glasses": true}},
	{"id": "julia", "name": "Júlia", "personality": "colecionador", "seed": 505,
		"look": {"hair_style": "cacheado", "hair_color": "1d1612", "backpack_color": "ff7eb6"}},
	{"id": "gui", "name": "Gui", "personality": "comilao", "seed": 606,
		"look": {"hair_style": "raspado", "build": 1.18}},
	{"id": "rafa", "name": "Rafa", "personality": "agitado", "seed": 707,
		"look": {"hair_style": "black_power", "hair_color": "1d1612"}},
	{"id": "mari", "name": "Mari", "personality": "estudioso", "seed": 808,
		"look": {"hair_style": "franja", "hair_color": "a32e1d", "glasses": true}},
]

const GENERIC_NAMES := ["Davi", "Sofia", "Miguel", "Alice", "Arthur", "Helena", "Heitor", "Laura", "Theo", "Valentina",
	"Gabriel", "Manuela", "Bernardo", "Isabela", "Enzo", "Lívia", "Samuel", "Clara", "Matheus", "Cecília",
	"Joaquim", "Eloá", "Caio", "Lara", "Benício", "Yasmin", "Nicolas", "Beatriz", "Murilo", "Giovanna",
	"Vitor", "Lorena", "Daniel", "Mariana", "Felipe", "Luana", "Kauã", "Maitê", "Breno", "Ester"]
const GENERIC_PERSONALITIES := ["comum", "comum", "comum", "futebol", "engracado", "timido", "colecionador", "comilao", "agitado", "estudioso"]

const ADULTS := {
	"teacher": {"id": "prof_marcia", "name": "Professora Márcia", "role": "teacher", "seed": 900,
		"look": {"hair_style": "longo", "hair_color": "3b2417", "shirt_color": "c0392b", "shirt_trim": "a93226",
			"shirt_logo": false, "long_pants": true, "pants_color": "2c3e50", "backpack": false, "glasses": true,
			"height_scale": 1.2, "build": 1.05}},
	"teacher_b": {"id": "prof_carlos", "name": "Professor Carlos", "role": "teacher", "seed": 904,
		"look": {"hair_style": "curto", "hair_color": "2b1d14", "shirt_color": "2e86c1", "shirt_trim": "1b4f72",
			"shirt_logo": false, "long_pants": true, "pants_color": "4d4d4d", "backpack": false, "glasses": false,
			"height_scale": 1.22, "build": 1.1, "beard": true}},
	"director": {"id": "diretor", "name": "Diretor Valdir", "role": "director", "seed": 901,
		"look": {"hair_style": "raspado", "hair_color": "5d5d5d", "shirt_color": "ecf0f1", "shirt_trim": "34495e",
			"shirt_logo": false, "long_pants": true, "pants_color": "34495e", "backpack": false, "glasses": true,
			"height_scale": 1.24, "build": 1.15, "shoe_color": "1f1f1f"}},
	"inspector": {"id": "inspetora", "name": "Dona Cida", "role": "inspector", "seed": 902,
		"look": {"hair_style": "cacheado", "hair_color": "8a8a8a", "shirt_color": "27ae60", "shirt_trim": "1e8449",
			"shirt_logo": false, "long_pants": true, "pants_color": "1c2833", "backpack": false,
			"height_scale": 1.17, "build": 1.12}},
	"cook": {"id": "cantineira", "name": "Tia Rosa", "role": "cook", "seed": 903,
		"look": {"hair_style": "rabo", "hair_color": "1d1612", "shirt_color": "f4f4f0", "shirt_trim": "e74c3c",
			"shirt_logo": false, "long_pants": true, "pants_color": "e8e8e8", "backpack": false, "cap": true,
			"cap_color": "e74c3c", "height_scale": 1.18, "build": 1.1}},
}

## Falas curtas (balões) por personalidade e momento.
## Falas: ver NPCLines (scripts/npc/npc_lines.gd).


static func appearance_for(entry: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.random(int(entry.get("seed", 1)), entry.get("role", "student") == "student")
	var look: Dictionary = entry.get("look", {})
	var d := a.to_dict()
	for k in look.keys():
		d[k] = look[k]
	var res := CharacterAppearance.from_dict(d)
	# adultos podem ser mais altos que alunos
	if look.has("height_scale"):
		res.height_scale = float(look.height_scale)
	return res


static func generic_student(index: int) -> Dictionary:
	return {
		"id": "aluno_%d" % index,
		"name": GENERIC_NAMES[index % GENERIC_NAMES.size()],
		"personality": GENERIC_PERSONALITIES[(index * 7 + 3) % GENERIC_PERSONALITIES.size()],
		"seed": 1000 + index * 37,
		"role": "student",
	}


static func ambient_line(personality: String, phase := "") -> String:
	return NPCLines.ambient(personality, phase)


static func talk_lines(personality: String) -> Array:
	return NPCLines.talk(personality)
