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
	sky_mat.sky_top_color = Color("1f6fd8")
	sky_mat.sky_horizon_color = Color("9fd0f5")
	sky_mat.ground_horizon_color = Color("b9dcef")
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
	env.ambient_light_color = Color("c4d9ee")
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color("bcdcf7")
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.16
	# brilho suave nas partes muito claras (céu, água, metal)
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("fbfcff")
	sun.light_energy = 1.4
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
		_chunk_nodes[key].position.y = builder.chunk_offsets.get(key, 0.0)
		n += 1
		if n % 12 == 0:
			await get_tree().process_frame
	_build_terrain_extras(geo)
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

	var life := AmbientLife.new()
	life.name = "AmbientLife"
	add_child(life)
	life.build()

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
		# a posição do rótulo já é a do mundo; o chunk de um andar de cima já está deslocado
		if parent_node != _labels_root:
			lb.position.y -= parent_node.position.y
		parent_node.add_child(lb)
		_labels.append([lb, float(l.vis)])

	_dynamic = Node3D.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)
	_spawn_interactables()
	progress.call(0.97, "Tocando o sinal...")
	await get_tree().process_frame
	_apply_quality()
	_limit_labels(self)
	_set_interiors_visible("A", false)
	_set_interiors_visible("A2", false)
	_set_interiors_visible("C1", false)
	_set_interiors_visible("C2", false)
	_set_interiors_visible("B", false)
	_set_interiors_visible("C", false)
	print("Escola construída em %d ms (%d chunks, %d árvores, %d assentos)" % [Time.get_ticks_msec() - t0, builder.chunks.size(), builder.trees.size(), Props.seats.size()])
	built.emit()


## Relevo com colisão (campo de alturas) e lagos.
func _build_terrain_extras(parent: Node3D) -> void:
	for hf in builder.heightfields:
		var body := StaticBody3D.new()
		body.name = "Relevo"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := HeightMapShape3D.new()
		shape.map_width = hf.w
		shape.map_depth = hf.d
		shape.map_data = hf.data
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
		body.global_position = hf.center
	for lk in builder.lakes:
		var mi := MeshInstance3D.new()
		mi.name = "Lago"
		var disc := CylinderMesh.new()
		disc.top_radius = lk.radius
		disc.bottom_radius = lk.radius
		disc.height = 0.02
		disc.radial_segments = 32
		disc.rings = 1
		mi.mesh = disc
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.55, 0.85, 0.82)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic = 0.2
		m.rim_enabled = true
		m.rim = 0.4
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = lk.center


var rides: Array = []


## Atividades das salas que eram só cenário (XP uma vez por dia em cada uma).
const ROOM_ACTIVITIES := [
	["Enfermaria", "Medir a altura", "stretch", 2.5, 5, ["Você mede %d cm! Está crescendo!"], Vector2i(118, 152), Vector2(-1.5, 0)],
	["Enfermaria", "Pegar um curativo", "interact", 2.5, 4, ["A enfermeira colocou um curativo de estrelinha!", "Curativo de dinossauro: agora sim!"], Vector2i.ZERO, Vector2(1.5, 0)],
	["Banheiro Feminino", "Lavar as mãos", "interact", 2.0, 3, ["Mãos limpinhas! Lavar as mãos evita doenças."], Vector2i.ZERO, Vector2(-2.6, -2.0)],
	["Banheiro Masculino", "Lavar as mãos", "interact", 2.0, 3, ["Mãos limpinhas! Lavar as mãos evita doenças."], Vector2i.ZERO, Vector2(-2.6, -2.0)],
	["Brinquedoteca", "Montar uma torre de blocos", "interact", 3.0, 6, ["Torre de %d blocos! Não caiu!"], Vector2i(8, 25), Vector2(0, 0)],
	["Sala de Dança", "Dançar", "celebrate", 5.0, 6, ["Que passos incríveis!", "A turma bateu palmas para a sua dança!"], Vector2i.ZERO, Vector2(0, 0)],
	["Ateliê Maker", "Montar um robozinho", "interact", 4.0, 8, ["Seu robozinho anda e pisca as luzes!", "Funcionou! O robô acenou para você."], Vector2i.ZERO, Vector2(0, 0)],
	["Sala de Robótica", "Programar o robô", "interact", 4.0, 8, ["O robô seguiu a linha até o fim!", "Programa certo: o robô desviou do obstáculo!"], Vector2i.ZERO, Vector2(0, 0)],
	["Secretaria", "Ler o mural de avisos", "look_around", 2.5, 3, ["Aviso: amanhã tem aula de Ciências no laboratório!", "Aviso: beba água no recreio!", "Aviso: as férias estão chegando!"], Vector2i.ZERO, Vector2(0, 0)],
	["Grêmio Estudantil", "Votar na ideia do recreio", "raise_hand", 2.5, 4, ["Voto contado: mais bolas para o futebol!", "Voto contado: gincana na sexta!"], Vector2i.ZERO, Vector2(0, 0)],
	["Mirante", "Olhar pelo telescópio", "look_around", 3.0, 4, ["Dá para ver o Morro e a montanha-russa!", "Lá longe, a turma jogando bola na quadra!"], Vector2i.ZERO, Vector2(0, -3.0)],
	["Depósito de Ed. Física", "Arrumar os materiais", "pickup", 3.0, 4, ["Cones e bolas no lugar! O professor agradece."], Vector2i.ZERO, Vector2(0, 0)],
]


