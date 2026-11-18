class_name LobbyButton
extends BaseButton
## Botão do menu (visual novo): liso, cantos de 12 px, sombra suave, ícone
## desenhado em vetor e texto. "round_icon" vira um ladrilho branco com o
## ícone colorido e o nome embaixo. O principal (JOGAR) tem um reflexo passando.
## Ícones: play, shirt, friends, gear, star, bag, back.

var text := ""
var sub := ""
var icon_name := ""
var color := Color("1fb5a3")
var primary := false
var font_size := 28
var round_icon := false  ## botão redondo só com ícone (rótulo embaixo)

var _font: Font
var _hole := Color.WHITE  ## cor do "furo" dos ícones (fundo atrás do ícone)
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
	var pulse := (1.0 + 0.012 * sin(_t * 2.6)) if primary else 1.0
	var s := pulse * (1.0 - 0.04 * _press)
	scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var down := 2.0 * _press
	if round_icon:
		# "ladrilho" quadrado branco, ícone colorido e nome embaixo
		var tile := Rect2(Vector2(0, down), Vector2(size.x, size.x))
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0.08, 0.1, 0.25, 0.10)
		sh.set_corner_radius_all(16)
		draw_style_box(sh, Rect2(tile.position + Vector2(0, 4), tile.size))
		var fc := StyleBoxFlat.new()
		fc.bg_color = Color.WHITE if not is_hovered() else Color("f7f8ff")
		fc.set_corner_radius_all(16)
		fc.border_color = UITheme.STROKE
		fc.set_border_width_all(1)
		draw_style_box(fc, tile)
		var ic := StyleBoxFlat.new()
		ic.bg_color = Color(color, 0.12)
		ic.set_corner_radius_all(12)
		var inner := tile.grow(-size.x * 0.2)
		draw_style_box(ic, inner)
		_hole = Color.WHITE.lerp(color, 0.12)
		_icon(inner.get_center(), size.x * 0.2, color)
		if text != "":
			var fs := font_size
			var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(_font, Vector2((size.x - tw) * 0.5, size.x + 10 + fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		return
	# botão liso: sombra suave, cantos de 12 px, um brilho discreto em cima
	var face := Rect2(r.position + Vector2(0, down), r.size - Vector2(0, 4))
	var sh2 := StyleBoxFlat.new()
	sh2.bg_color = Color(color.darkened(0.5), 0.25)
	sh2.set_corner_radius_all(12)
	draw_style_box(sh2, Rect2(face.position + Vector2(0, 4), face.size))
	var fc2 := StyleBoxFlat.new()
	fc2.bg_color = color.lightened(0.05) if is_hovered() else color
	fc2.set_corner_radius_all(12)
	draw_style_box(fc2, face)
	var gl := StyleBoxFlat.new()
	gl.bg_color = Color(1, 1, 1, 0.12)
	gl.corner_radius_top_left = 12
	gl.corner_radius_top_right = 12
	draw_style_box(gl, Rect2(face.position, Vector2(face.size.x, face.size.y * 0.45)))
	# reflexo passando devagar no principal
	if primary:
		var k := fposmod(_t * 0.35, 2.2) - 0.4
		var x := face.position.x + k * face.size.x
		var poly := PackedVector2Array([Vector2(x, face.position.y + 2), Vector2(x + 34, face.position.y + 2), Vector2(x + 4, face.end.y - 2), Vector2(x - 30, face.end.y - 2)])
		var clipped := Geometry2D.intersect_polygons(poly, _rect_poly(face.grow(-2)))
		for cp in clipped:
			draw_colored_polygon(cp, Color(1, 1, 1, 0.14))
	# ícone + textos
	var has_icon := icon_name != ""
	var icon_r := face.size.y * 0.22
	var tw2 := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var sub_fs := int(font_size * 0.5)
	var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs).x if sub != "" else 0.0
	var block := maxf(tw2, sw) + (icon_r * 2.0 + 16.0 if has_icon else 0.0)
	var x0 := face.position.x + (face.size.x - block) * 0.5
	var cy := face.position.y + face.size.y * 0.5
	if has_icon:
		_hole = color
		_icon(Vector2(x0 + icon_r, cy), icon_r, Color.WHITE)
		x0 += icon_r * 2.0 + 16.0
	var ty := cy + font_size * 0.36 - (sub_fs * 0.6 if sub != "" else 0.0)
	draw_string(_font, Vector2(x0, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if sub != "":
		draw_string(_font, Vector2(x0, ty + sub_fs + 8), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs, Color(1, 1, 1, 0.85))


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
			draw_rect(Rect2(c + Vector2(-r * 1.05, r * 0.55), Vector2(r * 2.1, r * 0.55)), _hole)
		"gear":
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c, c + Vector2.from_angle(a) * r, col, r * 0.42)
			draw_circle(c, r * 0.68, col)
			draw_circle(c, r * 0.3, _hole)
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
