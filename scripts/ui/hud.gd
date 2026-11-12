class_name HUD
extends Control
## HUD do jogo: nome do local, minimapa, mensagens, FPS, painel de emotes,
## pausa e menus. Os controles de toque ficam em MobileControls.

var controls: MobileControls
var minimap: Minimap
var player: PlayerController
var _zone_panel: PanelContainer
var _zone_label: Label
var _sub_label: Label
var _toast: Label
var _fps: Label
var _emote_panel: PanelContainer
var _pause_layer: Control
var _pause_box: VBoxContainer
var _settings: SettingsPanel
var _map_dim: ColorRect
var _toast_tween: Tween
var main_menu_cb: Callable
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _objective: Label
var _objective_point: Variant = null
var _mission_point: Variant = null
var _game_point: Variant = null  # ponto de encontro de brincadeiras online
var _wallet: Label
var _summary: Control
var _mg_panel: PanelContainer
var _mg_label: Label
var _meter: ProgressBar
var _fade: ColorRect
var _mission: Label


func _ready() -> void:
	add_to_group("hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS

	controls = MobileControls.new()
	controls.name = "MobileControls"
	add_child(controls)

	# Local atual
	_zone_panel = PanelContainer.new()
	_zone_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.16, 0.27, 0.72), 16))
	_zone_panel.position = Vector2(20, 18)
	_zone_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zv := VBoxContainer.new()
	zv.add_theme_constant_override("separation", -4)
	_zone_label = UITheme.title_label("Escola", 24, Color.WHITE)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_sub_label = Label.new()
	_sub_label.text = "Dia 1 · Manhã"
	_sub_label.add_theme_color_override("font_color", Color("ffe08a"))
	_sub_label.add_theme_font_size_override("font_size", 18)
	zv.add_child(_zone_label)
	zv.add_child(_sub_label)
	_zone_panel.add_child(zv)
	add_child(_zone_panel)

	_map_dim = ColorRect.new()
	_map_dim.color = Color(0, 0, 0, 0.45)
	_map_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_dim.visible = false
	_map_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# tocar fora do mapa fecha
	# (só clique: no celular o MESMO toque chega como clique + toque; o toque
	# que abriu o mapa não pode fechá-lo em seguida)
	_map_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and Time.get_ticks_msec() - _map_opened_ms > 350:
			minimap.open_full(false))
	add_child(_map_dim)

	minimap = Minimap.new()
	minimap.name = "Minimap"
	add_child(minimap)
	minimap.toggled_full.connect(_on_map_full)
	controls.blockers.append(minimap)
	controls.blockers.append(_map_dim)

	_toast = UITheme.title_label("", 30, Color.WHITE)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_toast.size = Vector2(840, 50)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	_fps = Label.new()
	_fps.add_theme_color_override("font_color", Color.WHITE)
	_fps.add_theme_constant_override("outline_size", 6)
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_font_size_override("font_size", 18)
	_fps.position = Vector2(20, 690)
	add_child(_fps)

	_build_emote_panel()
	_build_status()
	_build_minigame_hud()
	_build_pause()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	add_child(_fade)

	controls.pause_pressed.connect(open_pause)
	controls.emote_pressed.connect(func():
		if not _emote_panel.visible:
			_fill_emotes()
		_emote_panel.visible = not _emote_panel.visible)
	GameManager.zone_changed.connect(_on_zone_changed)
	GameManager.toast.connect(show_toast)
	GameManager.state_changed.connect(_on_state_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()


func bind(p: PlayerController, cam: CameraController, world: Node) -> void:
	player = p
	controls.bind(p, cam)
	minimap.setup(world, p)


func _layout() -> void:
	var vs := get_viewport_rect().size
	minimap.size = Vector2(230, 172) if not minimap.full else Vector2(minf(vs.x - 80, (vs.y - 40) * 1.2), vs.y - 40)
	if minimap.full:
		minimap.position = (vs - minimap.size) * 0.5
	else:
		minimap.position = Vector2(20, 18)
	_fps.position = Vector2(vs.x * 0.5 - 30, vs.y - 34)
	_toast.size = Vector2(840, 50)
	_toast.position = Vector2((vs.x - 840.0) * 0.5, vs.y * 0.62)
	_emote_panel.position = Vector2(vs.x - _emote_panel.size.x - 20, 120)
	if _objective:
		_layout_card()
		# moedas/nível embaixo dos botões redondos do canto direito
		_wallet.reset_size()
		_wallet.position = Vector2(vs.x - 20 - _wallet.size.x, 96)
		_zone_panel.position = Vector2(20, minimap.position.y + minimap.size.y + 8) if not minimap.full else Vector2(-999, -999)


var _map_opened_ms := 0


func _on_map_full(is_full: bool) -> void:
	if is_full:
		_map_opened_ms = Time.get_ticks_msec()
	else:
		controls.ignore_touches(400)
	_map_dim.visible = is_full
	# mapa aberto: some o resto da tela para não poluir
	controls.visible = not is_full
	_wallet.visible = false  # moedas e nível ficam na mochila
	_zone_panel.visible = not is_full
	_refresh_card()
	_layout()


var _obj_card: PanelContainer
var _mission_row: HBoxContainer
var _cancel_btn: Button
var _card_t := 0.0
var _cancel_confirm := 0.0
## main.gd preenche: se há missão cancelável e como cancelar.
var mission_cancel_check: Callable
var mission_cancel: Callable


func _build_status() -> void:
	# Cartão do objetivo/missão (topo central): grande ao mudar, discreto depois
	_obj_card = PanelContainer.new()
	var sb := UITheme.box(Color(0.1, 0.13, 0.25, 0.82), 20, Color(1, 1, 1, 0.25), 2, 0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_obj_card.add_theme_stylebox_override("panel", sb)
	_obj_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_obj_card.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_expand_card())
	add_child(_obj_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	_obj_card.add_child(cv)
	_objective = Label.new()
	_objective.add_theme_font_override("font", UITheme.bold_font())
	_objective.add_theme_font_size_override("font_size", 26)
	_objective.add_theme_color_override("font_color", Color.WHITE)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(_objective)
	_mission_row = HBoxContainer.new()
	_mission_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_mission_row.add_theme_constant_override("separation", 12)
	_mission_row.visible = false
	cv.add_child(_mission_row)
	_mission = Label.new()
	_mission.add_theme_font_override("font", UITheme.bold_font())
	_mission.add_theme_font_size_override("font_size", 23)
	_mission.add_theme_color_override("font_color", Color("8fdcff"))
	_mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_row.add_child(_mission)
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancelar"
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed", "focus"]:
		_cancel_btn.add_theme_stylebox_override(st, UITheme.box(Color("e04a3a"), 12, Color.WHITE, 2, 2))
	_cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	_cancel_btn.custom_minimum_size = Vector2(118, 40)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_mission_row.add_child(_cancel_btn)
	controls.blockers.append(_obj_card)
	# Moedas e nível
	_wallet = Label.new()
	_wallet.add_theme_font_override("font", UITheme.bold_font())
	_wallet.add_theme_font_size_override("font_size", 24)
	_wallet.add_theme_color_override("font_color", Color("ffe08a"))
	_wallet.add_theme_constant_override("outline_size", 8)
	_wallet.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25, 0.85))
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wsb := UITheme.box(Color(0.1, 0.13, 0.25, 0.75), 17, Color("ffcf3f"), 2, 0)
	wsb.content_margin_left = 12
	wsb.content_margin_right = 12
	_wallet.add_theme_stylebox_override("normal", wsb)
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet)
	_wallet.visible = false
	GameManager.rewards_changed.connect(func(_x, _c, _l): _update_wallet())
	_update_wallet()
	# Faixa grande (sinal, recreio, dia)
	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_banner_title = UITheme.title_label("", 84, Color("ffcf3f"))
	_banner_title.add_theme_constant_override("outline_size", 20)
	_banner_title.add_theme_color_override("font_outline_color", Color("1f2a44"))
	_banner_sub = UITheme.title_label("", 30, Color.WHITE)
	_banner_sub.add_theme_constant_override("outline_size", 10)
	_banner_sub.add_theme_color_override("font_outline_color", Color("1f2a44"))
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_sub)
	add_child(_banner)


