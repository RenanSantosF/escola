class_name PictureCard
extends Control
## Figura desenhada em vetor para as atividades da Educação Infantil (3–4 anos):
## formas, cores, frutas para contar, bichinhos, sol/lua, tamanhos.
## Nada depende de fonte de emoji.
## spec: {"kind": "shape"|"count"|"animal"|"thing"|"color", ...}

var spec: Dictionary = {}
var _t := 0.0
var bounce := true

const COLORS := {
	"vermelho": Color("e74c3c"), "azul": Color("2f80ed"), "amarelo": Color("f7c600"),
	"verde": Color("27ae60"), "rosa": Color("ff6fae"), "laranja": Color("ff8a1f"), "roxo": Color("8e44ad"),
}


func _init(s: Dictionary = {}) -> void:
	spec = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 120)


func _process(delta: float) -> void:
	if bounce and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	var wob := sin(_t * 3.0) * 0.04 if bounce else 0.0
	draw_set_transform(c, wob, Vector2.ONE)
	match str(spec.get("kind", "")):
		"shape":
			_shape(str(spec.get("shape", "circle")), Vector2.ZERO, r * float(spec.get("scale", 1.0)), _col(spec.get("color", "azul")))
		"color":
			_shape("circle", Vector2.ZERO, r, _col(spec.get("color", "azul")))
		"count":
			draw_set_transform(c, 0.0, Vector2.ONE)
			var n := int(spec.get("n", 1))
			var thing := str(spec.get("thing", "apple"))
			var cols := 3 if n > 4 else (2 if n > 1 else 1)
			var rows := int(ceil(float(n) / cols))
			var cell := minf(size.x / (cols + 0.4), size.y / (rows + 0.3))
			for i in n:
				var row := i / cols
				var col := i % cols
				var in_row := mini(cols, n - row * cols)
				var px := (col - (in_row - 1) * 0.5) * cell
				var py := (row - (rows - 1) * 0.5) * cell
				_thing(thing, Vector2(px, py + sin(_t * 4.0 + i) * 2.0), cell * 0.36)
		"animal":
			_animal(str(spec.get("animal", "cat")), Vector2.ZERO, r * float(spec.get("scale", 1.0)))
		"thing":
			_thing(str(spec.get("thing", "sun")), Vector2.ZERO, r * float(spec.get("scale", 1.0)))
		"number":
			draw_set_transform(c, 0.0, Vector2.ONE)
			var n2 := int(spec.get("n", 1))
			var f := UITheme.bold_font()
			var fs := int(size.y * 0.55)
			var txt := str(n2)
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(-w * 0.5, fs * 0.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("2c3e50"))
			# bolinhas embaixo ajudam quem ainda não conhece o número
			for i in n2:
				draw_circle(Vector2((i - (n2 - 1) * 0.5) * 14.0, size.y * 0.36), 5.0, Color("ff8a1f"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _col(v: Variant) -> Color:
	if v is Color:
		return v
	return COLORS.get(str(v), Color("2f80ed"))


func _outline(pts: PackedVector2Array, col: Color, w := 3.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, w, true)


func _shape(kind: String, p: Vector2, r: float, col: Color) -> void:
	var dark := col.darkened(0.35)
	match kind:
		"circle":
			draw_circle(p, r, col)
			draw_arc(p, r, 0, TAU, 40, dark, 3.0, true)
			draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.18, Color(1, 1, 1, 0.45))
		"square":
			var pts := PackedVector2Array([p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(r, r), p + Vector2(-r, r)])
			draw_colored_polygon(pts, col)
			_outline(pts, dark)
		"triangle":
			var pts2 := PackedVector2Array([p + Vector2(0, -r * 1.1), p + Vector2(r * 1.05, r * 0.8), p + Vector2(-r * 1.05, r * 0.8)])
			draw_colored_polygon(pts2, col)
			_outline(pts2, dark)
		"star":
			var pts3 := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				var rr := r * (1.1 if i % 2 == 0 else 0.48)
				pts3.append(p + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts3, col)
			_outline(pts3, dark)
		"heart":
			var pts4 := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts4.append(p + Vector2(x, y) * r / 16.0)
			draw_colored_polygon(pts4, col)
			_outline(pts4, dark)


func _eye(p: Vector2, r: float) -> void:
	draw_circle(p, r, Color.WHITE)
	draw_circle(p + Vector2(0, r * 0.15), r * 0.6, Color("1d1d1d"))
	draw_circle(p + Vector2(-r * 0.2, -r * 0.1), r * 0.22, Color.WHITE)


func _smile(p: Vector2, r: float) -> void:
	draw_arc(p, r, 0.2, PI - 0.2, 12, Color("3a2a20"), maxf(2.0, r * 0.25), true)


func _animal(kind: String, p: Vector2, r: float) -> void:
	match kind:
		"cat":
			var col := Color("f5a142")
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.9, -r * 0.3), p + Vector2(-r * 0.75, -r * 1.15), p + Vector2(-r * 0.2, -r * 0.75)]), col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.9, -r * 0.3), p + Vector2(r * 0.75, -r * 1.15), p + Vector2(r * 0.2, -r * 0.75)]), col)
			draw_circle(p, r * 0.85, col)
			_eye(p + Vector2(-r * 0.32, -r * 0.15), r * 0.17)
			_eye(p + Vector2(r * 0.32, -r * 0.15), r * 0.17)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.1, r * 0.12), p + Vector2(r * 0.1, r * 0.12), p + Vector2(0, r * 0.24)]), Color("ff6f91"))
			for s in [-1, 1]:
				for k in 2:
					draw_line(p + Vector2(s * r * 0.25, r * (0.25 + k * 0.1)), p + Vector2(s * r * 0.95, r * (0.15 + k * 0.2)), Color("5a3a20"), 2.0, true)
			_smile(p + Vector2(0, r * 0.2), r * 0.15)
		"dog":
			var col2 := Color("c08a55")
			draw_circle(p, r * 0.82, col2)
			draw_set_transform(size * 0.5 + p + Vector2(-r * 0.8, 0), 0.3, Vector2(0.45, 1.0))
			draw_circle(Vector2.ZERO, r * 0.55, Color("7a4f2a"))
			draw_set_transform(size * 0.5 + p + Vector2(r * 0.8, 0), -0.3, Vector2(0.45, 1.0))
			draw_circle(Vector2.ZERO, r * 0.55, Color("7a4f2a"))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
			draw_circle(p + Vector2(0, r * 0.3), r * 0.38, Color("f1d3a8"))
			draw_circle(p + Vector2(0, r * 0.18), r * 0.13, Color("2a1a10"))
			_eye(p + Vector2(-r * 0.3, -r * 0.2), r * 0.16)
			_eye(p + Vector2(r * 0.3, -r * 0.2), r * 0.16)
			draw_circle(p + Vector2(0, r * 0.55), r * 0.12, Color("ff6f91"))
		"pig":
			var col3 := Color("ffa8c5")
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.8, -r * 0.4), p + Vector2(-r * 0.7, -r * 1.0), p + Vector2(-r * 0.25, -r * 0.7)]), col3.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.8, -r * 0.4), p + Vector2(r * 0.7, -r * 1.0), p + Vector2(r * 0.25, -r * 0.7)]), col3.darkened(0.1))
			draw_circle(p, r * 0.85, col3)
			draw_set_transform(size * 0.5 + p + Vector2(0, r * 0.25), 0.0, Vector2(1.3, 0.85))
			draw_circle(Vector2.ZERO, r * 0.3, Color("ff7fa8"))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
			draw_circle(p + Vector2(-r * 0.12, r * 0.25), r * 0.07, Color("a3335a"))
			draw_circle(p + Vector2(r * 0.12, r * 0.25), r * 0.07, Color("a3335a"))
			_eye(p + Vector2(-r * 0.32, -r * 0.2), r * 0.14)
			_eye(p + Vector2(r * 0.32, -r * 0.2), r * 0.14)
		"bird":
			var col4 := Color("ffd23f")
			draw_circle(p, r * 0.8, col4)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.2, -r * 0.75), p + Vector2(0, -r * 1.15), p + Vector2(r * 0.2, -r * 0.75)]), Color("ff8a1f"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.2, r * 0.1), p + Vector2(r * 0.2, r * 0.1), p + Vector2(0, r * 0.4)]), Color("ff8a1f"))
			_eye(p + Vector2(-r * 0.3, -r * 0.2), r * 0.15)
			_eye(p + Vector2(r * 0.3, -r * 0.2), r * 0.15)
			draw_set_transform(size * 0.5 + p + Vector2(-r * 0.85, r * 0.2), -0.6, Vector2(0.5, 1.0))
			draw_circle(Vector2.ZERO, r * 0.35, col4.darkened(0.15))
			draw_set_transform(size * 0.5 + p + Vector2(r * 0.85, r * 0.2), 0.6, Vector2(0.5, 1.0))
			draw_circle(Vector2.ZERO, r * 0.35, col4.darkened(0.15))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
		"fish":
			var col5 := Color("3ec1d3")
			draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.55, 0), p + Vector2(r * 1.1, -r * 0.5), p + Vector2(r * 1.1, r * 0.5)]), col5.darkened(0.2))
			draw_set_transform(size * 0.5 + p + Vector2(-r * 0.1, 0), 0.0, Vector2(1.0, 0.65))
			draw_circle(Vector2.ZERO, r * 0.75, col5)
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
			_eye(p + Vector2(-r * 0.45, -r * 0.1), r * 0.14)
			_smile(p + Vector2(-r * 0.6, r * 0.1), r * 0.1)
		"cow":
			var col6 := Color("f4f4f4")
			draw_circle(p + Vector2(-r * 0.85, -r * 0.55), r * 0.22, Color("dddddd"))
			draw_circle(p + Vector2(r * 0.85, -r * 0.55), r * 0.22, Color("dddddd"))
			draw_circle(p, r * 0.82, col6)
			draw_circle(p + Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color("2a2a2a"))
			draw_circle(p + Vector2(r * 0.45, r * 0.0), r * 0.18, Color("2a2a2a"))
			draw_set_transform(size * 0.5 + p + Vector2(0, r * 0.45), 0.0, Vector2(1.3, 0.8))
			draw_circle(Vector2.ZERO, r * 0.35, Color("ffb6c8"))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
			_eye(p + Vector2(-r * 0.3, -r * 0.1), r * 0.14)
			_eye(p + Vector2(r * 0.3, -r * 0.1), r * 0.14)
		"duck":
			_animal("bird", p, r)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.35, r * 0.1), p + Vector2(r * 0.35, r * 0.1), p + Vector2(0, r * 0.38)]), Color("ff8a1f"))


