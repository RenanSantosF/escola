class_name LobbyPassCard
extends Button
## Cartão do PASSE DO RECREIO em destaque no menu: degradê roxo -> rosa,
## nível atual, barra de progresso, próximo prêmio desenhado e quantos
## prêmios estão esperando. Tocar abre o passe.

var _v: VBoxContainer
var _t := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22)
	add_child(m)
	_v = VBoxContainer.new()
	_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_v.add_theme_constant_override("separation", 8)
	m.add_child(_v)
	pressed.connect(func(): AudioManager.play_ui("ui_click"))
	refresh()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 8.0:
		return
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(UITheme.PASS_A.darkened(0.4), 0.25)
	sh.set_corner_radius_all(16)
	draw_style_box(sh, Rect2(r.position + Vector2(0, 6), r.size))
	# degradê diagonal roxo -> rosa com cantos arredondados
	var poly := _rounded(r, 16.0)
	var cols := PackedColorArray()
	for p in poly:
		var f := clampf((p.x / r.size.x) * 0.7 + (p.y / r.size.y) * 0.3, 0.0, 1.0)
		cols.append(UITheme.PASS_A.lerp(UITheme.PASS_B, f))
	draw_polygon(poly, cols)
	# brilhos suaves
	draw_circle(Vector2(r.size.x * 0.85, r.size.y * 0.15), r.size.y * 0.45, Color(1, 1, 1, 0.06))
	draw_circle(Vector2(r.size.x * 0.1, r.size.y * 1.0), r.size.y * 0.5, Color(1, 1, 1, 0.05))
	# estrelinhas piscando (canto de baixo à esquerda)
	var a := 0.5 + 0.5 * sin(_t * 2.0)
	_star(Vector2(26, r.size.y - 26), 7.0 + 2.0 * a, Color(1, 1, 1, 0.35 + 0.4 * a))
	_star(Vector2(48, r.size.y - 42), 4.0 + 1.5 * (1.0 - a), Color(1, 1, 1, 0.3 + 0.3 * (1.0 - a)))
	if is_hovered():
		var hl := StyleBoxFlat.new()
		hl.bg_color = Color(1, 1, 1, 0.06)
		hl.set_corner_radius_all(16)
		draw_style_box(hl, r)


func _star(c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := rad if k % 2 == 0 else rad * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + k * TAU / 10.0) * rr)
	draw_colored_polygon(pts, col)


static func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for c in corners:
		for k in 7:
			var ang: float = float(c[1]) + k * (PI * 0.5) / 6.0
			pts.append(Vector2(c[0]) + Vector2.from_angle(ang) * rad)
	return pts


func _label(text: String, size_px: int, bold := false, alpha := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		l.add_theme_font_override("font", UITheme.bold_font())
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	return l


## Próximo prêmio da trilha premium a partir do nível atual.
static func next_reward() -> Array:
	var t := RecessPass.tier()
	for k in range(t + 1, RecessPass.TIERS + 1):
		var r: Dictionary = RecessPass.PREMIUM.get(k, {})
		if r.has("item"):
			return [k, str(r.item)]
	return [RecessPass.TIERS, str((RecessPass.PREMIUM.get(RecessPass.TIERS, {}) as Dictionary).get("item", ""))]


func refresh() -> void:
	if _v == null:
		return
	for c in _v.get_children():
		c.queue_free()
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_v.add_child(top)
	var tt := _label("PASSE DO RECREIO", 24, true)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tt)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := UITheme.box(Color(1, 1, 1, 0.2), 8)
	bsb.content_margin_left = 10
	bsb.content_margin_right = 10
	bsb.content_margin_top = 2
	bsb.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", bsb)
	badge.add_child(_label("PREMIUM" if RecessPass.is_premium() else "GRÁTIS", 15, true))
	top.add_child(badge)
	_v.add_child(_label(RecessPass.season_name(), 16, false, 0.8))
	# nível e barra
	var lv := HBoxContainer.new()
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_theme_constant_override("separation", 8)
	_v.add_child(lv)
	lv.add_child(_label("Nível %d" % RecessPass.tier(), 40, true))
	var of := _label("/ %d" % RecessPass.TIERS, 20, false, 0.75)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	lv.add_child(of)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = RecessPass.tier_progress()
	bar.add_theme_stylebox_override("background", UITheme.box(Color(1, 1, 1, 0.22), 5))
	bar.add_theme_stylebox_override("fill", UITheme.box(Color.WHITE, 5))
	_v.add_child(bar)
	# próximo prêmio (com o desenho do item)
	var nr := next_reward()
	var item := ShopCatalog.get_item(str(nr[1]))
	if not item.is_empty():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		_v.add_child(row)
		var ic := ItemIcon.new(item)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.custom_minimum_size = Vector2(118, 82)
		ic.clip_contents = true
		row.add_child(ic)
		var tv := VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tv)
		tv.add_child(_label("Próximo prêmio · nível %d" % int(nr[0]), 15, false, 0.8))
		var nm := _label(str(item.get("name", "")), 21, true)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(230, 0)
		tv.add_child(nm)
	var pend := RecessPass.pending()
	var cta := _label(("%d prêmio%s para pegar  ›" % [pend, "s" if pend > 1 else ""]) if pend > 0 else "Ver o passe  ›", 20, true)
	cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if pend > 0:
		cta.add_theme_color_override("font_color", Color("fde68a"))
	_v.add_child(cta)