func _build_minigame_hud() -> void:
	_mg_panel = PanelContainer.new()
	_mg_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.16, 0.27, 0.82), 16))
	_mg_panel.visible = false
	_mg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mg_label = UITheme.title_label("", 26, Color.WHITE)
	_mg_panel.add_child(_mg_label)
	add_child(_mg_panel)
	_meter = ProgressBar.new()
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(320, 26)
	_meter.add_theme_stylebox_override("fill", UITheme.box(Color("ff8a3d"), 10))
	_meter.add_theme_stylebox_override("background", UITheme.box(Color(1, 1, 1, 0.6), 10))
	_meter.visible = false
	add_child(_meter)


## Placar/estado do minijogo (texto vazio esconde).
func set_minigame_text(text: String) -> void:
	_mg_panel.visible = text != ""
	_mg_label.text = text
	# brincando: o placar ocupa o lugar do objetivo e das moedas
	var playing := text != ""
	_wallet.visible = false
	_refresh_card()
	var vs := get_viewport_rect().size
	_mg_label.add_theme_font_size_override("font_size", 22)
	_mg_panel.reset_size()
	_mg_panel.position = Vector2((vs.x - _mg_panel.size.x) * 0.5, 16)


## Barra de força (0..1); valor negativo esconde.
func set_meter(value: float) -> void:
	_meter.visible = value >= 0.0
	if value >= 0.0:
		_meter.value = value * 100.0
		var vs := get_viewport_rect().size
		_meter.position = Vector2((vs.x - 320.0) * 0.5, vs.y - 120.0)


