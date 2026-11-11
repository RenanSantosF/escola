class_name LobbyBackground
extends Control
## Fundo animado do menu: céu em degradê, raios de sol girando atrás do
## personagem, nuvens passando, confete caindo e morrinhos com flores.
## Tudo desenhado em 2D (leve, sem texturas).

const CONFETTI := 46
const CLOUDS := 6
const COLORS := [Color("ff4d6d"), Color("ffd23f"), Color("3ec1ff"), Color("6be36b"), Color("b46bff"), Color("ff9f43")]

var rays_center := Vector2(0.5, 0.52)  ## fração da tela
var _t := 0.0
var _conf: Array = []
var _clouds: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 7
	for i in CONFETTI:
		_conf.append({"x": _rng.randf(), "y": _rng.randf(), "s": _rng.randf_range(0.04, 0.09), "r": _rng.randf() * TAU,
			"w": _rng.randf_range(1.5, 4.0), "c": COLORS[i % COLORS.size()], "z": _rng.randf_range(6.0, 12.0)})
	for i in CLOUDS:
		_clouds.append({"x": _rng.randf(), "y": _rng.randf_range(0.06, 0.38), "s": _rng.randf_range(0.6, 1.3), "v": _rng.randf_range(0.006, 0.016)})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for c in _conf:
		c.y += c.s * delta
		c.r += c.w * delta
		if c.y > 1.05:
			c.y = -0.05
			c.x = _rng.randf()
	for cl in _clouds:
		cl.x += cl.v * delta
		if cl.x > 1.25:
			cl.x = -0.25
	queue_redraw()


func _draw() -> void:
	var sz := size
	# céu: azul vivo em cima, azul-claro e um toque quente no horizonte
	var top := Color("3d6dff")
	var mid := Color("62c3ff")
	var low := Color("bdf0ff")
	var steps := 24
	for i in steps:
		var f0 := float(i) / steps
		var f1 := float(i + 1) / steps
		var c0 := top.lerp(mid, minf(f0 * 1.6, 1.0)) if f0 < 0.62 else mid.lerp(low, (f0 - 0.62) / 0.38)
		var c1 := top.lerp(mid, minf(f1 * 1.6, 1.0)) if f1 < 0.62 else mid.lerp(low, (f1 - 0.62) / 0.38)
		draw_polygon(PackedVector2Array([Vector2(0, f0 * sz.y), Vector2(sz.x, f0 * sz.y), Vector2(sz.x, f1 * sz.y), Vector2(0, f1 * sz.y)]),
			PackedColorArray([c0, c0, c1, c1]))
	# raios de sol girando atrás do personagem
	var c := Vector2(sz.x * rays_center.x, sz.y * rays_center.y)
	var rr := sz.length()
	var n := 14
	for k in n:
		var a0 := _t * 0.12 + k * TAU / n
		var a1 := a0 + TAU / n * 0.5
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * rr, c + Vector2.from_angle(a1) * rr]), Color(1, 1, 1, 0.09))
	# brilho do sol
	for k in 6:
		draw_circle(c, sz.y * (0.34 - k * 0.045), Color(1, 0.98, 0.85, 0.05 + k * 0.012))
	# nuvens
	for cl in _clouds:
		var p := Vector2(cl.x * sz.x, cl.y * sz.y)
		var s: float = cl.s * sz.y * 0.07
		var col := Color(1, 1, 1, 0.92)
		# nuvem fofinha: só círculos (sem cantos)
		draw_circle(p + Vector2(0, s * 0.25), s * 1.05, col)
		draw_circle(p + Vector2(s * 1.1, s * 0.55), s * 0.8, col)
		draw_circle(p + Vector2(-s * 1.1, s * 0.6), s * 0.7, col)
		draw_circle(p + Vector2(s * 0.45, -s * 0.35), s * 0.9, col)
		draw_circle(p + Vector2(-s * 0.5, s * 0.75), s * 0.7, col)
		draw_circle(p + Vector2(s * 0.5, s * 0.8), s * 0.7, col)
	# morrinhos
	_hill(sz, 0.80, 0.16, Color("7bd96a"), 0.0)
	_hill(sz, 0.87, 0.12, Color("4fbf5a"), 1.7)
	# flores nos morros
	for k in 18:
		var fx := fposmod(k * 0.113 + 0.05, 1.0)
		var fy := 0.9 + 0.05 * sin(k * 2.3)
		var fp := Vector2(fx * sz.x, fy * sz.y)
		var bob := sin(_t * 2.0 + k) * 2.0
		draw_circle(fp + Vector2(0, bob), sz.y * 0.009, COLORS[k % COLORS.size()])
		draw_circle(fp + Vector2(0, bob), sz.y * 0.004, Color("fff7c2"))
	# confete
	for cf in _conf:
		var cp := Vector2((cf.x + sin(_t * 1.3 + cf.z) * 0.01) * sz.x, cf.y * sz.y)
		var w: float = sz.y * 0.011
		var h: float = w * 0.55 * absf(cos(cf.r))
		draw_set_transform(cp, cf.r, Vector2.ONE)
		draw_rect(Rect2(-w * 0.5, -h * 0.5 - 0.5, w, h + 1.0), cf.c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hill(sz: Vector2, base: float, amp: float, col: Color, ph: float) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var x := float(i) / n
		var y := base - amp * (0.5 + 0.5 * sin(x * 5.0 + ph)) * 0.6 - amp * 0.2
		pts.append(Vector2(x * sz.x, y * sz.y))
	pts.append(Vector2(sz.x, sz.y))
	pts.append(Vector2(0, sz.y))
	draw_colored_polygon(pts, col)
