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

var ball: KickBall
var team_a: Array[NPC] = []  # do jogador, lado oeste (x < -40)
var team_b: Array[NPC] = []  # lado leste
var score_a := 0
var score_b := 0
var _out := {}  # nó -> segundos restantes no cemitério
var _holder: Node = null
var _npc_throw_t := 0.0
var _hit_cd := 0.0


func begin() -> void:
	for b in get_tree().get_nodes_in_group("ball"):
		if (b as KickBall).kind == "dodgeball":
			ball = b
			break
	if ball == null:
		end_game(0, "Sem bola!", 0, 0)
		return
	ball.hit_body.connect(_on_ball_hit)
	var pool: Array[NPC] = []
	for n in npcs.npcs:
		if n.role == "student" and n.active and n.activity != "minigame":
			pool.append(n)
	pool.sort_custom(func(a, b): return a.global_position.distance_squared_to(Vector3(-40, 0, -50)) < b.global_position.distance_squared_to(Vector3(-40, 0, -50)))
	for n in pool:
		if team_a.size() < 3:
			team_a.append(n)
		elif team_b.size() < 4:
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
	if node == player or node in team_a:
		return 0
	if node in team_b:
		return 1
	return -1


func play_label() -> String:
	return "Arremessar" if _holder == player else "Desviar!"


func interact_label() -> String:
	return "Pegar a bola" if _can_grab(player) else ""


func _can_grab(who: Node3D) -> bool:
	return _holder == null and not _out.has(who) and ball.global_position.distance_to(who.global_position + Vector3(0, 0.3, 0)) < 1.3 and ball.linear_velocity.length() < 6.0


func on_interact() -> bool:
	if _countdown <= 0.0 and _can_grab(player):
		_grab(player)
	return true


func on_play() -> bool:
	if _holder == player and _countdown <= 0.0:
		var target := _pick_target(player, team_b)
		_throw(player, target, 0)
		return true
	return true


func _grab(who: Node) -> void:
	_holder = who
	var slot: Node3D = who.visual.hand_slot()
	ball.hold(slot, who)
	AudioManager.play_3d("pickup", ball.global_position, -4.0)


func _pick_target(from: Node3D, enemies: Array) -> Node3D:
	var fwd := Vector3(sin(from.yaw), 0, cos(from.yaw))
	var best: Node3D = null
	var best_s := INF
	var cands: Array = []
	cands.append_array(enemies)
	if from != player and _team_of(from) == 1 and not _out.has(player):
		cands.append(player)
	for e in cands:
		if _out.has(e):
			continue
		var to: Vector3 = e.global_position - from.global_position
		to.y = 0
		var ang := fwd.angle_to(to.normalized())
		var s := ang * 4.0 + to.length() * 0.15
		if from != player:
			s = to.length() * 0.2 + randf() * 2.0 - (1.5 if e == player else 0.0)
		if s < best_s:
			best_s = s
			best = e
	return best


func _throw(who: Node3D, target: Node3D, team: int) -> void:
	who.visual.play("throw")
	var from_holder := who
	get_tree().create_timer(0.45).timeout.connect(func():
		if not running or _holder != from_holder:
			return
		_holder = null
		var start: Vector3 = from_holder.visual.hand_position() + Vector3(0, 0.1, 0)
		var aim: Vector3
		if target:
			var tv := Vector3.ZERO
			if target is CharacterBody3D:
				tv = (target as CharacterBody3D).velocity if target == player else Vector3.ZERO
			aim = target.global_position + Vector3(0, 1.0, 0) + tv * 0.3
		else:
			aim = start + Vector3(sin(from_holder.yaw), 0, cos(from_holder.yaw)) * 10.0
		var d := aim - start
		var speed := 13.0 if from_holder == player else 10.5
		var t := d.length() / speed
		var vel := d / maxf(t, 0.05) + Vector3(0, 0.5 * 9.8 * t, 0)
		ball.throw_from(start, vel, team)
		AudioManager.play_3d("whoosh", start, -3.0))


func _on_ball_hit(body: Node) -> void:
	if not running or _hit_cd > 0.0:
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
	_eliminate(body)
	_update_hud()
	if score_a >= TARGET or score_b >= TARGET:
		get_tree().create_timer(1.0).timeout.connect(_finish)


func _eliminate(body: Node) -> void:
	_out[body] = 6.0
	var team := _team_of(body)
	# cemitério: atrás do time adversário
	var cx := -29.0 if team == 0 else -51.0
	var pos := Vector3(cx, 0.05, randf_range(-55, -45))
	if body == player:
		player.visual.play("hit")
		GameManager.show_toast("Você foi queimado! Volta em 6 segundos.")
		player.global_position = pos
		player.velocity = Vector3.ZERO
		player.movement_locked = true
	else:
		var n := body as NPC
		n.visual.play("hit")
		n.say(["Ahhh!", "Me queimaram!", "Não valeu!"].pick_random(), 1.5)
		n.teleport(pos, 0.0)
		n.stop()
	AudioManager.play_3d("bonk", (body as Node3D).global_position, -6.0)


func tick(delta: float) -> void:
	if not running:
		return
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	if counting(delta):
		return
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
			else:
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
		var target := _pick_target(h, team_a if team == 1 else team_b)
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
	var won := 1 if score_a > score_b else (0 if score_a == score_b else -1)
	end_game(won, "Queimada %d x %d" % [score_a, score_b], 22 if won > 0 else 10, 35 if won > 0 else 15, {"score": score_a})


func cleanup() -> void:
	player.movement_locked = false
	if is_instance_valid(ball):
		if ball.held_by:
			ball.throw_from(ball.global_position, Vector3.ZERO, -1)
		ball.live = false
		ball.hit_body.disconnect(_on_ball_hit)
		ball.reset_ball()
	super.cleanup()
