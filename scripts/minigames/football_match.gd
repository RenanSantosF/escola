extends Minigame
## Futebol na quadra: 4 contra 4 (com goleiros), 2 minutos ou 3 gols.
## Chutar (botão amarelo) com mira assistida para o gol; Passar (verde)
## para o colega mais à frente. Gols detectados pela linha e pela trave.
## Torneio do recreio: 3 vitórias (em dias diferentes ou não) = taça.

const COURT := Rect2(20, -59, 40, 20)
const GOAL_HALF := 1.45
const MATCH_TIME := 120.0
const CAPTAINS := ["bia", "rafa", "pedro"]

var ball: KickBall
var team_a: Array[NPC] = []  # do jogador (ataca o gol leste, x=60)
var team_b: Array[NPC] = []  # ataca o gol oeste, x=20
var keeper_a: NPC
var keeper_b: NPC
var score_a := 0
var score_b := 0
var _goal_pause := 0.0
var _kick_cd := {}
var _out_t := 0.0
var _rival := "Time da Bia"


func begin() -> void:
	ball = npcs.football
	if ball == null:
		end_game(0, "Sem bola!", 0, 0)
		return
	var t: Dictionary = SaveManager.section("stats").get("torneio", {"wins": 0, "round": 0})
	var captain: String = CAPTAINS[int(t.get("round", 0)) % CAPTAINS.size()]
	_rival = "Time do %s" % GameManager.npc_display_name(captain) if captain != "bia" else "Time da Bia"
	# escolhe jogadores: Lucas no time do jogador; capitão rival no outro
	var pool: Array[NPC] = []
	for n in npcs.npcs:
		if n.role == "student" and n.active and n.activity != "minigame":
			pool.append(n)
	pool.sort_custom(func(a, b): return a.global_position.distance_squared_to(Vector3(40, 0, -49)) < b.global_position.distance_squared_to(Vector3(40, 0, -49)))
	var lucas := _pick(pool, "lucas")
	var cap := _pick(pool, captain)
	if lucas:
		team_a.append(lucas)
	if cap:
		team_b.append(cap)
	while (team_a.size() < 3 or team_b.size() < 4) and not pool.is_empty():
		var n: NPC = pool.pop_front()
		if team_a.size() < 3:
			team_a.append(n)
		else:
			team_b.append(n)
	take_npcs(team_a + team_b)
	keeper_a = team_a.pop_back() if team_a.size() >= 2 else null
	keeper_b = team_b.pop_back() if team_b.size() >= 2 else null
	time_left = MATCH_TIME
	_kickoff(0)
	super.begin()
	hud.show_banner("Futebol!", "Seu time x %s" % _rival)


func _pick(pool: Array[NPC], nid: String) -> NPC:
	for n in pool:
		if n.data.get("id", "") == nid:
			pool.erase(n)
			return n
	return null


func _kickoff(_team_scored: int) -> void:
	ball.reset_ball()
	ball.global_position = Vector3(40, 0.3, -49)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	player.force_stand()
	player.global_position = Vector3(37.0, 0.05, -49.0)
	player.yaw = PI * 0.5
	player.velocity = Vector3.ZERO
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()
	var pos_a := [Vector3(33, 0.05, -45), Vector3(33, 0.05, -53), Vector3(28, 0.05, -49)]
	var pos_b := [Vector3(43, 0.05, -49), Vector3(47, 0.05, -45), Vector3(47, 0.05, -53)]
	for i in team_a.size():
		team_a[i].teleport(pos_a[i % pos_a.size()], PI * 0.5)
	for i in team_b.size():
		team_b[i].teleport(pos_b[i % pos_b.size()], -PI * 0.5)
	if keeper_a:
		keeper_a.teleport(Vector3(20.6, 0.05, -49), PI * 0.5)
	if keeper_b:
		keeper_b.teleport(Vector3(59.4, 0.05, -49), -PI * 0.5)
	countdown(3.0)
	_update_hud()


func _update_hud() -> void:
	hud.set_minigame_text("Seu time %d x %d %s   ·   %s" % [score_a, score_b, _rival, fmt_time(time_left)])


func play_label() -> String:
	return "Chutar" if _near_ball(1.3) else "Correr atrás!"


func interact_label() -> String:
	return "Passar" if _near_ball(1.3) else ""


func _near_ball(r: float) -> bool:
	return ball != null and Vector2(ball.global_position.x - player.global_position.x, ball.global_position.z - player.global_position.z).length() < r


