extends Minigame
## Aviãozinho de papel:
##  1) Dobrar: 3 dobras com toque no tempo certo (define a qualidade).
##  2) Mirar: joystick ajusta direção/ângulo; SEGURE para carregar a força
##     (a linha mostra o voo previsto) e SOLTE para lançar.
##  3) Voo: planador estável (sem loopings); o joystick faz curvas no ar.
## Pontos: distância + argolas atravessadas + pouso no alvo. 3 lançamentos.

const LAUNCH := Vector3(12, 1.45, 1.5)
## circuito em zigue-zague: precisa fazer curva no ar
const RINGS := [Vector3(12, 1.65, -4.5), Vector3(13.6, 1.5, -8.5), Vector3(12.2, 1.3, -12.0), Vector3(10.6, 1.05, -15.0)]
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
var _arc: AimArc


func begin() -> void:
	_space = world.get_world_3d().direct_space_state
	_deco = Node3D.new()
	world.add_child(_deco)
	_build_rings()
	_plane = _make_plane()
	_deco.add_child(_plane)
	_arc = AimArc.new()
	_deco.add_child(_arc)
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
	hud.show_banner("Dobre o avião!", "Toque quando a barra estiver no MEIO (3 dobras)")
	player.camera_rig.set_override(Transform3D(Basis(), player.global_position + Vector3(0.9, 1.6, -1.4)).looking_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP))
	player.visual.play("interact")
	_update_hud()


func _update_hud() -> void:
	var s := ""
	match step:
		Step.FOLD:
			s = "Dobra %d de 3" % (folds + 1)
		Step.AIM:
			s = "Joystick mira  ·  SEGURE e SOLTE para lançar  ·  Avião %d%%" % int(fold_quality * 100)
		Step.FLY:
			s = "Voando %.1f m  ·  Joystick faz curva" % _distance()
		_:
			s = ""
	hud.set_minigame_text("Aviãozinho  ·  Lançamento %d/%d  ·  Recorde %d  ·  %s" % [THROWS - throws_left + 1, THROWS, best_score, s])


func play_label() -> String:
	match step:
		Step.FOLD:
			return "Dobrar!"
		Step.AIM:
			return "Solte!" if _charging else "Segurar"
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
				_power_dir = 1.0
	return true


func on_play_release() -> bool:
	if step == Step.AIM and _charging:
		_launch()
	return true


func _start_aim() -> void:
	step = Step.AIM
	hud.set_meter(-1.0)
	yaw = PI
	pitch = 0.12
	_plane.visible = true
	_charging = false
	_power = 0.55
	player.visual.play("look_around")
	_wind = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.3, 0.3))
	if absf(_wind.x) > 0.3:
		GameManager.show_toast("Vento para a %s!" % ("direita" if _wind.x < 0 else "esquerda"))
	_update_hud()


func _launch() -> void:
	_charging = false
	_arc.hide_arc()
	hud.set_meter(-1.0)
	step = Step.FLY
	player.visual.play("throw")
	pos = LAUNCH
	vel = _launch_vel()
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
			pitch = clampf(pitch - mv.y * delta * 0.6, -0.15, 0.45)
			if _charging:
				_power += _power_dir * delta * 0.7
				if _power >= 1.0 or _power <= 0.0:
					_power_dir *= -1.0
					_power = clampf(_power, 0.0, 1.0)
				hud.set_meter(_power)
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			_arc.show_points(_predict(), Color("5ec8ff") if not _charging else Color("ffcf3f"))
			_plane.global_position = LAUNCH
			_plane.look_at(LAUNCH - dir, Vector3.UP)
			player.yaw = yaw
			var cam := LAUNCH - Vector3(sin(yaw), 0, cos(yaw)) * 2.6 + Vector3(0, 0.9, 0)
			player.camera_rig.set_override(Transform3D(Basis(), cam).looking_at(LAUNCH + dir * 6.0, Vector3.UP))
		Step.FLY:
			_fly(delta)
	_update_hud()
	player._emit_context()


func _launch_vel() -> Vector3:
	var speed := lerpf(5.0, 10.5, _power)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	return dir * speed


