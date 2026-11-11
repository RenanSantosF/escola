class_name CharacterStage
extends SubViewportContainer
## Palco 3D do personagem (mundo próprio, leve): pódio colorido, luzes de
## estúdio e o boneco vivo. ARRASTE para girar (com embalo), pinça ou rodinha
## para aproximar, TOQUE no boneco para ele fazer uma graça. Sozinho ele
## respira, olha em volta e às vezes acena. Usado no menu, na mochila
## (visual/loja) e na escolha menino/menina.

signal tapped

var character: CharacterVisual
var auto_emotes := true  ## faz gracinhas sozinho de vez em quando
var podium := true
var podium_color := Color("ffcf3f")
var zoom_min := 2.0
var zoom_max := 4.2
var base_dist := 2.85  ## distância da câmera (corpo todo)

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _yaw := 0.0
var _yaw_vel := 0.0
var _dist := 2.85
var _target_dist := 2.85
var _look_y := 0.95
var _target_look_y := 0.95
var _drag := false
var _drag_moved := 0.0
var _idle_t := 0.0
var _emote_t := 5.0
var _touches := {}
var _pinch_d := 0.0
var _spin := 0.0
var _sparkle: GPUParticles3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_dist = base_dist
	_target_dist = base_dist
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X if Settings.quality() != Settings.Quality.LOW else Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.tonemap_white = 1.6
	_vp.add_child(env)
	# luz principal quente + contraluz azulada (contorno bonito) + preenchimento rosado
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 28, 0)
	key.light_energy = 0.95
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = Settings.quality() != Settings.Quality.LOW
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.55
	rim.light_color = Color(0.55, 0.8, 1.0)
	_vp.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.6, 1.4, 1.8)
	fill.omni_range = 6.0
	fill.light_energy = 0.35
	fill.light_color = Color(1.0, 0.75, 0.85)
	_vp.add_child(fill)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	if podium:
		_build_podium()
	_cam = Camera3D.new()
	_cam.fov = 34
	_vp.add_child(_cam)
	_sparkle = _make_sparkle()
	_vp.add_child(_sparkle)
	_place_camera()


func _build_podium() -> void:
	var md := MeshData.new()
	md.cur_color = podium_color.darkened(0.25)
	md.add_cylinder(Transform3D(Basis(), Vector3(0, -0.08, 0)), 0.78, 0.84, 0.16, 32)
	md.cur_color = podium_color
	md.add_cylinder(Transform3D(Basis(), Vector3(0, 0.005, 0)), 0.72, 0.72, 0.02, 32)
	md.cur_color = Color.WHITE
	for k in 24:
		var a := k * TAU / 24.0
		md.add_box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0.02, sin(a)) * 0.6), Vector3(0.06, 0.012, 0.04))
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mi.mesh = md.build_mesh(mat)
	_vp.add_child(mi)


func _make_sparkle() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color("fff3a0"))
	ramp.set_color(1, Color(1, 0.6, 0.9, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 1.0, 0)
	return p


## Põe (ou troca) o visual. sparkle = brilhinho + giro (para "olhar a mudança").
func set_appearance(a: CharacterAppearance, sparkle := false) -> void:
	if character == null:
		character = CharacterVisual.new()
		character.appearance = a
		_pivot.add_child(character)
	else:
		character.set_appearance(a)
	if sparkle:
		_spin = TAU
		_sparkle.restart()
		_sparkle.emitting = true
		AudioManager.play_ui("pickup", -8.0)


## Aproxima no rosto (chapéu, cabelo, óculos) ou mostra o corpo todo.
func focus(part: String) -> void:
	match part:
		"head":
			_target_dist = zoom_min
			_target_look_y = 1.35
		_:
			_target_dist = base_dist
			_target_look_y = 0.95


func play(action: String) -> void:
	if character:
		character.play(action)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_d = 0.0
	if event is InputEventScreenDrag and _touches.size() >= 2:
		_touches[event.index] = event.position
		var ps: Array = _touches.values()
		var d: float = (ps[0] as Vector2).distance_to(ps[1])
		if _pinch_d > 0.0:
			_target_dist = clampf(_target_dist - (d - _pinch_d) * 0.006, zoom_min, zoom_max)
		_pinch_d = d
		accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_drag_moved = 0.0
			else:
				if _drag and _drag_moved < 12.0:
					_on_tap()
				_drag = false
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_dist = clampf(_target_dist - 0.25, zoom_min, zoom_max)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_dist = clampf(_target_dist + 0.25, zoom_min, zoom_max)
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		_drag_moved += absf(mm.relative.x) + absf(mm.relative.y)
		_yaw += mm.relative.x * 0.012
		_yaw_vel = mm.relative.x * 0.012 / maxf(get_process_delta_time(), 0.001)
		_target_look_y = clampf(_target_look_y - mm.relative.y * 0.003, 0.6, 1.45)
		_idle_t = 0.0
		accept_event()


func _on_tap() -> void:
	_idle_t = 0.0
	_emote_t = 6.0
	if character:
		character.play(["wave", "celebrate", "clap", "hop_two", "look_around"].pick_random())
	AudioManager.play_ui("ui_click", -4.0)
	tapped.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_idle_t += delta
	if not _drag:
		# embalo do giro e, parado um tempo, volta a olhar para a frente devagar
		_yaw += _yaw_vel * delta
		_yaw_vel = lerpf(_yaw_vel, 0.0, 1.0 - exp(-3.5 * delta))
		if _idle_t > 3.0 and absf(_yaw_vel) < 0.2:
			_yaw = lerp_angle(_yaw, sin(Time.get_ticks_msec() * 0.0004) * 0.35, 1.0 - exp(-1.2 * delta))
	if _spin > 0.0:
		var step := minf(_spin, delta * 9.0)
		_spin -= step
		_yaw += step
	_pivot.rotation.y = _yaw
	_dist = lerpf(_dist, _target_dist, 1.0 - exp(-8.0 * delta))
	_look_y = lerpf(_look_y, _target_look_y, 1.0 - exp(-8.0 * delta))
	_place_camera()
	if auto_emotes and character:
		_emote_t -= delta
		if _emote_t <= 0.0:
			_emote_t = randf_range(6.0, 10.0)
			character.play(["wave", "look_around", "stretch", "celebrate", "scratch_head"].pick_random())


func _place_camera() -> void:
	if _cam == null:
		return
	var h := _look_y + 0.15 + (_dist - 2.0) * 0.05
	_cam.position = Vector3(0, h, _dist)
	_cam.look_at(Vector3(0, _look_y, 0), Vector3.UP)
