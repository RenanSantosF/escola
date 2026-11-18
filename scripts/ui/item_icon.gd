class_name ItemIcon
extends Control
## Ícone desenhado de um item da loja (camiseta, calça, tênis, mochila, boné,
## penteado, óculos, skin, emoji animado, efeito, veículo, decoração...),
## com fundo da cor da raridade e brilho passando nos épicos e lendários.

var item: Dictionary = {}
var _t := 0.0
var animate := true


func _init(it: Dictionary = {}) -> void:
	item = it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 100)


func _process(delta: float) -> void:
	if animate and is_visible_in_tree():
		_t += delta
		var rar := ShopCatalog.rarity_of(item)
		if rar in ["epico", "lendario"] or item.get("animated", false) or item.cat == "aura":
			queue_redraw()


func _col(key: String, def: Color) -> Color:
	var look: Dictionary = item.get("look", {})
	return Color(look[key]) if look.has(key) else def


func _draw() -> void:
	if item.is_empty() or size.x < 4.0 or size.y < 4.0:
		return
	var rar := ShopCatalog.rarity_of(item)
	var rcol: Color = ShopCatalog.RARITY[rar][1]
	var r := Rect2(Vector2.ZERO, size)
	# fundo: degradê da raridade com raios
	var top := rcol.lightened(0.45)
	var bot := rcol.darkened(0.05)
	var steps := 12
	for i in steps:
		var y0 := size.y * i / steps
		draw_rect(Rect2(0, y0, size.x, size.y / steps + 1), top.lerp(bot, float(i) / steps))
	var c := size * 0.5
	if rar in ["epico", "lendario"]:
		for k in 10:
			var a := _t * 0.4 + k * TAU / 10.0
			var p1 := c + Vector2(cos(a), sin(a)) * size.length()
			var p2 := c + Vector2(cos(a + 0.12), sin(a + 0.12)) * size.length()
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1, 1, 1, 0.12))
	var s := minf(size.x, size.y) * 0.4
	draw_set_transform(c, 0.0, Vector2.ONE)
	match str(item.cat):
		"camiseta":
			_shirt(s, _col("shirt_color", Color.WHITE), _col("shirt_trim", Color("2f6fd0")), bool(item.get("look", {}).get("shirt_logo", false)))
		"calca":
			_pants(s, _col("pants_color", Color("23325c")), bool(item.get("look", {}).get("long_pants", false)))
		"calcado":
			_shoe(s, _col("shoe_color", Color.WHITE))
		"mochila":
			if bool(item.get("look", {}).get("backpack", true)):
				_bag(s, _col("backpack_color", Color("d63c3c")))
			else:
				_none(s)
		"bone":
			if bool(item.get("look", {}).get("cap", true)):
				_cap(s, _col("cap_color", Color("2f6fd0")))
			else:
				_none(s)
		"penteado":
			_hair(s, _col("hair_color", Color("3b2417")), str(item.get("look", {}).get("hair_style", "curto")))
		"acessorio":
			if bool(item.get("look", {}).get("glasses", false)):
				_glasses(s)
			else:
				_none(s)
		"skin":
			_mini_kid(s)
		"emote":
			var fx: Array = EmoteFX.FX.get(str(item.get("emote", "")), ["sparkle", Color("ffe680"), "pulse"])
			var tex := EmoteFX.icon(fx[0], fx[1])
			var k := 1.0 + (0.12 * absf(sin(_t * 5.0)) if item.get("animated", false) else 0.0)
			draw_texture_rect(tex, Rect2(-Vector2(s, s) * k, Vector2(s, s) * 2.0 * k), false)
		"aura":
			var kind := str(item.get("look", {}).get("aura", ""))
			if kind == "":
				_none(s)
			else:
				var tex2 := CharacterVisual.aura_icon(kind)
				for i in 6:
					var a := _t * 1.6 + i * TAU / 6.0
					var p := Vector2(cos(a) * s * 0.8, sin(a) * s * 0.35 - fmod(_t * 30.0 + i * 15.0, s * 1.2) + s * 0.4)
					draw_texture_rect(tex2, Rect2(p - Vector2(s, s) * 0.22, Vector2(s, s) * 0.44), false)
				_mini_kid(s * 0.7, true)
		"veiculo":
			_vehicle(s, str(item.get("vehicle", "skate")))
		"kart":
			_kart(s, item.get("kart", {}))
		"decoracao":
			_decor(s, str(item.get("decor", "")))
		"pacote":
			_gift(s)
		"figurinha":
			_card(s)
		"gude":
			for i in 3:
				var cc: Color = [Color("3fa7d6"), Color("e84393"), Color("ffd23f")][i]
				var pp := Vector2(-s * 0.5 + i * s * 0.5, s * 0.15 * (i % 2))
				draw_circle(pp, s * 0.3, cc)
				draw_circle(pp + Vector2(-s * 0.1, -s * 0.1), s * 0.09, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# brilho passando (épico/lendário)
	if rar in ["epico", "lendario"]:
		var x := fmod(_t * 0.7, 2.0) * size.x * 1.4 - size.x * 0.4
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 24, 0), Vector2(x - size.y * 0.4 + 24, size.y), Vector2(x - size.y * 0.4, size.y)]), Color(1, 1, 1, 0.25))
	r = r


