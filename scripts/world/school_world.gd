class_name SchoolWorld
extends Node3D
## Raiz do mundo: ambiente (céu, sol, névoa), construção procedural da
## escola, objetos interativos, zonas (nome do local, telhados que somem
## ao entrar nos prédios) e aplicação das configurações gráficas.

signal built

var builder: SchoolBuilder
var sun: DirectionalLight3D
var env: Environment
var player_indoor := false
var current_zone: Dictionary = {}

var _chunk_nodes := {}
var _hidden_roofs := {}
var _zone_timer := 0.0
var _player: Node3D
var _labels_root: Node3D
var _dynamic: Node3D
var seats: Array[Seat] = []
var _labels: Array = []  # [Label3D, alcance base]
var _ranged: Array = []  # [GeometryInstance3D, alcance base]


func _ready() -> void:
	GameManager.world = self
	_setup_environment()
	Settings.changed.connect(_on_setting_changed)


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d8fe0")
	sky_mat.sky_horizon_color = Color("bfe0f7")
	sky_mat.ground_horizon_color = Color("cfe3c4")
	sky_mat.ground_bottom_color = Color("7aa36b")
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("e9dfcd")
	env.ambient_light_sky_contribution = 0.35
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color("cfe4f5")
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_fade_start = 0.85
	sun.light_angular_distance = 0.6
	add_child(sun)


## Constrói a escola (corrotina). progress(f, texto) é chamado entre etapas.
func build(progress: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	builder = SchoolBuilder.new()
	var step := func(f: float, msg: String) -> void:
		progress.call(f, msg)
		await get_tree().process_frame
	await builder.build_all(step)
	progress.call(0.8, "Arrumando as carteiras...")
	await get_tree().process_frame

	var geo := Node3D.new()
	geo.name = "Geometry"
	add_child(geo)
	var n := 0
	for key in builder.chunks.keys():
		var wb: WorldBatcher = builder.chunks[key]
		_chunk_nodes[key] = wb.build(geo)
		n += 1
		if n % 12 == 0:
			await get_tree().process_frame
	progress.call(0.9, "Plantando árvores...")
	await get_tree().process_frame
	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)
	TreeFactory.build(trees, builder.trees, true)
	for c in trees.get_children():
		_ranged.append([c, (c as GeometryInstance3D).visibility_range_end])
	for key in _chunk_nodes.keys():
		for c in _chunk_nodes[key].get_children():
			if c is GeometryInstance3D and (c as GeometryInstance3D).visibility_range_end > 0.0:
				_ranged.append([c, (c as GeometryInstance3D).visibility_range_end])

	_labels_root = Node3D.new()
	_labels_root.name = "Labels"
	add_child(_labels_root)
	for l in builder.labels:
		var lb := Label3D.new()
		lb.text = l.text
		lb.font = UITheme.bold_font()
		lb.font_size = l.size
		lb.pixel_size = l.pixel
		lb.modulate = l.color
		lb.outline_modulate = l.outline
		lb.outline_size = 10 if l.outline.a > 0.0 else 0
		lb.shaded = false
		lb.double_sided = false
		lb.alpha_cut = Label3D.ALPHA_CUT_DISABLED
		lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		lb.visibility_range_end = l.vis
		lb.position = l.pos
		lb.rotation.y = l.rot
		lb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if l.get("width", 0.0) > 0.0:
			lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lb.width = l.width
		var parent_node: Node3D = _chunk_nodes.get(l.get("parent", ""), _labels_root)
		parent_node.add_child(lb)
		_labels.append([lb, float(l.vis)])

	_dynamic = Node3D.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)
	_spawn_interactables()
	progress.call(0.97, "Tocando o sinal...")
	await get_tree().process_frame
	_apply_quality()
	_set_interiors_visible("A", false)
	_set_interiors_visible("B", false)
	_set_interiors_visible("C", false)
	print("Escola construída em %d ms (%d chunks, %d árvores, %d assentos)" % [Time.get_ticks_msec() - t0, builder.chunks.size(), builder.trees.size(), Props.seats.size()])
	built.emit()


func _spawn_interactables() -> void:
	var seats_root := Node3D.new()
	seats_root.name = "Seats"
	add_child(seats_root)
	for s in Props.seats:
		var seat := Seat.new()
		seat.prompt = s.label
		seat.position = s.pos
		seat.rotation.y = s.yaw
		seat.seat_top = s.seat_top
		seat.room = s.get("room", "")
		seat.swing = s.label == "Balançar"
		seat.set_process(seat.swing)
		if seat.room.begins_with("Sala") or seat.room.begins_with("Laborat"):
			seat.approach = -0.5
		seats_root.add_child(seat)
		seats.append(seat)
	for f in Props.fountains:
		var wf := WaterFountain.new()
		wf.position = f.pos
		wf.rotation.y = f.yaw
		wf.spout = f.spout
		seats_root.add_child(wf)
	for b in builder.balls:
		var ball := KickBall.create(b.kind)
		ball.position = b.pos
		_dynamic.add_child(ball)
	for p in builder.pickups:
		var item := PickupItem.create_paper_ball()
		item.position = p.pos
		_dynamic.add_child(item)
	# algumas bolinhas de papel no pátio
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for i in 8:
		var item := PickupItem.create_paper_ball()
		item.position = Vector3(r.randf_range(-40, 40), 0.2, r.randf_range(-20, 0))
		_dynamic.add_child(item)