func on_play() -> bool:
	if _countdown > 0.0 or not _near_ball(1.3):
		return true
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var goal := Vector3(60, 0, -49)
	var to_goal := (goal - player.global_position)
	to_goal.y = 0
	var dir := fwd
	# mira assistida: se estiver mais ou menos virado para o gol
	if fwd.angle_to(to_goal.normalized()) < deg_to_rad(40):
		var aim := goal + Vector3(0, 0, randf_range(-1.0, 1.0))
		dir = (aim - player.global_position)
		dir.y = 0
		dir = dir.normalized()
	var running := Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed + 0.5
	player.visual.play("kick")
	var b := ball
	get_tree().create_timer(0.3).timeout.connect(func():
		if running_game():
			b.kick(dir, 11.0 if running else 8.5, 2.2))
	return true


func on_interact() -> bool:
	if _countdown > 0.0 or not _near_ball(1.3):
		return true
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	var best: NPC = null
	var best_score := INF
	for n in team_a:
		var to := n.global_position - player.global_position
		to.y = 0
		var ang := fwd.angle_to(to.normalized())
		if ang < deg_to_rad(80) and to.length() < 18.0:
			var s := ang * 5.0 + to.length() * 0.1
			if s < best_score:
				best_score = s
				best = n
	if best == null:
		return on_play()
	var to2 := best.global_position - ball.global_position
	to2.y = 0
	player.visual.play("kick")
	var dist := to2.length()
	var b := ball
	get_tree().create_timer(0.3).timeout.connect(func():
		if running_game():
			b.kick(to2.normalized(), clampf(dist * 0.9 + 2.5, 4.0, 12.0), 0.6))
	best.say("Tô livre!", 1.2)
	return true


func running_game() -> bool:
	return running and is_instance_valid(ball)


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		ball.linear_velocity = Vector3.ZERO
		ball.global_position = Vector3(40, ball.global_position.y, -49)
		return
	if _goal_pause > 0.0:
		_goal_pause -= delta
		if _goal_pause <= 0.0:
			if score_a >= 3 or score_b >= 3:
				_finish()
			else:
				_kickoff(0)
		return
	time_left -= delta
	_update_hud()
	if time_left <= 0.0:
		_finish()
		return
	_check_goal()
	_check_out(delta)
	for n in team_a:
		_field_ai(n, 0, delta)
	for n in team_b:
		_field_ai(n, 1, delta)
	if keeper_a:
		_keeper_ai(keeper_a, 20.6, 1.0)
	if keeper_b:
		_keeper_ai(keeper_b, 59.4, -1.0)
	player._emit_context()


func _check_goal() -> void:
	var p := ball.global_position
	if absf(p.z + 49.0) < GOAL_HALF and p.y < 2.0:
		if p.x > 60.15 and p.x < 61.2:
			_goal(0)
		elif p.x < 19.85 and p.x > 18.8:
			_goal(1)


func _goal(team: int) -> void:
	if team == 0:
		score_a += 1
		hud.show_banner("GOOOL!", "Seu time %d x %d" % [score_a, score_b])
		player.visual.play("celebrate")
		AudioManager.play_ui("celebrate", -2.0)
		for n in team_a:
			n.visual.play("clap")
	else:
		score_b += 1
		hud.show_banner("Gol do adversário", "Seu time %d x %d" % [score_a, score_b])
		for n in team_b:
			n.visual.play("celebrate")
	if player.camera_rig:
		player.camera_rig.shake(0.08)
	_goal_pause = 2.5
	_update_hud()


func _check_out(delta: float) -> void:
	var p := ball.global_position
	if COURT.grow(0.6).has_point(Vector2(p.x, p.z)):
		_out_t = 0.0
		return
	_out_t += delta
	if _out_t > 1.2:
		_out_t = 0.0
		# lateral / tiro de meta: volta para dentro perto de onde saiu
		var nx := clampf(p.x, COURT.position.x + 1.5, COURT.end.x - 1.5)
		var nz := clampf(p.z, COURT.position.y + 1.0, COURT.end.y - 1.0)
		ball.global_position = Vector3(nx, 0.3, nz)
		ball.linear_velocity = Vector3.ZERO
		hud.show_banner("Lateral!", "")