func _o(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var cl := pts.duplicate()
	cl.append(pts[0])
	draw_polyline(cl, col.darkened(0.45), 3.0, true)


func _shirt(s: float, col: Color, trim: Color, logo: bool) -> void:
	_o(PackedVector2Array([Vector2(-s * 0.45, -s * 0.8), Vector2(-s, -s * 0.45), Vector2(-s * 0.75, -s * 0.05), Vector2(-s * 0.5, -s * 0.25),
		Vector2(-s * 0.5, s * 0.85), Vector2(s * 0.5, s * 0.85), Vector2(s * 0.5, -s * 0.25), Vector2(s * 0.75, -s * 0.05),
		Vector2(s, -s * 0.45), Vector2(s * 0.45, -s * 0.8), Vector2(s * 0.18, -s * 0.7), Vector2(-s * 0.18, -s * 0.7)]), col)
	_pattern_2d(str(item.get("look", {}).get("shirt_pattern", "")), Rect2(-s * 0.48, -s * 0.45, s * 0.96, s * 1.28), trim)
	draw_polyline(PackedVector2Array([Vector2(-s * 0.45, -s * 0.8), Vector2(-s * 0.18, -s * 0.7), Vector2(0, -s * 0.5), Vector2(s * 0.18, -s * 0.7), Vector2(s * 0.45, -s * 0.8)]), trim, 6.0, true)
	draw_line(Vector2(-s, -s * 0.45), Vector2(-s * 0.75, -s * 0.05), trim, 6.0)
	draw_line(Vector2(s, -s * 0.45), Vector2(s * 0.75, -s * 0.05), trim, 6.0)
	if logo:
		draw_circle(Vector2(-s * 0.22, -s * 0.25), s * 0.12, trim)


## Estampa desenhada dentro de um retângulo (camiseta/tronco).
func _pattern_2d(kind: String, r: Rect2, c: Color) -> void:
	match kind:
		"listras":
			var n := 5
			for i in n:
				if i % 2 == 0:
					draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / n, r.size.x, r.size.y / n), c)
		"xadrez":
			for i in 4:
				for j in 4:
					if (i + j) % 2 == 0:
						draw_rect(Rect2(r.position + Vector2(r.size.x * i / 4.0, r.size.y * j / 4.0), r.size / 4.0), c)
		"faixa":
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, r.size.y * 0.25), r.position + Vector2(r.size.x, r.size.y * 0.65),
				r.position + Vector2(r.size.x, r.size.y * 0.9), r.position + Vector2(0, r.size.y * 0.5)]), c)
		"raio":
			var o := r.position + r.size * 0.5
			var w := r.size.x * 0.25
			var h := r.size.y * 0.45
			draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.3, -h), o + Vector2(-w, h * 0.1), o + Vector2(0, h * 0.1), o + Vector2(-w * 0.4, h), o + Vector2(w, -h * 0.15), o + Vector2(0, -h * 0.15)]), c)
		"degrade":
			for i in 8:
				var col := c
				col.a = float(i) / 8.0
				draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / 8.0, r.size.x, r.size.y / 8.0 + 1), col)
		"estrela":
			var pts := PackedVector2Array()
			var o2 := r.position + r.size * 0.5
			var rr := minf(r.size.x, r.size.y) * 0.32
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(o2 + Vector2(cos(a), sin(a)) * (rr if i % 2 == 0 else rr * 0.45))
			draw_colored_polygon(pts, c)


