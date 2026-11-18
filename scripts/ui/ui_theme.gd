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
## Visual novo (menu, mochila, loja e opções): claro, limpo e moderno.
const BG := Color("f2f4fa")         # fundo das telas
const CARD := Color("ffffff")       # cartões
const CARD_2 := Color("f5f7fc")     # cartão secundário / botão claro
const STROKE := Color("e3e7f1")     # contorno discreto
const INK := Color("141a2e")        # texto principal
const INK_2 := Color("5b6582")      # texto secundário
const ACCENT := Color("4f46e5")     # cor principal (índigo)
const ACCENT_SOFT := Color("eceefe")
const GOOD := Color("16a34a")
const GOLD := Color("f59e0b")
const PASS_A := Color("7c3aed")     # passe: roxo -> rosa
const PASS_B := Color("ec4899")
const PLAY := Color("22c55e")       # botão JOGAR

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
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("6b7690"))
	# botões lisos, cantos discretos (10 px), sombra suave
	t.set_stylebox("normal", "Button", flat(ACCENT, 10))
	t.set_stylebox("hover", "Button", flat(ACCENT.lightened(0.08), 10))
	t.set_stylebox("pressed", "Button", flat(ACCENT.darkened(0.12), 10, false))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 10, Color(ACCENT, 0.0), 0, 0))
	t.set_stylebox("disabled", "Button", flat(Color("dfe3ee"), 10, false))
	t.set_stylebox("panel", "PanelContainer", card())
	t.set_stylebox("panel", "Panel", card())
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
	t.set_font_size("font_size", "CheckButton", 21)
	t.set_font("font", "CheckButton", ThemeDB.fallback_font)
	t.set_icon("checked", "CheckButton", _switch_tex(true))
	t.set_icon("unchecked", "CheckButton", _switch_tex(false))
	t.set_icon("checked_disabled", "CheckButton", _switch_tex(true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch_tex(false))
	var flat := box(Color(1, 1, 1, 0.0), 14)
	var flat_h := box(Color(0, 0, 0, 0.05), 14)
	for st in ["normal", "pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", flat)
	t.set_stylebox("hover", "CheckButton", flat_h)
	t.set_stylebox("hover_pressed", "CheckButton", flat_h)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
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


## Fundo liso com sombra suave (botões do visual novo).
static func flat(bg: Color, radius := 10, shadow := true) -> StyleBoxFlat:
	var s := box(bg, radius)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.12)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	return s


## Cartão branco com contorno discreto e sombra leve.
static func card(bg := CARD, radius := 14, stroke := STROKE) -> StyleBoxFlat:
	var s := box(bg, radius, stroke, 1, 0)
	s.shadow_color = Color(0.08, 0.1, 0.25, 0.07)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


## Botão principal (cor cheia) / secundário (claro, texto escuro).
static func style_button(b: Button, col := ACCENT, light := false, radius := 10) -> void:
	var fg := INK if light else Color.WHITE
	b.add_theme_stylebox_override("normal", flat(col, radius))
	b.add_theme_stylebox_override("hover", flat(col.lightened(0.06) if not light else col.darkened(0.03), radius))
	b.add_theme_stylebox_override("pressed", flat(col.darkened(0.1), radius, false))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), radius))
	b.add_theme_stylebox_override("disabled", flat(Color("e6e9f1"), radius, false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color("98a1b8"))


## "Chip" de categoria/aba: ativo = índigo; inativo = claro.
static func chip(text: String, active: bool, cb: Callable, fs := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", fs)
	style_button(b, ACCENT if active else CARD, not active, 10)
	if not active:
		for st in ["normal", "hover"]:
			var sb := card(CARD, 10)
			sb.shadow_size = 0
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	return b


## Interruptor (liga/desliga) desenhado: trilho arredondado + bolinha.
static func _switch_tex(on: bool) -> ImageTexture:
	var w := 64
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := ACCENT if on else Color("d4d9e6")
	var r := h * 0.5
	var knob_c := Vector2(w - r, r) if on else Vector2(r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			# trilho: retângulo com pontas redondas
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var col := Color(track, a)
			var kd := p.distance_to(knob_c)
			var ka := clampf(r - 3.0 - kd, 0.0, 1.0)
			if ka > 0.0:
				col = col.lerp(Color.WHITE, ka)
				col.a = maxf(col.a, ka)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


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


## Rótulo comum (texto normal) com tamanho e cor.
static func text_label(text: String, size := 20, col := INK_2, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
