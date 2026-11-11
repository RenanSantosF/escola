extends Minigame
## Basquete relâmpago (quadrinha do Parque do Morro): 45 segundos, bolas à
## vontade. SEGURE o botão (a linha mostra o arco: verde = força certa) e SOLTE.
## A mira conta: o joystick vira para os lados. "Chuá" (sem tocar no aro) vale
## +1. A cada 3 cestas você vai para uma marca mais longe (vale mais).
## Cestas seguidas fazem combo (x2, x3) e os últimos 10 segundos valem dobro.

const HOOP := Vector3(ParkHill.COURT.x + 6.0, 3.05, ParkHill.COURT.y)  # centro do aro
const SPOTS := [Vector3(ParkHill.COURT.x + 2.5, 0.05, ParkHill.COURT.y), Vector3(ParkHill.COURT.x + 0.5, 0.05, ParkHill.COURT.y + 2.5),
	Vector3(ParkHill.COURT.x - 2.0, 0.05, ParkHill.COURT.y), Vector3(ParkHill.COURT.x + 0.5, 0.05, ParkHill.COURT.y - 2.5)]
const POINTS := [2, 2, 3, 3]
const MAKES_TO_MOVE := 3
const GAME_TIME := 45.0
const RIM_R := 0.23

var score := 0
var made := 0
var shots := 0
var spot_i := 0
var _made_here := 0
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _yaw := 0.0
var _aim_yaw := 0.0  # direção certa para a cesta desta marca
var _balls: Array = []  # {node, pos, vel, state, t}
var _root: Node3D
var _arc: AimArc
var _ideal := 0.5
var _ball_mesh: Mesh
var _cool := 0.0


func begin() -> void:
	_root = Node3D.new()
	world.add_child(_root)
	_arc = AimArc.new()
	_root.add_child(_arc)
	var md := MeshData.new()
	md.cur_color = Color("ff7a1a")
	md.add_sphere(Transform3D(), 0.13, 12, 8)
	md.cur_color = Color("3a1f0f")
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.132, 0.132, 0.012, 14, false)
	_ball_mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	player.force_stand()
	player.movement_locked = true
	time_left = GAME_TIME
	_go_spot(0)
	countdown(3.0)
	super.begin()


func double_end() -> bool:
	return true


func _go_spot(i: int) -> void:
	spot_i = i % SPOTS.size()
	_made_here = 0
	var sp: Vector3 = SPOTS[spot_i]
	player.global_position = sp
	var to := HOOP - sp
	_aim_yaw = atan2(to.x, to.z)
	_yaw = _aim_yaw
	player.yaw = _yaw
	if player.camera_rig:
		var back := -Vector3(sin(_yaw), 0, cos(_yaw))
		player.camera_rig.set_override(Transform3D(Basis(), sp + back * 3.0 + Vector3(0.8, 2.2, 0)).looking_at(HOOP + Vector3(0, -0.8, 0), Vector3.UP))
	_ideal = clampf((Vector2(to.x, to.z).length() - 2.5) / 7.5, 0.15, 0.9)
	_update_hud()


func _update_hud() -> void:
	var mult := combo_mult() * (2 if time_left <= 10.0 else 1)
	hud.set_minigame_text("Basquete  ·  %d pontos  ·  %s  ·  marca vale %d%s" % [score, Minigame.fmt_time(time_left), POINTS[spot_i], ("  ·  x%d" % mult) if mult > 1 else ""])


func play_label() -> String:
	return "Soltar!" if _charging else "Segure: arremesso"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_play() -> bool:
	if _countdown > 0.0 or _cool > 0.0:
		return true
	_charging = true
	_power = 0.0
	_power_dir = 1.0
	return true


func on_play_release() -> bool:
	if _charging:
		_charging = false
		hud.set_meter(-1.0)
		_arc.hide_arc()
		_shoot()
	return true


## Velocidade do arremesso: a força muda o alcance; a mira, o lado.
func _velocity(power: float) -> Vector3:
	var from := player.global_position + Vector3(0, 1.7, 0)
	var dir := Vector3(sin(_yaw), 0, cos(_yaw))
	var dist := Vector2(HOOP.x - from.x, HOOP.z - from.z).length()
	var reach := dist * (1.0 + (power - _ideal) * 0.9)
	var t := 0.95 + dist * 0.05
	var vy := (HOOP.y + 0.15 - from.y + 0.5 * 9.8 * t * t) / t
	return dir * (reach / t) + Vector3(0, vy, 0)