func _pants(s: float, col: Color, long: bool) -> void:
	var h := s * (0.95 if long else 0.45)
	_o(PackedVector2Array([Vector2(-s * 0.55, -s * 0.7), Vector2(s * 0.55, -s * 0.7), Vector2(s * 0.62, -s * 0.7 + h * 2.0), Vector2(s * 0.08, -s * 0.7 + h * 2.0),
		Vector2(0, -s * 0.25), Vector2(-s * 0.08, -s * 0.7 + h * 2.0), Vector2(-s * 0.62, -s * 0.7 + h * 2.0)]), col)
	draw_rect(Rect2(-s * 0.55, -s * 0.7, s * 1.1, s * 0.14), col.darkened(0.3))


func _shoe(s: float, col: Color) -> void:
	_o(PackedVector2Array([Vector2(-s * 0.8, s * 0.2), Vector2(-s * 0.7, -s * 0.45), Vector2(-s * 0.15, -s * 0.45), Vector2(s * 0.1, -s * 0.05),
		Vector2(s * 0.85, s * 0.1), Vector2(s * 0.9, s * 0.35), Vector2(-s * 0.8, s * 0.35)]), col)
	draw_rect(Rect2(-s * 0.82, s * 0.3, s * 1.74, s * 0.16), Color("eeeeee"))
	for i in 3:
		draw_line(Vector2(-s * 0.5 + i * s * 0.16, -s * 0.35), Vector2(-s * 0.35 + i * s * 0.16, -s * 0.1), Color.WHITE, 3.0)


func _bag(s: float, col: Color) -> void:
	draw_arc(Vector2(0, -s * 0.6), s * 0.3, PI, TAU, 16, col.darkened(0.3), 6.0)
	_o(PackedVector2Array([Vector2(-s * 0.6, -s * 0.6), Vector2(s * 0.6, -s * 0.6), Vector2(s * 0.7, s * 0.85), Vector2(-s * 0.7, s * 0.85)]), col)
	_o(PackedVector2Array([Vector2(-s * 0.4, s * 0.1), Vector2(s * 0.4, s * 0.1), Vector2(s * 0.45, s * 0.7), Vector2(-s * 0.45, s * 0.7)]), col.lightened(0.15))


