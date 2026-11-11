class_name CharacterAppearance
extends RefCounted
## Dados visuais de um personagem (usados pelo construtor de modelo,
## pela loja e pelo save). Tudo serializável em Dictionary.

const SKIN_TONES := [
	Color("f6d3b3"), Color("e8b48f"), Color("d29a6c"), Color("b07448"), Color("8a5534"), Color("5e3a22"),
]
const HAIR_COLORS := [
	Color("1d1612"), Color("3b2417"), Color("6b3e1f"), Color("a8642b"), Color("d9b25f"), Color("a32e1d"),
]
const HAIR_STYLES := ["curto", "espetado", "longo", "rabo", "cacheado", "black_power", "raspado", "franja"]
const SHIRT_COLORS := [
	Color("f4f4f0"), Color("2f6fd0"), Color("e04a3a"), Color("f2b632"), Color("3aa45b"), Color("8e5bd1"),
	Color("ff8a3d"), Color("26a6b8"),
]
const PANTS_COLORS := [Color("23325c"), Color("3f5f99"), Color("3a3a3a"), Color("6b4f2b"), Color("2d5a3b")]
const SHOE_COLORS := [Color("f2f2f2"), Color("1f1f1f"), Color("d63c3c"), Color("2f6fd0"), Color("f2c230")]
const BACKPACK_COLORS := [Color("d63c3c"), Color("2f6fd0"), Color("f2c230"), Color("3aa45b"), Color("8e5bd1"), Color("ff7eb6")]

var skin := Color("e8b48f")
var hair_style := "curto"
var hair_color := Color("3b2417")
var eye_color := Color("2b1a10")
var shirt_color := Color("f4f4f0")
var shirt_trim := Color("2f6fd0")  # detalhe de uniforme (gola/manga)
var shirt_logo := true
var pants_color := Color("23325c")
var long_pants := false
var sock_color := Color("f4f4f0")
var shoe_color := Color("f2f2f2")
var shoe_sole := Color("d8d8d8")
var backpack := true
var backpack_color := Color("d63c3c")
var cap := false
var cap_color := Color("2f6fd0")
var glasses := false
var height_scale := 1.0
var build := 1.0  # 0.9 magro .. 1.15 forte
## Menina: cílios, laço no cabelo e boca rosada (escolhido ao criar a conta).
var girl := false


func to_dict() -> Dictionary:
	return {
		"skin": skin.to_html(false), "hair_style": hair_style, "hair_color": hair_color.to_html(false),
		"eye_color": eye_color.to_html(false), "shirt_color": shirt_color.to_html(false),
		"shirt_trim": shirt_trim.to_html(false), "shirt_logo": shirt_logo,
		"pants_color": pants_color.to_html(false), "long_pants": long_pants,
		"sock_color": sock_color.to_html(false), "shoe_color": shoe_color.to_html(false),
		"shoe_sole": shoe_sole.to_html(false), "backpack": backpack,
		"backpack_color": backpack_color.to_html(false), "cap": cap, "cap_color": cap_color.to_html(false),
		"glasses": glasses, "height_scale": height_scale, "build": build, "girl": girl,
	}


## Ajusta o visual para menino ou menina (cabelo de partida).
func set_girl(on: bool) -> void:
	girl = on
	if on and hair_style in ["curto", "espetado", "raspado"]:
		hair_style = "longo"
	elif not on and hair_style in ["longo", "rabo"]:
		hair_style = "curto"


static func from_dict(d: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	for key in d.keys():
		if not key in a:
			continue
		var cur = a.get(key)
		var v = d[key]
		if cur is Color and v is String:
			a.set(key, Color.from_string(v, cur))
		elif cur is bool:
			a.set(key, bool(v))
		elif cur is float and (v is float or v is int):
			a.set(key, float(v))
		elif cur is String and v is String:
			a.set(key, v)
	if not a.hair_style in HAIR_STYLES:
		a.hair_style = "curto"
	a.height_scale = clampf(a.height_scale, 0.85, 1.15)
	a.build = clampf(a.build, 0.85, 1.2)
	return a


## Aparência aleatória coerente (para NPCs). Usa seed para ser reproduzível.
static func random(seed_value: int, uniform := true) -> CharacterAppearance:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var a := CharacterAppearance.new()
	a.skin = SKIN_TONES[r.randi() % SKIN_TONES.size()]
	a.hair_style = HAIR_STYLES[r.randi() % HAIR_STYLES.size()]
	a.hair_color = HAIR_COLORS[r.randi() % HAIR_COLORS.size()]
	if uniform:
		a.shirt_color = Color("f4f4f0")
		a.shirt_trim = [Color("2f6fd0"), Color("2f6fd0"), Color("d63c3c")][r.randi() % 3]
		a.pants_color = PANTS_COLORS[r.randi() % 2]
	else:
		a.shirt_color = SHIRT_COLORS[r.randi() % SHIRT_COLORS.size()]
		a.shirt_trim = a.shirt_color.darkened(0.2)
		a.shirt_logo = false
		a.pants_color = PANTS_COLORS[r.randi() % PANTS_COLORS.size()]
	a.long_pants = r.randf() < 0.4
	a.shoe_color = SHOE_COLORS[r.randi() % SHOE_COLORS.size()]
	a.backpack = r.randf() < 0.6
	a.backpack_color = BACKPACK_COLORS[r.randi() % BACKPACK_COLORS.size()]
	a.cap = r.randf() < 0.12
	a.cap_color = SHIRT_COLORS[r.randi() % SHIRT_COLORS.size()]
	a.glasses = r.randf() < 0.15
	a.height_scale = r.randf_range(0.92, 1.06)
	a.build = r.randf_range(0.92, 1.1)
	return a
