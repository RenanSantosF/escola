extends Minigame
## Queimada: dois times de 4 em metades da quadra de terra. Quem é
## atingido por uma bola arremessada (antes de ela quicar) vai para o
## "cemitério" por alguns segundos. Vence quem queimar 6 primeiro ou tiver
## mais pontos ao fim de 90 s. Pegar a bola: botão verde. Arremessar
## (mira automática no adversário à frente): botão amarelo. Desviar:
## correr e pular.

const CENTER_X := -40.0
const COURT := Rect2(-52, -56, 24, 12)
const TIME := 90.0
const TARGET := 6
const OUT_SECS := 15.0  # tempo no cemitério
const DODGE_SECS := 0.55  # desvio: a bola não queima nesse tempinho
const DODGE_CD := 1.4

var ball: KickBall
var team_a: Array[NPC] = []  # do jogador, lado oeste (x < -40)
var team_b: Array[NPC] = []  # lado leste
var score_a := 0
var score_b := 0
var _out := {}  # nó -> segundos restantes no cemitério
var _holder: Node = null
var _npc_throw_t := 0.0
var _hit_cd := 0.0
# ---- com a turma: o anfitrião simula a bola e os bots; os outros mandam
# "pegar" e "arremessar" e veem tudo pelo estado que ele manda.
var net_role := ""
var my_team := "a"
var humans_a: Array = []
var humans_b: Array = []
var _human_id := {}
var _yaw_over := {}
var _net_t := 0.0
var _state: Dictionary = {}
var _state_age := 0.0
var _puppets: Array[NPC] = []
var _me_out := false
var _dodge_until := {}  # quem -> ms até quando está desviando
var _dodge_cd := 0.0


func begin() -> void:
	for b in get_tree().get_nodes_in_group("ball"):
		if (b as KickBall).kind == "dodgeball":
			ball = b
			break
	if ball == null:
		end_game(0, "Sem bola!", 0, 0)
		return
	ball.hit_body.connect(_on_ball_hit)
	var bots_a := 3
	var bots_b := 4
	if is_net():
		my_team = str((net.get("teams", {}) as Dictionary).get(net.get("me", ""), "a"))
		net_role = "host" if str(net.get("host", "")) == str(net.get("me", "")) else "client"
		NetworkManager.mg_relay.connect(_on_relay)
		if net_role == "client":
			_start_client()
			return
		_collect_humans()
		bots_a = maxi(3 - humans_a.size(), 0)
		bots_b = maxi(4 - humans_b.size(), 0)
	var pool: Array[NPC] = students(bots_a + bots_b, Vector3(-40, 0.05, -50))
	for n in pool:
		if team_a.size() < bots_a:
			team_a.append(n)
		elif team_b.size() < bots_b:
			team_b.append(n)
	take_npcs(team_a + team_b)
	player.force_stand()
	player.global_position = Vector3(-46, 0.05, -50)
	player.yaw = PI * 0.5
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()
	for i in team_a.size():
		team_a[i].teleport(Vector3(-45 - i * 1.5, 0.05, -47 - i * 2.5), PI * 0.5)
	for i in team_b.size():
		team_b[i].teleport(Vector3(-35 + i * 1.0, 0.05, -46.5 - i * 2.5), -PI * 0.5)
	ball.reset_ball()
	ball.global_position = Vector3(-40, 0.4, -50)
	ball.linear_velocity = Vector3.ZERO
	time_left = TIME
	countdown(3.0)
	super.begin()
	_update_hud()


func _update_hud() -> void:
	var extra := "   ·   Você está no cemitério!" if _out.has(player) else ""
	hud.set_minigame_text("Queimada  ·  Seu time %d x %d   ·   %s%s" % [score_a, score_b, fmt_time(time_left), extra])


func _team_of(node: Node) -> int:
	if node == player or (node is NPC and node in team_a) or humans_a.has(node):
		return 0
	if (node is NPC and node in team_b) or humans_b.has(node):
		return 1
	return -1


func _vis(n: Node) -> CharacterVisual:
	if n == player:
		return player.visual
	if n is NPC:
		return (n as NPC).visual
	return n.get_child(0) as CharacterVisual  # avatar de um colega online


