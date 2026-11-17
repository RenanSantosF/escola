class_name EmoteFX
extends Node3D
## Emojis ANIMADOS: uma figura colorida (desenhada pelo jogo, sem fonte de
## emoji) aparece pulando em cima da cabeça enquanto o boneco faz a
## dancinha. Os colegas online também veem.

## emote -> [figura, cor, animação da figura]
const FX := {
	"dance": ["notes", Color("ff6fae"), "bounce"], "robot": ["bolt", Color("4fc3ff"), "shake"],
	"floss": ["star", Color("ffd23f"), "spin"], "spin_jump": ["rainbow", Color("ffffff"), "pop"],
	"laugh": ["laugh", Color("ffd23f"), "shake"], "heart_hands": ["heart", Color("ff3b6b"), "pulse"],
	"flex": ["crown", Color("ffcf3f"), "pop"], "celebrate": ["star", Color("ffd23f"), "pop"],
	"clap": ["sparkle", Color("ffe680"), "pulse"],
}
static var _tex := {}

var kind := "heart"
var col := Color.WHITE
var anim := "pulse"
var _t := 0.0
var _life := 2.4
var _spr: Sprite3D
var _extra: Array[Sprite3D] = []


## Mostra a figura em cima de `target` (o visual do personagem).
static func spawn(target: Node3D, emote: String) -> void:
	if not FX.has(emote) or target == null or not target.is_inside_tree():
		return
	var e := EmoteFX.new()
	var f: Array = FX[emote]
	e.kind = f[0]
	e.col = f[1]
	e.anim = f[2]
	target.add_child(e)
	e.position = Vector3(0, 2.35, 0)


func _ready() -> void:
	_spr = _make()
	if kind in ["heart", "notes", "star"]:
		for i in 3:
			var s := _make()
			s.pixel_size *= 0.5
			s.modulate.a = 0.0
			_extra.append(s)


func _make() -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = icon(kind, col)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = 0.0075
	s.no_depth_test = true
	s.render_priority = 5
	s.shaded = false
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	var k := _t / _life
	var appear := clampf(_t / 0.18, 0.0, 1.0)
	var fade := clampf((_life - _t) / 0.3, 0.0, 1.0)
	var sc := 1.0
	match anim:
		"bounce":
			_spr.position.y = absf(sin(_t * 7.0)) * 0.25
			sc = 1.0 + 0.1 * sin(_t * 14.0)
		"pulse":
			sc = 1.0 + 0.22 * absf(sin(_t * 6.0))
		"spin":
			_spr.rotation.z = _t * 5.0
			sc = 1.0 + 0.1 * sin(_t * 9.0)
		"shake":
			_spr.position.x = sin(_t * 38.0) * 0.05
			_spr.rotation.z = sin(_t * 20.0) * 0.18
		"pop":
			sc = 1.0 + 0.5 * exp(-_t * 5.0) * absf(sin(_t * 14.0))
			_spr.position.y = _t * 0.12
	_spr.scale = Vector3.ONE * sc * appear * (0.6 + 0.4 * appear)
	_spr.modulate.a = fade
	for i in _extra.size():
		var s := _extra[i]
		var lt := fmod(_t * 0.9 + i * 0.33, 1.0)
		s.position = Vector3(sin(i * 2.1 + _t) * 0.4, lt * 0.9, 0)
		s.modulate.a = sin(lt * PI) * fade
	if _t >= _life:
		queue_free()
	k = k


# ------------------------------------------------------------------ figuras

