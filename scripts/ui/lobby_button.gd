class_name LobbyButton
extends BaseButton
## Botão "bala" do menu: arredondado, com borda de baixo mais escura (parece
## 3D), brilho em cima, ícone desenhado em vetor e texto. Afunda ao tocar e
## volta com mola. O principal (JOGAR) pulsa e tem um reflexo passando.
## Ícones: play, shirt, friends, gear, star, bag, back.

var text := ""
var sub := ""
var icon_name := ""
var color := Color("1fb5a3")
var primary := false
var font_size := 28
var round_icon := false  ## botão redondo só com ícone (rótulo embaixo)

var _font: Font
var _press := 0.0
var _t := 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


func _ready() -> void:
	_font = UITheme.bold_font()
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	button_down.connect(func(): AudioManager.play_ui("ui_click", -2.0))
	_t = randf() * 3.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var target := 1.0 if button_pressed or is_pressed() else 0.0
	_press = lerpf(_press, target, 1.0 - exp(-25.0 * delta))
	var pulse := (1.0 + 0.035 * sin(_t * 3.2)) if primary else 1.0
	var s := pulse * (1.0 - 0.06 * _press)
	scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var lip := 7.0 if not round_icon else 6.0
	var down := lip * _press * 0.8
	var rad := minf(size.y * 0.5, 30.0) if not round_icon else size.x * 0.5
	var face := Rect2(r.position + Vector2(0, down), Vector2(r.size.x, r.size.y - lip))
	if round_icon:
		var ctr := Vector2(size.x * 0.5, size.x * 0.5)
		draw_circle(ctr + Vector2(0, 6), size.x * 0.5, Color(0, 0, 0, 0.18))
		draw_circle(ctr + Vector2(0, lip), size.x * 0.5, color.darkened(0.3))
		draw_circle(ctr + Vector2(0, down), size.x * 0.5, color)
		draw_circle(ctr + Vector2(0, down - size.x * 0.12), size.x * 0.36, Color(1, 1, 1, 0.13))
		draw_arc(ctr + Vector2(0, down), size.x * 0.5 - 2, 0, TAU, 40, Color(1, 1, 1, 0.65), 3.0, true)
		_icon(ctr + Vector2(0, down), size.x * 0.27, Color.WHITE)
		if text != "":
			var fs := font_size
			var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var ty := size.x + 8 + fs
			draw_string_outline(_font, Vector2((size.x - tw) * 0.5, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.06, 0.1, 0.24, 0.85))
			draw_string(_font, Vector2((size.x - tw) * 0.5, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		return
	# sombra, "lábio" de baixo e face
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0.2)
	sh.set_corner_radius_all(int(rad))
	draw_style_box(sh, Rect2(r.position + Vector2(0, 8), r.size - Vector2(0, 4)))
	var lp := StyleBoxFlat.new()
	lp.bg_color = color.darkened(0.3)
	lp.set_corner_radius_all(int(rad))
	draw_style_box(lp, Rect2(r.position + Vector2(0, lip), r.size - Vector2(0, lip)))
	var fc := StyleBoxFlat.new()
	fc.bg_color = color.lightened(0.06) if is_hovered() else color
	fc.set_corner_radius_all(int(rad))
	fc.border_color = Color(1, 1, 1, 0.55)
	fc.set_border_width_all(3)
	draw_style_box(fc, face)
	# brilho em cima
	var gl := StyleBoxFlat.new()
	gl.bg_color = Color(1, 1, 1, 0.16)
	gl.set_corner_radius_all(int(rad * 0.8))
	draw_style_box(gl, Rect2(face.position + Vector2(10, 6), Vector2(face.size.x - 20, face.size.y * 0.38)))
	# reflexo passando no principal
	if primary:
		var k := fposmod(_t * 0.45, 1.6) - 0.3
		var x := face.position.x + k * face.size.x
		var poly := PackedVector2Array([Vector2(x, face.position.y + 4), Vector2(x + 26, face.position.y + 4), Vector2(x - 4, face.end.y - 4), Vector2(x - 30, face.end.y - 4)])
		var clipped := Geometry2D.intersect_polygons(poly, _rect_poly(face.grow(-4)))
		for cp in clipped:
			draw_colored_polygon(cp, Color(1, 1, 1, 0.22))
	# ícone + textos
	var has_icon := icon_name != ""
	var icon_r := face.size.y * 0.26
	var tw2 := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var sub_fs := int(font_size * 0.55)
	var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs).x if sub != "" else 0.0
	var block := maxf(tw2, sw) + (icon_r * 2.0 + 14.0 if has_icon else 0.0)
	var x0 := face.position.x + (face.size.x - block) * 0.5
	var cy := face.position.y + face.size.y * 0.5
	if has_icon:
		_icon(Vector2(x0 + icon_r, cy), icon_r, Color.WHITE)
		x0 += icon_r * 2.0 + 14.0
	var ty := cy + font_size * 0.36 - (sub_fs * 0.55 if sub != "" else 0.0)
	draw_string_outline(_font, Vector2(x0, ty + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, color.darkened(0.45))
	draw_string(_font, Vector2(x0, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if sub != "":
		draw_string(_font, Vector2(x0, ty + sub_fs + 6), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs, Color(1, 1, 1, 0.88))


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _icon(c: Vector2, r: float, col: Color) -> void:
	match icon_name:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.8), c + Vector2(r * 0.85, 0), c + Vector2(-r * 0.55, r * 0.8)]), col)
		"shirt":
			var p := PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.8), c + Vector2(-r, -r * 0.45), c + Vector2(-r * 0.75, -r * 0.05),
				c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(-r * 0.5, r * 0.85), c + Vector2(r * 0.5, r * 0.85), c + Vector2(r * 0.5, -r * 0.2),
				c + Vector2(r * 0.75, -r * 0.05), c + Vector2(r, -r * 0.45), c + Vector2(r * 0.35, -r * 0.8), c + Vector2(0, -r * 0.5)])
			draw_colored_polygon(p, col)
		"friends":
			draw_circle(c + Vector2(-r * 0.4, -r * 0.35), r * 0.32, col)
			draw_circle(c + Vector2(r * 0.42, -r * 0.42), r * 0.28, Color(col, 0.85))
			draw_circle(c + Vector2(-r * 0.4, r * 0.55), r * 0.55, col)
			draw_circle(c + Vector2(r * 0.42, r * 0.45), r * 0.45, Color(col, 0.85))
			draw_rect(Rect2(c + Vector2(-r, r * 0.55), Vector2(r * 2.0, r * 0.5)), color)
		"gear":
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c, c + Vector2.from_angle(a) * r, col, r * 0.42)
			draw_circle(c, r * 0.68, col)
			draw_circle(c, r * 0.3, color)
		"star":
			var pts := PackedVector2Array()
			for k in 10:
				var rad := r if k % 2 == 0 else r * 0.45
				pts.append(c + Vector2.from_angle(-PI * 0.5 + k * TAU / 10.0) * rad)
			draw_colored_polygon(pts, col)
		"bag":
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.35), Vector2(r * 1.5, r * 1.2)), col)
			draw_arc(c + Vector2(0, -r * 0.35), r * 0.4, PI, TAU, 12, col, r * 0.18)
		"back":
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 0.8), c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.6, r * 0.8)]), col)