func _zone_named(n: String) -> Dictionary:
	for z in builder.zones:
		if str(z.name) == n:
			return z
	return {}


func _spawn_room_activities() -> void:
	for a in ROOM_ACTIVITIES:
		var z := _zone_named(a[0])
		if z.is_empty():
			continue
		var r: Rect2 = z.rect
		var fy := (float(z.y0) + 0.5) if z.has("y0") else 0.0
		var off: Vector2 = a[7]
		var c := r.get_center() + off
		var ra := RoomActivity.new()
		ra.key = "%s_%s" % [a[0], a[1]]
		ra.prompt = a[1]
		ra.anim = a[2]
		ra.secs = a[3]
		ra.xp = a[4]
		ra.results = a[5]
		ra.number_range = a[6]
		ra.position = Vector3(c.x, fy + 0.05, c.y)
		add_child(ra)
	for gt in builder.game_tables:
		var tg := TableGame.new()
		tg.kind = gt.kind
		var zt := _zone_named(gt.room)
		tg.position = gt.pos + Vector3(0, ((float(zt.y0) + 0.5) if zt.has("y0") else 0.0) + 0.05, 0)
		add_child(tg)
	for cm in builder.cinemas:
		var cs := CinemaScreen.new()
		cs.room_rect = cm.rect
		cs.room_name = cm.room
		var z2 := _zone_named(cm.room)
		cs.floor_y = (float(z2.y0) + 0.5) if z2.has("y0") else 0.0
		var lbl := Label3D.new()
		lbl.font = UITheme.bold_font()
		lbl.font_size = 52
		lbl.pixel_size = 0.006
		lbl.modulate = Color("2c3e50")
		lbl.outline_size = 0
		lbl.width = 900.0
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.visibility_range_end = 24.0
		cs.label = lbl
		cs.add_child(lbl)
		add_child(cs)
		lbl.global_position = cm.pos + Vector3(0, cs.floor_y, 0)
		lbl.rotation.y = cm.rot