func _shoot() -> void:
	shots += 1
	_cool = 0.35
	player.visual.play("throw")
	AudioManager.play_ui("throw", -8.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _ball_mesh
	_root.add_child(mi)
	var from := player.global_position + Vector3(0, 1.7, 0)
	mi.global_position = from
	_balls.append({"node": mi, "pos": from, "vel": _velocity(_power), "state": "fly", "t": 0.0, "rim": false})


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		return
	time_left -= delta
	tick_clock(time_left)
	_cool = maxf(_cool - delta, 0.0)
	var mv := player.read_move_raw()
	_yaw = clampf(_yaw - mv.x * delta * 0.5, _aim_yaw - 0.35, _aim_yaw + 0.35)
	player.yaw = _yaw
	if _charging:
		# de longe a barra corre mais rápido
		_power += _power_dir * delta * (0.55 + spot_i * 0.08)
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
		hud.set_meter(_power)
		var good := absf(_power - _ideal) < 0.07 and absf(_yaw - _aim_yaw) < 0.04
		_arc.show_arc(player.global_position + Vector3(0, 1.7, 0), _velocity(_power), 0.05, Color("6be36b") if good else Color("ffcf3f"))
	for b in _balls:
		_step_ball(b, delta)
	_balls = _balls.filter(func(b): return b.state != "gone")
	_update_hud()
	player._emit_context()
	if time_left <= 0.0:
		_finish()


func _step_ball(b: Dictionary, delta: float) -> void:
	b.t += delta
	var prev: Vector3 = b.pos
	b.vel += Vector3(0, -9.8, 0) * delta
	b.pos += b.vel * delta
	(b.node as Node3D).global_position = b.pos
	(b.node as Node3D).rotate_x(delta * 9.0)
	if b.state == "fly" and prev.y >= HOOP.y and b.pos.y < HOOP.y and b.vel.y < 0.0:
		var f := clampf((prev.y - HOOP.y) / maxf(prev.y - b.pos.y, 0.0001), 0.0, 1.0)
		var cross: Vector3 = prev.lerp(b.pos, f)
		var off := Vector2(cross.x - HOOP.x, cross.z - HOOP.z).length()
		if off < RIM_R * 0.62:
			_make(b, true)
		elif off < RIM_R:
			# raspou no aro: entra se estava mais para dentro
			AudioManager.play_ui("ball_bounce", -6.0, 0.1)
			if randf() < 1.0 - (off - RIM_R * 0.62) / (RIM_R * 0.38) * 0.7:
				_make(b, false)
			else:
				_miss(b, true)
		elif off < RIM_R + 0.35:
			AudioManager.play_ui("bonk", -8.0)
			_miss(b, true)
		else:
			_miss(b, false)
	if b.pos.y < 0.1 or b.t > 4.0:
		if b.state == "fly":
			_miss(b, false)
		b.state = "gone"
		(b.node as Node3D).queue_free()


func _make(b: Dictionary, swish: bool) -> void:
	b.state = "in"
	b.vel = Vector3(0, -2.0, 0)
	b.pos = Vector3(HOOP.x, HOOP.y - 0.05, HOOP.z)
	made += 1
	_made_here += 1
	var mult := add_combo() * (2 if time_left <= 10.0 else 1)
	var pts: int = (int(POINTS[spot_i]) + (1 if swish else 0)) * mult
	score += pts
	popup(HOOP + Vector3(0, 0.4, 0), ("CHUÁ! +%d" if swish else "+%d") % pts, Color("6be36b") if swish else Color("ffd23f"))
	AudioManager.play_ui("crowd_cheer" if swish else "point", -10.0 if swish else -4.0)
	Effects.burst(HOOP, "confetti")
	if _made_here >= MAKES_TO_MOVE:
		get_tree().create_timer(0.6).timeout.connect(func():
			if running:
				_go_spot(spot_i + 1)
				GameManager.show_toast("Mais longe! Cada cesta vale %d" % POINTS[spot_i]))


func _miss(b: Dictionary, rim: bool) -> void:
	b.state = "out"
	if rim:
		b.vel = Vector3(randf_range(-2, 2), 1.5, randf_range(-2, 2))
	break_combo()
	if absf(_power - _ideal) > 0.07:
		GameManager.show_toast("Mais força!" if _power < _ideal else "Menos força!")
	elif absf(_yaw - _aim_yaw) > 0.04:
		GameManager.show_toast("Mire no meio da cesta!")


func _finish() -> void:
	if not running:
		return
	var won := 1 if score >= 30 else (0 if score >= 15 else -1)
	if made >= 10:
		GameManager.unlock_achievement("cestinha")
	end_game(won, "Basquete: %d pontos (%d de %d cestas, combo %d)" % [score, made, shots, best_combo], 0, 10 + score, {"score": score})


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