func _yaw(n: Node) -> float:
	if _yaw_over.has(n):
		return _yaw_over[n]
	if n.get("yaw") != null:
		return n.get("yaw")
	return (n.get_child(0) as Node3D).rotation.y


func _enemies(team: int) -> Array:
	return (team_b + humans_b) if team == 0 else (team_a + humans_a)


func play_label() -> String:
	return ("Soltar!" if _aiming else "Segure p/ mirar") if _holder == player else "Desviar!"


func interact_label() -> String:
	return "Pegar a bola" if _can_grab(player) else ""


func _can_grab(who: Node3D) -> bool:
	return _holder == null and not _out.has(who) and ball.global_position.distance_to(who.global_position + Vector3(0, 0.3, 0)) < 1.3 and ball.linear_velocity.length() < 6.0


func on_interact() -> bool:
	if net_role == "client":
		if _client_can_grab():
			NetworkManager.mg_send_relay(str(net.gid), {"k": "grab"})
		return true
	if _countdown <= 0.0 and _can_grab(player):
		_grab(player)
	return true


var _aiming := false
var _arc: AimArc


func on_play() -> bool:
	if _holder == player and _countdown <= 0.0:
		_aiming = true
	elif _holder != player:
		_dodge()
	return true


## Desviar: pulinho para o lado e meio segundo sem queimar.
func _dodge() -> void:
	if _dodge_cd > 0.0 or _out.has(player) or _me_out or _countdown > 0.0:
		return
	_dodge_cd = DODGE_CD
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var side := Vector3(-fwd.z, 0, fwd.x) * (1.0 if randf() < 0.5 else -1.0)
	# desvia para longe da bola, se ela estiver vindo
	if ball and ball.linear_velocity.length() > 2.0:
		var bv := ball.linear_velocity
		bv.y = 0
		side = Vector3(-bv.z, 0, bv.x).normalized()
		if side.dot(player.global_position - ball.global_position) < 0.0:
			side = -side
	player.velocity = side * 7.5 + Vector3.UP * 3.2
	player.visual.play("hop_one")
	_dodge_until[player] = Time.get_ticks_msec() + int(DODGE_SECS * 1000.0)
	if net_role == "client":
		NetworkManager.mg_send_relay(str(net.gid), {"k": "dodge"})


func on_play_release() -> bool:
	if _aiming and _holder == player:
		_aiming = false
		if _arc:
			_arc.hide_arc()
		if net_role == "client":
			var f := Vector3(sin(player.yaw), 0, cos(player.yaw))
			NetworkManager.mg_send_relay(str(net.gid), {"k": "throw", "d": [snappedf(f.x, 0.01), snappedf(f.z, 0.01)]})
			player.visual.play("throw")
		else:
			var target := _pick_target(player, _enemies(0))
			_throw(player, target, 0)
	_aiming = false
	return true


func _grab(who: Node) -> void:
	_holder = who
	var slot: Node3D = _vis(who).hand_slot()
	ball.hold(slot, who)
	AudioManager.play_3d("catch", ball.global_position, -2.0)


func _pick_target(from: Node3D, enemies: Array) -> Node3D:
	var fwd := Vector3(sin(_yaw(from)), 0, cos(_yaw(from)))
	var best: Node3D = null
	var best_s := INF
	var cands: Array = []
	cands.append_array(enemies)
	if from != player and _team_of(from) == 1 and not _out.has(player) and not cands.has(player):
		cands.append(player)
	for e in cands:
		if _out.has(e):
			continue
		var to: Vector3 = e.global_position - from.global_position
		to.y = 0
		var ang := fwd.angle_to(to.normalized())
		var s := ang * 4.0 + to.length() * 0.15
		if from is NPC:
			s = to.length() * 0.2 + randf() * 2.0 - (1.5 if not (e is NPC) else 0.0)
		if s < best_s:
			best_s = s
			best = e
	return best


var _last_thrower: Node3D = null
var my_hits := 0