func _spawn_interactables() -> void:
	for sl in builder.slides:
		var ss := SlideSpot.new()
		ss.points = sl.points
		ss.position = sl.start
		add_child(ss)
	for r in builder.rides:
		var rt := RideTrack.new()
		rt.name = "Atracao_" + str(r.kind)
		rt.kind = r.kind
		rt.prompt = r.prompt
		rt.points = r.points
		rt.laps = int(r.get("laps", 1))
		rt.lift = r.get("lift", Vector2(-1, -1))
		rt.lift_top = r.get("lift_top", Vector3.ZERO)
		rt.position = r.base
		add_child(rt)
		rides.append(rt)
	_spawn_room_activities()
	for tp in builder.trampolines:
		var tr := Trampoline.new()
		tr.position = tp
		add_child(tr)
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
	for fw in builder.fountains_water:
		var wf := WishFountain.new()
		wf.radius = fw.r
		wf.top = fw.top
		wf.position = fw.pos
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
		if z.indoor and z.rect.has_point(p) and _y_ok(z, pos.y):
			var rid: String = z.roof
			if rid == "" or rid == "C":
				return false
			if _hidden_roofs.get(rid, false):
				return false
			# sala pertinho da câmera também mostra quem está dentro
			var cam := get_viewport().get_camera_3d()
			if cam and cam.global_position.distance_to(pos) < NEAR_ROOM + 4.0 and absf(cam.global_position.y - pos.y) < 3.5:
				return false
			return true
	return false


func _y_ok(z: Dictionary, y: float) -> bool:
	return not z.has("y0") or (y >= z.y0 and y < z.y1)


func zone_at(pos: Vector3) -> Dictionary:
	var p := Vector2(pos.x, pos.z)
	for z in builder.zones:
		if z.rect.has_point(p) and _y_ok(z, pos.y):
			return z
	return {}


func surface_at(pos: Vector3) -> String:
	return builder.surface_at(pos.x, pos.z) if builder else "hard"


# ------------------------------------------------------------ zonas/telhados

func _process(delta: float) -> void:
	if _player == null or builder == null:
		return
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.3
		_update_near_rooms()
	_zone_timer -= delta
	if _zone_timer > 0.0:
		return
	_zone_timer = 0.2
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var zone: Dictionary = {}
	for z in builder.zones:
		if z.rect.has_point(p) and _y_ok(z, _player.global_position.y):
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
	# Dentro do prédio o telhado fica invisível para a câmera, mas CONTINUA
	# fazendo sombra: a sala fica iluminada de verdade pelas janelas e portas
	# (manchas de sol no chão), sem o sol "lavar" o ambiente inteiro.
	for c in node.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.visible = true
	_roof_hidden_count += 1 if hidden else -1
	_update_indoor_light()


var _roof_hidden_count := 0
var _light_tween: Tween


## Dentro: luz ambiente mais forte e morna (lâmpadas); fora: luz do céu.
func _update_indoor_light() -> void:
	if env == null:
		return
	var inside := _roof_hidden_count > 0
	if _light_tween:
		_light_tween.kill()
	_light_tween = create_tween().set_parallel(true)
	# diferença suave: dentro só um pouco mais quente e claro (sem "pulo" de luz)
	_light_tween.tween_property(env, "ambient_light_energy", 1.0 if inside else 0.8, 1.2)
	_light_tween.tween_property(env, "ambient_light_color", Color("f2ead9") if inside else Color("c4d9ee"), 1.2)
	_light_tween.tween_property(env, "ambient_light_sky_contribution", 0.4 if inside else 0.55, 1.2)


var _inside_ids := {}
var _near_rooms := {}
var _near_t := 0.0
const NEAR_ROOM := 12.0


func _set_interiors_visible(id: String, vis: bool) -> void:
	_inside_ids[id] = vis
	for cname in builder.interior_chunks.get(id, []):
		var node: Node3D = _chunk_nodes.get(cname)
		if node:
			node.visible = vis or _near_rooms.has(cname)
			# colisões continuam ativas mesmo invisíveis


## Salas pertinho da câmera (mesmo de fora, pela porta/janela) aparecem.
func _update_near_rooms() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var near := {}
	for cname in builder.interior_rects.keys():
		var r: Rect2 = builder.interior_rects[cname]
		var fy: float = builder.chunk_offsets.get(cname, 0.0)
		if absf(cp.y - (fy + 1.6)) > 3.2:
			continue
		var q := Vector2(clampf(cp.x, r.position.x, r.end.x), clampf(cp.z, r.position.y, r.end.y))
		if q.distance_to(Vector2(cp.x, cp.z)) < NEAR_ROOM:
			near[cname] = true
	if near.hash() == _near_rooms.hash():
		return
	_near_rooms = near
	for id in builder.interior_chunks.keys():
		var inside: bool = _inside_ids.get(id, false)
		for cname in builder.interior_chunks[id]:
			var node: Node3D = _chunk_nodes.get(cname)
			if node:
				node.visible = inside or _near_rooms.has(cname)


