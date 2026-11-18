class_name GamesPicker
extends Control
## Atalho das BRINCADEIRAS: escolhe a brincadeira e a seta azul guia até lá
## (quanto custa e se é no recreio aparecem no cartão).

var minigames: MinigameManager


static func open(parent: Control, mgr: MinigameManager) -> GamesPicker:
	var p := GamesPicker.new()
	p.minigames = mgr
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.08, 0.18, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card(UITheme.CARD, 18))
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UITheme.title_label("Ir para uma brincadeira", 30, UITheme.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UITheme.make_button("Fechar", queue_free, 130)
	close.custom_minimum_size = Vector2(130, 48)
	close.add_theme_font_size_override("font_size", 19)
	UITheme.style_button(close, UITheme.CARD_2, true)
	head.add_child(close)
	var rec := minigames != null and minigames.is_recess()
	v.add_child(UITheme.text_label("Toque e siga a seta azul até lá." if rec else "As brincadeiras são no RECREIO. Já dá para ver onde ficam!", 18, UITheme.INK_2))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var here: Vector3 = GameManager.player.global_position if GameManager.player else Vector3.ZERO
	var ids: Array = MinigameManager.GAMES.keys()
	ids.sort_custom(func(a, b): return (MinigameManager.GAMES[a].pos as Vector3).distance_to(here) < (MinigameManager.GAMES[b].pos as Vector3).distance_to(here))
	for gid in ids:
		grid.add_child(_game_btn(str(gid), here))
	UITheme.scroll_friendly(v)


func _game_btn(gid: String, here: Vector3) -> Button:
	var g: Dictionary = MinigameManager.GAMES[gid]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 86)
	var sb := UITheme.card(UITheme.CARD_2, 12)
	sb.shadow_size = 0
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var sbh := UITheme.card(UITheme.ACCENT_SOFT, 12, UITheme.ACCENT)
	sbh.shadow_size = 0
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	b.add_child(h)
	var dot := Label.new()
	dot.text = str(g.icon)
	dot.custom_minimum_size = Vector2(44, 44)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_theme_font_override("font", UITheme.bold_font())
	dot.add_theme_font_size_override("font_size", 22)
	dot.add_theme_color_override("font_color", Color.WHITE if (g.color as Color).get_luminance() < 0.7 else UITheme.INK)
	var ds := UITheme.box(g.color, 12)
	ds.content_margin_left = 0
	ds.content_margin_right = 0
	dot.add_theme_stylebox_override("normal", ds)
	h.add_child(dot)
	var tv := VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 0)
	h.add_child(tv)
	var nm := UITheme.title_label(str(g.title), 19, UITheme.INK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(nm)
	var dist := int((g.pos as Vector3).distance_to(here))
	tv.add_child(UITheme.text_label("%d moedas  ·  %d m" % [int(MinigameManager.PRICES.get(gid, 3)), dist], 15, UITheme.INK_2))
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		if minigames:
			minigames.guide_to(gid)
		queue_free())
	return b
