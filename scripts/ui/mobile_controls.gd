class_name MobileControls
extends Control
## Controles de toque (paisagem): joystick flutuante à esquerda, botões de
## ação à direita e arrasto livre para girar a câmera. Toda a entrada de
## toque passa por aqui para suportar vários dedos ao mesmo tempo.

signal pause_pressed
signal emote_pressed

const JOY_RADIUS := 92.0
const KNOB_RADIUS := 40.0
const DEADZONE := 0.12

var player: PlayerController
var camera_rig: CameraController

var btn_play: TouchButton
var btn_jump: TouchButton
var btn_interact: TouchButton
var btn_run: TouchButton
var btn_pause: TouchButton
var btn_emote: TouchButton
var buttons: Array[TouchButton] = []
var blockers: Array[Control] = []  # áreas da HUD que não giram a câmera

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_rest := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _button_touch := {}  # index -> TouchButton
var _cam_touches := {}  # index -> posição
var _pinch_dist := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_play = _make_button(TouchButton.Icon.PLAY, Color("ffcf3f"), "Comemorar")
	btn_jump = _make_button(TouchButton.Icon.JUMP, Color("8fd3ff"), "Pular")
	btn_interact = _make_button(TouchButton.Icon.INTERACT, Color("9be37a"), "")
	btn_run = _make_button(TouchButton.Icon.RUN, Color("ff9f6b"), "Correr")
	btn_run.toggle = true
	btn_pause = _make_button(TouchButton.Icon.PAUSE, Color("ffffff"), "")
	btn_emote = _make_button(TouchButton.Icon.EMOTE, Color("ffffff"), "")
	btn_play.pressed.connect(_on_play)
	btn_jump.pressed.connect(_on_jump)
	btn_interact.pressed.connect(_on_interact)
	btn_run.pressed.connect(_on_run)
	btn_pause.pressed.connect(pause_pressed.emit)
	btn_emote.pressed.connect(emote_pressed.emit)
	get_viewport().size_changed.connect(_layout)
	Settings.changed.connect(_on_setting_changed)
	GameManager.state_changed.connect(_on_state_changed)
	_apply_opacity()
	_layout()


func _on_play() -> void:
	if player:
		player.request_play()


func _on_jump() -> void:
	if player:
		player.request_jump()


func _on_interact() -> void:
	if player:
		player.request_interact()


func _on_run() -> void:
	if player:
		player.run_active = btn_run.toggled_on


func _on_setting_changed(key: String) -> void:
	if key == "controls_opacity":
		_apply_opacity()


func _on_state_changed(_s: int) -> void:
	_release_all()


func bind(p: PlayerController, cam: CameraController) -> void:
	player = p
	camera_rig = cam
	p.controls = self
	p.context_changed.connect(_on_context_changed)


func _make_button(icon: TouchButton.Icon, col: Color, text: String) -> TouchButton:
	var b := TouchButton.new()
	b.icon = icon
	b.base_color = col
	b.label = text
	add_child(b)
	buttons.append(b)
	return b


func _apply_opacity() -> void:
	modulate.a = float(Settings.get_value("controls_opacity"))


func _safe_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var r := Rect2(Vector2.ZERO, vs)
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x > 0 and screen.x > 0 and OS.get_name() in ["Android", "iOS"]:
		var sx := vs.x / float(screen.x)
		var sy := vs.y / float(screen.y)
		r = Rect2(Vector2(safe.position) * Vector2(sx, sy), Vector2(safe.size) * Vector2(sx, sy))
	return r


func _layout() -> void:
	var sr := _safe_rect()
	var br := sr.end
	var m := 24.0
	_place(btn_play, br + Vector2(-m - 72, -m - 92), 148)
	_place(btn_jump, br + Vector2(-m - 232, -m - 58), 104)
	_place(btn_interact, br + Vector2(-m - 226, -m - 214), 116)
	_place(btn_run, br + Vector2(-m - 72, -m - 268), 100)
	_place(btn_pause, Vector2(br.x - m - 36, sr.position.y + m + 36), 72)
	_place(btn_emote, Vector2(br.x - m - 122, sr.position.y + m + 36), 72)
	_joy_rest = Vector2(sr.position.x + m + 150, br.y - m - 140)
	if _joy_index == -1:
		_joy_center = _joy_rest
		_joy_pos = _joy_rest


func _place(b: TouchButton, center: Vector2, diameter: float) -> void:
	b.size = Vector2(diameter, diameter)
	b.position = center - b.size * 0.5


func get_move_vector() -> Vector2:
	return _joy_vec


