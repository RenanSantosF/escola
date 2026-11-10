extends Minigame
## Guerra de bolinhas de papel (45 s) no espaço de convivência.
## SEGURE o botão amarelo para mirar: aparece o arco da trajetória e o alvo
## trava no colega mais próximo à sua frente (gire com o joystick). SOLTE
## para arremessar. As bolinhas dos colegas mostram um círculo vermelho
## onde vão cair: corra ou pule para desviar. 3 vidas.

const AREA := Rect2(34, -22, 24, 18)
const TIME := 45.0
const SPEED := 11.0

var foes: Array[NPC] = []
var hits := 0
var lives := 3
var _shots: Array = []  # {node, pos, vel, from_player, alive, warn}
var _root: Node3D
var _arc: AimArc
var _aiming := false
var _aim_t := 0.0
var _aim_target: NPC = null
var _cd := 0.0
var _npc_t := 2.0
var _inv := 0.0
var _warn_mat: StandardMaterial3D
var _target_ring: MeshInstance3D


func begin() -> void:
	for n in students(4, Vector3(35.5, 0.05, -6.0)):
		foes.append(n)
	take_npcs(foes)
	_root = Node3D.new()
	world.add_child(_root)
	_arc = AimArc.new()
	_root.add_child(_arc)
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warn_mat.vertex_color_use_as_albedo = true
	_warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_ring = _ring_mesh(Color(1, 0.85, 0.2, 0.8), 0.6)
	_target_ring.visible = false
	_root.add_child(_target_ring)
	player.force_stand()
	player.global_position = Vector3(46, 0.05, -5.5)
	player.yaw = PI
	if player.camera_rig:
		player.camera_rig.yaw = 0.0
		player.camera_rig.snap_to_target()
	for i in foes.size():
		foes[i].teleport(Vector3(38 + i * 5.0, 0.05, -18), 0.0)
	time_left = TIME
	countdown(3.0)
	super.begin()
	hud.show_banner("Guerra de papel!", "SEGURE o botão amarelo para mirar e SOLTE para jogar")


