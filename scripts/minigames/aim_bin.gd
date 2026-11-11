extends Minigame
## Pontaria relâmpago: 40 segundos acertando bolinhas de papel nas lixeiras
## da coleta seletiva. Joystick mira, SEGURE o botão (o arco mostra a curva) e
## SOLTE. Uma lixeira fica "BÔNUS x2" e troca a cada 6 s. Acertos seguidos
## fazem combo e os últimos 10 segundos valem dobro.

const BIN_Z := -24.0
const BINS := [Vector3(23.4, 0.0, -24.0), Vector3(23.8, 0.0, -24.0), Vector3(24.2, 0.0, -24.0), Vector3(24.6, 0.0, -24.0)]
const BIN_POINTS := [10, 20, 30, 50]
const BIN_NAMES := ["papel", "plástico", "vidro", "metal"]
const FROM := Vector3(24, 0.05, -17.5)

const GAME_TIME := 40.0
var balls_left := 999
var score := 0
var hits := 0
var _bonus_k := 3
var _bonus_t := 6.0
var _bonus_lbl: Label3D
var _cool := 0.0
var _yaw := PI
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _flying: Array = []  # {node, pos, vel, done}
var _root: Node3D
var _arc: AimArc


func begin() -> void:
	_root = Node3D.new()
	world.add_child(_root)
	_arc = AimArc.new()
	_root.add_child(_arc)
	player.force_stand()
	player.global_position = FROM
	player.yaw = PI
	player.movement_locked = true
	if player.camera_rig:
		# câmera baixa e à esquerda (o poste fica fora da frente), perto das lixeiras
		player.camera_rig.set_override(Transform3D(Basis(), FROM + Vector3(-0.8, 1.95, 1.4)).looking_at(Vector3(24, 0.5, -24), Vector3.UP))
	time_left = GAME_TIME
	_bonus_lbl = Label3D.new()
	_bonus_lbl.text = "x2"
	_bonus_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bonus_lbl.font = UITheme.bold_font()
	_bonus_lbl.font_size = 96
	_bonus_lbl.outline_size = 16
	_bonus_lbl.modulate = Color("ffd23f")
	_bonus_lbl.pixel_size = 0.005
	_root.add_child(_bonus_lbl)
	_move_bonus()
	countdown(3.0)
	super.begin()
	_update_hud()


func double_end() -> bool:
	return true


func _move_bonus() -> void:
	var k := _bonus_k
	while k == _bonus_k:
		k = randi() % BINS.size()
	_bonus_k = k
	_bonus_t = 6.0
	_bonus_lbl.global_position = BINS[k] + Vector3(0, 1.15, 0)


func _update_hud() -> void:
	var mult := combo_mult() * (2 if time_left <= 10.0 else 1)
	hud.set_minigame_text("Pontaria  ·  %d pontos  ·  %s  ·  azul 10 · verm. 20 · verde 30 · amarela 50%s" % [score, Minigame.fmt_time(time_left), ("  ·  x%d" % mult) if mult > 1 else ""])


func play_label() -> String:
	return "Soltar!" if _charging else "Segure p/ mirar"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_play() -> bool:
	if _countdown > 0.0 or _cool > 0.0:
		return true
	if not _charging:
		_charging = true
		_power = 0.0
		_power_dir = 1.0
	return true


func on_play_release() -> bool:
	if _charging:
		_charging = false
		hud.set_meter(-1.0)
		_arc.hide_arc()
		_throw()
	return true


func _throw() -> void:
	_cool = 0.25
	AudioManager.play_ui("throw", -8.0)
	player.visual.play("throw")
	var dir := Vector3(sin(_yaw), 0, cos(_yaw))
	var speed := lerpf(4.0, 10.0, _power)
	var vel := dir * speed * 0.8 + Vector3(0, speed * 0.6, 0)
	var md := MeshData.new()
	md.cur_color = Color("f4f1e8")
	md.add_sphere(Transform3D(), 0.06, 8, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_root.add_child(mi)
	var start := FROM + Vector3(0, 1.5, 0) + dir * 0.3
	mi.global_position = start
	get_tree().create_timer(0.4).timeout.connect(func():
		_flying.append({"node": mi, "pos": start, "vel": vel, "done": false, "hit": false}))
	_update_hud()


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		return
	time_left -= delta
	tick_clock(time_left)
	_cool = maxf(_cool - delta, 0.0)
	_bonus_t -= delta
	if _bonus_t <= 0.0:
		_move_bonus()
	_bonus_lbl.scale = Vector3.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012))
	var mv := player.read_move_raw()
	_yaw -= mv.x * delta * 0.7
	_yaw = clampf(_yaw, PI - 0.6, PI + 0.6)
	player.yaw = _yaw
	if _charging:
		_power += _power_dir * delta * 0.85
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
		hud.set_meter(_power)
		var d := Vector3(sin(_yaw), 0, cos(_yaw))
		var sp := lerpf(4.0, 10.0, _power)
		_arc.show_arc(FROM + Vector3(0, 1.5, 0) + d * 0.3, d * sp * 0.8 + Vector3(0, sp * 0.6, 0), 0.05)
	for f in _flying:
		if f.done:
			continue
		var prev: Vector3 = f.pos
		f.vel += Vector3(0, -9.8, 0) * delta
		f.pos += f.vel * delta
		f.node.global_position = f.pos
		# entrou numa lixeira? (topo a 0.75 m, raio 0.17)
		if prev.y > 0.75 and f.pos.y <= 0.75:
			for k in BINS.size():
				if Vector2(f.pos.x - BINS[k].x, f.pos.z - BINS[k].z).length() < 0.17:
					f.done = true
					f.hit = true
					hits += 1
					var mult := add_combo() * (2 if time_left <= 10.0 else 1) * (2 if k == _bonus_k else 1)
					var pts: int = int(BIN_POINTS[k]) * mult
					score += pts
					popup(BINS[k] + Vector3(0, 1.0, 0), "+%d" % pts, Color("6be36b") if k == _bonus_k else Color("ffd23f"))
					if k == _bonus_k:
						AudioManager.play_ui("reward", -6.0)
						_move_bonus()
					f.node.visible = false
		if f.pos.y < 0.04:
			f.done = true
			if not f.hit:
				break_combo()
	_update_hud()
	player._emit_context()
	_flying = _flying.filter(func(f):
		if f.done and is_instance_valid(f.node) and not f.node.visible:
			f.node.queue_free()
		return not f.done or (is_instance_valid(f.node) and f.node.visible))
	if time_left <= 0.0:
		_finish()


func _finish() -> void:
	if not running:
		return
	var won := 1 if score >= 250 else (0 if score >= 100 else -1)
	if score >= 400:
		GameManager.unlock_achievement("mira_certeira")
	end_game(won, "Pontaria: %d pontos (%d acertos, combo %d)" % [score, hits, best_combo], 0, 10 + score / 12, {"score": score})


func cleanup() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