func _cap(s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(Vector2(cos(a) * s * 0.7, sin(a) * s * 0.65 + s * 0.15))
	_o(pts, col)
	_o(PackedVector2Array([Vector2(s * 0.3, s * 0.1), Vector2(s * 1.05, s * 0.18), Vector2(s * 1.0, s * 0.32), Vector2(s * 0.3, s * 0.28)]), col.darkened(0.2))
	draw_circle(Vector2(0, -s * 0.5), s * 0.08, col.darkened(0.3))


func _hair(s: float, col: Color, style: String) -> void:
	draw_circle(Vector2(0, s * 0.15), s * 0.55, Color("e8b48f"))
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.append(Vector2(cos(a) * s * 0.62, sin(a) * s * 0.62 + s * 0.05))
	match style:
		"longo", "rabo":
			_o(PackedVector2Array([Vector2(-s * 0.62, s * 0.05), Vector2(-s * 0.7, s * 0.9), Vector2(-s * 0.35, s * 0.9), Vector2(-s * 0.45, s * 0.1)]), col)
			_o(PackedVector2Array([Vector2(s * 0.62, s * 0.05), Vector2(s * 0.7, s * 0.9), Vector2(s * 0.35, s * 0.9), Vector2(s * 0.45, s * 0.1)]), col)
		"black_power", "cacheado":
			for i in 9:
				var a := PI + PI * i / 8.0
				draw_circle(Vector2(cos(a) * s * 0.6, sin(a) * s * 0.6), s * (0.3 if style == "black_power" else 0.2), col)
		"espetado":
			for i in 5:
				var x := -s * 0.5 + i * s * 0.25
				_o(PackedVector2Array([Vector2(x - s * 0.15, -s * 0.3), Vector2(x, -s * 0.85), Vector2(x + s * 0.15, -s * 0.3)]), col)
	_o(cap, col)
	draw_circle(Vector2(-s * 0.2, s * 0.2), s * 0.06, Color("2b1a10"))
	draw_circle(Vector2(s * 0.2, s * 0.2), s * 0.06, Color("2b1a10"))
	draw_arc(Vector2(0, s * 0.32), s * 0.15, 0.3, PI - 0.3, 10, Color("8a3b2b"), 3.0)


func _glasses(s: float) -> void:
	for sx in [-1.0, 1.0]:
		draw_arc(Vector2(sx * s * 0.42, 0), s * 0.32, 0, TAU, 24, Color("1d1d1d"), 6.0)
		draw_circle(Vector2(sx * s * 0.42, 0), s * 0.28, Color(0.8, 0.95, 1.0, 0.5))
	draw_line(Vector2(-s * 0.12, -s * 0.05), Vector2(s * 0.12, -s * 0.05), Color("1d1d1d"), 5.0)


func _mini_kid(s: float, simple := false) -> void:
	var shirt := _col("shirt_color", Color("f4f4f0"))
	var trim := _col("shirt_trim", Color("2f6fd0"))
	var pants := _col("pants_color", Color("23325c"))
	var shoe := _col("shoe_color", Color.WHITE)
	var hair := _col("hair_color", Color("3b2417"))
	if simple:
		shirt = Color("f4f4f0")
		trim = Color("2f6fd0")
	draw_rect(Rect2(-s * 0.32, s * 0.25, s * 0.26, s * 0.6), pants)
	draw_rect(Rect2(s * 0.06, s * 0.25, s * 0.26, s * 0.6), pants)
	draw_rect(Rect2(-s * 0.38, s * 0.8, s * 0.32, s * 0.14), shoe)
	draw_rect(Rect2(s * 0.06, s * 0.8, s * 0.32, s * 0.14), shoe)
	_o(PackedVector2Array([Vector2(-s * 0.4, -s * 0.35), Vector2(s * 0.4, -s * 0.35), Vector2(s * 0.42, s * 0.3), Vector2(-s * 0.42, s * 0.3)]), shirt)
	draw_line(Vector2(-s * 0.4, -s * 0.35), Vector2(s * 0.4, -s * 0.35), trim, 5.0)
	if not simple:
		_pattern_2d(str(item.get("look", {}).get("shirt_pattern", "")), Rect2(-s * 0.4, -s * 0.33, s * 0.8, s * 0.62), trim)
	draw_rect(Rect2(-s * 0.62, -s * 0.3, s * 0.2, s * 0.5), shirt)
	draw_rect(Rect2(s * 0.42, -s * 0.3, s * 0.2, s * 0.5), shirt)
	draw_circle(Vector2(0, -s * 0.65), s * 0.32, Color("e8b48f"))
	draw_arc(Vector2(0, -s * 0.7), s * 0.33, PI, TAU, 16, hair, s * 0.16)
	if bool(item.get("look", {}).get("cap", false)) and not simple:
		_cap(s * 0.42, _col("cap_color", Color("2f6fd0")))
	if bool(item.get("look", {}).get("glasses", false)) and not simple:
		draw_line(Vector2(-s * 0.2, -s * 0.66), Vector2(s * 0.2, -s * 0.66), Color("1d1d1d"), 3.0)


func _vehicle(s: float, kind: String) -> void:
	match kind:
		"bike":
			draw_arc(Vector2(-s * 0.55, s * 0.3), s * 0.35, 0, TAU, 20, Color("1d1d1d"), 5.0)
			draw_arc(Vector2(s * 0.55, s * 0.3), s * 0.35, 0, TAU, 20, Color("1d1d1d"), 5.0)
			draw_polyline(PackedVector2Array([Vector2(-s * 0.55, s * 0.3), Vector2(-s * 0.1, -s * 0.2), Vector2(s * 0.45, -s * 0.2), Vector2(s * 0.55, s * 0.3)]), Color("e53935"), 6.0)
			draw_line(Vector2(-s * 0.1, -s * 0.2), Vector2(0, s * 0.3), Color("e53935"), 6.0)
		_:
			_o(PackedVector2Array([Vector2(-s * 0.95, -s * 0.05), Vector2(s * 0.95, -s * 0.05), Vector2(s * 0.85, s * 0.12), Vector2(-s * 0.85, s * 0.12)]), Color("ff8a1f") if kind == "skate" else Color("2f80ed"))
			draw_circle(Vector2(-s * 0.55, s * 0.28), s * 0.14, Color("1d1d1d"))
			draw_circle(Vector2(s * 0.55, s * 0.28), s * 0.14, Color("1d1d1d"))
			if kind == "patinete":
				draw_line(Vector2(s * 0.75, -s * 0.05), Vector2(s * 0.6, -s * 0.9), Color("8a96a3"), 6.0)
				draw_line(Vector2(s * 0.4, -s * 0.9), Vector2(s * 0.8, -s * 0.9), Color("1d1d1d"), 7.0)


func _kart(s: float, k: Dictionary) -> void:
	var col := Color(str(k.get("color", ""))) if str(k.get("color", "")) != "" else Color("e53935")
	var acc := Color(str(k.get("accent", "ffffff")))
	var style := str(k.get("style", ""))
	var body := str(k.get("body", ""))
	var rim := Color("ffcf3f") if body == "campeao" else (acc if body == "neon" else Color("cfd5dc"))
	var rw := s * (0.29 if body in ["turbo", "campeao"] else 0.24)
	# visto de lado: corpo, bico, aerofólio, rodas e piloto
	if body == "neon":
		draw_line(Vector2(-s * 0.9, s * 0.32), Vector2(s * 0.95, s * 0.32), Color(acc, 0.35), s * 0.22)
		draw_line(Vector2(-s * 0.9, s * 0.3), Vector2(s * 0.95, s * 0.3), acc, s * 0.07)
	if body == "foguete":
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 1.0, -s * 0.05), Vector2(-s * 1.0, s * 0.2), Vector2(-s * 1.55, s * 0.08)]), Color("ff8a1f"))
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 1.0, s * 0.02), Vector2(-s * 1.0, s * 0.14), Vector2(-s * 1.3, s * 0.08)]), Color("ffe08a"))
	draw_circle(Vector2(-s * 0.55, s * 0.35 - (rw - s * 0.24)), rw, Color("1d1d1d"))
	draw_circle(Vector2(s * 0.6, s * 0.35), s * 0.24, Color("1d1d1d"))
	draw_circle(Vector2(-s * 0.55, s * 0.35 - (rw - s * 0.24)), rw * 0.45, rim)
	draw_circle(Vector2(s * 0.6, s * 0.35), s * 0.24 * 0.45, rim)
	_o(PackedVector2Array([Vector2(-s * 0.95, s * 0.15), Vector2(-s * 0.85, -s * 0.15), Vector2(s * 0.3, -s * 0.15), Vector2(s * 1.0, s * 0.05), Vector2(s * 1.0, s * 0.25), Vector2(-s * 0.95, s * 0.25)]), col)
	match body:
		"":
			_o(PackedVector2Array([Vector2(-s * 1.0, -s * 0.45), Vector2(-s * 0.7, -s * 0.45), Vector2(-s * 0.75, -s * 0.15), Vector2(-s * 0.9, -s * 0.15)]), col.darkened(0.3))
		"esportivo", "neon":
			draw_line(Vector2(-s * 0.85, -s * 0.15), Vector2(-s * 0.85, -s * 0.55), Color("2b2d33"), s * 0.07)
			_o(PackedVector2Array([Vector2(-s * 1.15, -s * 0.66), Vector2(-s * 0.6, -s * 0.6), Vector2(-s * 0.62, -s * 0.5), Vector2(-s * 1.12, -s * 0.52)]), acc if body == "esportivo" else col.lightened(0.2))
			if body == "neon":
				draw_line(Vector2(-s * 1.15, -s * 0.68), Vector2(-s * 0.6, -s * 0.62), acc, s * 0.05)
			draw_line(Vector2(s * 0.75, s * 0.27), Vector2(s * 1.15, s * 0.27), Color("1d1d1d"), s * 0.06)
		"turbo":
			# carburadores cromados e asa gigante
			for i in 3:
				var x := -s * 0.62 + i * s * 0.11
				draw_rect(Rect2(x, -s * 0.5, s * 0.08, s * 0.36), Color("d7dde4"))
				draw_rect(Rect2(x - s * 0.015, -s * 0.54, s * 0.11, s * 0.06), Color("9aa5b1"))
			draw_line(Vector2(-s * 0.95, -s * 0.15), Vector2(-s * 0.95, -s * 0.62), Color("2b2d33"), s * 0.08)
			_o(PackedVector2Array([Vector2(-s * 1.4, -s * 0.8), Vector2(-s * 0.68, -s * 0.7), Vector2(-s * 0.7, -s * 0.57), Vector2(-s * 1.37, -s * 0.62)]), acc)
			_o(PackedVector2Array([Vector2(-s * 1.42, -s * 0.95), Vector2(-s * 0.95, -s * 0.89), Vector2(-s * 0.97, -s * 0.81), Vector2(-s * 1.4, -s * 0.85)]), col)
			draw_line(Vector2(-s * 0.95, s * 0.12), Vector2(-s * 1.25, s * 0.06), Color("d7dde4"), s * 0.09)
			draw_line(Vector2(s * 0.7, s * 0.27), Vector2(s * 1.2, s * 0.27), Color("1d1d1d"), s * 0.07)
		"foguete":
			_o(PackedVector2Array([Vector2(s * 0.95, -s * 0.1), Vector2(s * 1.55, s * 0.08), Vector2(s * 0.95, s * 0.25)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(s * 1.3, s * 0.0), Vector2(s * 1.55, s * 0.08), Vector2(s * 1.3, s * 0.15)]), acc)
			_o(PackedVector2Array([Vector2(-s * 0.95, -s * 0.15), Vector2(-s * 0.85, -s * 0.75), Vector2(-s * 0.6, -s * 0.15)]), acc)
			draw_line(Vector2(-s * 0.7, s * 0.05), Vector2(s * 0.5, s * 0.05), acc, s * 0.18)
		"campeao":
			_o(PackedVector2Array([Vector2(s * 0.9, s * 0.0), Vector2(s * 1.6, s * 0.12), Vector2(s * 1.6, s * 0.22), Vector2(s * 0.9, s * 0.22)]), col)
			_o(PackedVector2Array([Vector2(s * 1.25, s * 0.28), Vector2(s * 1.7, s * 0.28), Vector2(s * 1.7, s * 0.34), Vector2(s * 1.25, s * 0.34)]), acc)
			_o(PackedVector2Array([Vector2(-s * 0.55, -s * 0.15), Vector2(-s * 0.5, -s * 0.6), Vector2(-s * 0.3, -s * 0.6), Vector2(-s * 0.2, -s * 0.15)]), col)
			draw_line(Vector2(-s * 0.95, -s * 0.15), Vector2(-s * 0.95, -s * 0.7), Color("2b2d33"), s * 0.07)
			_o(PackedVector2Array([Vector2(-s * 1.25, -s * 0.86), Vector2(-s * 0.7, -s * 0.8), Vector2(-s * 0.72, -s * 0.7), Vector2(-s * 1.22, -s * 0.72)]), acc)
			_o(PackedVector2Array([Vector2(-s * 1.28, -s * 1.0), Vector2(-s * 0.85, -s * 0.95), Vector2(-s * 0.87, -s * 0.88), Vector2(-s * 1.26, -s * 0.9)]), acc)
	match style:
		"listras":
			draw_rect(Rect2(-s * 0.6, -s * 0.05, s * 1.5, s * 0.08), acc)
		"xadrez":
			for i in 6:
				draw_rect(Rect2(-s * 0.6 + i * s * 0.22, -s * 0.12 + (i % 2) * s * 0.12, s * 0.12, s * 0.12), acc)
		"chamas":
			for i in 4:
				draw_colored_polygon(PackedVector2Array([Vector2(s * 0.5 - i * s * 0.3, s * 0.2), Vector2(s * 0.25 - i * s * 0.3, -s * 0.1), Vector2(s * 0.1 - i * s * 0.3, s * 0.2)]), acc)
		"estrelas":
			for p in [Vector2(-s * 0.4, 0), Vector2(0.1 * s, s * 0.05), Vector2(s * 0.55, s * 0.08)]:
				draw_circle(p, s * 0.07, acc)
		"arco":
			var rb := [Color("e53935"), Color("ff8a1f"), Color("ffd23f"), Color("27ae60"), Color("2f80ed")]
			for i in rb.size():
				draw_rect(Rect2(-s * 0.85, -s * 0.12 + i * s * 0.07, s * 1.8, s * 0.07), rb[i])
	draw_circle(Vector2(-s * 0.15, -s * 0.38), s * 0.2, Color("e8b48f"))
	draw_arc(Vector2(-s * 0.15, -s * 0.38), s * 0.22, PI, TAU, 12, col.darkened(0.2), s * 0.12)