func _throw(who: Node3D, target: Node3D, team: int) -> void:
	_vis(who).play("throw")
	var from_holder := who
	get_tree().create_timer(0.45).timeout.connect(func():
		if not running or _holder != from_holder:
			return
		_holder = null
		var start: Vector3 = _vis(from_holder).hand_position() + Vector3(0, 0.1, 0)
		var aim: Vector3
		if target:
			var tv := Vector3.ZERO
			if target is CharacterBody3D:
				tv = (target as CharacterBody3D).velocity if target == player else Vector3.ZERO
			aim = target.global_position + Vector3(0, 1.0, 0) + tv * 0.3
			if from_holder is NPC:
				# colega de treino erra às vezes (dá para desviar e correr)
				aim += Vector3(randf_range(-1.1, 1.1), randf_range(-0.3, 0.4), randf_range(-1.1, 1.1))
		else:
			aim = start + Vector3(sin(_yaw(from_holder)), 0, cos(_yaw(from_holder))) * 10.0
		var d := aim - start
		var speed := 9.0 if from_holder is NPC else 13.0
		var vel := AimArc.solve(start, aim, speed)
		ball.throw_from(start, vel, team)
		_last_thrower = from_holder
		AudioManager.play_3d("throw", start, -1.0))


func _on_ball_hit(body: Node) -> void:
	if not running or _hit_cd > 0.0:
		return
	if int(_dodge_until.get(body, 0)) > Time.get_ticks_msec():
		if body == player:
			GameManager.show_toast("Desviou!")
		return
	var team := _team_of(body)
	if team == -1 or ball.live_team == -1 or team == ball.live_team or _out.has(body):
		return
	ball.live = false
	_hit_cd = 0.3
	if ball.live_team == 0:
		score_a += 1
	else:
		score_b += 1
	# foi eu que queimei? festa!
	if _last_thrower == player:
		my_hits += 1
		add_combo()
		popup((body as Node3D).global_position + Vector3(0, 2.2, 0), "QUEIMOU!", Color("ff4d6d"), 80)
		if player.camera_rig:
			player.camera_rig.shake(0.12)
	elif body == player:
		break_combo()
		if player.camera_rig:
			player.camera_rig.shake(0.2)
	_eliminate(body)
	_update_hud()
	if score_a >= TARGET or score_b >= TARGET:
		get_tree().create_timer(1.0).timeout.connect(_finish)


func _eliminate(body: Node) -> void:
	_out[body] = OUT_SECS
	var team := _team_of(body)
	# cemitério: atrás do time adversário
	var cx := -29.0 if team == 0 else -51.0
	var pos := Vector3(cx, 0.05, randf_range(-55, -45))
	if body == player:
		player.visual.play("hit")
		GameManager.show_toast("Você foi queimado! Volta em %d segundos." % int(OUT_SECS))
		player.global_position = pos
		player.velocity = Vector3.ZERO
		player.movement_locked = true
	elif body is NPC:
		var n := body as NPC
		n.visual.play("hit")
		n.say(["Ahhh!", "Me queimaram!", "Não valeu!"].pick_random(), 1.5)
		n.teleport(pos, 0.0)
		n.stop()
	AudioManager.play_3d("hit", (body as Node3D).global_position, -1.0)
	Effects.burst((body as Node3D).global_position + Vector3(0, 1.0, 0), "sparkle")


func tick(delta: float) -> void:
	if not running:
		return
	if net_role == "client":
		_client_tick(delta)
		return
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	if net_role == "host":
		_net_send(delta)
	if counting(delta):
		return
	if net_role == "host":
		_check_remote_hits()
	time_left -= delta
	if time_left <= 0.0:
		_finish()
		return
	_update_hud()
	# volta do cemitério
	for b in _out.keys():
		_out[b] -= delta
		if _out[b] <= 0.0:
			_out.erase(b)
			var team := _team_of(b)
			var back := Vector3(-46.0 if team == 0 else -34.0, 0.05, randf_range(-53, -47))
			if b == player:
				player.global_position = back
				player.movement_locked = false
			elif b is NPC:
				(b as NPC).teleport(back, PI * 0.5 if team == 0 else -PI * 0.5)
	# jogador não pode passar do meio
	if not _out.has(player):
		var p := player.global_position
		if p.x > CENTER_X - 0.4 and COURT.grow(3).has_point(Vector2(p.x, p.z)):
			player.global_position.x = CENTER_X - 0.4
			player.velocity.x = minf(player.velocity.x, 0.0)
	# bola parada no chão fora de alcance volta ao meio
	if _holder == null and not COURT.grow(4).has_point(Vector2(ball.global_position.x, ball.global_position.z)):
		ball.global_position = Vector3(-40, 0.4, -50)
		ball.linear_velocity = Vector3.ZERO
	_npc_ai(delta)
	if _aiming and _holder == player:
		if _arc == null:
			_arc = AimArc.new()
			world.add_child(_arc)
		var t := _pick_target(player, _enemies(0))
		var start: Vector3 = player.visual.hand_position() + Vector3(0, 0.1, 0)
		var aim: Vector3 = (t.global_position + Vector3(0, 1.0, 0)) if t else start + Vector3(sin(player.yaw), 0, cos(player.yaw)) * 10.0
		_arc.show_arc(start, AimArc.solve(start, aim, 13.0), 0.05, Color("ff8a3d"))
	player._emit_context()


