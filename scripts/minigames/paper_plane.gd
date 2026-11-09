extends Minigame
## Aviãozinho de papel:
##  1) Dobrar: 3 dobras com toque no tempo certo (define a qualidade).
##  2) Mirar: joystick ajusta direção/ângulo; força oscilante (toque duplo).
##  3) Voo: física de planador (sustentação, arrasto, vento, oscilação).
## Pontos: distância + argolas atravessadas + pouso no alvo. 3 lançamentos.

const LAUNCH := Vector3(12, 1.45, 1.5)
const RINGS := [Vector3(12, 1.6, -6), Vector3(13, 1.3, -12.5)]
const TARGET := Vector3(12, 0.02, -16.5)
const THROWS := 3

enum Step { FOLD, AIM, FLY, DONE }

var step: int = Step.FOLD
var folds := 0
var fold_quality := 0.0
var _fold_t := 0.0
var yaw := PI
var pitch := 0.12
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var throws_left := THROWS
var best_score := 0
var total_score := 0
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var _rings_passed := {}
var _wind := Vector3.ZERO
var _fly_t := 0.0
var _plane: Node3D
var _deco: Node3D
var _space: PhysicsDirectSpaceState3D
var _land_wait := 0.0


func begin() -> void:
	_space = world.get_world_3d().direct_space_state
	_deco = Node3D.new()
	world.add_child(_deco)
	_build_rings()
	_plane = _make_plane()
	_deco.add_child(_plane)
	player.force_stand()
	player.movement_locked = true
	player.global_position = Vector3(LAUNCH.x, 0.05, LAUNCH.z + 0.4)
	player.yaw = PI
	_start_fold()
	super.begin()


func _build_rings() -> void:
	var md := MeshData.new()
	for r in RINGS:
		md.cur_color = Color("ff8a3d")
		for k in 16:
			var a := k * TAU / 16.0
			var p: Vector3 = r + Vector3(cos(a) * 0.9, sin(a) * 0.9, 0)
			md.add_box(Transform3D(Basis(Vector3.BACK, a), p), Vector3(0.1, 0.38, 0.06))
		md.cur_color = Color("8a5a32")
		md.add_box(Transform3D(Basis(), Vector3(r.x, (r.y - 0.9) * 0.5, r.z)), Vector3(0.06, r.y - 0.9, 0.06))
	for k in 3:
		md.cur_color = [Color("e53935"), Color("ffffff"), Color("e53935")][k]
		md.add_cylinder(Transform3D(Basis(), TARGET + Vector3(0, 0.003 * (k + 1), 0)), 1.6 - k * 0.55, 1.6 - k * 0.55, 0.01, 24)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_deco.add_child(mi)


func _make_plane() -> Node3D:
	var md := MeshData.new()
	md.cur_color = Color("fdfdf8")
	# duas asas + quilha (triângulos)
	var tip := Vector3(0, 0, 0.22)
	var pts := [[tip, Vector3(-0.13, 0.02, -0.12), Vector3(0, 0, -0.12)], [tip, Vector3(0, 0, -0.12), Vector3(0.13, 0.02, -0.12)],
		[tip, Vector3(0, -0.05, -0.12), Vector3(0, 0, -0.12)]]
	for t in pts:
		var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
		for side: float in [1.0, -1.0]:
			var i0 := md.add_vertex(t[0], n * side)
			var i1 := md.add_vertex(t[1], n * side)
			var i2 := md.add_vertex(t[2], n * side)
			md.tri(i0, i1, i2)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	var n3 := Node3D.new()
	n3.add_child(mi)
	return n3


func _start_fold() -> void:
	step = Step.FOLD
	folds = 0
	fold_quality = 0.0
	_fold_t = 0.0
	_plane.visible = false
	hud.show_banner("Dobre o avião!", "Toque quando a barra estiver no MEIO")
	player.camera_rig.set_override(Transform3D(Basis(), player.global_position + Vector3(0.9, 1.6, -1.4)).looking_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP))
	player.visual.play("interact")
	_update_hud()


