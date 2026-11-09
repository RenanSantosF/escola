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
var _wallet: Label
var _summary: Control
var _mg_panel: PanelContainer
var _mg_label: Label
var _meter: ProgressBar
var _fade: ColorRect
var _mission: Label


func _ready() -> void:
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
	_zone_label = UITheme.title_label("Escola", 26, Color.WHITE)
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
	_map_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_dim)

	minimap = Minimap.new()
	minimap.name = "Minimap"
	add_child(minimap)
	minimap.toggled_full.connect(_on_map_full)
	controls.blockers.append(minimap)

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
	controls.emote_pressed.connect(func(): _emote_panel.visible = not _emote_panel.visible)
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
	minimap.size = Vector2(200, 150) if not minimap.full else Vector2(minf(vs.x - 120, vs.y * 1.25), vs.y - 120)
	if minimap.full:
		minimap.position = (vs - minimap.size) * 0.5
	else:
		minimap.position = Vector2(20, 104)
	_fps.position = Vector2(vs.x * 0.5 - 30, vs.y - 34)
	_toast.size = Vector2(840, 50)
	_toast.position = Vector2((vs.x - 840.0) * 0.5, 100)
	_emote_panel.position = Vector2(vs.x - _emote_panel.size.x - 20, 120)
	if _objective:
		_objective.size = Vector2(vs.x - 600, 34)
		_objective.position = Vector2(300, 60)
		_mission.size = Vector2(vs.x - 600, 28)
		_mission.position = Vector2(300, 90)
		_wallet.size = Vector2(420, 30)
		_wallet.position = Vector2(vs.x - 300 - 420, 32)


func _on_map_full(is_full: bool) -> void:
	_map_dim.visible = is_full
	_layout()


func _build_status() -> void:
	# Objetivo atual (topo central)
	_objective = Label.new()
	_objective.add_theme_font_override("font", UITheme.bold_font())
	_objective.add_theme_font_size_override("font_size", 22)
	_objective.add_theme_color_override("font_color", Color.WHITE)
	_objective.add_theme_constant_override("outline_size", 8)
	_objective.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25, 0.85))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective)
	_mission = Label.new()
	_mission.add_theme_font_size_override("font_size", 19)
	_mission.add_theme_color_override("font_color", Color("ffe08a"))
	_mission.add_theme_constant_override("outline_size", 7)
	_mission.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25, 0.85))
	_mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission.visible = false
	add_child(_mission)
	# Moedas e nível
	_wallet = Label.new()
	_wallet.add_theme_font_override("font", UITheme.bold_font())
	_wallet.add_theme_font_size_override("font_size", 22)
	_wallet.add_theme_color_override("font_color", Color("ffe08a"))
	_wallet.add_theme_constant_override("outline_size", 8)
	_wallet.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25, 0.85))
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet)
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
	var vs := get_viewport_rect().size
	_mg_panel.reset_size()
	_mg_panel.position = Vector2((vs.x - _mg_panel.size.x) * 0.5, 96)


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
	_wallet.text = "Nível %d  ·  %d XP/%d   🪙 %d" % [lv, int(p.get("xp", 0)), GameManager.xp_for_level(lv), int(p.get("coins", 0))]
	_wallet.text = _wallet.text.replace("🪙", "Moedas:")


func show_banner(title: String, subtitle := "") -> void:
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
	_banner_tween.chain().tween_interval(2.2)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)


func set_mission(text: String) -> void:
	_mission.text = text
	_mission.visible = text != ""


## Escurece (1) ou clareia (0) a tela; retorna o tween para aguardar.
func fade(to: float, time := 0.45) -> Tween:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to, time)
	if to <= 0.0:
		tw.tween_callback(func(): _fade.visible = false)
	return tw


func set_objective(text: String) -> void:
	_objective.text = text
	_objective.visible = text != ""


func set_objective_point(p: Variant) -> void:
	_objective_point = p
	queue_redraw()


func _draw() -> void:
	# seta na borda da tela apontando para o objetivo quando fora de vista
	if _objective_point == null or not controls.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport_rect().size
	var wp: Vector3 = _objective_point
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
	draw_colored_polygon(pts, Color("ffcf3f"))


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
	if AdsManager.can_show_rewarded():
		var dbl := UITheme.make_button("Dobrar moedas (ver anúncio)", func():
			AdsManager.show_rewarded("dobrar_dia", func():
				GameManager.add_rewards(0, int(s.coins))
				GameManager.show_toast("Moedas dobradas! +%d" % s.coins)), 420)
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_emote_panel.add_child(v)
	var emotes := [["Acenar", "wave"], ["Comemorar", "celebrate"], ["Ficar triste", "sad"], ["Espreguiçar", "stretch"], ["Coçar a cabeça", "scratch_head"], ["Olhar em volta", "look_around"]]
	for e in emotes:
		var b := UITheme.make_button(e[0], func():
			_emote_panel.visible = false
			if player:
				player.emote(e[1]), 250)
		b.custom_minimum_size = Vector2(250, 54)
		b.add_theme_font_size_override("font_size", 22)
		v.add_child(b)
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
	_pause_box.add_child(UITheme.title_label("Pausa", 44))
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
	var tw := create_tween()
	_zone_panel.pivot_offset = _zone_panel.size * 0.5
	tw.tween_property(_zone_panel, "scale", Vector2(1.08, 1.08), 0.1)
	tw.tween_property(_zone_panel, "scale", Vector2.ONE, 0.15)


func set_day_text(t: String) -> void:
	_sub_label.text = t


func show_toast(message: String) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	if _objective_point != null:
		queue_redraw()
	_fps.visible = bool(Settings.get_value("show_fps"))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