func spawn_point() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, builder.spawn_yaw), builder.spawn)


func set_player(p: Node3D) -> void:
	_player = p


func get_map_data() -> Dictionary:
	return {"zones": builder.zones, "shapes": builder.map_shapes, "lot": SchoolBuilder.LOT}


## true se a posição está dentro de um prédio cujo interior está oculto
## (jogador do lado de fora) — usado para esconder NPCs lá dentro.
func interior_hidden_at(pos: Vector3) -> bool:
	if builder == null:
		return false
	var p := Vector2(pos.x, pos.z)
	for z in builder.zones:
		if z.indoor and z.rect.has_point(p):
			var rid: String = z.roof
			if rid == "" or rid == "C":
				return false
			return not _hidden_roofs.get(rid, false)
	return false


func zone_at(pos: Vector3) -> Dictionary:
	var p := Vector2(pos.x, pos.z)
	for z in builder.zones:
		if z.rect.has_point(p):
			return z
	return {}


func surface_at(pos: Vector3) -> String:
	return builder.surface_at(pos.x, pos.z) if builder else "hard"


# ------------------------------------------------------------ zonas/telhados

func _process(delta: float) -> void:
	if _player == null or builder == null:
		return
	_zone_timer -= delta
	if _zone_timer > 0.0:
		return
	_zone_timer = 0.2
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var zone: Dictionary = {}
	for z in builder.zones:
		if z.rect.has_point(p):
			zone = z
			break
	if zone.is_empty():
		zone = {"name": "Escola", "indoor": false, "roof": ""}
	if zone.get("name") != current_zone.get("name"):
		_enter_zone(zone)


func _enter_zone(zone: Dictionary) -> void:
	var old_roof: String = current_zone.get("roof", "")
	var new_roof: String = zone.get("roof", "")
	current_zone = zone
	player_indoor = zone.get("indoor", false)
	if old_roof != new_roof:
		if old_roof != "":
			_set_roof_hidden(old_roof, false)
		if new_roof != "":
			_set_roof_hidden(new_roof, true)
	GameManager.set_zone(zone.name, player_indoor)
	refresh_ambient()


## Som ambiente conforme o local e a fase do dia.
var recess_active := false


func refresh_ambient() -> void:
	var zn: String = current_zone.get("name", "")
	if zn in ["Cantina", "Fila da Cantina", "Pátio Coberto"] and recess_active:
		AudioManager.set_ambient("ambient_cantina", -7.0)
	elif player_indoor:
		AudioManager.set_ambient("ambient_sala" if zn.begins_with("Sala") else "ambient_indoor", -9.0)
	elif recess_active:
		AudioManager.set_ambient("ambient_recreio", -8.0)
	else:
		AudioManager.set_ambient("ambient_outdoor", -6.0)


func _set_roof_hidden(id: String, hidden: bool) -> void:
	_hidden_roofs[id] = hidden
	for cname in builder.roof_chunks.get(id, []):
		var node: Node3D = _chunk_nodes.get(cname)
		if node:
			_fade_roof(node, hidden)
	_set_interiors_visible(id, hidden)


func _fade_roof(node: Node3D, hidden: bool) -> void:
	# Mantém a sombra do telhado (interior fica "na sombra" de forma natural
	# só quando o jogador está fora); dentro, some para a câmera ver o ambiente.
	for c in node.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.visible = not hidden


func _set_interiors_visible(id: String, vis: bool) -> void:
	for cname in builder.interior_chunks.get(id, []):
		var node: Node3D = _chunk_nodes.get(cname)
		if node:
			node.visible = vis
			# colisões continuam ativas mesmo invisíveis


# ------------------------------------------------------------ qualidade

func _on_setting_changed(key: String) -> void:
	if key == "quality":
		_apply_quality()


func _apply_quality() -> void:
	var q := Settings.quality()
	var vp := get_viewport()
	match q:
		Settings.Quality.LOW:
			sun.shadow_enabled = false
			env.fog_enabled = false
			env.adjustment_enabled = false
			env.glow_enabled = false
			vp.scaling_3d_scale = 0.75
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			_set_far(110.0)
		Settings.Quality.MEDIUM:
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 30.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			env.fog_enabled = true
			env.adjustment_enabled = true
			env.glow_enabled = false
			vp.scaling_3d_scale = 0.9
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			_set_far(170.0)
		Settings.Quality.HIGH:
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 55.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			env.fog_enabled = true
			env.adjustment_enabled = true
			env.glow_enabled = true
			env.glow_intensity = 0.4
			env.glow_bloom = 0.05
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			_set_far(260.0)
	# Árvores: sem sombras na qualidade baixa
	if has_node("Trees"):
		for c in get_node("Trees").get_children():
			if not c is GeometryInstance3D:
				continue
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q != Settings.Quality.LOW else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Distância de exibição (rótulos, áreas externas, árvores)
	var mult := 0.6 if q == Settings.Quality.LOW else (0.85 if q == Settings.Quality.MEDIUM else 1.0)
	for e in _labels:
		(e[0] as Label3D).visibility_range_end = e[1] * mult
	for e in _ranged:
		(e[0] as GeometryInstance3D).visibility_range_end = e[1] * mult


func _set_far(far: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.far = far