func _decor(s: float, kind: String) -> void:
	match kind:
		"planta":
			_o(PackedVector2Array([Vector2(-s * 0.4, s * 0.2), Vector2(s * 0.4, s * 0.2), Vector2(s * 0.3, s * 0.85), Vector2(-s * 0.3, s * 0.85)]), Color("c0703f"))
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.45
				draw_circle(Vector2(cos(a), sin(a)) * s * 0.55 + Vector2(0, s * 0.1), s * 0.22, Color("27ae60"))
		"globo":
			draw_circle(Vector2(0, -s * 0.1), s * 0.6, Color("2f80ed"))
			draw_circle(Vector2(-s * 0.2, -s * 0.25), s * 0.22, Color("27ae60"))
			draw_circle(Vector2(s * 0.25, s * 0.05), s * 0.18, Color("27ae60"))
			draw_rect(Rect2(-s * 0.3, s * 0.6, s * 0.6, s * 0.15), Color("8a5a32"))
		"trofeu":
			_o(PackedVector2Array([Vector2(-s * 0.5, -s * 0.7), Vector2(s * 0.5, -s * 0.7), Vector2(s * 0.3, s * 0.0), Vector2(-s * 0.3, s * 0.0)]), Color("ffcf3f"))
			draw_rect(Rect2(-s * 0.08, 0, s * 0.16, s * 0.5), Color("ffcf3f"))
			draw_rect(Rect2(-s * 0.4, s * 0.5, s * 0.8, s * 0.2), Color("8a5a32"))
		_:
			_o(PackedVector2Array([Vector2(-s * 0.8, -s * 0.2), Vector2(s * 0.8, -s * 0.2), Vector2(s * 0.8, s * 0.3), Vector2(-s * 0.8, s * 0.3)]), Color("ff6fae"))
			for i in 4:
				draw_rect(Rect2(-s * 0.6 + i * s * 0.35, -s * 0.55, s * 0.12, s * 0.4), [Color("e53935"), Color("2f80ed"), Color("ffd23f"), Color("27ae60")][i])


