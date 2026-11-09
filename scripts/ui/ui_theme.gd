class_name UITheme
extends RefCounted
## Tema visual da interface (gerado em código para ficar consistente
## e leve). Cores alegres, cantos arredondados e fontes grandes para toque.

const YELLOW := Color("ffcf3f")
const ORANGE := Color("ff8a3d")
const BLUE := Color("2f6fd0")
const DARK := Color("1f2a44")
const CREAM := Color("fff8e7")
const GREEN := Color("3aa45b")
const RED := Color("e04a3a")

static var _theme: Theme
static var _bold: FontVariation


static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
	return _bold


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 26
	t.set_font("font", "Button", bold_font())
	t.set_font("font", "Label", ThemeDB.fallback_font)
	t.set_color("font_color", "Label", DARK)
	t.set_font_size("font_size", "Button", 28)
	t.set_color("font_color", "Button", DARK)
	t.set_color("font_hover_color", "Button", DARK)
	t.set_color("font_pressed_color", "Button", DARK)
	t.set_color("font_focus_color", "Button", DARK)
	t.set_stylebox("normal", "Button", box(YELLOW, 18, DARK.lerp(YELLOW, 0.5), 0, 6))
	t.set_stylebox("hover", "Button", box(YELLOW.lightened(0.15), 18, DARK.lerp(YELLOW, 0.5), 0, 6))
	t.set_stylebox("pressed", "Button", box(ORANGE, 18, DARK.lerp(ORANGE, 0.5), 0, 2))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 18, Color.WHITE, 3, 0))
	t.set_stylebox("disabled", "Button", box(Color("cfcfcf"), 18, Color("9a9a9a"), 0, 4))
	t.set_stylebox("panel", "PanelContainer", box(CREAM, 26, Color("e2c98a"), 4, 0))
	t.set_stylebox("panel", "Panel", box(CREAM, 26, Color("e2c98a"), 4, 0))
	# Sliders grandes para o dedo
	var track := StyleBoxFlat.new()
	track.bg_color = Color("e5d7b5")
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ORANGE
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_tex(34, BLUE))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(38, BLUE.lightened(0.2)))
	t.set_font_size("font_size", "CheckButton", 26)
	var flat := box(Color(1, 1, 1, 0.0), 14)
	var flat_h := box(Color(0, 0, 0, 0.05), 14)
	for st in ["normal", "pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", flat)
	t.set_stylebox("hover", "CheckButton", flat_h)
	t.set_stylebox("hover_pressed", "CheckButton", flat_h)
	t.set_color("font_color", "CheckButton", DARK)
	t.set_color("font_hover_color", "CheckButton", DARK)
	t.set_color("font_pressed_color", "CheckButton", DARK)
	t.set_color("font_hover_pressed_color", "CheckButton", DARK)
	t.set_font_size("font_size", "OptionButton", 26)
	_theme = t
	return t


static func box(bg: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0, shadow_bottom := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	if shadow_bottom > 0:
		s.border_width_bottom = shadow_bottom
		s.border_color = border
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func _circle_tex(size: int, col: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d, 0.0, 1.0)
			var px := col if d < c - 3 else Color.WHITE
			px.a = a
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)


static func title_label(text: String, size := 40, col := DARK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func make_button(text: String, cb: Callable, min_w := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	return b