func _ring_mesh(col: Color, r: float) -> MeshInstance3D:
	var md := MeshData.new()
	md.cur_color = col
	for k in 20:
		var a := k * TAU / 20.0
		md.add_box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * r), Vector3(0.05, 0.02, r * 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(_warn_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func play_label() -> String:
	return "Soltar!" if _aiming else "Segure p/ mirar"


func on_play() -> bool:
	if _cd <= 0.0 and _countdown <= 0.0:
		_aiming = true
		_aim_t = 0.0
	return true


func on_play_release() -> bool:
	if not _aiming:
		return true
	_aiming = false
	_arc.hide_arc()
	_target_ring.visible = false
	_cd = 0.45
	var vel := _aim_velocity()
	var start := _hand()
	player.visual.play("throw")
	get_tree().create_timer(0.3).timeout.connect(func(): _spawn_shot(start, vel, true))
	return true


func _hand() -> Vector3:
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	return player.global_position + Vector3(0, 1.5, 0) + fwd * 0.4


## Alvo travado: colega mais próximo num cone de 45° à frente.
func _pick_target() -> NPC:
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var best: NPC = null
	var bs := INF
	for f in foes:
		var to := f.global_position - player.global_position
		to.y = 0
		var ang := fwd.angle_to(to.normalized())
		if ang < deg_to_rad(45) and to.length() < 18.0:
			var s := ang * 5.0 + to.length() * 0.1
			if s < bs:
				bs = s
				best = f
	return best


func _aim_velocity() -> Vector3:
	var start := _hand()
	if _aim_target:
		return AimArc.solve(start, _aim_target.global_position + Vector3(0, 1.0, 0), SPEED)
	# sem alvo: distância cresce enquanto segura (5 a 16 m)
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var dist := lerpf(5.0, 16.0, clampf(_aim_t / 1.0, 0.0, 1.0))
	return AimArc.solve(start, player.global_position + fwd * dist, SPEED)


func _spawn_shot(start: Vector3, vel: Vector3, from_player: bool) -> void:
	if not running:
		return
	var md := MeshData.new()
	md.cur_color = Color("f4f1e8") if from_player else Color("ffe9a8")
	md.add_sphere(Transform3D(), 0.07, 8, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(mi)
	var warn: MeshInstance3D = null
	if not from_player:
		# aviso no chão onde a bolinha vai cair
		var land := start
		var p := start
		var v := vel
		for i in 120:
			p += v * 0.02
			v.y -= 9.8 * 0.02
			if p.y <= 0.05:
				break
		land = p
		warn = _ring_mesh(Color(1, 0.2, 0.2, 0.85), 0.55)
		_root.add_child(warn)
		warn.global_position = Vector3(land.x, 0.06, land.z)
	_shots.append({"node": mi, "pos": start, "vel": vel, "from_player": from_player, "alive": true, "warn": warn})
	AudioManager.play_3d("whoosh", start, -8.0)


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		return
	_cd = maxf(_cd - delta, 0.0)
	_inv = maxf(_inv - delta, 0.0)
	time_left -= delta
	hud.set_minigame_text("Guerra de papel  ·  Acertos: %d  ·  Vidas: %s  ·  %s" % [hits, "♥".repeat(maxi(lives, 0)), fmt_time(time_left)])
	if time_left <= 0.0:
		_finish()
		return
	# mira
	if _aiming:
		_aim_t += delta
		_aim_target = _pick_target()
		var land := _arc.show_arc(_hand(), _aim_velocity(), 0.05, Color("ffcf3f"))
		_target_ring.visible = _aim_target != null
		if _aim_target:
			_target_ring.global_position = _aim_target.global_position + Vector3(0, 0.06, 0)
		elif land != Vector3.ZERO:
			_target_ring.visible = false
	# colegas correm e arremessam
	_npc_t -= delta
	for f in foes:
		if not f.moving:
			f.go_to(Vector3(randf_range(AREA.position.x, AREA.end.x), 0.05, randf_range(AREA.position.y, AREA.end.y)), randf() < 0.5)
	if _npc_t <= 0.0:
		_npc_t = randf_range(1.3, 2.3)
		var f: NPC = foes.pick_random()
		f.stop()
		f.face(player.global_position)
		f.visual.play("throw")
		f.say(["Toma!", "Lá vai!", "Hahaha!"].pick_random(), 1.0)
		var start := f.global_position + Vector3(0, 1.5, 0)
		var lead := Vector3(player.velocity.x, 0, player.velocity.z) * 0.5
		var aim := player.global_position + Vector3(0, 0.9, 0) + lead + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		var v := AimArc.solve(start, aim, 8.5)
		get_tree().create_timer(0.45).timeout.connect(func(): _spawn_shot(start, v, false))
	# bolinhas em voo
	for s in _shots:
		if not s.alive:
			continue
		s.vel += Vector3(0, -9.8, 0) * delta
		s.pos += s.vel * delta
		s.node.global_position = s.pos
		if s.pos.y < 0.05:
			_kill_shot(s)
			continue
		if s.from_player:
			for f in foes:
				if (f.global_position + Vector3(0, 1.0, 0)).distance_to(s.pos) < 0.6:
					hits += 1
					_kill_shot(s)
					f.visual.play("hit")
					f.say(["Ai!", "Me pegou!", "Não valeu!"].pick_random(), 1.0)
					AudioManager.play_3d("bonk", f.global_position, -8.0)
					Effects.burst(s.pos, "sparkle")
					break
		elif _inv <= 0.0 and (player.global_position + Vector3(0, 1.0, 0)).distance_to(s.pos) < 0.5:
			_kill_shot(s)
			lives -= 1
			_inv = 1.0
			player.visual.play("hit")
			AudioManager.play_ui("bonk", -6.0)
			if lives <= 0:
				_finish()
				return
	_shots = _shots.filter(func(s): return s.alive)
	var p := player.global_position
	player.global_position.x = clampf(p.x, AREA.position.x - 2.0, AREA.end.x + 2.0)
	player.global_position.z = clampf(p.z, AREA.position.y - 2.0, AREA.end.y + 2.0)
	player._emit_context()


func _kill_shot(s: Dictionary) -> void:
	s.alive = false
	if is_instance_valid(s.node):
		s.node.queue_free()
	if s.warn and is_instance_valid(s.warn):
		s.warn.queue_free()


func _finish() -> void:
	if not running:
		return
	var won := 1 if hits >= 8 and lives > 0 else (0 if hits >= 4 else -1)
	end_game(won, "%d acertos" % hits, 5 + hits * 2, 10 + hits * 3, {"score": hits})


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