func _npc_ai(delta: float) -> void:
	var bp := ball.global_position
	for team in [0, 1]:
		var list: Array = team_a if team == 0 else team_b
		var min_x := -51.0 if team == 0 else -39.6
		var max_x := -40.4 if team == 0 else -29.0
		var on_my_side := bp.x > min_x - 0.5 and bp.x < max_x + 0.5
		var chaser: NPC = null
		if _holder == null and on_my_side:
			var bd := INF
			for n in list:
				if _out.has(n):
					continue
				var d: float = n.global_position.distance_to(bp)
				if d < bd:
					bd = d
					chaser = n
		for n in list:
			if _out.has(n):
				continue
			if n == chaser:
				if _can_grab(n):
					_grab(n)
					n.stop()
					_npc_throw_t = randf_range(0.8, 1.6)
				else:
					n.running = true
					n.moving = true
					n.path = PackedVector3Array([Vector3(clampf(bp.x, min_x, max_x), 0.05, clampf(bp.z, -55.5, -44.5))])
					n.path_i = 0
			elif not n.moving:
				# esquiva: se movimenta pelo próprio lado
				if randf() < 0.02:
					n.go_to(Vector3(randf_range(min_x + 1, max_x - 1), 0.05, randf_range(-55, -45)), randf() < 0.5)
				else:
					n.face(bp)
	# NPC com a bola arremessa depois de mirar
	if _holder is NPC:
		_npc_throw_t -= delta
		var h := _holder as NPC
		var team := _team_of(h)
		var target := _pick_target(h, _enemies(team))
		if target:
			h.face(target.global_position)
		if _npc_throw_t <= 0.0:
			if target == player:
				h.say("Lá vai!", 1.0)
			_throw(h, target, team)
			_npc_throw_t = 99.0


func _finish() -> void:
	if not running:
		return
	if net_role == "host":
		var st := _state_dict()
		st["end"] = 1
		NetworkManager.mg_send_relay(str(net.gid), st)
		NetworkManager.mg_team_result(str(net.gid), score_a, score_b)
	var won := 1 if score_a > score_b else (0 if score_a == score_b else -1)
	end_game(won, "Queimada %d x %d" % [score_a, score_b], 22 if won > 0 else 10, 35 if won > 0 else 15, {"score": score_a})


func cleanup() -> void:
	player.movement_locked = false
	if NetworkManager.mg_relay.is_connected(_on_relay):
		NetworkManager.mg_relay.disconnect(_on_relay)
	if _arc:
		_arc.queue_free()
	if is_instance_valid(ball):
		if ball.held_by:
			ball.throw_from(ball.global_position, Vector3.ZERO, -1)
		ball.live = false
		ball.hit_body.disconnect(_on_ball_hit)
		ball.freeze = false
		ball.reset_ball()
	super.cleanup()


# ================================================================ com a turma

func _remote_root(id: String) -> Node3D:
	var s := get_tree().get_first_node_in_group("online_session")
	if s and s.remotes.has(id):
		return s.remotes[id].root
	return null


func _collect_humans() -> void:
	var teams: Dictionary = net.get("teams", {})
	for id in net.get("players", []):
		if str(id) == str(net.get("me", "")):
			continue
		_add_human(str(id), str(teams.get(id, "b")))