## Física de planador estável: a sustentação nunca passa do peso, o
## avião troca altura por velocidade e o balanço vertical é amortecido.
func _step_flight(p: Vector3, v: Vector3, dt: float, steer: float) -> Array:
	var h := Vector3(v.x, 0, v.z)
	var hs := h.length()
	var q := fold_quality
	var lift := minf(9.8 * lerpf(0.78, 0.93, q), 0.42 * hs * hs)
	var ay := -9.8 + lift - v.y * 1.1
	var drag := lerpf(0.05, 0.028, q) * hs
	h -= h * drag * dt
	# descendo, ganha um pouco de velocidade (planeio)
	if v.y < 0.0 and hs > 0.01:
		h += h / hs * (-v.y) * 0.5 * dt
	# curva pelo joystick
	if absf(steer) > 0.01:
		h = h.rotated(Vector3.UP, -steer * 1.3 * dt)
	h += _wind * 0.35 * dt
	var nv := Vector3(h.x, v.y + ay * dt, h.z)
	return [p + nv * dt, nv]


func _predict() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p := LAUNCH
	var v := _launch_vel()
	for i in 140:
		var r := _step_flight(p, v, 0.04, 0.0)
		p = r[0]
		v = r[1]
		if i % 2 == 0:
			pts.append(p)
		if p.y <= 0.05:
			break
	return pts


func _fly(delta: float) -> void:
	if _land_wait > 0.0:
		_land_wait -= delta
		if _land_wait <= 0.0:
			_score_throw()
		return
	var steer := player.read_move_raw().x
	var steps := 3
	var dt := delta / steps
	for i in steps:
		var prev := pos
		var r := _step_flight(pos, vel, dt, steer)
		pos = r[0]
		vel = r[1]
		_fly_t += dt
		# argolas: cruzou o plano da argola perto do centro
		for k in RINGS.size():
			var rg: Vector3 = RINGS[k]
			if not _rings_passed.has(k) and (prev.z - rg.z) * (pos.z - rg.z) <= 0.0:
				var cross := Vector2(pos.x - rg.x, pos.y - rg.y).length()
				if cross < 1.0:
					_rings_passed[k] = true
					var mult := add_combo()
					popup(rg + Vector3(0, 1.0, 0), "+%d" % (20 * mult), Color("ffd23f"))
					Effects.burst(rg, "confetti")
		# colisão com o cenário (ignora o primeiro instante, perto da mão)
		if _fly_t > 0.12:
			var qr := PhysicsRayQueryParameters3D.create(prev, pos, 1)
			var hit := _space.intersect_ray(qr)
			if not hit.is_empty():
				pos = hit.position
				vel = Vector3.ZERO
				_land_wait = 1.2
				break
		if pos.y <= 0.04:
			pos.y = 0.03
			vel = Vector3.ZERO
			_land_wait = 1.2
			AudioManager.play_3d("step_grass", pos, -6.0)
			break
	_plane.global_position = pos
	if vel.length() > 0.1:
		_plane.look_at(pos - vel.normalized(), Vector3.UP)
		_plane.rotate_object_local(Vector3.FORWARD, steer * 0.6)
	var back := Vector3(vel.x, 0, vel.z)
	if back.length() < 0.1:
		back = Vector3(sin(yaw), 0, cos(yaw))
	var cam := pos - back.normalized() * 3.2 + Vector3(0, 1.3, 0)
	player.camera_rig.set_override(Transform3D(Basis(), cam).looking_at(pos, Vector3.UP))
	if _fly_t > 14.0:
		_land_wait = 0.5


var tgt_bonus := ""


func _score_throw() -> void:
	tgt_bonus = ""
	var dist := _distance()
	var ring_pts := 0
	for i in _rings_passed.size():
		ring_pts += 20 * (3 if i >= 5 else (2 if i >= 2 else 1))
	var pts := int(dist * 3.0) + ring_pts
	if _rings_passed.size() == RINGS.size():
		pts += 40
		tgt_bonus = "  ·  TODAS AS ARGOLAS! +40"
	combo = 0
	var td := Vector2(pos.x - TARGET.x, pos.z - TARGET.z).length()
	var tgt_msg := tgt_bonus
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
		# o avião já está dobrado: só mira e lança de novo
		get_tree().create_timer(2.0).timeout.connect(_start_aim)
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
	hud.set_meter(-1.0)
	player.visual.stop_action()
	super.cleanup()