func _thing(kind: String, p: Vector2, r: float) -> void:
	match kind:
		"apple":
			draw_circle(p + Vector2(-r * 0.3, 0), r * 0.7, Color("e74c3c"))
			draw_circle(p + Vector2(r * 0.3, 0), r * 0.7, Color("e74c3c"))
			draw_circle(p + Vector2(-r * 0.35, -r * 0.25), r * 0.2, Color(1, 1, 1, 0.4))
			draw_line(p + Vector2(0, -r * 0.6), p + Vector2(r * 0.1, -r * 1.0), Color("6b3e1e"), maxf(2.0, r * 0.12))
			draw_set_transform(size * 0.5 + p + Vector2(r * 0.35, -r * 0.85), 0.5, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, r * 0.3, Color("2ecc71"))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
		"ball":
			draw_circle(p, r, Color("ff8a1f"))
			draw_arc(p, r, 0, TAU, 24, Color("b35400"), 2.0)
			draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), Color("b35400"), 2.0)
			draw_arc(p + Vector2(0, 0), r * 0.5, -PI * 0.5, PI * 0.5, 12, Color("b35400"), 2.0)
		"star":
			_shape("star", p, r, Color("f7c600"))
		"balloon":
			draw_line(p + Vector2(0, r * 0.9), p + Vector2(0, r * 1.5), Color("555555"), 2.0)
			draw_set_transform(size * 0.5 + p, 0.0, Vector2(0.85, 1.0))
			draw_circle(Vector2.ZERO, r, Color("ff6fae"))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
		"sun":
			for i in 10:
				var a := TAU * i / 10.0 + _t
				draw_line(p + Vector2(cos(a), sin(a)) * r * 0.85, p + Vector2(cos(a), sin(a)) * r * 1.25, Color("ffb300"), maxf(3.0, r * 0.12), true)
			draw_circle(p, r * 0.75, Color("ffd23f"))
			_eye(p + Vector2(-r * 0.25, -r * 0.1), r * 0.1)
			_eye(p + Vector2(r * 0.25, -r * 0.1), r * 0.1)
			_smile(p + Vector2(0, r * 0.1), r * 0.25)
		"moon":
			draw_circle(p, r * 0.85, Color("f3e9a6"))
			draw_circle(p + Vector2(r * 0.4, -r * 0.2), r * 0.7, Color("2c3e66"))
		"cloud":
			for o in [Vector2(-0.5, 0.1), Vector2(0, -0.2), Vector2(0.5, 0.1), Vector2(0.0, 0.2)]:
				draw_circle(p + o * r, r * 0.5, Color("eef4fb"))
		"flower":
			for i in 6:
				var a2 := TAU * i / 6.0
				draw_circle(p + Vector2(cos(a2), sin(a2)) * r * 0.5, r * 0.35, Color("ff6fae"))
			draw_circle(p, r * 0.3, Color("ffd23f"))
		"house":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.1), p + Vector2(0, -r), p + Vector2(r, -r * 0.1)]), Color("e74c3c"))
			draw_rect(Rect2(p + Vector2(-r * 0.8, -r * 0.1), Vector2(r * 1.6, r * 1.0)), Color("f5d48a"))
			draw_rect(Rect2(p + Vector2(-r * 0.2, r * 0.35), Vector2(r * 0.4, r * 0.55)), Color("8a5a32"))
		"car":
			draw_rect(Rect2(p + Vector2(-r, -r * 0.1), Vector2(r * 2.0, r * 0.6)), Color("2f80ed"))
			draw_rect(Rect2(p + Vector2(-r * 0.5, -r * 0.55), Vector2(r * 1.0, r * 0.5)), Color("2f80ed"))
			draw_rect(Rect2(p + Vector2(-r * 0.4, -r * 0.48), Vector2(r * 0.8, r * 0.35)), Color("cde8ff"))
			draw_circle(p + Vector2(-r * 0.55, r * 0.5), r * 0.25, Color("222222"))
			draw_circle(p + Vector2(r * 0.55, r * 0.5), r * 0.25, Color("222222"))
		"tree":
			draw_rect(Rect2(p + Vector2(-r * 0.15, r * 0.2), Vector2(r * 0.3, r * 0.8)), Color("8a5a32"))
			draw_circle(p + Vector2(0, -r * 0.2), r * 0.7, Color("27ae60"))
		"banana":
			draw_arc(p + Vector2(0, -r * 0.6), r * 1.0, 0.5, PI - 0.5, 16, Color("f7d02c"), r * 0.45, true)
		"carrot":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.3, -r * 0.6), p + Vector2(r * 0.3, -r * 0.6), p + Vector2(0, r * 1.0)]), Color("ff8a1f"))
			draw_line(p + Vector2(0, -r * 0.6), p + Vector2(-r * 0.2, -r * 1.0), Color("27ae60"), 3.0)
			draw_line(p + Vector2(0, -r * 0.6), p + Vector2(r * 0.2, -r * 1.0), Color("27ae60"), 3.0)