func _update_wallet() -> void:
	var p: Dictionary = SaveManager.section("player")
	var lv := int(p.get("level", 1))
	_wallet.text = "Nível %d   ·   %d moedas" % [lv, int(p.get("coins", 0))]


func show_banner(title: String, subtitle := "", hold := 2.2) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	var vs := get_viewport_rect().size
	_banner.size = Vector2(vs.x, 160)
	_banner.position = Vector2(0, vs.y * 0.24)
	if _banner_tween:
		_banner_tween.kill()
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.6, 0.6)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.4)
	_banner_tween.chain().tween_interval(hold)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)


func set_mission(text: String) -> void:
	if text == _mission.text:
		return
	_mission.text = text
	_mission_row.visible = text != ""
	_expand_card()


func _expand_card() -> void:
	_card_t = 7.0
	_refresh_card()


func _refresh_card() -> void:
	var has := _objective.text != "" or _mission_row.visible
	_obj_card.visible = has and controls.visible and not (_mg_panel and _mg_panel.visible)
	if not has:
		return
	var compact := _card_t <= 0.0
	_obj_card.modulate.a = 0.6 if compact else 1.0
	_objective.add_theme_font_size_override("font_size", 20 if compact else 26)
	_mission.add_theme_font_size_override("font_size", 18 if compact else 23)
	_layout_card()


func _layout_card() -> void:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - 640.0, 760.0)
	_obj_card.custom_minimum_size = Vector2(w, 0)
	# largura fixa nos textos: assim a quebra de linha calcula a altura certa
	# na hora (sem isso o cartão podia ficar com a altura da tela inteira)
	_objective.custom_minimum_size = Vector2(w - 40.0, 0)
	_mission.custom_minimum_size = Vector2(w - 40.0 - (130.0 if _cancel_btn.visible else 0.0), 0)
	_obj_card.size = Vector2(w, 0)
	_obj_card.reset_size()
	_obj_card.position = Vector2((vs.x - _obj_card.size.x) * 0.5, 16)
	# textos que quebram linha só sabem a altura certa depois do layout:
	# encolhe de novo no próximo quadro (senão o cartão fica gigante)
	if not _card_relayout_pending:
		_card_relayout_pending = true
		_relayout_card_later.call_deferred()


