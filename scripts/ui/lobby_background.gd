class_name LobbyBackground
extends Control
## Fundo do menu (visual novo): degradê claro, manchas de cor bem suaves
## flutuando devagar, pontinhos discretos e um "palco" de luz embaixo do
## personagem. Tudo desenhado em 2D (leve, sem texturas).

const BLOBS := [
	{"x": 0.18, "y": 0.30, "r": 0.34, "c": Color("a5b4fc"), "v": 0.35},
	{"x": 0.86, "y": 0.22, "r": 0.30, "c": Color("f9a8d4"), "v": 0.27},
	{"x": 0.62, "y": 0.92, "r": 0.36, "c": Color("99f6e4"), "v": 0.22},
	{"x": 0.05, "y": 0.95, "r": 0.24, "c": Color("fde68a"), "v": 0.3},
]

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 4.0 or sz.y < 4.0:
		return
	# degradê claro de cima para baixo
	var top := Color("f5f7ff")
	var bottom := Color("e3e8f8")
	var bands := 24
	for i in bands:
		var f0 := float(i) / bands
		var f1 := float(i + 1) / bands
		draw_polygon(PackedVector2Array([Vector2(0, f0 * sz.y), Vector2(sz.x, f0 * sz.y), Vector2(sz.x, f1 * sz.y), Vector2(0, f1 * sz.y)]),
			PackedColorArray([top.lerp(bottom, f0), top.lerp(bottom, f0), top.lerp(bottom, f1), top.lerp(bottom, f1)]))
	# manchas de cor (círculos com bordas que somem)
	var m := minf(sz.x, sz.y)
	for b in BLOBS:
		var c := Vector2(b.x * sz.x + sin(_t * float(b.v)) * m * 0.04, b.y * sz.y + cos(_t * float(b.v) * 0.8) * m * 0.03)
		var r: float = float(b.r) * m
		var col: Color = b.c
		for k in 10:
			var f := 1.0 - k / 10.0
			draw_circle(c, r * f, Color(col, 0.035))
	# pontinhos discretos
	var step := 34.0
	var dot := Color(0.31, 0.27, 0.9, 0.07)
	var y := step * 0.5
	while y < sz.y:
		var x := step * 0.5
		while x < sz.x:
			draw_circle(Vector2(x, y), 1.4, dot)
			x += step
		y += step