func _add_human(id: String, team: String) -> void:
	var r := _remote_root(id)
	if r == null or _human_id.has(r):
		return
	_human_id[r] = id
	(humans_a if team == "a" else humans_b).append(r)


func _id_of(n: Node) -> String:
	if n == null:
		return ""
	if n == player:
		return str(net.get("me", ""))
	return str(_human_id.get(n, ""))


## Bola acertou um colega online? (o avatar dele não tem corpo físico aqui)
func _check_remote_hits() -> void:
	if ball == null or not ball.live or ball.live_team == -1:
		return
	var bp := ball.global_position
	for r in humans_a + humans_b:
		if _out.has(r) or _team_of(r) == ball.live_team:
			continue
		var p: Vector3 = (r as Node3D).global_position
		if Vector2(bp.x - p.x, bp.z - p.z).length() < 0.7 and bp.y > p.y + 0.1 and bp.y < p.y + 2.0:
			_on_ball_hit(r)
			return


func _state_dict() -> Dictionary:
	var bp := ball.global_position
	var out_ids: Array = []
	for b in _out.keys():
		var id := _id_of(b)
		if id != "":
			out_ids.append(id)
	var bots: Array = []
	for n in team_a + team_b:
		bots.append([snappedf(n.global_position.x, 0.01), snappedf(n.global_position.z, 0.01), snappedf(n.yaw, 0.01), 1 if n.moving else 0])
	return {"a": score_a, "b": score_b, "t": snappedf(time_left, 0.1), "c": 1 if _countdown > 0.0 else 0,
		"ball": [snappedf(bp.x, 0.01), snappedf(bp.y, 0.01), snappedf(bp.z, 0.01)], "h": _id_of(_holder) if _holder and not (_holder is NPC) else ("bot" if _holder else ""),
		"out": out_ids, "bots": bots}


func _net_send(delta: float) -> void:
	_net_t -= delta
	if _net_t > 0.0:
		return
	_net_t = 0.08
	NetworkManager.mg_send_relay(str(net.gid), _state_dict())


func _on_relay(gid: String, from: String, d: Variant) -> void:
	if gid != str(net.get("gid", "")) or not (d is Dictionary):
		return
	if net_role == "host":
		var r: Node3D = null
		for k in _human_id.keys():
			if _human_id[k] == from:
				r = k
		if r == null or _countdown > 0.0 or _out.has(r):
			return
		match str(d.get("k", "")):
			"grab":
				if _can_grab(r):
					_grab(r)
			"dodge":
				_dodge_until[r] = Time.get_ticks_msec() + int(DODGE_SECS * 1000.0)
			"throw":
				if _holder == r:
					var dv: Array = d.get("d", [])
					if dv.size() == 2:
						_yaw_over[r] = atan2(float(dv[0]), float(dv[1]))
					var team := _team_of(r)
					_throw(r, _pick_target(r, _enemies(team)), team)
	elif net_role == "client" and from == str(net.get("host", "")):
		_state = d
		_state_age = 0.0