var _card_relayout_pending := false


func _relayout_card_later() -> void:
	_card_relayout_pending = false
	if not is_instance_valid(_obj_card):
		return
	_obj_card.size = Vector2(_obj_card.custom_minimum_size.x, 0)
	_obj_card.reset_size()


func _on_cancel_pressed() -> void:
	if _cancel_confirm <= 0.0:
		_cancel_confirm = 3.0
		_cancel_btn.text = "Certeza?"
		return
	_cancel_confirm = 0.0
	_cancel_btn.text = "Cancelar"
	if mission_cancel.is_valid():
		mission_cancel.call()


## Escurece (1) ou clareia (0) a tela; retorna o tween para aguardar.
func fade(to: float, time := 0.45) -> Tween:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to, time)
	if to <= 0.0:
		tw.tween_callback(func(): _fade.visible = false)
	return tw


func set_objective(text: String) -> void:
	var changed := text != _objective.text
	_objective.text = text
	_objective.visible = text != ""
	if changed:
		_expand_card()


func set_objective_point(p: Variant) -> void:
	_objective_point = p
	queue_redraw()


func set_game_point(p: Variant) -> void:
	_game_point = p
	queue_redraw()


func set_mission_point(p: Variant) -> void:
	_mission_point = p
	queue_redraw()


func _draw() -> void:
	if not controls.visible:
		return
	if _objective_point != null:
		_draw_pointer(_objective_point, Color("ffcf3f"))
	if _mission_point != null:
		_draw_pointer(_mission_point, Color("5ec8ff"))
	if _game_point != null:
		_draw_pointer(_game_point, Color("ff4d6d"))


## Seta na borda da tela apontando para um ponto fora de vista.
func _draw_pointer(point: Vector3, col: Color) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport_rect().size
	var wp: Vector3 = point
	var behind := cam.is_position_behind(wp)
	var sp := cam.unproject_position(wp)
	var margin := 70.0
	var inside := not behind and sp.x > margin and sp.x < vs.x - margin and sp.y > margin and sp.y < vs.y - margin
	if inside:
		return
	var c := vs * 0.5
	var dir := (sp - c)
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var t := minf((vs.x * 0.5 - margin) / maxf(absf(dir.x), 0.001), (vs.y * 0.5 - margin) / maxf(absf(dir.y), 0.001))
	var p := c + dir * t
	var side := dir.orthogonal()
	var pts := PackedVector2Array([p + dir * 26.0, p - dir * 10.0 + side * 18.0, p - dir * 10.0 - side * 18.0])
	draw_circle(p, 30.0, Color(0.12, 0.16, 0.27, 0.6))
	draw_colored_polygon(pts, col)