func _on_context_changed(interact_label: String, play_label: String) -> void:
	btn_interact.label = interact_label
	btn_interact.highlight = interact_label != ""
	btn_interact.modulate.a = 1.0 if interact_label != "" else 0.55
	btn_play.label = play_label
	btn_play.highlight = play_label in ["Chutar", "Arremessar"]


# ------------------------------------------------------------------ entrada

func _input(event: InputEvent) -> void:
	if not visible or not GameManager.is_playing():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_down(st.index, st.position)
		else:
			_touch_up(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touch_drag(sd.index, sd.position, sd.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	for b in buttons:
		if b.visible and b.contains(pos):
			_button_touch[index] = b
			b.press()
			AudioManager.play_ui("ui_click", -10.0, 0.05)
			get_viewport().set_input_as_handled()
			return
	for c in blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return
	var vs := get_viewport_rect().size
	if _joy_index == -1 and pos.x < vs.x * 0.45 and pos.y > vs.y * 0.3:
		_joy_index = index
		var sr := _safe_rect()
		_joy_center = Vector2(clampf(pos.x, sr.position.x + JOY_RADIUS, vs.x * 0.45), clampf(pos.y, sr.position.y + JOY_RADIUS, sr.end.y - JOY_RADIUS))
		_update_joy(pos)
		get_viewport().set_input_as_handled()
		return
	_cam_touches[index] = pos
	_pinch_dist = -1.0


func _touch_up(index: int) -> void:
	if _button_touch.has(index):
		_button_touch[index].release()
		_button_touch.erase(index)
	elif index == _joy_index:
		_joy_index = -1
		_joy_vec = Vector2.ZERO
		_joy_center = _joy_rest
		_joy_pos = _joy_rest
		queue_redraw()
	elif _cam_touches.has(index):
		_cam_touches.erase(index)
		_pinch_dist = -1.0


func _touch_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if index == _joy_index:
		_update_joy(pos)
		return
	if _button_touch.has(index):
		# arrastar a partir de um botão também gira a câmera (ex.: correr + olhar)
		if camera_rig and rel.length() > 2.0 and not _button_touch[index].contains(pos):
			camera_rig.rotate_input(rel)
		return
	if not _cam_touches.has(index):
		return
	_cam_touches[index] = pos
	if _cam_touches.size() >= 2:
		var pts: Array = _cam_touches.values()
		var d: float = (pts[0] as Vector2).distance_to(pts[1])
		if _pinch_dist > 0.0 and camera_rig:
			camera_rig.zoom_input((_pinch_dist - d) * 0.012)
		_pinch_dist = d
	elif camera_rig:
		camera_rig.rotate_input(rel)


func _update_joy(pos: Vector2) -> void:
	var off := pos - _joy_center
	var v := off / JOY_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	_joy_pos = _joy_center + v * JOY_RADIUS
	var l := v.length()
	if l < DEADZONE:
		_joy_vec = Vector2.ZERO
	else:
		# curva de resposta: mais precisão em movimentos pequenos
		var k := (l - DEADZONE) / (1.0 - DEADZONE)
		_joy_vec = v.normalized() * pow(k, 1.25)
	queue_redraw()


func _release_all() -> void:
	for idx in _button_touch.keys():
		_button_touch[idx].release()
	_button_touch.clear()
	_cam_touches.clear()
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	_joy_center = _joy_rest
	_joy_pos = _joy_rest
	queue_redraw()


func _process(_delta: float) -> void:
	if player and btn_run.toggled_on != player.run_active:
		btn_run.toggled_on = player.run_active


func _draw() -> void:
	var active := _joy_index != -1
	var a := 0.55 if active else 0.3
	draw_circle(_joy_center, JOY_RADIUS + 6, Color(0, 0, 0, a * 0.35))
	draw_circle(_joy_center, JOY_RADIUS, Color(1, 1, 1, a * 0.35))
	draw_arc(_joy_center, JOY_RADIUS, 0, TAU, 64, Color(1, 1, 1, a + 0.2), 3.0, true)
	for k in 4:
		var dir := Vector2.from_angle(k * PI * 0.5)
		var tip := _joy_center + dir * (JOY_RADIUS - 14)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12 + dir.orthogonal() * 9, tip - dir * 12 - dir.orthogonal() * 9]), Color(1, 1, 1, a + 0.1))
	draw_circle(_joy_pos + Vector2(0, 4), KNOB_RADIUS, Color(0, 0, 0, 0.25))
	draw_circle(_joy_pos, KNOB_RADIUS, Color(1, 1, 1, 0.55 + a * 0.5))
	draw_arc(_joy_pos, KNOB_RADIUS - 2, 0, TAU, 40, Color("ffcf3f"), 4.0, true)