func on_net_event(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	if net_role == "host" and kind == "joined":
		_add_human(str(ev.get("id", "")), str(ev.get("team", "b")))
		# um bot do time dele sai do jogo
		var list := team_a if str(ev.get("team", "b")) == "a" else team_b
		if not list.is_empty():
			var out_bot: NPC = list.pop_back()
			if _holder == out_bot:
				_holder = null
			participants.erase(out_bot)
			npcs.release_practice(out_bot)
		hud.show_banner("Reforço!", "%s entrou na queimada" % NetworkManager.name_of(str(ev.get("id", ""))))
	elif net_role == "host" and kind == "left":
		for r in _human_id.keys():
			if _human_id[r] == str(ev.get("id", "")):
				humans_a.erase(r)
				humans_b.erase(r)
				_out.erase(r)
				if _holder == r:
					_holder = null
				_human_id.erase(r)
	elif net_role == "client" and kind == "host" and running:
		# quem começou saiu: a partida acaba para todos
		end_game(0, "A queimada acabou (quem começou saiu)", 6, 10)


# ---------------------------------------------------------------- colega

func _side() -> float:
	return -1.0 if my_team == "a" else 1.0  # lado oeste (-) ou leste (+)


func _start_client() -> void:
	player.force_stand()
	player.global_position = Vector3(CENTER_X + _side() * 6.0, 0.05, randf_range(-53, -47))
	player.yaw = -_side() * PI * 0.5
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()
	ball.freeze = true
	time_left = TIME
	super.begin()
	hud.set_minigame_text("Queimada com a turma · esperando quem começou...")


func _client_can_grab() -> bool:
	return str(_state.get("h", "")) == "" and not _me_out and ball.global_position.distance_to(player.global_position + Vector3(0, 0.3, 0)) < 1.4


func _client_tick(delta: float) -> void:
	_state_age += delta
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	if _state.is_empty():
		if _state_age > 20.0:
			end_game(0, "Quem começou não respondeu", 2, 4)
		return
	var me := str(net.get("me", ""))
	score_a = int(_state.get("a", 0))
	score_b = int(_state.get("b", 0))
	time_left = float(_state.get("t", time_left))
	var mine := score_a if my_team == "a" else score_b
	var theirs := score_b if my_team == "a" else score_a
	# bola: na minha mão (sem atraso) ou onde o anfitrião mandou
	var holder := str(_state.get("h", ""))
	_holder = player if holder == me else null
	var b: Array = _state.get("ball", [])
	if holder == me:
		ball.global_position = player.visual.hand_position()
	elif b.size() == 3:
		ball.global_position = ball.global_position.lerp(Vector3(float(b[0]), float(b[1]), float(b[2])), 1.0 - exp(-14.0 * delta))
	# fui queimado? vai para o cemitério (atrás do outro time) e volta depois
	var outs: Array = _state.get("out", [])
	var is_out := me in outs
	if is_out and not _me_out:
		player.visual.play("hit")
		GameManager.show_toast("Você foi queimado! Volta em %d segundos." % int(OUT_SECS))
		player.global_position = Vector3(CENTER_X - _side() * 11.0, 0.05, randf_range(-55, -45))
		player.movement_locked = true
	elif not is_out and _me_out:
		player.global_position = Vector3(CENTER_X + _side() * 6.0, 0.05, randf_range(-53, -47))
		player.movement_locked = false
	_me_out = is_out
	# não passa do meio
	if not _me_out:
		var p := player.global_position
		if COURT.grow(3).has_point(Vector2(p.x, p.z)):
			if _side() < 0.0 and p.x > CENTER_X - 0.4:
				player.global_position.x = CENTER_X - 0.4
			elif _side() > 0.0 and p.x < CENTER_X + 0.4:
				player.global_position.x = CENTER_X + 0.4
	# bots desenhados onde o anfitrião mandou
	var list: Array = _state.get("bots", [])
	while _puppets.size() < list.size():
		var got: Array[NPC] = students(1, Vector3(-40, 0.05, -50))
		if got.is_empty():
			break
		take_npcs(got)
		_puppets.append(got[0])
	for i in _puppets.size():
		var n := _puppets[i]
		n.visible = i < list.size()
		if i >= list.size():
			continue
		var e: Array = list[i]
		var tgt := Vector3(float(e[0]), 0.05, float(e[1]))
		if n.global_position.distance_to(tgt) > 6.0:
			n.teleport(tgt, float(e[2]))
		else:
			n.global_position = n.global_position.lerp(tgt, 1.0 - exp(-12.0 * delta))
			n.yaw = lerp_angle(n.yaw, float(e[2]), 1.0 - exp(-12.0 * delta))
			n.visual.rotation.y = n.yaw
		n.moving = false
	hud.set_minigame_text("Queimada com a turma  ·  Seu time %d x %d  ·  %s%s" % [mine, theirs, fmt_time(time_left), "   ·   Você está no cemitério!" if _me_out else ""])
	if int(_state.get("end", 0)) == 1:
		var won := 1 if mine > theirs else (0 if mine == theirs else -1)
		end_game(won, "Queimada %d x %d" % [mine, theirs], 22 if won > 0 else 10, 35 if won > 0 else 15, {"score": mine})
		return
	player._emit_context()
