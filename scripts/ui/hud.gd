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
	_build_pause()

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


func _on_map_full(is_full: bool) -> void:
	_map_dim.visible = is_full
	_layout()


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
	var paused := s == GameManager.State.PAUSED
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
	_fps.visible = bool(Settings.get_value("show_fps"))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