func _field_ai(n: NPC, team: int, _delta: float) -> void:
	var bp := ball.global_position
	var goal := Vector3(60.0 if team == 0 else 20.0, 0, -49)
	var gdir := goal - bp
	gdir.y = 0
	gdir = gdir.normalized()
	var mates: Array = team_a if team == 0 else team_b
	var chaser := true
	for o in mates:
		if o != n and o.global_position.distance_to(bp) < n.global_position.distance_to(bp):
			chaser = false
	# no time do jogador, o jogador também conta como perseguidor
	if team == 0 and player.global_position.distance_to(bp) < n.global_position.distance_to(bp):
		chaser = false
	var key := n.get_instance_id()
	var cd: float = _kick_cd.get(key, 0.0)
	if cd > 0.0:
		_kick_cd[key] = cd - get_process_delta_time()
	if chaser:
		var to := bp - n.global_position
		to.y = 0
		var behind := bp - gdir * 0.45
		if to.length() < 0.8 and cd <= 0.0:
			_kick_cd[key] = 1.0
			n.stop()
			n.yaw = atan2(gdir.x, gdir.z)
			n.visual.play("kick")
			var dist_goal := bp.distance_to(goal)
			var spread := 0.3 if dist_goal < 14.0 else 0.5
			var power := randf_range(7.0, 10.0) if dist_goal < 16.0 else randf_range(5.0, 7.5)
			var dir := gdir.rotated(Vector3.UP, randf_range(-spread, spread))
			get_tree().create_timer(0.3).timeout.connect(func():
				if running_game() and ball.global_position.distance_to(n.global_position) < 1.4:
					ball.kick(dir, power, randf_range(0.8, 2.0)))
		else:
			n.running = true
			n.moving = true
			n.path = PackedVector3Array([Vector3(behind.x, 0.05, behind.z)])
			n.path_i = 0
	else:
		var idx := mates.find(n)
		var home_x := (34.0 if team == 0 else 46.0)
		var lane := -45.0 if idx % 2 == 0 else -53.0
		var tx := clampf(lerpf(home_x, bp.x, 0.55), 22.0, 58.0)
		var tgt := Vector3(tx, 0.05, lerpf(lane, bp.z, 0.3))
		if n.global_position.distance_to(tgt) > 1.5:
			n.running = n.global_position.distance_to(tgt) > 5.0
			n.moving = true
			n.path = PackedVector3Array([tgt])
			n.path_i = 0
		else:
			n.face(bp)


func _keeper_ai(k: NPC, x: float, dir: float) -> void:
	var bp := ball.global_position
	var tz := clampf(bp.z, -49.0 - GOAL_HALF + 0.3, -49.0 + GOAL_HALF - 0.3)
	var d := Vector2(bp.x - x, bp.z + 49).length()
	if d < 3.0 and absf(bp.x - x) < 3.5:
		# sai para afastar a bola
		var to := bp - k.global_position
		to.y = 0
		if to.length() < 0.8:
			var key := k.get_instance_id()
			if _kick_cd.get(key, 0.0) <= 0.0:
				_kick_cd[key] = 1.2
				k.visual.play("kick")
				var kdir := Vector3(dir, 0, randf_range(-0.6, 0.6)).normalized()
				ball.kick(kdir, randf_range(8.0, 11.0), 2.5)
				k.say("Defendeu!", 1.2)
			else:
				_kick_cd[key] = _kick_cd[key] - get_process_delta_time()
		else:
			k.moving = true
			k.running = true
			k.path = PackedVector3Array([Vector3(bp.x, 0.05, bp.z)])
			k.path_i = 0
	else:
		var tgt := Vector3(x, 0.05, tz)
		if k.global_position.distance_to(tgt) > 0.3:
			k.moving = true
			k.running = false
			k.path = PackedVector3Array([tgt])
			k.path_i = 0
		else:
			k.face(bp)


func _finish() -> void:
	var won := 1 if score_a > score_b else (0 if score_a == score_b else -1)
	var stats: Dictionary = SaveManager.section("stats")
	var t: Dictionary = stats.get("torneio", {"wins": 0, "round": 0})
	var extra := ""
	if won > 0:
		t["wins"] = int(t.get("wins", 0)) + 1
		t["round"] = int(t.get("round", 0)) + 1
		if int(t.wins) % 3 == 0:
			extra = "  ·  CAMPEÃO DO TORNEIO!"
			GameManager.add_rewards(60, 50)
			GameManager.unlock_achievement("campeao_torneio")
	stats["torneio"] = t
	GameManager.add_stat("gols", score_a)
	var coins := 25 if won > 0 else (12 if won == 0 else 8)
	var xp := 40 if won > 0 else (20 if won == 0 else 15)
	end_game(won, "%d x %d%s" % [score_a, score_b, extra], coins, xp, {"score": score_a})


func cleanup() -> void:
	if is_instance_valid(ball):
		ball.reset_ball()
	super.cleanup()
