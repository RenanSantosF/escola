extends Minigame
## Futebol na quadra, estilo videogame:
## - a bola CONDUZIDA fica colada no pé (correr = bola mais solta);
## - COM A BOLA: Amarelo (segure/solte) = chute com força; Verde toque = passe;
##   Verde segurando = lançamento (passe alto e longo); Azul = passe em
##   profundidade (na frente do colega que corre);
## - SEM A BOLA: Verde = roubar a bola (carrinho); Amarelo = pedir a bola;
## - goleiros são sempre bots; antes de começar escolhe tamanho do time,
##   dificuldade e se completa os times com bots.

const COURT := Rect2(20, -59, 40, 20)
const GOAL_HALF := 1.45
const MATCH_TIME := 150.0
const CAPTAINS := ["bia", "rafa", "pedro"]
const GOAL_A := Vector3(60, 0, -49)  # gol que o time do jogador ataca
const GOAL_B := Vector3(20, 0, -49)
const DRIBBLE_DIST := 0.5
const CATCH_DIST := 0.75

var ball: KickBall
var team_a: Array[NPC] = []  # do jogador (ataca o gol leste, x=60)
var team_b: Array[NPC] = []  # ataca o gol oeste, x=20
var keeper_a: NPC
var keeper_b: NPC
var score_a := 0
var score_b := 0
var holder: Node3D = null  # quem está com a bola (jogador, NPC ou goleiro)
var _hold_immune := 0.0  # quem acabou de receber não perde na hora
var _free_t := 0.0  # bola livre há quanto tempo
var _last_touch_team := -1
var _goal_pause := 0.0
var _think := {}
var _tackle_cd := 0.0
var _charge := false
var _power := 0.0
var _pass_down_ms := 0
var _out_t := 0.0
var _rival := "Time da Bia"
var _setup_panel: PanelContainer
var _started := false
# opções escolhidas
var side_size := 4  # jogadores de linha por time (contando você)
var difficulty := 1  # 0 fácil, 1 normal, 2 difícil
var fill_bots := true


func begin() -> void:
	ball = npcs.football
	if ball == null:
		end_game(0, "Sem bola!", 0, 0)
		return
	player.force_stand()
	player.movement_locked = true
	player.global_position = Vector3(37.0, 0.05, -49.0)
	player.yaw = PI * 0.5
	super.begin()
	_show_setup()


# ---------------------------------------------------------------- seletor

func _show_setup() -> void:
	_setup_panel = PanelContainer.new()
	_setup_panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.98), 26, Color("2ecc71"), 5, 6))
	_setup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_setup_panel.position = Vector2(-360, -250)
	_setup_panel.custom_minimum_size = Vector2(720, 0)
	hud.add_child(_setup_panel)
	hud.controls.blockers.append(_setup_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_setup_panel.add_child(v)
	v.add_child(UITheme.title_label("Futebol na quadra", 44, Color("1e8449")))
	v.add_child(_option_row("Tamanho do time", [["3 x 3", 3], ["4 x 4", 4], ["5 x 5", 5]], func(x): side_size = x, side_size))
	v.add_child(_option_row("Dificuldade", [["Fácil", 0], ["Normal", 1], ["Difícil", 2]], func(x): difficulty = x, difficulty))
	v.add_child(_option_row("Completar com bots", [["Sim", true], ["Não (só 1 x 1)", false]], func(x): fill_bots = x, fill_bots))
	var tip := Label.new()
	tip.text = "Goleiros são sempre bots. Com a bola: Amarelo chuta, Verde passa (segure = lançamento), Azul = profundidade. Sem a bola: Verde rouba."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 19)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	var go := UITheme.make_button("Começar!", _start_match, 320)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	hud.set_minigame_text("Futebol · escolha como quer jogar")