func show_day_summary(s: Dictionary, on_next: Callable) -> void:
	if _summary:
		_summary.queue_free()
	_summary = Control.new()
	_summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_summary)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.15, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UITheme.title_label("Fim do Dia %d!" % s.day, 44))
	var stars := "★".repeat(clampi(int(round(float(s.correct) / maxf(s.total, 1) * 3.0)), 1, 3)) + "☆".repeat(3 - clampi(int(round(float(s.correct) / maxf(s.total, 1) * 3.0)), 1, 3))
	v.add_child(UITheme.title_label(stars, 56, Color("f2b632")))
	var info := Label.new()
	info.text = "Tarefas certas: %d de %d\nMoedas ganhas: +%d\nExperiência: +%d XP" % [s.correct, s.total, s.coins, s.xp]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 28)
	v.add_child(info)
	if s.get("level_up", false):
		v.add_child(UITheme.title_label("Você subiu para o nível %d!" % GameManager.level(), 30, UITheme.GREEN))
	var extra: String = s.get("extra", "")
	if extra != "":
		var el := Label.new()
		el.text = extra
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.add_theme_font_size_override("font_size", 22)
		v.add_child(el)
	# Recompensado opcional: só aparece se houver anúncio real disponível.
	if AdsManager.can_offer("dobrar_dia") and int(s.coins) > 0:
		var dbl: Button
		dbl = UITheme.make_button("Ver vídeo: dobrar moedas (+%d)" % int(s.coins), func():
			dbl.disabled = true
			AdsManager.show_rewarded("dobrar_dia", func():
				GameManager.add_rewards(0, int(s.coins))
				GameManager.show_toast("Moedas dobradas! +%d" % s.coins)), 460)
		dbl.add_theme_stylebox_override("normal", UITheme.box(Color("9be37a"), 18, Color("5aa83a"), 0, 6))
		v.add_child(dbl)
	v.add_child(UITheme.make_button("Próximo dia", func():
		_summary.queue_free()
		_summary = null
		on_next.call(), 320))
	controls.visible = false
	_summary.tree_exited.connect(func(): controls.visible = GameManager.is_playing())


func _build_emote_panel() -> void:
	_emote_panel = PanelContainer.new()
	_emote_panel.visible = false
	_emote_box = VBoxContainer.new()
	_emote_box.add_theme_constant_override("separation", 8)
	_emote_panel.add_child(_emote_box)
	_fill_emotes()


var _emote_box: VBoxContainer


## Só os emojis que o jogador tem (o resto se compra na mochila).
func _fill_emotes() -> void:
	for c in _emote_box.get_children():
		c.queue_free()
	for e in ShopCatalog.owned_emotes():
		var em: String = e[1]
		var b := UITheme.make_button(e[0], func():
			_emote_panel.visible = false
			if player:
				player.emote(em), 250)
		b.custom_minimum_size = Vector2(250, 54)
		b.add_theme_font_size_override("font_size", 22)
		_emote_box.add_child(b)
	var more := Label.new()
	more.text = "Mais emojis na mochila"
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.add_theme_font_size_override("font_size", 17)
	_emote_box.add_child(more)
	if _emote_panel.is_inside_tree():
		_emote_panel.reset_size()
	add_child(_emote_panel)
	_emote_panel.reset_size()
	controls.blockers.append(_emote_panel)