func _update_hud() -> void:
	var s := ""
	match step:
		Step.FOLD:
			s = "Dobra %d de 3" % (folds + 1)
		Step.AIM:
			s = "Mire (joystick) e lance  ·  Avião %d%%" % int(fold_quality * 100)
		Step.FLY:
			s = "Voando... %.1f m" % _distance()
		_:
			s = ""
	hud.set_minigame_text("Aviãozinho  ·  Lançamento %d/%d  ·  Recorde %d  ·  %s" % [THROWS - throws_left + 1, THROWS, best_score, s])


func play_label() -> String:
	match step:
		Step.FOLD:
			return "Dobrar!"
		Step.AIM:
			return "Lançar!" if _charging else "Força"
	return "Aguarde"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_jump() -> bool:
	return true


func on_play() -> bool:
	match step:
		Step.FOLD:
			# barra oscila 0..1; meio (0.5) é perfeito
			var v := 0.5 + 0.5 * sin(_fold_t * 3.4)
			var q := 1.0 - absf(v - 0.5) * 2.0
			fold_quality += q / 3.0
			folds += 1
			AudioManager.play_ui("pickup" if q > 0.7 else "ui_click", -4.0)
			GameManager.show_toast(["Dobra perfeita!", "Boa dobra!", "Dobra torta..."][0 if q > 0.8 else (1 if q > 0.45 else 2)])
			if folds >= 3:
				_start_aim()
			_update_hud()
		Step.AIM:
			if not _charging:
				_charging = true
				_power = 0.0
			else:
				_launch()
	return true


func _start_aim() -> void:
	step = Step.AIM
	hud.set_meter(-1.0)
	yaw = PI
	pitch = 0.12
	_plane.visible = true
	_charging = false
	player.visual.play("look_around")
	_wind = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.3, 0.3))
	if absf(_wind.x) > 0.3:
		GameManager.show_toast("Vento para a %s!" % ("direita" if _wind.x < 0 else "esquerda"))
	_update_hud()


func _launch() -> void:
	_charging = false
	hud.set_meter(-1.0)
	step = Step.FLY
	player.visual.play("throw")
	var speed := lerpf(6.0, 13.0, _power)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	pos = LAUNCH
	vel = dir * speed
	_rings_passed.clear()
	_fly_t = 0.0
	_land_wait = 0.0
	AudioManager.play_3d("whoosh", LAUNCH, -2.0)


func _distance() -> float:
	return Vector2(pos.x - LAUNCH.x, pos.z - LAUNCH.z).length()


func tick(delta: float) -> void:
	if not running:
		return
	match step:
		Step.FOLD:
			_fold_t += delta
			hud.set_meter(0.5 + 0.5 * sin(_fold_t * 3.4))
		Step.AIM:
			var mv := player.read_move_raw()
			yaw -= mv.x * delta * 0.8
			pitch = clampf(pitch - mv.y * delta * 0.6, -0.2, 0.7)
			if _charging:
				_power += _power_dir * delta * 0.8
				if _power >= 1.0 or _power <= 0.0:
					_power_dir *= -1.0
					_power = clampf(_power, 0.0, 1.0)
				hud.set_meter(_power)
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			_plane.global_position = LAUNCH
			_plane.look_at(LAUNCH - dir, Vector3.UP)
			player.yaw = yaw
			var cam := LAUNCH - Vector3(sin(yaw), 0, cos(yaw)) * 2.6 + Vector3(0, 0.9, 0)
			player.camera_rig.set_override(Transform3D(Basis(), cam).looking_at(LAUNCH + dir * 6.0, Vector3.UP))
		Step.FLY:
			_fly(delta)
	_update_hud()
	player._emit_context()