# ------------------------------------------------------------ qualidade

func _on_setting_changed(key: String) -> void:
	if key == "quality":
		_apply_quality()


## Resolução do 3D: tablets e celulares de tela enorme desenhavam milhões de
## pixels (pesado e quente). Limita o número de linhas desenhadas; a interface
## (botões, textos) continua nítida na resolução da tela.
func _scale_for(base: float, max_lines: float) -> float:
	var h := float(DisplayServer.window_get_size().y)
	if h <= 0.0:
		return base
	return clampf(minf(base, max_lines / h), 0.4, 1.0)


func _apply_quality() -> void:
	var q := Settings.quality()
	var vp := get_viewport()
	match q:
		Settings.Quality.LOW:
			sun.shadow_enabled = false
			env.fog_enabled = false
			env.adjustment_enabled = false
			env.glow_enabled = false
			vp.scaling_3d_scale = _scale_for(Settings.render_scale_low, 600.0)
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
			vp.scaling_3d_scale = _scale_for(0.9, 800.0)
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
			vp.scaling_3d_scale = _scale_for(1.0, 1100.0)
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			_set_far(260.0)
	# Árvores: sem sombras na qualidade baixa
	if has_node("Trees"):
		for c in get_node("Trees").get_children():
			if not c is GeometryInstance3D:
				continue
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q != Settings.Quality.LOW else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Qualidade baixa: pedaços pequenos do cenário (bancos, enfeites, placas)
	# que estavam "sempre visíveis" somem de longe (menos desenhos por quadro).
	_limit_small_chunks(q == Settings.Quality.LOW)
	# bichinhos e partículas (bebedouros) só fora da qualidade baixa
	if has_node("AmbientLife"):
		(get_node("AmbientLife") as Node3D).visible = q != Settings.Quality.LOW
	if has_node("Seats"):
		for c in get_node("Seats").find_children("*", "GPUParticles3D", true, false):
			(c as GPUParticles3D).visible = q != Settings.Quality.LOW
	# Distância de exibição (rótulos, áreas externas, árvores)
	var mult := 0.6 if q == Settings.Quality.LOW else (0.85 if q == Settings.Quality.MEDIUM else 1.0)
	for e in _labels:
		(e[0] as Label3D).visibility_range_end = e[1] * mult
	for e in _ranged:
		(e[0] as GeometryInstance3D).visibility_range_end = e[1] * mult


## Placas e textos 3D: cada um custa uma chamada de desenho; sem alcance
## definido, somem a partir de 28 m (de longe nem dá para ler).
func _limit_labels(n: Node) -> void:
	for c in n.get_children():
		if c is Label3D:
			var l := c as Label3D
			if l.visibility_range_end <= 0.0:
				l.visibility_range_end = 28.0
				l.visibility_range_end_margin = 2.0
			l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_limit_labels(c)


var _small_limited := {}


func _limit_small_chunks(on: bool) -> void:
	for cname in _chunk_nodes.keys():
		var node: Node3D = _chunk_nodes[cname]
		if node == null:
			continue
		for c in node.get_children():
			if not c is GeometryInstance3D:
				continue
			var gi := c as GeometryInstance3D
			if on:
				if gi.visibility_range_end > 0.0 or _small_limited.has(gi):
					continue
				var size := gi.get_aabb().size
				if maxf(size.x, size.z) < 26.0 and size.y < 12.0:
					_small_limited[gi] = true
					gi.visibility_range_end = 55.0
					gi.visibility_range_end_margin = 4.0
			elif _small_limited.has(gi):
				gi.visibility_range_end = 0.0
		if not on:
			continue
	if not on:
		_small_limited.clear()


func _set_far(far: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.far = far