func _build_pause() -> void:
	_pause_layer = Control.new()
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.visible = false
	add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	_pause_box = VBoxContainer.new()
	_pause_box.add_theme_constant_override("separation", 16)
	panel.add_child(_pause_box)
	_pause_box.add_child(UITheme.title_label("Menu", 44))
	_pause_box.add_child(UITheme.make_button("Continuar", close_pause))
	_pause_box.add_child(UITheme.make_button("Configurações", _open_settings))
	_pause_box.add_child(UITheme.make_button("Menu principal", func():
		SaveManager.save_game()
		if main_menu_cb.is_valid():
			main_menu_cb.call()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	center.add_child(_settings)
	_settings.closed.connect(func():
		_settings.visible = false
		panel.visible = true)
	_pause_box.set_meta("panel", panel)


func _open_settings() -> void:
	(_pause_box.get_meta("panel") as Control).visible = false
	_settings.visible = true


func open_pause() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_emote_panel.visible = false
	GameManager.set_state(GameManager.State.PAUSED)


func close_pause() -> void:
	GameManager.set_state(GameManager.State.PLAYING)


func _on_state_changed(s: int) -> void:
	var paused := s == GameManager.State.PAUSED and not GameManager.overlay_open
	_pause_layer.visible = paused
	if paused:
		(_pause_box.get_meta("panel") as Control).visible = true
		_settings.visible = false
	var playing_ui := s == GameManager.State.PLAYING or paused
	controls.visible = s == GameManager.State.PLAYING
	_zone_panel.visible = playing_ui
	minimap.visible = playing_ui
	if not playing_ui:
		_emote_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.state == GameManager.State.PLAYING:
			open_pause()
		elif GameManager.state == GameManager.State.PAUSED:
			close_pause()
		get_viewport().set_input_as_handled()


func _on_zone_changed(zone_name: String, _indoor: bool) -> void:
	_zone_label.text = zone_name
	if _zone_tween:
		_zone_tween.kill()
	_zone_panel.modulate.a = 1.0
	_zone_tween = create_tween()
	_zone_tween.tween_interval(4.0)
	_zone_tween.tween_property(_zone_panel, "modulate:a", 0.0, 0.6)


var _zone_tween: Tween


func set_day_text(t: String) -> void:
	_sub_label.text = t


## Contador grande e fácil de ver: "Aula em 3:12", "Castigo 0:32"...
var _timer_chip: Label


func set_timer_chip(text: String, col := Color("2f6fd0")) -> void:
	if _timer_chip == null:
		_timer_chip = Label.new()
		_timer_chip.add_theme_font_override("font", UITheme.bold_font())
		_timer_chip.add_theme_font_size_override("font_size", 24)
		_timer_chip.add_theme_color_override("font_color", Color.WHITE)
		_timer_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_timer_chip)
	if text == "" or not controls.visible or minimap.full:
		_timer_chip.visible = false
		return
	if _timer_chip.text != text or not _timer_chip.visible:
		_timer_chip.text = text
		var sb := UITheme.box(Color(col, 0.92), 10, Color(1, 1, 1, 0.5), 2, 0)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		_timer_chip.add_theme_stylebox_override("normal", sb)
		_timer_chip.reset_size()
	var vs := get_viewport_rect().size
	var card_bottom := (_obj_card.position.y + _obj_card.size.y) if _obj_card.visible else 12.0
	_timer_chip.position = Vector2((vs.x - _timer_chip.size.x) * 0.5, card_bottom + 6.0)
	_timer_chip.visible = true


var _alert: Label
var _alert_t := 0.0


## Aviso vermelho grande no alto (ex.: "Volte para a sala! 7"). "" esconde.
func set_alert(text: String) -> void:
	if _alert == null:
		if text == "":
			return
		_alert = Label.new()
		_alert.add_theme_font_override("font", UITheme.bold_font())
		_alert.add_theme_font_size_override("font_size", 34)
		_alert.add_theme_color_override("font_color", Color.WHITE)
		_alert.add_theme_color_override("font_outline_color", Color("7a1010"))
		_alert.add_theme_constant_override("outline_size", 6)
		_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := UITheme.box(Color("e53935", 0.95), 18, Color(1, 1, 1, 0.85), 3, 6)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		_alert.add_theme_stylebox_override("normal", sb)
		add_child(_alert)
	if text == "":
		_alert.visible = false
		_alert.text = ""
		return
	if _alert.text != text:
		_alert.text = text
		_alert.reset_size()
		_alert.size = _alert.get_combined_minimum_size()
		_alert.pivot_offset = _alert.size * 0.5
		_alert.scale = Vector2(1.18, 1.18)  # "pulsa" a cada segundo
	var vs := get_viewport_rect().size
	_alert.position = Vector2((vs.x - _alert.size.x) * 0.5, vs.y * 0.22)
	_alert.visible = true


func alert_text() -> String:
	return _alert.text if _alert and _alert.visible else ""


var _result: PanelContainer
var _result_t := 0.0


## Cartão de fim de brincadeira: estrelas, resumo, XP, recorde e "Jogar de novo".
## Fecha sozinho em 7 s (ou no X / ao jogar de novo).
func show_result(game: String, head: String, summary: String, stars: int, xp: int, record: String, again: Callable) -> void:
	if _result and is_instance_valid(_result):
		_result.queue_free()
	var p := PanelContainer.new()
	_result = p
	var sb := UITheme.box(Color(1, 1, 1, 0.97), 26, Color("ffcf3f"), 5, 8)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var g := UITheme.title_label(game.to_upper(), 20, Color("6b7690"))
	v.add_child(g)
	v.add_child(UITheme.title_label(head, 44, Color("16a34a") if stars == 3 else (UITheme.DARK if stars == 2 else Color("c2410c"))))
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 6)
	v.add_child(star_row)
	for i in 3:
		var st := _ResultStar.new()
		st.on = i < stars
		st.custom_minimum_size = Vector2(56, 56)
		star_row.add_child(st)
		st.scale = Vector2.ZERO
		st.pivot_offset = Vector2(28, 28)
		var tw := st.create_tween()
		tw.tween_interval(0.15 + i * 0.18)
		tw.tween_property(st, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i < stars:
			var pitch := 1.0 + i * 0.12
			tw.tween_callback(func(): AudioManager.play_ui_pitch("point", pitch, -6.0))
	var sl := Label.new()
	sl.text = summary
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(520, 0)
	sl.add_theme_font_size_override("font_size", 22)
	sl.add_theme_color_override("font_color", UITheme.DARK)
	v.add_child(sl)
	var info := UITheme.title_label("+%d XP%s" % [xp, ("   ·   " + record) if record != "" else ""], 24, Color("b45309") if record.begins_with("NOVO") else Color("2563eb"))
	v.add_child(info)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	if again.is_valid():
		var b := UITheme.make_button("Jogar de novo", func():
			p.queue_free()
			again.call(), 260)
		b.add_theme_stylebox_override("normal", UITheme.box(Color("22c55e"), 18, Color("15803d"), 0, 6))
		b.add_theme_color_override("font_color", Color.WHITE)
		h.add_child(b)
	h.add_child(UITheme.make_button("Fechar", func(): p.queue_free(), 180))
	# premiado opcional: XP em dobro (só com vídeo pronto e até 3 vezes por dia)
	if xp > 0 and AdsManager.can_offer("xp_brincadeira"):
		var vb: Button
		vb = UITheme.make_button("Ver vídeo: XP em dobro (+%d)" % xp, func():
			vb.disabled = true
			_result_t = 999.0
			AdsManager.show_rewarded("xp_brincadeira", func():
				GameManager.add_rewards(xp, 0)
				GameManager.show_toast("XP em dobro! +%d XP" % xp)
				if is_instance_valid(p):
					p.queue_free()), 420)
		vb.add_theme_stylebox_override("normal", UITheme.box(Color("9be37a"), 18, Color("5aa83a"), 0, 6))
		v.add_child(vb)
	add_child(p)
	p.reset_size()
	var vs := get_viewport_rect().size
	p.position = Vector2((vs.x - p.size.x) * 0.5, vs.y * 0.16)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.7, 0.7)
	p.modulate.a = 0.0
	var tw2 := p.create_tween().set_parallel(true)
	tw2.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(p, "modulate:a", 1.0, 0.2)
	_result_t = 7.0
	get_tree().create_timer(7.0).timeout.connect(func():
		if is_instance_valid(p) and _result_t < 100.0:  # vendo o vídeo: não fecha sozinho
			var tw3 := p.create_tween()
			tw3.tween_property(p, "modulate:a", 0.0, 0.4)
			tw3.tween_callback(p.queue_free))