func _fly(delta: float) -> void:
	if _land_wait > 0.0:
		_land_wait -= delta
		if _land_wait <= 0.0:
			_score_throw()
		return
	var steps := 3
	var dt := delta / steps
	for i in steps:
		var sp := vel.length()
		var dir := vel / maxf(sp, 0.001)
		var up_perp := (Vector3.UP - dir * dir.dot(Vector3.UP)).normalized()
		var cl := 0.11 * lerpf(0.6, 1.15, fold_quality)
		var cd := 0.035 + (1.0 - fold_quality) * 0.03
		var acc := Vector3(0, -9.8, 0)
		acc += up_perp * cl * sp * sp
		acc -= dir * cd * sp * sp
		acc += (_wind - Vector3(vel.x, 0, vel.z) * 0.0) * 0.5
		# leve balanço lateral
		acc += Vector3(cos(yaw), 0, -sin(yaw)) * sin(_fly_t * 5.0) * 0.4
		var prev := pos
		vel += acc * dt
		pos += vel * dt
		_fly_t += dt
		# argolas
		for k in RINGS.size():
			var r: Vector3 = RINGS[k]
			if not _rings_passed.has(k) and (prev.z - r.z) * (pos.z - r.z) <= 0.0:
				var cross := Vector2(pos.x - r.x, pos.y - r.y).length()
				if cross < 0.9:
					_rings_passed[k] = true
					AudioManager.play_ui("ui_confirm", -4.0)
					GameManager.show_toast("Passou pela argola! +20")
		# colisão com o cenário
		var q := PhysicsRayQueryParameters3D.create(prev, pos, 1)
		var hit := _space.intersect_ray(q)
		if not hit.is_empty() or pos.y <= 0.04:
			if not hit.is_empty():
				pos = hit.position
			pos.y = maxf(pos.y, 0.03)
			_land_wait = 1.2
			break
	_plane.global_position = pos
	if vel.length() > 0.1:
		_plane.look_at(pos - vel.normalized(), Vector3.UP)
	var cam := pos - Vector3(vel.x, 0, vel.z).normalized() * 3.0 + Vector3(0, 1.4, 0)
	player.camera_rig.set_override(Transform3D(Basis(), cam).looking_at(pos, Vector3.UP))
	if _fly_t > 12.0:
		_land_wait = 0.5


func _score_throw() -> void:
	var dist := _distance()
	var pts := int(dist * 3.0) + _rings_passed.size() * 20
	var td := Vector2(pos.x - TARGET.x, pos.z - TARGET.z).length()
	var tgt_msg := ""
	if td < 0.5:
		pts += 50
		tgt_msg = "  ·  NO CENTRO DO ALVO! +50"
	elif td < 1.6:
		pts += 25
		tgt_msg = "  ·  No alvo! +25"
	total_score += pts
	best_score = maxi(best_score, pts)
	var rec: Dictionary = SaveManager.section("stats").get("aviao_recorde", {"dist": 0.0})
	if dist > float(rec.get("dist", 0.0)):
		rec["dist"] = dist
		SaveManager.section("stats")["aviao_recorde"] = rec
		tgt_msg += "  ·  Novo recorde de distância!"
	hud.show_banner("%.1f m" % dist, "%d pontos%s" % [pts, tgt_msg])
	throws_left -= 1
	if throws_left <= 0:
		get_tree().create_timer(2.0).timeout.connect(_finish)
	else:
		get_tree().create_timer(2.0).timeout.connect(_start_fold)
		step = Step.DONE


func _finish() -> void:
	if not running:
		return
	var won := 1 if total_score >= 150 else (0 if total_score >= 80 else -1)
	if best_score >= 120:
		GameManager.unlock_achievement("piloto")
	end_game(won, "Aviãozinho: %d pontos" % total_score, 5 + total_score / 15, 10 + total_score / 8, {"score": total_score})


func cleanup() -> void:
	if is_instance_valid(_deco):
		_deco.queue_free()
	player.visual.stop_action()
	super.cleanup()