## Textura da figura (feita uma vez e guardada).
static func icon(kind: String, c: Color) -> ImageTexture:
	var key := kind + c.to_html()
	if _tex.has(key):
		return _tex[key]
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var C := Vector2(n * 0.5, n * 0.5)
	var outline := Color("2c2340")
	match kind:
		"heart":
			_poly(img, _heart(C, 40.0), outline)
			_poly(img, _heart(C, 34.0), c)
			_disk(img, C + Vector2(-12, -14), 7, Color(1, 1, 1, 0.6))
		"star", "sparkle":
			var r1 := 44.0 if kind == "star" else 40.0
			var r2 := 20.0 if kind == "star" else 12.0
			_poly(img, _star(C, r1, r2, 5 if kind == "star" else 4), outline)
			_poly(img, _star(C, r1 - 6, r2 - 3, 5 if kind == "star" else 4), c)
		"laugh":
			_disk(img, C, 44, outline)
			_disk(img, C, 39, c)
			# olhos fechados de rir e boca aberta
			for sx in [-1, 1]:
				for k in 7:
					var a := PI + k * PI / 6.0
					_disk(img, C + Vector2(sx * 14, -8) + Vector2(cos(a), sin(a)) * 8, 2.5, outline)
			_poly(img, PackedVector2Array([C + Vector2(-22, 6), C + Vector2(22, 6), C + Vector2(14, 26), C + Vector2(-14, 26)]), outline)
			_poly(img, PackedVector2Array([C + Vector2(-12, 16), C + Vector2(12, 16), C + Vector2(8, 24), C + Vector2(-8, 24)]), Color("ff6f91"))
			_disk(img, C + Vector2(-32, 2), 6, Color("4fc3ff"))
			_disk(img, C + Vector2(32, 2), 6, Color("4fc3ff"))
		"notes":
			for o in [Vector2(-14, 10), Vector2(16, 0)]:
				_disk(img, C + o, 12, outline)
				_disk(img, C + o, 9, c)
				_rect(img, Rect2(C + o + Vector2(7, -38), Vector2(5, 38)), outline)
			_rect(img, Rect2(C + Vector2(-7, -38), Vector2(30, 8)), outline)
		"bolt":
			var b := PackedVector2Array([C + Vector2(8, -44), C + Vector2(-22, 6), C + Vector2(-2, 6), C + Vector2(-12, 44), C + Vector2(24, -8), C + Vector2(4, -8)])
			_poly(img, b, outline)
			var b2 := PackedVector2Array()
			for p in b:
				b2.append(C + (p - C) * 0.8)
			_poly(img, b2, c)
		"crown":
			var cr := PackedVector2Array([C + Vector2(-40, 26), C + Vector2(-40, -18), C + Vector2(-20, 4), C + Vector2(0, -30), C + Vector2(20, 4), C + Vector2(40, -18), C + Vector2(40, 26)])
			_poly(img, cr, outline)
			var cr2 := PackedVector2Array()
			for p in cr:
				cr2.append(C + (p - C) * 0.84 + Vector2(0, 2))
			_poly(img, cr2, c)
			for o in [Vector2(-18, 14), Vector2(0, 14), Vector2(18, 14)]:
				_disk(img, C + o, 5, Color("e53935"))
		"rainbow":
			var cols := [Color("e53935"), Color("ff8a1f"), Color("ffd23f"), Color("27ae60"), Color("2f80ed"), Color("8e44ad")]
			for i in cols.size():
				_ring(img, C + Vector2(0, 18), 44 - i * 6, 6, cols[i])
			_disk(img, C + Vector2(-34, 22), 10, Color.WHITE)
			_disk(img, C + Vector2(34, 22), 10, Color.WHITE)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func _heart(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * r / 17.0)
	return pts


static func _star(c: Vector2, r1: float, r2: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI * 0.5 + i * PI / n
		pts.append(c + Vector2(cos(a), sin(a)) * (r1 if i % 2 == 0 else r2))
	return pts


static func _inside(p: Vector2, poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)


static func _poly(img: Image, poly: PackedVector2Array, c: Color) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for y in range(maxi(int(r.position.y), 0), mini(int(r.end.y) + 1, img.get_height())):
		for x in range(maxi(int(r.position.x), 0), mini(int(r.end.x) + 1, img.get_width())):
			if _inside(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, c)


static func _disk(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(maxi(int(c.y - r), 0), mini(int(c.y + r) + 1, img.get_height())):
		for x in range(maxi(int(c.x - r), 0), mini(int(c.x + r) + 1, img.get_width())):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)


static func _ring(img: Image, c: Vector2, r: float, w: float, col: Color) -> void:
	for y in range(maxi(int(c.y - r), 0), mini(int(c.y) + 1, img.get_height())):
		for x in range(maxi(int(c.x - r), 0), mini(int(c.x + r) + 1, img.get_width())):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r and d >= r - w:
				img.set_pixel(x, y, col)


static func _rect(img: Image, r: Rect2, col: Color) -> void:
	img.fill_rect(Rect2i(r.intersection(Rect2(0, 0, img.get_width(), img.get_height()))), col)
