class_name KartHUD
extends Control
## Painel da corrida de kart: posição grande, volta, tempo, velocímetro,
## item (com roleta), vácuo e o mapinha da pista com todos os karts e o óleo.

var race: Node  # KartRace (minigame)
var _map_pts := PackedVector2Array()
var _map_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	var pts := KartTrack.points()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = mn.min(Vector2(p.x, p.z))
		mx = mx.max(Vector2(p.x, p.z))
	_map_rect = Rect2(mn, mx - mn)
	for i in range(0, pts.size(), 3):
		_map_pts.append(Vector2(pts[i].x, pts[i].z))
	_map_pts.append(_map_pts[0])


func _map(p: Vector2, box: Rect2) -> Vector2:
	var k := minf(box.size.x / _map_rect.size.x, box.size.y / _map_rect.size.y)
	var off := box.position + (box.size - _map_rect.size * k) * 0.5
	return off + (p - _map_rect.position) * k


func _shadow_text(f: Font, pos: Vector2, t: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string_outline(f, pos, t, align, w, fs, 10, Color(0, 0, 0, 0.55))
	draw_string(f, pos, t, align, w, fs, col)


func _draw() -> void:
	if race == null or not is_instance_valid(race) or race.me.is_empty():
		return
	var vs := size
	var f := UITheme.bold_font()
	var me: Dictionary = race.me
	var place: int = race._place_of(me)
	var n: int = race._racer_count()
	# posição: 1º grande
	var pcol: Color = [Color("ffd23f"), Color("dfe6ee"), Color("e59866")][place - 1] if place <= 3 else Color.WHITE
	_shadow_text(f, Vector2(28, vs.y * 0.56), "%dº" % place, 96, pcol)
	_shadow_text(f, Vector2(34, vs.y * 0.56 + 40), "de %d" % n, 30, Color.WHITE)
	# volta e tempo (em cima, no meio)
	var lap := mini(int(me.lap) + 1, race.LAPS)
	_shadow_text(f, Vector2(0, 140), "VOLTA %d/%d   ·   %s" % [lap, race.LAPS, race._fmt(race._elapsed)], 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	# velocímetro
	var kmh := int(absf(float(me.v)) * 3.6)
	var cx := vs.x * 0.5 - 100.0
	var cy := vs.y - 40.0
	draw_rect(Rect2(cx, cy, 200, 18), Color(0, 0, 0, 0.35))
	var frac := clampf(absf(float(me.v)) / race.BOOST_V, 0.0, 1.0)
	draw_rect(Rect2(cx, cy, 200 * frac, 18), Color("ff8a1f") if float(me.boost) > 0.0 else Color("4fc3ff"))
	_shadow_text(f, Vector2(cx, cy - 8), "%d km/h" % kmh, 30, Color.WHITE)
	# vácuo: barrinha carregando e "VÁCUO!" com riscos de vento
	var slip := clampf(float(me.slip) / race.SLIP_CHARGE, 0.0, 1.0)
	if slip > 0.05:
		var on := slip >= 1.0
		var wc := Color("bfe9ff") if on else Color(1, 1, 1, 0.75)
		var bx := vs.x * 0.5 + 115.0
		draw_rect(Rect2(bx, cy, 90, 18), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bx, cy, 90 * slip, 18), wc)
		_shadow_text(f, Vector2(bx, cy - 8), "VÁCUO!" if on else "vácuo", 26, wc)
		if on:
			var tt := Time.get_ticks_msec() * 0.004
			for i in 6:
				var yy := 200.0 + i * 70.0
				var xx := fposmod(tt * 300.0 + i * 137.0, 160.0)
				draw_line(Vector2(xx, yy), Vector2(xx + 70, yy), Color(1, 1, 1, 0.35), 3.0)
				draw_line(Vector2(vs.x - xx, yy + 30), Vector2(vs.x - xx - 70, yy + 30), Color(1, 1, 1, 0.35), 3.0)
	# caixa do item (com a roleta girando quando pegou uma caixinha)
	var ib := Rect2(28, vs.y * 0.56 - 225.0, 108, 108)
	draw_rect(ib.grow(4), Color(1, 1, 1, 0.9), false, 4.0)
	draw_rect(ib, Color(0.1, 0.12, 0.2, 0.55))
	var shown := str(me.item)
	if float(me.roulette) > 0.0:
		var names := ["turbo", "oleo", "turbo3", "foguete"]
		shown = names[int(Time.get_ticks_msec() / 90) % names.size()]
	if shown != "":
		draw_item(self, shown, ib.get_center(), 40.0, int(me.item_n))
		if float(me.roulette) <= 0.0:
			_shadow_text(f, Vector2(ib.position.x - 10, ib.end.y + 30), "toque no amarelo", 18, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, ib.size.x + 20)
	else:
		_shadow_text(f, ib.get_center() + Vector2(-ib.size.x * 0.5, 16), "?", 48, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, ib.size.x)
	# mapinha
	var box := Rect2(vs.x - 230, 110, 200, 170)
	draw_rect(box.grow(8), Color(0, 0, 0, 0.35))
	var line := PackedVector2Array()
	for p in _map_pts:
		line.append(_map(p, box))
	draw_polyline(line, Color(1, 1, 1, 0.85), 4.0, true)
	var sp: Vector3 = KartTrack.pos_at(0.0)
	draw_circle(_map(Vector2(sp.x, sp.z), box), 4, Color.WHITE)
	for oil in race._oils:
		var o3: Vector3 = KartTrack.pos_at(float(oil.s))
		draw_circle(_map(Vector2(o3.x, o3.z), box), 3.5, Color(0.12, 0.08, 0.2))
	for r in race.racers:
		var p3: Vector3 = KartTrack.pos_at(float(r.s))
		var mp := _map(Vector2(p3.x, p3.z), box)
		draw_circle(mp, 8 if r == me else 6, Color.WHITE)
		draw_circle(mp, 6 if r == me else 4.5, r.color)
	# miniturbo carregando
	if race._drift and race._drift_t > 0.3:
		var t: float = race._drift_t
		var col := Color("ff8a1f") if t >= race.DRIFT_MINI[1] else (Color("4fc3ff") if t >= race.DRIFT_MINI[0] else Color(1, 1, 1, 0.7))
		_shadow_text(f, Vector2(0, vs.y * 0.7), "DERRAPANDO!", 40, col, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


## Desenha o ícone de um item do kart (turbo, turbo3, oleo, foguete).
static func draw_item(ci: CanvasItem, id: String, c: Vector2, r: float, n := 1) -> void:
	match id:
		"turbo":
			_chevrons(ci, c, r, Color("ff8a1f"))
		"turbo3":
			for i in clampi(n, 1, 3):
				var a := TAU * i / 3.0 - PI * 0.5
				_chevrons(ci, c + Vector2(cos(a), sin(a)) * r * 0.45, r * 0.5, Color("ff8a1f"))
		"oleo":
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				var rr := r * (0.8 + 0.12 * sin(a * 3.0))
				pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.6 + r * 0.1))
			ci.draw_colored_polygon(pts, Color(0.12, 0.08, 0.2))
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.02), r * 0.18, Color(0.7, 0.5, 1.0, 0.7))
			ci.draw_circle(c + Vector2(-r * 0.05, -r * 0.65), r * 0.22, Color(0.12, 0.08, 0.2))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.6), c + Vector2(r * 0.15, -r * 0.6), c + Vector2(-r * 0.05, -r * 1.0)]), Color(0.12, 0.08, 0.2))
		"foguete":
			var body := PackedVector2Array([c + Vector2(-r * 0.28, r * 0.55), c + Vector2(-r * 0.28, -r * 0.35), c + Vector2(0, -r * 0.9), c + Vector2(r * 0.28, -r * 0.35), c + Vector2(r * 0.28, r * 0.55)])
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.15, r * 0.55), c + Vector2(r * 0.15, r * 0.55), c + Vector2(0, r * 1.05)]), Color("ffb300"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.28, r * 0.15), c + Vector2(-r * 0.6, r * 0.6), c + Vector2(-r * 0.28, r * 0.55)]), Color("2f80ed"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.28, r * 0.15), c + Vector2(r * 0.6, r * 0.6), c + Vector2(r * 0.28, r * 0.55)]), Color("2f80ed"))
			ci.draw_colored_polygon(body, Color("e53935"))
			ci.draw_circle(c + Vector2(0, -r * 0.2), r * 0.15, Color("bfe9ff"))


static func _chevrons(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for k in 2:
		var y := c.y + r * 0.35 - k * r * 0.65
		var pts := PackedVector2Array([Vector2(c.x - r * 0.75, y + r * 0.3), Vector2(c.x, y - r * 0.4), Vector2(c.x + r * 0.75, y + r * 0.3), Vector2(c.x + r * 0.75, y + r * 0.62), Vector2(c.x, y - r * 0.08), Vector2(c.x - r * 0.75, y + r * 0.62)])
		ci.draw_colored_polygon(pts, col.lightened(0.15 * k))
