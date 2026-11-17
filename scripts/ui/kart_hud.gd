class_name KartHUD
extends Control
## Painel da corrida de kart: posição grande, volta, tempo, velocímetro,
## turbos e o mapinha da pista com todos os karts.

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
	# turbos
	for i in race._turbos:
		var c := Vector2(cx + 220 + i * 34, cy + 8)
		draw_circle(c, 14, Color("ffb300"))
		draw_string(f, c + Vector2(-7, 8), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("2c3e50"))
	# mapinha
	var box := Rect2(vs.x - 230, 110, 200, 170)
	draw_rect(box.grow(8), Color(0, 0, 0, 0.35))
	var line := PackedVector2Array()
	for p in _map_pts:
		line.append(_map(p, box))
	draw_polyline(line, Color(1, 1, 1, 0.85), 4.0, true)
	var sp: Vector3 = KartTrack.pos_at(0.0)
	draw_circle(_map(Vector2(sp.x, sp.z), box), 4, Color.WHITE)
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
