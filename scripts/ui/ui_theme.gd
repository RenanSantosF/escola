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
## Paleta nova (lobby e telas): marinho + verde-água, sem laranja.
const NAVY := Color("0f1a3d")
const NAVY_2 := Color("1a2a5c")
const TEAL := Color("1fb5a3")
const SKY := Color("4cc9f0")
const MIST := Color("eef3fa")
const LINE := Color("c9d4e8")

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
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("6b7690"))
	# botões com cantos discretos (nada de "pílula" exagerada)
	t.set_stylebox("normal", "Button", box(TEAL, 10, TEAL.darkened(0.35), 0, 4))
	t.set_stylebox("hover", "Button", box(TEAL.lightened(0.1), 10, TEAL.darkened(0.35), 0, 4))
	t.set_stylebox("pressed", "Button", box(TEAL.darkened(0.15), 10, TEAL.darkened(0.35), 0, 1))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 10, Color.WHITE, 2, 0))
	t.set_stylebox("disabled", "Button", box(Color("d5dbe6"), 10, Color("aab3c5"), 0, 3))
	t.set_stylebox("panel", "PanelContainer", box(MIST, 14, LINE, 2, 0))
	t.set_stylebox("panel", "Panel", box(MIST, 14, LINE, 2, 0))
	# Sliders grandes para o dedo
	var track := StyleBoxFlat.new()
	track.bg_color = Color("d5dceb")
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = TEAL
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


## Prende um controle no canto superior direito (x = distância da borda direita).
static func pin_top_right(c: Control, from_right: float, top: float, w: float, h: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = -from_right
	c.offset_right = -from_right + w
	c.offset_top = top
	c.offset_bottom = top + h


## Botão de fundo claro: texto escuro em todos os estados.
## Quebra o texto em linhas que cabem em max_w (medindo cada palavra).
static func wrap_text(text: String, font: Font, size: int, max_w: float) -> String:
	var out: PackedStringArray = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var test := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
				out.append(line)
				line = word
			else:
				line = test
		out.append(line)
	return "\n".join(out)


static func dark_text(b: Button) -> void:
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, DARK)


static func make_button(text: String, cb: Callable, min_w := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	return b


## Faz o arrastar o dedo em cima de botões/cartões rolar a lista
## (o toque passa do item para o ScrollContainer). Chame depois de montar.
static func scroll_friendly(root: Node) -> void:
	for c in root.get_children():
		if c is Control and not (c is ScrollContainer) and not (c is LineEdit) and not (c is Slider):
			if (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		scroll_friendly(c)
