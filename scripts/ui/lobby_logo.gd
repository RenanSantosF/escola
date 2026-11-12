class_name LobbyLogo
extends Control
## Logo do menu: "RECESS" com cada letra de uma cor, pulando em onda,
## e a fita "CLUB" balançando embaixo.

const COLORS := [Color("ff4d6d"), Color("ffd23f"), Color("3ec1ff"), Color("6be36b"), Color("b46bff"), Color("ff9f43")]

var title := "RECESS"
var ribbon := "CLUB"
var font_size := 92
var _font: Font
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.bold_font()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var fs := font_size
	var total := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (title.length() - 1) * 4.0
	var x := (size.x - total) * 0.5
	var base := fs * 0.95
	for i in title.length():
		var ch := title[i]
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if ch == " ":
			x += w + 4.0
			continue
		var y := base + sin(_t * 3.2 - i * 0.55) * 7.0
		var rot := sin(_t * 2.4 - i * 0.7) * 0.06
		var col: Color = COLORS[i % COLORS.size()]
		draw_set_transform(Vector2(x + w * 0.5, y), rot, Vector2.ONE)
		# sombra "3D", contorno grosso e a letra
		draw_string_outline(_font, Vector2(-w * 0.5, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 22, Color(0.06, 0.1, 0.3, 0.55))
		draw_string_outline(_font, Vector2(-w * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18, Color.WHITE)
		draw_string(_font, Vector2(-w * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += w + 4.0
	# fita
	var rfs := int(fs * 0.36)
	var spaced := "  ".join(ribbon.split(""))
	var rw := _font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x + 70.0
	var rh := rfs * 1.7
	var rc := Vector2(size.x * 0.5, base + fs * 0.42 + rh * 0.5)
	draw_set_transform(rc, sin(_t * 1.6) * 0.04 - 0.03, Vector2.ONE)
	var tail := PackedVector2Array([Vector2(-rw * 0.5 - 26, -rh * 0.3), Vector2(-rw * 0.5 + 6, -rh * 0.3), Vector2(-rw * 0.5 + 6, rh * 0.62), Vector2(-rw * 0.5 - 26, rh * 0.62), Vector2(-rw * 0.5 - 14, rh * 0.16)])
	draw_colored_polygon(tail, Color("c2410c"))
	var tail2 := PackedVector2Array()
	for p in tail:
		tail2.append(Vector2(-p.x, p.y))
	draw_colored_polygon(tail2, Color("c2410c"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ff7a1a")
	sb.set_corner_radius_all(int(rh * 0.3))
	sb.border_color = Color.WHITE
	sb.set_border_width_all(4)
	draw_style_box(sb, Rect2(Vector2(-rw * 0.5, -rh * 0.5), Vector2(rw, rh)))
	var tw2 := _font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
	draw_string_outline(_font, Vector2(-tw2 * 0.5, rfs * 0.36), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, 6, Color("9a3412"))
	draw_string(_font, Vector2(-tw2 * 0.5, rfs * 0.36), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