class _ResultStar extends Control:
	var on := true

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.48
		var pts := PackedVector2Array()
		for k in 10:
			var rad := r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2.from_angle(-PI * 0.5 + k * TAU / 10.0) * rad)
		draw_colored_polygon(pts, Color("ffcf3f") if on else Color("dfe4ec"))
		pts.append(pts[0])
		draw_polyline(pts, Color("d97706") if on else Color("c5ccd8"), 3.0, true)


var _hint: PanelContainer
var _hint_lbl: Label
var _hint_tween: Tween


## Dica temporária (balão amarelo com lâmpada, embaixo no meio). Some sozinha.
func show_hint(text: String, secs := 4.5) -> void:
	if _hint == null:
		_hint = PanelContainer.new()
		var sb := UITheme.box(Color("fff4c2"), 22, Color("f2b632"), 3, 5)
		sb.content_margin_left = 18
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		_hint.add_theme_stylebox_override("panel", sb)
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		_hint.add_child(h)
		var bulb := Label.new()
		bulb.text = "DICA"
		bulb.add_theme_font_override("font", UITheme.bold_font())
		bulb.add_theme_font_size_override("font_size", 18)
		bulb.add_theme_color_override("font_color", Color.WHITE)
		var bb := StyleBoxFlat.new()
		bb.bg_color = Color("f59e0b")
		bb.set_corner_radius_all(10)
		bb.content_margin_left = 8
		bb.content_margin_right = 8
		bulb.add_theme_stylebox_override("normal", bb)
		bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bulb)
		_hint_lbl = Label.new()
		_hint_lbl.add_theme_font_override("font", UITheme.bold_font())
		_hint_lbl.add_theme_font_size_override("font_size", 24)
		_hint_lbl.add_theme_color_override("font_color", Color("5a3e00"))
		_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_hint_lbl)
		add_child(_hint)
		_hint.modulate.a = 0.0
	var vs := get_viewport_rect().size
	var w := minf(vs.x * 0.56, 720.0)
	# quebra as linhas medindo as palavras (o autowrap do Godot media com
	# largura zero: uma letra por linha, e o balão cobria a tela até em cima)
	_hint_lbl.text = UITheme.wrap_text(text, UITheme.bold_font(), 24, w - 120.0)
	_hint_lbl.custom_minimum_size = Vector2.ZERO
	_hint.custom_minimum_size = Vector2.ZERO
	_hint.visible = true
	_hint.size = Vector2.ZERO
	_hint.reset_size()
	var hsz := _hint.get_combined_minimum_size()
	hsz.y = minf(hsz.y, vs.y * 0.3)
	_hint.size = hsz
	_hint.position = Vector2((vs.x - hsz.x) * 0.5, vs.y * 0.6 - hsz.y * 0.5)
	if _hint_tween:
		_hint_tween.kill()
	_hint.scale = Vector2(0.9, 0.9)
	_hint.pivot_offset = _hint.size * 0.5
	_hint_tween = create_tween()
	_hint_tween.set_parallel(true)
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.2)
	_hint_tween.tween_property(_hint, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hint_tween.chain().tween_interval(secs)
	_hint_tween.chain().tween_property(_hint, "modulate:a", 0.0, 0.5)
	_hint_tween.chain().tween_callback(func(): _hint.visible = false)
	AudioManager.play_ui("ui_confirm", -12.0)


func hide_hint() -> void:
	if _hint:
		if _hint_tween:
			_hint_tween.kill()
		_hint.modulate.a = 0.0
		_hint.visible = false


func show_toast(message: String) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	if _alert and _alert.visible and _alert.scale.x > 1.0:
		_alert.scale = Vector2.ONE * maxf(1.0, _alert.scale.x - delta * 0.8)
	if _objective_point != null or _mission_point != null or _game_point != null:
		queue_redraw()
	if _obj_card:
		var was := _card_t > 0.0
		_card_t -= delta
		if was and _card_t <= 0.0:
			_refresh_card()
		if _obj_card.visible != ((_objective.text != "" or _mission_row.visible) and controls.visible and not _mg_panel.visible):
			_refresh_card()
		var cv := mission_cancel_check.is_valid() and bool(mission_cancel_check.call())
		if cv != _cancel_btn.visible:
			_cancel_btn.visible = cv
			_layout_card()
		if _cancel_confirm > 0.0:
			_cancel_confirm -= delta
			if _cancel_confirm <= 0.0:
				_cancel_btn.text = "Cancelar"
	_fps.visible = bool(Settings.get_value("show_fps"))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