func _gift(s: float) -> void:
	_o(PackedVector2Array([Vector2(-s * 0.7, -s * 0.2), Vector2(s * 0.7, -s * 0.2), Vector2(s * 0.7, s * 0.8), Vector2(-s * 0.7, s * 0.8)]), Color("e53935"))
	_o(PackedVector2Array([Vector2(-s * 0.8, -s * 0.45), Vector2(s * 0.8, -s * 0.45), Vector2(s * 0.8, -s * 0.15), Vector2(-s * 0.8, -s * 0.15)]), Color("ff5a5a"))
	draw_rect(Rect2(-s * 0.1, -s * 0.45, s * 0.2, s * 1.25), Color("ffd23f"))
	draw_circle(Vector2(-s * 0.2, -s * 0.6), s * 0.18, Color("ffd23f"))
	draw_circle(Vector2(s * 0.2, -s * 0.6), s * 0.18, Color("ffd23f"))


func _card(s: float) -> void:
	for i in 3:
		var o := Vector2((i - 1) * s * 0.3, (i - 1) * s * 0.08)
		_o(PackedVector2Array([o + Vector2(-s * 0.4, -s * 0.6), o + Vector2(s * 0.4, -s * 0.6), o + Vector2(s * 0.4, s * 0.6), o + Vector2(-s * 0.4, s * 0.6)]), [Color("ffd23f"), Color("4fc3ff"), Color("ff6fae")][i])


func _none(s: float) -> void:
	draw_arc(Vector2.ZERO, s * 0.6, 0, TAU, 32, Color(1, 1, 1, 0.85), 8.0)
	draw_line(Vector2(-s * 0.42, s * 0.42), Vector2(s * 0.42, -s * 0.42), Color(1, 1, 1, 0.85), 8.0)