func _option_row(label: String, opts: Array, setter: Callable, current: Variant) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var buttons: Array[Button] = []
	for o in opts:
		var b := Button.new()
		b.text = o[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(130, 52)
		b.add_theme_font_size_override("font_size", 20)
		buttons.append(b)
		row.add_child(b)
	var paint := func(sel: Variant):
		for i in opts.size():
			var on: bool = opts[i][1] == sel
			for st in ["normal", "hover", "focus", "pressed"]:
				buttons[i].add_theme_stylebox_override(st, UITheme.box(Color("2ecc71") if on else Color("e8e3d6"), 16, Color("1e8449") if on else Color(0, 0, 0, 0), 3 if on else 0, 3))
			buttons[i].add_theme_color_override("font_color", Color.WHITE if on else UITheme.DARK)
	for i in opts.size():
		var val: Variant = opts[i][1]
		buttons[i].pressed.connect(func():
			AudioManager.play_ui("ui_click")
			setter.call(val)
			paint.call(val))
	paint.call(current)
	return row


func _start_match() -> void:
	if _started:
		return
	_started = true
	if is_instance_valid(_setup_panel):
		_setup_panel.queue_free()
	var t: Dictionary = SaveManager.section("stats").get("torneio", {"wins": 0, "round": 0})
	var captain: String = CAPTAINS[int(t.get("round", 0)) % CAPTAINS.size()]
	_rival = "Time do %s" % GameManager.npc_display_name(captain) if captain != "bia" else "Time da Bia"
	var pool: Array[NPC] = []
	for n in npcs.npcs:
		if n.role == "student" and n.active and n.activity != "minigame":
			pool.append(n)
	pool.sort_custom(func(a, b): return a.global_position.distance_squared_to(Vector3(40, 0, -49)) < b.global_position.distance_squared_to(Vector3(40, 0, -49)))
	var mates := (side_size - 1) if fill_bots else 0
	var rivals := side_size if fill_bots else 1
	var lucas := _pick(pool, "lucas")
	var cap := _pick(pool, captain)
	if lucas and mates > 0:
		team_a.append(lucas)
	elif lucas:
		pool.append(lucas)
	if cap:
		team_b.append(cap)
	while not pool.is_empty() and (team_a.size() < mates or team_b.size() < rivals):
		var n: NPC = pool.pop_front()
		if team_a.size() < mates:
			team_a.append(n)
		else:
			team_b.append(n)
	# goleiros: sempre bots (pega quem sobrou)
	keeper_a = pool.pop_front() if not pool.is_empty() else null
	keeper_b = pool.pop_front() if not pool.is_empty() else null
	var all: Array = team_a + team_b
	if keeper_a:
		all.append(keeper_a)
	if keeper_b:
		all.append(keeper_b)
	take_npcs(all)
	for n in all:
		n.run_speed = [3.7, 4.2, 4.7][difficulty]
	time_left = MATCH_TIME
	player.movement_locked = false
	_kickoff(0)
	hud.show_banner("Futebol!", "Seu time x %s" % _rival)


func _pick(pool: Array[NPC], nid: String) -> NPC:
	for n in pool:
		if n.data.get("id", "") == nid:
			pool.erase(n)
			return n
	return null


func _kickoff(team_starts: int) -> void:
	_release(Vector3.ZERO, 0.0)
	ball.reset_ball()
	ball.global_position = Vector3(40, 0.3, -49)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	player.force_stand()
	player.global_position = Vector3(39.0 if team_starts == 0 else 36.0, 0.05, -49.0)
	player.yaw = PI * 0.5
	player.velocity = Vector3.ZERO
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.pitch = -24.0
		player.camera_rig.snap_to_target()
	var pos_a := [Vector3(33, 0.05, -45), Vector3(33, 0.05, -53), Vector3(28, 0.05, -49), Vector3(30, 0.05, -44)]
	var pos_b := [Vector3(44, 0.05, -49), Vector3(47, 0.05, -45), Vector3(47, 0.05, -53), Vector3(52, 0.05, -49), Vector3(50, 0.05, -44)]
	for i in team_a.size():
		team_a[i].teleport(pos_a[i % pos_a.size()], PI * 0.5)
	for i in team_b.size():
		team_b[i].teleport(pos_b[i % pos_b.size()], -PI * 0.5)
	if keeper_a:
		keeper_a.teleport(Vector3(20.6, 0.05, -49), PI * 0.5)
	if keeper_b:
		keeper_b.teleport(Vector3(59.4, 0.05, -49), -PI * 0.5)
	countdown(3.0)
	get_tree().create_timer(3.0).timeout.connect(func(): AudioManager.play_ui("whistle", -6.0))
	_update_hud()


func _update_hud() -> void:
	var who := ""
	if holder == player:
		who = "  ·  com você"
	hud.set_minigame_text("Seu time %d x %d %s  ·  %s%s" % [score_a, score_b, _rival, fmt_time(time_left), who])


# ---------------------------------------------------------------- botões

func play_label() -> String:
	if not _started:
		return ""
	if holder == player:
		return "Solte: chute!" if _charge else "Chutar"
	return "Pedir bola"


func interact_label() -> String:
	if not _started:
		return ""
	return "Passe / Lançar" if holder == player else "Roubar"


func on_jump() -> bool:
	if holder == player and _countdown <= 0.0:
		_through_ball()
		return true
	return false


func on_play() -> bool:
	if not _started or _countdown > 0.0:
		return true
	if holder == player:
		_charge = true
		_power = 0.0
	else:
		_ask_ball()
	return true


func on_play_release() -> bool:
	if _charge:
		_charge = false
		hud.set_meter(-1.0)
		if holder == player:
			_shoot_player(_power)
	return true


func on_interact() -> bool:
	if not _started or _countdown > 0.0:
		return true
	if holder == player:
		_pass_down_ms = Time.get_ticks_msec()
	else:
		_tackle()
	return true


func on_interact_release() -> bool:
	if _pass_down_ms == 0:
		return true
	var held := Time.get_ticks_msec() - _pass_down_ms
	_pass_down_ms = 0
	if holder != player:
		return true
	if held > 350:
		_long_pass()
	else:
		_short_pass()
	return true


## "in" seguro: procurar o jogador num Array[NPC] gera erro no Godot.
func _has(arr: Array, n: Object) -> bool:
	if n == null:
		return false
	if arr.is_typed() and not (n is NPC):
		return false
	return arr.has(n)


func _fwd(n: Node3D) -> Vector3:
	var y: float = n.get("yaw") if n.get("yaw") != null else 0.0
	return Vector3(sin(y), 0, cos(y))


## Colega mais livre na direção em que o jogador olha.
func _best_mate(from: Node3D, mates: Array, max_dist := 22.0) -> Node3D:
	var fwd := _fwd(from)
	var best: Node3D = null
	var best_score := INF
	for n in mates:
		if n == from or not is_instance_valid(n):
			continue
		var to: Vector3 = (n as Node3D).global_position - from.global_position
		to.y = 0
		var d := to.length()
		if d < 2.0 or d > max_dist:
			continue
		var ang := fwd.angle_to(to.normalized())
		var press := _pressure(n as Node3D, _has(team_a, from) or from == player or from == keeper_a)
		var s := ang * 4.0 + d * 0.08 + press * 2.0
		if s < best_score:
			best_score = s
			best = n
	return best


## 0..1: quanto o colega está marcado.
func _pressure(n: Node3D, is_team_a: bool) -> float:
	var foes: Array = team_b if is_team_a else (team_a + [player])
	var m := 0.0
	for f in foes:
		var d: float = (f as Node3D).global_position.distance_to(n.global_position)
		m = maxf(m, clampf(1.0 - d / 3.0, 0.0, 1.0))
	return m


func _mates_of_player() -> Array:
	return team_a.duplicate()


func _short_pass() -> void:
	var t := _best_mate(player, _mates_of_player(), 18.0)
	if t == null:
		_kick_from(player, _fwd(player), 7.0, 0.4)
		return
	var to := t.global_position - ball.global_position
	to.y = 0
	_kick_from(player, to.normalized(), clampf(to.length() * 0.95 + 3.0, 5.0, 13.0), 0.3)
	(t as NPC).say("Tô livre!", 1.0)


func _long_pass() -> void:
	# lançamento: bola alta para o colega mais adiantado
	var best: Node3D = null
	for n in team_a:
		if best == null or n.global_position.x > best.global_position.x:
			best = n
	if best == null:
		_kick_from(player, _fwd(player), 11.0, 4.5)
		return
	var lead := best.global_position + Vector3(3.0, 0, 0)
	var to := lead - ball.global_position
	to.y = 0
	var d := to.length()
	_kick_from(player, to.normalized(), clampf(d * 0.62 + 2.0, 6.0, 15.0), clampf(d * 0.32, 3.0, 6.5))
	hud.show_banner("Lançamento!", "")


func _through_ball() -> void:
	# passe em profundidade: na frente do colega, rumo ao gol
	var t := _best_mate(player, _mates_of_player(), 24.0)
	if t == null:
		_kick_from(player, _fwd(player), 9.0, 0.3)
		return
	var ahead := t.global_position + (GOAL_A - t.global_position).normalized() * 4.5
	ahead.z = clampf(ahead.z, COURT.position.y + 1.0, COURT.end.y - 1.0)
	var to := ahead - ball.global_position
	to.y = 0
	_kick_from(player, to.normalized(), clampf(to.length() * 0.9 + 3.0, 6.0, 14.0), 0.2)
	(t as NPC).say("Vai!", 1.0)
	if t is NPC:
		_think[(t as NPC).get_instance_id()] = {"run_to": ahead, "t": 2.5}


func _shoot_player(power: float) -> void:
	var fwd := _fwd(player)
	var to_goal := GOAL_A - player.global_position
	to_goal.y = 0
	var dir := fwd
	# mira assistida aos cantos se estiver virado para o gol
	if fwd.angle_to(to_goal.normalized()) < deg_to_rad(45):
		var corner := 1.05 * (1.0 if fwd.z > to_goal.normalized().z else -1.0)
		var aim := GOAL_A + Vector3(0, 0, corner * randf_range(0.6, 1.0))
		dir = (aim - player.global_position)
		dir.y = 0
		dir = dir.normalized()
	_kick_from(player, dir, lerpf(7.0, 16.0, power), lerpf(0.6, 3.0, power))


func _ask_ball() -> void:
	if holder is NPC and _has(team_a, holder):
		var h := holder as NPC
		var to := player.global_position - ball.global_position
		to.y = 0
		h.say("Toma!", 1.0)
		_kick_from(h, to.normalized(), clampf(to.length() * 0.95 + 3.0, 5.0, 13.0), 0.3)
	else:
		GameManager.show_toast("Pedindo a bola! Fique livre de marcação.")


func _tackle() -> void:
	if _tackle_cd > 0.0:
		return
	_tackle_cd = 0.8
	player.visual.play("kick")
	if holder != null and holder != player and not _has(team_a, holder) and holder != keeper_b:
		var d := holder.global_position.distance_to(player.global_position)
		if d < 1.8 and _hold_immune <= 0.0:
			var chance: float = [0.85, 0.7, 0.55][difficulty]
			if randf() < chance:
				(holder as NPC).say("Ei!", 0.8)
				_take(player)
				hud.show_banner("Roubou!", "")
				return
		GameManager.show_toast("Errou o bote!")


# ---------------------------------------------------------------- posse

func _take(n: Node3D) -> void:
	holder = n
	_hold_immune = 0.6
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	_last_touch_team = 0 if (n == player or _has(team_a, n) or n == keeper_a) else 1
	if n is NPC:
		_think[(n as NPC).get_instance_id()] = {"decide": randf_range(0.5, 1.1)}


func _release(dir: Vector3, power: float, lift := 0.0) -> void:
	if holder == null and not ball.freeze:
		return
	holder = null
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = dir * power + Vector3.UP * lift
	_free_t = 0.0


func _kick_from(n: Node3D, dir: Vector3, power: float, lift: float) -> void:
	if holder != n:
		return
	if n is NPC:
		(n as NPC).visual.play("kick")
	elif n == player:
		player.visual.play("kick")
	# solta a bola um pouco à frente para não bater no próprio pé
	ball.global_position = n.global_position + dir * 0.7 + Vector3(0, 0.15, 0)
	_release(dir, power, lift)
	AudioManager.play_3d("kick", ball.global_position, -2.0)
	if power > 10.0:
		Effects.burst(ball.global_position, "dust")


func _dribble_pos(n: Node3D) -> Vector3:
	var fwd := _fwd(n)
	var sp := 0.0
	if n == player:
		sp = Vector2(player.velocity.x, player.velocity.z).length()
	elif n is NPC:
		sp = 4.0 if (n as NPC).moving else 0.0
	var loose := DRIBBLE_DIST + (0.25 if sp > 4.6 else 0.0) + sin(Time.get_ticks_msec() * 0.012) * 0.06 * clampf(sp / 4.0, 0.0, 1.0)
	return n.global_position + fwd * loose + Vector3(0, 0.11, 0)


# ---------------------------------------------------------------- jogo

func running_game() -> bool:
	return running and is_instance_valid(ball)


func tick(delta: float) -> void:
	if not running or not _started:
		return
	if counting(delta):
		if holder == null:
			ball.linear_velocity = Vector3.ZERO
			ball.global_position = Vector3(40, 0.3, -49)
		return
	if _goal_pause > 0.0:
		_goal_pause -= delta
		if _goal_pause <= 0.0:
			if score_a >= 3 or score_b >= 3:
				_finish()
			else:
				_kickoff(1 if _last_touch_team == 0 else 0)
		return
	time_left -= delta
	_tackle_cd = maxf(_tackle_cd - delta, 0.0)
	_hold_immune = maxf(_hold_immune - delta, 0.0)
	if _charge:
		_power = minf(_power + delta * 0.9, 1.0)
		hud.set_meter(_power)
	_update_hud()
	if time_left <= 0.0:
		_finish()
		return
	# bola colada no pé de quem conduz
	if holder != null:
		ball.global_position = _dribble_pos(holder)
		ball.rotate_x(delta * 8.0)
	else:
		_free_t += delta
		_try_catch()
	_check_goal()
	_check_out(delta)
	for n in team_a:
		_field_ai(n, 0, delta)
	for n in team_b:
		_field_ai(n, 1, delta)
	if keeper_a:
		_keeper_ai(keeper_a, 20.6, 1.0, delta)
	if keeper_b:
		_keeper_ai(keeper_b, 59.4, -1.0, delta)
	player._emit_context()


## Bola livre: quem estiver mais perto e com a bola baixa domina.
func _try_catch() -> void:
	if _free_t < 0.18:
		return
	var bp := ball.global_position
	if bp.y > 0.7 or ball.linear_velocity.length() > 13.0:
		return
	var cands: Array = [player] + team_a + team_b
	var best: Node3D = null
	var bd := CATCH_DIST
	for n in cands:
		var d := Vector2((n as Node3D).global_position.x - bp.x, (n as Node3D).global_position.z - bp.z).length()
		if d < bd:
			bd = d
			best = n
	if best:
		_take(best)
		if best == player:
			AudioManager.play_ui("ui_click", -8.0)


func _check_goal() -> void:
	var p := ball.global_position
	if absf(p.z + 49.0) < GOAL_HALF and p.y < 2.0:
		if p.x > 60.15 and p.x < 61.2:
			_goal(0)
		elif p.x < 19.85 and p.x > 18.8:
			_goal(1)


func _goal(team: int) -> void:
	holder = null
	ball.freeze = false
	_last_touch_team = team
	if team == 0:
		score_a += 1
		hud.show_banner("GOOOL!", "Seu time %d x %d" % [score_a, score_b])
		player.visual.play("celebrate")
		AudioManager.play_ui("applause", -4.0)
		Effects.burst(ball.global_position, "confetti")
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
	if _out_t > 1.0:
		_out_t = 0.0
		holder = null
		ball.freeze = false
		var nx := clampf(p.x, COURT.position.x + 1.5, COURT.end.x - 1.5)
		var nz := clampf(p.z, COURT.position.y + 1.0, COURT.end.y - 1.0)
		ball.global_position = Vector3(nx, 0.3, nz)
		ball.linear_velocity = Vector3.ZERO
		hud.show_banner("Lateral!", "")


func _go(n: NPC, tgt: Vector3, run: bool) -> void:
	tgt.x = clampf(tgt.x, COURT.position.x + 0.8, COURT.end.x - 0.8)
	tgt.z = clampf(tgt.z, COURT.position.y + 0.8, COURT.end.y - 0.8)
	if n.global_position.distance_to(tgt) > 0.4:
		n.running = run
		n.moving = true
		n.path = PackedVector3Array([Vector3(tgt.x, 0.05, tgt.z)])
		n.path_i = 0


func _field_ai(n: NPC, team: int, delta: float) -> void:
	var key := n.get_instance_id()
	var st: Dictionary = _think.get(key, {})
	var goal := GOAL_A if team == 0 else GOAL_B
	var my_goal := GOAL_B if team == 0 else GOAL_A
	var mates: Array = (team_a + [player]) if team == 0 else team_b
	var foes: Array = team_b if team == 0 else (team_a + [player])
	var bp := ball.global_position
	# corrida pedida (passe em profundidade)
	if st.has("run_to") and holder != n:
		st.t = float(st.t) - delta
		if st.t > 0.0:
			_go(n, st.run_to, true)
			_think[key] = st
			return
		st.erase("run_to")
	if holder == n:
		# conduz rumo ao gol e decide de tempos em tempos
		st.decide = float(st.get("decide", 0.8)) - delta
		var to_goal := goal - n.global_position
		to_goal.y = 0
		n.yaw = lerp_angle(n.yaw, atan2(to_goal.x, to_goal.z), 1.0 - exp(-4.0 * delta))
		_go(n, n.global_position + to_goal.normalized() * 3.0, false)
		var pressed := _pressure(n, team == 0) > 0.45
		if st.decide <= 0.0 or (pressed and st.decide < 0.4):
			st.decide = randf_range(0.7, 1.3)
			var dist_goal := to_goal.length()
			if dist_goal < 13.0 and randf() < 0.65:
				var aim := goal + Vector3(0, 0, randf_range(-1.2, 1.2))
				var d := aim - n.global_position
				d.y = 0
				_kick_from(n, d.normalized(), randf_range(10.0, 14.0) * [0.85, 1.0, 1.1][difficulty], randf_range(0.6, 1.8))
			elif pressed or randf() < 0.35:
				var t := _best_mate(n, mates, 18.0)
				if t:
					var to := t.global_position - n.global_position
					to.y = 0
					_kick_from(n, to.normalized(), clampf(to.length() * 0.95 + 3.0, 5.0, 13.0), 0.3)
		_think[key] = st
		return
	var holder_is_mate := _has(mates, holder)
	var holder_is_foe := _has(foes, holder)
	var nearest := true
	for o in mates:
		if o != n and o != player and (o as Node3D).global_position.distance_to(bp) < n.global_position.distance_to(bp):
			nearest = false
	if team == 0 and player.global_position.distance_to(bp) < n.global_position.distance_to(bp) and holder == null:
		nearest = false
	if holder == null and nearest:
		_go(n, bp, true)
	elif holder_is_foe and nearest:
		# marca e tenta roubar
		_go(n, holder.global_position, true)
		if n.global_position.distance_to(holder.global_position) < 1.3 and _hold_immune <= 0.0 and holder != keeper_a and holder != keeper_b:
			var rate: float = float([0.35, 0.7, 1.1][difficulty]) * (0.6 if holder == player else 1.0)
			if randf() < rate * delta:
				n.visual.play("kick")
				if holder == player:
					hud.show_banner("Roubaram a bola!", "")
				_take(n)
	else:
		# posicionamento: apoio ao ataque ou volta para defender
		var idx: int = maxi(mates.find(n), 0)
		var lane := -45.0 if idx % 2 == 0 else -53.0
		var attack := holder_is_mate
		var base_x := lerpf(my_goal.x, goal.x, 0.62 if attack else 0.35)
		var tx := lerpf(base_x, bp.x, 0.35) + (2.5 if attack else -1.0) * (1.0 if team == 0 else -1.0)
		var tgt := Vector3(tx, 0.05, lerpf(lane, bp.z, 0.25))
		if n.global_position.distance_to(tgt) > 1.2:
			_go(n, tgt, n.global_position.distance_to(tgt) > 5.0)
		else:
			n.face(bp)
	_think[key] = st


func _keeper_ai(k: NPC, x: float, dir: float, delta: float) -> void:
	var key := k.get_instance_id()
	var st: Dictionary = _think.get(key, {})
	var bp := ball.global_position
	if holder == k:
		# segura um pouco e repõe para um colega
		st.wait = float(st.get("wait", 1.0)) - delta
		if st.wait <= 0.0:
			st.erase("wait")
			var mates: Array = (team_a + [player]) if k == keeper_a else team_b
			var t: Node3D = null
			for m in mates:
				if t == null or (m as Node3D).global_position.distance_to(k.global_position) < t.global_position.distance_to(k.global_position) + randf_range(-3, 3):
					t = m
			var to := (t.global_position - k.global_position) if t else Vector3(dir, 0, 0)
			to.y = 0
			_kick_from(k, to.normalized(), clampf(to.length() * 0.8 + 4.0, 6.0, 13.0), 1.2)
		_think[key] = st
		return
	var tz := clampf(bp.z, -49.0 - GOAL_HALF + 0.3, -49.0 + GOAL_HALF - 0.3)
	# defesa: bola vindo para o gol perto do goleiro
	var toward := ball.linear_velocity.x * -dir > 2.0
	var d := Vector2(bp.x - k.global_position.x, bp.z - k.global_position.z).length()
	if holder == null and toward and d < 1.6 and bp.y < 1.8:
		var save: float = [0.45, 0.62, 0.8][difficulty]
		if randf() < save:
			k.visual.play("pickup")
			k.say("Defendeu!", 1.2)
			_take(k)
			st["wait"] = 1.0
			_think[key] = st
			return
	if holder == null and absf(bp.x - x) < 3.0 and absf(bp.z + 49) < 3.0:
		_go(k, bp, true)
		if d < CATCH_DIST:
			_take(k)
			st["wait"] = 0.8
	else:
		var tgt := Vector3(x, 0.05, tz)
		if k.global_position.distance_to(tgt) > 0.3:
			k.moving = true
			k.running = false
			k.path = PackedVector3Array([tgt])
			k.path_i = 0
		else:
			k.face(bp)
	_think[key] = st


func _finish() -> void:
	if not running:
		return
	var won := 1 if score_a > score_b else (0 if score_a == score_b else -1)
	var stats: Dictionary = SaveManager.section("stats")
	var t: Dictionary = stats.get("torneio", {"wins": 0, "round": 0})
	var extra := ""
	if won > 0 and _started:
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
	if is_instance_valid(_setup_panel):
		_setup_panel.queue_free()
	hud.set_meter(-1.0)
	if is_instance_valid(ball):
		holder = null
		ball.freeze = false
		ball.reset_ball()
	for n in team_a + team_b + [keeper_a, keeper_b]:
		if is_instance_valid(n):
			(n as NPC).run_speed = 4.3
	super.cleanup()
