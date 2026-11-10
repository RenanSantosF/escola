class_name GuideTrail
extends Node3D
## "GPS" para criança: uma trilha de setinhas brilhantes no chão que segue o
## caminho de verdade (desvia de paredes, sobe escadas) até o destino, e uma
## seta grande sobre a cabeça do jogador apontando para onde ir.
## Usa o destino da HUD: missão (azul) > ponto de encontro (vermelho) >
## objetivo do dia (amarelo).

const STEP := 1.4  # metros entre setinhas
const MAX_DOTS := 26
const REPATH := 0.5

var hud: HUD
var player: PlayerController
var nav: NavGraph
var _mm: MultiMeshInstance3D
var _arrow: MeshInstance3D
var _mat: StandardMaterial3D
var _arrow_mat: StandardMaterial3D
var _t := 0.0
var _pts: PackedVector3Array = []
var _col := Color.WHITE


func setup(h: HUD, p: PlayerController, n: NavGraph) -> void:
	hud = h
	player = p
	nav = n
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# setinha (chevron) deitada no chão
	var md := MeshData.new()
	md.cur_color = Color.WHITE
	var pts := [Vector3(-0.32, 0, -0.12), Vector3(0, 0, 0.22), Vector3(0.32, 0, -0.12), Vector3(0, 0, 0.04)]
	var i0 := md.add_vertex(pts[0], Vector3.UP)
	var i1 := md.add_vertex(pts[1], Vector3.UP)
	var i2 := md.add_vertex(pts[3], Vector3.UP)
	md.tri(i0, i1, i2)
	var j0 := md.add_vertex(pts[3], Vector3.UP)
	var j1 := md.add_vertex(pts[1], Vector3.UP)
	var j2 := md.add_vertex(pts[2], Vector3.UP)
	md.tri(j0, j1, j2)
	var mesh := md.build_mesh(_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MAX_DOTS
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)
	# seta sobre a cabeça
	_arrow_mat = StandardMaterial3D.new()
	_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arrow_mat.vertex_color_use_as_albedo = true
	_arrow_mat.no_depth_test = true
	_arrow_mat.render_priority = 6
	var am := MeshData.new()
	am.cur_color = Color.WHITE
	am.add_box(Transform3D(Basis(), Vector3(0, 0, -0.12)), Vector3(0.12, 0.06, 0.32))
	am.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.14)), 0.0, 0.2, 0.26, 10)
	_arrow = MeshInstance3D.new()
	_arrow.mesh = am.build_mesh(_arrow_mat)
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
	_arrow.visible = false


func _target() -> Variant:
	if hud == null:
		return null
	if hud._mission_point != null:
		_col = Color("5ec8ff")
		return hud._mission_point
	if hud._game_point != null:
		_col = Color("ff4d6d")
		return hud._game_point
	if hud._objective_point != null:
		_col = Color("ffcf3f")
		return hud._objective_point
	return null


func _process(delta: float) -> void:
	if player == null:
		return
	var tv: Variant = _target()
	var hide: bool = tv == null or player.minigame != null or player.mode == PlayerController.Mode.SITTING or not hud.controls.visible
	if hide:
		_mm.multimesh.visible_instance_count = 0
		_arrow.visible = false
		return
	var target: Vector3 = (tv as Vector3) - Vector3(0, 1.0, 0)
	var dist := player.global_position.distance_to(target)
	if dist < 2.2:
		_mm.multimesh.visible_instance_count = 0
		_arrow.visible = false
		return
	_t -= delta
	if _t <= 0.0:
		_t = REPATH
		_pts = nav.path(player.global_position, target) if nav else PackedVector3Array([player.global_position, target])
		if _pts.is_empty():
			_pts = PackedVector3Array([player.global_position, target])
		_pts.insert(0, player.global_position)
	_place_dots()
	# seta sobre a cabeça aponta para o próximo trecho do caminho
	var nxt := target
	for p in _pts:
		if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > 2.0:
			nxt = p
			break
	var dir := Vector3(nxt.x - player.global_position.x, 0, nxt.z - player.global_position.z)
	if dir.length() > 0.1:
		_arrow.visible = true
		_arrow.global_position = player.global_position + Vector3(0, 2.3 + sin(Time.get_ticks_msec() * 0.005) * 0.06, 0)
		_arrow.global_basis = Basis.looking_at(-dir.normalized(), Vector3.UP).scaled(Vector3.ONE * 0.75)
		_arrow_mat.albedo_color = _col


func _place_dots() -> void:
	var mm := _mm.multimesh
	var n := 0
	var phase := fmod(Time.get_ticks_msec() * 0.0012, 1.0) * STEP  # setinhas "andando"
	var carry := STEP - phase
	for i in range(_pts.size() - 1):
		var a := _pts[i]
		var b := _pts[i + 1]
		var seg := b - a
		var l := Vector2(seg.x, seg.z).length()
		if l < 0.01:
			continue
		var dir := seg / l
		var d := carry
		while d < l and n < MAX_DOTS:
			var p := a + dir * d
			if i == 0 and d < 1.0:
				d += STEP
				continue
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			var xf := Transform3D(Basis.looking_at(-flat, Vector3.UP), p + Vector3(0, 0.06, 0))
			mm.set_instance_transform(n, xf)
			var fade := 1.0 - float(n) / MAX_DOTS
			mm.set_instance_color(n, Color(_col, 0.35 + 0.6 * fade))
			n += 1
			d += STEP
		carry = d - l
		if n >= MAX_DOTS:
			break
	mm.visible_instance_count = n
