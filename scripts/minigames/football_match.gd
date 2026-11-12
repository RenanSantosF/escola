extends Minigame
## Futebol na quadra, estilo videogame:
## - a bola CONDUZIDA fica colada no pé (correr = bola mais solta);
## - COM A BOLA: Amarelo (segure/solte) = chute com força; Verde toque = passe;
##   Verde segurando = lançamento (passe alto e longo); Azul = passe em
##   profundidade (na frente do colega que corre);
## - SEM A BOLA: Verde = roubar a bola (carrinho); Amarelo = pedir a bola;
## - só gente de verdade na linha (mínimo 2 jogadores); os goleiros são bots.

const COURT := Rect2(20, -59, 40, 20)
const GOAL_HALF := 1.45
const MATCH_TIME := 150.0
const CAPTAINS := ["bia", "rafa", "pedro"]
const GOAL_A := Vector3(60, 0, -49)  # gol que o time do jogador ataca
const GOAL_B := Vector3(20, 0, -49)
const DRIBBLE_DIST := 0.5
const CATCH_DIST := 0.95
const TACKLE_DIST := 2.4
const TACKLE_CHANCE := 0.8

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
var fill_bots := false  # sem bots na linha: só a turma
# ---- online: o celular do anfitrião simula a bola e os bots; os outros mandam
# os comandos (chute, passe, roubo) e recebem o jogo ~12 vezes por segundo.
var net_role := ""  # "" sozinho, "host" ou "client"
var my_team := "a"
var humans_a: Array = []  # colegas online no time do anfitrião (nós dos avatares)
var humans_b: Array = []
var _human_id := {}  # avatar -> id do jogador
var _net_t := 0.0
var _ko := 0  # contador de saídas de bola (o cliente se reposiciona)
var _last_state: Dictionary = {}
var _state_age := 0.0
var _puppets: Array[NPC] = []
var _client_holder := ""
var _client_ko := -1
var _ball_target := Vector3(40, 0.3, -49)
var _shot_n := 0  # conta os chutes (o goleiro decide UMA vez por chute)
var _keeper_call := {}  # goleiro -> [chute, vai defender?]


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
	if not is_net():
		end_game(0, "O futebol precisa de pelo menos 2 jogadores. Chame a turma!", 0, 0)
		return
	my_team = str((net.get("teams", {}) as Dictionary).get(net.get("me", ""), "a"))
	if str(net.get("host", "")) == str(net.get("me", "")):
		net_role = "host"
		_start_match()  # sem seletor: entra direto (times = quem está jogando)
	else:
		net_role = "client"
		_start_client()


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
	v.add_child(_option_row("Completar com bots", [["Sim", true], ["Não (só quem está jogando)" if is_multi() else "Não (só 1 x 1)", false]], func(x): fill_bots = x, fill_bots))
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
	if net_role == "host":
		_collect_humans()
	var mates := maxi(side_size - 1 - humans_a.size(), 0) if fill_bots else 0
	var rivals := maxi(side_size - humans_b.size(), 0) if fill_bots else 0
	# quem está por perto ou colegas de treino (goleiros sempre bots: +2)
	var pool: Array[NPC] = students(mates + rivals + 2, Vector3(40, 0.05, -49), ["lucas", captain])
	var lucas := _pick(pool, "lucas")
	var cap := _pick(pool, captain)
	if lucas and mates > 0 and team_a.size() < mates:
		team_a.append(lucas)
	elif lucas:
		pool.append(lucas)
	if cap and rivals > 0:
		team_b.append(cap)
	elif cap:
		pool.append(cap)
	while not pool.is_empty() and (team_a.size() < mates or team_b.size() < rivals):
		var n: NPC = pool.pop_front()
		if team_a.size() < mates:
			team_a.append(n)
		else:
			team_b.append(n)
	# goleiros: sempre bots (pega quem sobrou)
	keeper_a = pool.pop_front() if not pool.is_empty() else null
	keeper_b = pool.pop_front() if not pool.is_empty() else null
	for left_over in pool:
		npcs.release_practice(left_over)
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
	if net_role == "host":
		_rival = "o time laranja"
		hud.show_banner("Futebol com a turma!", "Você e seu time contra o time laranja")
	else:
		hud.show_banner("Futebol!", "Seu time x %s" % _rival)


func _pick(pool: Array[NPC], nid: String) -> NPC:
	for n in pool:
		if n.data.get("id", "") == nid:
			pool.erase(n)
			return n
	return null


func _kickoff(team_starts: int) -> void:
	_ko += 1
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
	if not _started or (net_role == "client" and _last_state.is_empty()):
		return ""
	if holder == player:
		return "Solte: chute!" if _charge else "Chutar"
	return "Pedir bola"


func interact_label() -> String:
	if not _started:
		return ""
	return "Passe / Lançar" if holder == player else "Roubar"


func _client_blocked() -> bool:
	return _last_state.is_empty() or int(_last_state.get("c", 0)) == 1


func on_jump() -> bool:
	if net_role == "client":
		if holder == player and not _client_blocked():
			_client_cmd("through")
			player.visual.play("kick")
		return true
	if holder == player and _countdown <= 0.0:
		_through_ball()
		return true
	return false


func on_play() -> bool:
	if net_role == "client":
		if _client_blocked():
			return true
		if holder == player:
			_charge = true
			_power = 0.0
		else:
			_client_cmd("ask")
			GameManager.show_toast("Pedindo a bola!")
		return true
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
		if net_role == "client":
			if holder == player:
				_client_cmd("shoot", {"p": snappedf(_power, 0.01)})
				player.visual.play("kick")
		elif holder == player:
			_shoot_player(_power)
	return true


func on_interact() -> bool:
	if net_role == "client":
		if _client_blocked():
			return true
		if holder == player:
			_pass_down_ms = Time.get_ticks_msec()
		elif _tackle_cd <= 0.0:
			_tackle_cd = 0.6
			player.visual.play("kick")
			var to := ball.global_position - player.global_position
			to.y = 0
			if to.length() > 0.1 and to.length() < 3.5:
				player.velocity = to.normalized() * 8.0  # bote: passinho rápido na bola
			_client_cmd("tackle")
		return true
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
	if net_role == "client":
		_client_cmd("long" if held > 350 else "pass")
		player.visual.play("kick")
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
	var y := 0.0
	if n.get("yaw") != null:
		y = n.get("yaw")
	elif n.get_child_count() > 0 and n.get_child(0) is Node3D:
		y = (n.get_child(0) as Node3D).rotation.y  # avatar online: o visual guarda o ângulo
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
	var foes: Array = (team_b + humans_b) if is_team_a else (team_a + [player] + humans_a)
	var m := 0.0
	for f in foes:
		var d: float = (f as Node3D).global_position.distance_to(n.global_position)
		m = maxf(m, clampf(1.0 - d / 3.0, 0.0, 1.0))
	return m


## Passe rasteiro e rápido (antes era lento e dava tempo de cortar).
static func pass_power(dist: float) -> float:
	return clampf(dist * 1.15 + 6.0, 9.0, 19.0)


func _mates_of_player() -> Array:
	return team_a + humans_a


func _short_pass() -> void:
	var t := _best_mate(player, _mates_of_player(), 18.0)
	if t == null:
		_kick_from(player, _fwd(player), 7.0, 0.4)
		return
	var to := t.global_position - ball.global_position
	to.y = 0
	_kick_from(player, to.normalized(), pass_power(to.length()), 0.12)
	if t is NPC:
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
	_kick_from(player, to.normalized(), pass_power(to.length()), 0.1)
	if t is NPC:
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
		var corner := 1.12 * (1.0 if fwd.z > to_goal.normalized().z else -1.0)
		var aim := GOAL_A + Vector3(0, 0, corner * randf_range(0.75, 1.0))
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
		_kick_from(h, to.normalized(), pass_power(to.length()), 0.12)
	else:
		GameManager.show_toast("Pedindo a bola! Fique livre de marcação.")


func _tackle() -> void:
	if _tackle_cd > 0.0:
		return
	_tackle_cd = 0.6
	player.visual.play("kick")
	if holder != null and holder != player and not _has(team_a, holder) and not humans_a.has(holder) and holder != keeper_b:
		var to := holder.global_position - player.global_position
		to.y = 0
		var d := to.length()
		# bote: dá um passinho rápido na direção de quem está com a bola
		if d > 0.1 and d < 3.5:
			player.velocity = to.normalized() * 8.0
		if d < TACKLE_DIST and _hold_immune <= 0.0:
			if randf() < TACKLE_CHANCE:
				if holder is NPC:
					(holder as NPC).say("Ei!", 0.8)
				_take(player)
				hud.show_banner("Roubou!", "")
				AudioManager.play_ui("catch", -4.0)
				return
		GameManager.show_toast("Errou o bote! Chegue mais perto." if d >= TACKLE_DIST else "Quase! Tente de novo.")


# ---------------------------------------------------------------- posse

func _take(n: Node3D) -> void:
	holder = n
	_hold_immune = 0.4
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	_last_touch_team = 0 if (n == player or _has(team_a, n) or n == keeper_a or humans_a.has(n)) else 1
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
	_shot_n += 1


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
	else:
		sp = 3.0
	var loose := DRIBBLE_DIST + (0.25 if sp > 4.6 else 0.0) + sin(Time.get_ticks_msec() * 0.012) * 0.06 * clampf(sp / 4.0, 0.0, 1.0)
	return n.global_position + fwd * loose + Vector3(0, 0.11, 0)


# ---------------------------------------------------------------- jogo

func running_game() -> bool:
	return running and is_instance_valid(ball)


func tick(delta: float) -> void:
	if not running:
		return
	if net_role == "client":
		_client_tick(delta)
		return
	if not _started:
		return
	if net_role == "host":
		_net_send(delta)
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
	if bp.y > 0.7 or ball.linear_velocity.length() > 21.0:
		return
	var cands: Array = [player] + team_a + team_b + humans_a + humans_b
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
		AudioManager.play_ui("goal", -2.0)
		Effects.burst(ball.global_position, "confetti")
		popup(ball.global_position + Vector3(0, 2.0, 0), "GOOOL!", Color("ffd23f"), 110)
		if player.camera_rig:
			player.camera_rig.shake(0.15)
		for n in team_a:
			n.visual.play("clap")
	else:
		score_b += 1
		hud.show_banner("Gol do adversário", "Seu time %d x %d" % [score_a, score_b])
		AudioManager.play_ui("crowd_cheer", -12.0)
		note_miss()
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
	var mates: Array = (team_a + [player] + humans_a) if team == 0 else (team_b + humans_b)
	var foes: Array = (team_b + humans_b) if team == 0 else (team_a + [player] + humans_a)
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
		if o != n and o is NPC and (o as Node3D).global_position.distance_to(bp) < n.global_position.distance_to(bp):
			nearest = false
	# colega de verdade mais perto da bola livre: o bot deixa ele ir
	if holder == null:
		for o in mates:
			if not (o is NPC) and (o as Node3D).global_position.distance_to(bp) < n.global_position.distance_to(bp):
				nearest = false
	if holder == null and nearest:
		_go(n, bp, true)
	elif holder_is_foe and nearest:
		# marca e tenta roubar
		_go(n, holder.global_position, true)
		if n.global_position.distance_to(holder.global_position) < 1.3 and _hold_immune <= 0.0 and holder != keeper_a and holder != keeper_b:
			var rate: float = float([0.35, 0.7, 1.1][difficulty]) * (0.6 if not (holder is NPC) else 1.0)
			if randf() < rate * delta:
				n.visual.play("kick")
				if holder == player:
					hud.show_banner("Roubaram a bola!", "")
				_take(n)
				_think[n.get_instance_id()] = {"decide": randf_range(0.5, 1.1)}
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
			var mates: Array = (team_a + [player] + humans_a) if k == keeper_a else (team_b + humans_b)
			var t: Node3D = null
			for m in mates:
				if t == null or (m as Node3D).global_position.distance_to(k.global_position) < t.global_position.distance_to(k.global_position) + randf_range(-3, 3):
					t = m
			var to := (t.global_position - k.global_position) if t else Vector3(dir, 0, 0)
			to.y = 0
			_kick_from(k, to.normalized(), clampf(to.length() * 0.8 + 4.0, 6.0, 13.0), 1.2)
		_think[key] = st
		return
	var tz := clampf(-49.0 + (bp.z + 49.0) * 0.6, -49.0 - GOAL_HALF + 0.5, -49.0 + GOAL_HALF - 0.5)
	# defesa: bola vindo para o gol perto do goleiro
	var toward := ball.linear_velocity.x * -dir > 2.0
	var d := Vector2(bp.x - k.global_position.x, bp.z - k.global_position.z).length()
	# decide UMA vez por chute, quando a bola vem para o gol:
	# chute forte e no canto é mais difícil de pegar
	if holder == null and toward and absf(bp.x - x) < 9.0:
		var call: Array = _keeper_call.get(k, [-1, false])
		if int(call[0]) != _shot_n:
			var speed := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
			var vx := ball.linear_velocity.x
			var tt := (x - bp.x) / vx if absf(vx) > 0.1 else 0.0
			var zat := bp.z + ball.linear_velocity.z * maxf(tt, 0.0)
			var corner := clampf(absf(zat + 49.0) / GOAL_HALF, 0.0, 1.0)
			var save: float = [0.4, 0.52, 0.64][difficulty]
			save *= 1.0 - corner * 0.55
			save *= 1.0 - clampf((speed - 8.0) / 8.0, 0.0, 1.0) * 0.45
			call = [_shot_n, randf() < save]
			_keeper_call[k] = call
			if not bool(call[1]):
				# erra: pula para o lado errado e a bola passa por ele
				if k.has_method("let_pass"):
					k.let_pass(1.4)
				st["dive"] = 1.0
				st["dive_z"] = -49.0 - signf(zat + 49.0 + 0.01) * GOAL_HALF * 0.8
				_think[key] = st
		if bool(call[1]) and d < 1.6 and bp.y < 1.8:
			k.visual.play("pickup")
			k.say("Defendeu!", 1.2)
			_take(k)
			st["wait"] = 1.0
			_think[key] = st
			return
	if float(st.get("dive", 0.0)) > 0.0:
		st["dive"] = float(st.dive) - delta
		_go(k, Vector3(x, 0.05, float(st.dive_z)), true)
		_think[key] = st
		return
	# bola devagar perto da área: o goleiro vai buscar
	var slow := ball.linear_velocity.length() < 5.0
	if holder == null and slow and absf(bp.x - x) < 3.0 and absf(bp.z + 49) < 3.0:
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
	if net_role == "host":
		NetworkManager.mg_send_relay(str(net.gid), _state_dict(true))
		NetworkManager.mg_team_result(str(net.gid), score_a, score_b)
	var stats: Dictionary = SaveManager.section("stats")
	var t: Dictionary = stats.get("torneio", {"wins": 0, "round": 0})
	var extra := ""
	if won > 0 and _started:
		t["wins"] = int(t.get("wins", 0)) + 1
		t["round"] = int(t.get("round", 0)) + 1
		if int(t.wins) % 3 == 0:
			extra = "  ·  CAMPEÃO DO TORNEIO!"
			GameManager.add_rewards(110, 0)
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
	for n in team_a + team_b + [keeper_a, keeper_b] + _puppets:
		if is_instance_valid(n):
			(n as NPC).run_speed = 4.3
	if NetworkManager.mg_relay.is_connected(_on_relay):
		NetworkManager.mg_relay.disconnect(_on_relay)
	super.cleanup()


# ================================================================ online
# Anfitrião (host): simula tudo e manda o estado. Os colegas (client) mandam
# comandos e desenham a bola e os bots do jeito que o anfitrião mandou.

func _session() -> Node:
	return get_tree().get_first_node_in_group("online_session")


func _remote_root(id: String) -> Node3D:
	var s := _session()
	if s and s.remotes.has(id):
		return s.remotes[id].root
	return null


## Anfitrião: monta os times com os avatares dos colegas.
func _collect_humans() -> void:
	humans_a.clear()
	humans_b.clear()
	_human_id.clear()
	var teams: Dictionary = net.get("teams", {})
	for id in net.get("players", []):
		if str(id) == str(net.get("me", "")):
			continue
		_add_human(str(id), str(teams.get(id, "b")))
	if not NetworkManager.mg_relay.is_connected(_on_relay):
		NetworkManager.mg_relay.connect(_on_relay)


func _add_human(id: String, team: String) -> bool:
	var r := _remote_root(id)
	if r == null or _human_id.has(r):
		return false
	_human_id[r] = id
	(humans_a if team == "a" else humans_b).append(r)
	return true


func _remove_human(id: String) -> void:
	for r in _human_id.keys():
		if _human_id[r] == id:
			if holder == r:
				_release(Vector3.ZERO, 0.0)
			humans_a.erase(r)
			humans_b.erase(r)
			_human_id.erase(r)


func _id_of(n: Node3D) -> String:
	if n == null:
		return ""
	if n == player:
		return str(net.get("me", ""))
	if _human_id.has(n):
		return _human_id[n]
	var bots := _bot_list()
	var i := bots.find(n)
	return "b%d" % i if i >= 0 else ""


## Bots em ordem fixa: [papel, npc]. Papel: 0 time a, 1 time b, 2 goleiro a, 3 goleiro b.
func _bot_list() -> Array:
	var out: Array = []
	for n in team_a:
		out.append(n)
	for n in team_b:
		out.append(n)
	if keeper_a:
		out.append(keeper_a)
	if keeper_b:
		out.append(keeper_b)
	return out


func _bot_role(n: NPC) -> int:
	if n == keeper_a:
		return 2
	if n == keeper_b:
		return 3
	return 0 if _has(team_a, n) else 1


func _state_dict(ended := false) -> Dictionary:
	var bp := ball.global_position
	var bots: Array = []
	for n in _bot_list():
		var b := n as NPC
		bots.append([snappedf(b.global_position.x, 0.01), snappedf(b.global_position.z, 0.01), snappedf(b.yaw, 0.01), 1 if b.moving else 0, _bot_role(b)])
	var d := {"a": score_a, "b": score_b, "t": snappedf(time_left, 0.1), "c": 1 if _countdown > 0.0 else 0,
		"ball": [snappedf(bp.x, 0.01), snappedf(bp.y, 0.01), snappedf(bp.z, 0.01)], "h": _id_of(holder), "ko": _ko, "bots": bots}
	if ended:
		d["end"] = 1
	return d


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
		_host_input(from, d)
	elif net_role == "client" and from == str(net.get("host", "")):
		_last_state = d
		_state_age = 0.0


## Anfitrião: comando de um colega.
func _host_input(from: String, d: Dictionary) -> void:
	var r: Node3D = null
	for k in _human_id.keys():
		if _human_id[k] == from:
			r = k
	if r == null or not _started or _countdown > 0.0 or _goal_pause > 0.0:
		return
	var team_a_side := humans_a.has(r)
	var mates: Array = (team_a + [player] + humans_a) if team_a_side else (team_b + humans_b)
	mates.erase(r)
	var goal := GOAL_A if team_a_side else GOAL_B
	var dir_arr: Array = d.get("d", [])
	var fwd := Vector3(float(dir_arr[0]), 0, float(dir_arr[1])).normalized() if dir_arr.size() == 2 else _fwd(r)
	match str(d.get("k", "")):
		"shoot":
			if holder != r:
				return
			var power := clampf(float(d.get("p", 0.5)), 0.0, 1.0)
			var to_goal := goal - r.global_position
			to_goal.y = 0
			var dir := fwd
			if fwd.angle_to(to_goal.normalized()) < deg_to_rad(45):
				var aim := goal + Vector3(0, 0, randf_range(-1.05, 1.05))
				dir = (aim - r.global_position)
				dir.y = 0
				dir = dir.normalized()
			_kick_from(r, dir, lerpf(7.0, 16.0, power), lerpf(0.6, 3.0, power))
		"pass", "long", "through":
			if holder != r:
				return
			var t := _best_mate(r, mates, 24.0 if d.k != "pass" else 18.0)
			if t == null:
				_kick_from(r, fwd, 8.0, 0.4)
				return
			var target := t.global_position
			var lift := 0.12
			if d.k == "through":
				target += (goal - t.global_position).normalized() * 4.5
				target.z = clampf(target.z, COURT.position.y + 1.0, COURT.end.y - 1.0)
				lift = 0.2
			var to := target - ball.global_position
			to.y = 0
			var dist := to.length()
			if d.k == "long":
				_kick_from(r, to.normalized(), clampf(dist * 0.62 + 2.0, 6.0, 15.0), clampf(dist * 0.32, 3.0, 6.5))
			else:
				_kick_from(r, to.normalized(), pass_power(dist), lift)
			if t is NPC:
				(t as NPC).say("Vai!" if d.k == "through" else "Tô livre!", 1.0)
				if d.k == "through":
					_think[t.get_instance_id()] = {"run_to": target, "t": 2.5}
		"tackle":
			if holder == null or holder == r or mates.has(holder) or holder == keeper_a or holder == keeper_b:
				return
			if holder.global_position.distance_to(r.global_position) < TACKLE_DIST and _hold_immune <= 0.0 and randf() < TACKLE_CHANCE:
				if holder is NPC:
					(holder as NPC).say("Ei!", 0.8)
				elif holder == player:
					hud.show_banner("Roubaram a bola!", "")
				_take(r)
		"ask":
			if holder is NPC and mates.has(holder):
				var h := holder as NPC
				var to2 := r.global_position - ball.global_position
				to2.y = 0
				h.say("Toma!", 1.0)
				_kick_from(h, to2.normalized(), pass_power(to2.length()), 0.12)


## Mudanças na turma durante a partida (do OnlinePlay).
func on_net_event(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	var id := str(ev.get("id", ""))
	if kind == "host" and id == str(net.get("me", "")) and net_role == "client":
		_become_host(ev)
		return
	if kind == "host" and net_role == "client":
		net["host"] = id
		net["teams"] = ev.get("teams", net.get("teams", {}))
		my_team = str((net.teams as Dictionary).get(net.get("me", ""), my_team))
		return
	if net_role != "host":
		return
	match kind:
		"joined":
			# quem chega entra no lugar de um bot do time dele
			var team := str(ev.get("team", "b"))
			if not _add_human(id, team):
				return
			(net.players as Array).append(id)
			var list := team_a if team == "a" else team_b
			if fill_bots and not list.is_empty():
				var out: NPC = list.pop_back()
				if holder == out:
					_release(Vector3.ZERO, 0.0)
				out.activity = "wander"
				participants.erase(out)
				hud.show_banner("Substituição!", "%s entrou no lugar de %s" % [NetworkManager.name_of(id), out.display_name])
			else:
				hud.show_banner("Reforço!", "%s entrou no jogo" % NetworkManager.name_of(id))
		"left":
			var was_a := false
			for r in _human_id.keys():
				if _human_id[r] == id:
					was_a = humans_a.has(r)
			_remove_human(id)
			if fill_bots:
				_add_sub_bot(0 if was_a else 1)
			elif humans_b.is_empty() and team_b.is_empty() and running:
				# o outro time ficou sem ninguém: acaba
				GameManager.show_toast("O time laranja ficou sem jogadores.")
				_finish()


## Um bot entra no lugar de quem saiu.
func _add_sub_bot(team: int) -> void:
	for n in students(1, Vector3(40, 0.05, -49)):
			take_npcs([n])
			n.run_speed = [3.7, 4.2, 4.7][difficulty]
			(team_a if team == 0 else team_b).append(n)
			n.teleport(Vector3(40.0 + (-6.0 if team == 0 else 6.0), 0.05, -49.0), PI * 0.5 if team == 0 else -PI * 0.5)
			hud.show_banner("Substituição!", "%s entrou no jogo" % n.display_name)
			return


# ---------------------------------------------------------------- colega (client)

func _start_client() -> void:
	_started = true
	player.movement_locked = false
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	time_left = MATCH_TIME
	if not NetworkManager.mg_relay.is_connected(_on_relay):
		NetworkManager.mg_relay.connect(_on_relay)
	_client_kickoff()
	hud.set_minigame_text("Futebol com a turma · esperando o anfitrião escolher as opções...")


func _client_side() -> float:
	return 1.0 if my_team == "a" else -1.0


func _client_kickoff() -> void:
	var idx := maxi((net.get("players", []) as Array).find(net.get("me", "")), 0)
	var side := _client_side()
	player.force_stand()
	player.global_position = Vector3(40.0 - side * (4.0 + (idx % 3) * 2.5), 0.05, -49.0 + (idx % 2) * 4.0 - 2.0)
	player.yaw = PI * 0.5 * side
	player.velocity = Vector3.ZERO
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.pitch = -24.0
		player.camera_rig.snap_to_target()


func _client_tick(delta: float) -> void:
	_state_age += delta
	_tackle_cd = maxf(_tackle_cd - delta, 0.0)
	if _charge:
		_power = minf(_power + delta * 0.9, 1.0)
		hud.set_meter(_power)
	var st := _last_state
	if st.is_empty():
		if _state_age > 45.0:
			end_game(0, "O anfitrião não começou a partida", 2, 4)
		return
	if _state_age > 8.0:
		hud.set_minigame_text("Conexão com o anfitrião caiu... esperando outro assumir")
		return
	var prev_a := score_a
	var prev_b := score_b
	score_a = int(st.get("a", 0))
	score_b = int(st.get("b", 0))
	time_left = float(st.get("t", time_left))
	if score_a != prev_a or score_b != prev_b:
		var ours := (score_a > prev_a) == (my_team == "a")
		hud.show_banner("GOOOL!" if ours else "Gol do adversário", "Seu time %d x %d" % _my_score())
		if ours:
			player.visual.play("celebrate")
			AudioManager.play_ui("goal", -2.0)
	var ko := int(st.get("ko", 0))
	if ko != _client_ko:
		if _client_ko >= 0:
			_client_kickoff()
		_client_ko = ko
	_client_holder = str(st.get("h", ""))
	holder = player if _client_holder == str(net.get("me", "")) else null
	# bola: no meu pé (sem atraso) ou onde o anfitrião mandou
	var b: Array = st.get("ball", [])
	if b.size() == 3:
		_ball_target = Vector3(float(b[0]), float(b[1]), float(b[2]))
	if holder == player:
		ball.global_position = _dribble_pos(player)
	else:
		ball.global_position = ball.global_position.lerp(_ball_target, 1.0 - exp(-14.0 * delta))
	_client_bots(st.get("bots", []), delta)
	var who := "  ·  com você" if holder == player else ""
	hud.set_minigame_text("Seu time %d x %d  ·  %s%s" % [_my_score()[0], _my_score()[1], fmt_time(time_left), who])
	if int(st.get("end", 0)) == 1:
		var mine: int = _my_score()[0]
		var theirs: int = _my_score()[1]
		var won := 1 if mine > theirs else (0 if mine == theirs else -1)
		end_game(won, "%d x %d" % [mine, theirs], 25 if won > 0 else (12 if won == 0 else 8), 40 if won > 0 else 20, {"score": mine})
		return
	player._emit_context()


func _my_score() -> Array:
	return [score_a, score_b] if my_team == "a" else [score_b, score_a]


## Bots desenhados onde o anfitrião mandou (bonecos sem cérebro).
func _client_bots(list: Array, delta: float) -> void:
	while _puppets.size() < list.size():
		var got: NPC = null
		for n in students(1, Vector3(40, 0.05, -49)):
			got = n
		if got == null:
			break
		take_npcs([got])
		_puppets.append(got)
	for i in _puppets.size():
		var n := _puppets[i]
		if i >= list.size():
			n.visible = false
			continue
		var e: Array = list[i]
		n.visible = true
		var tgt := Vector3(float(e[0]), 0.05, float(e[1]))
		if n.global_position.distance_to(tgt) > 6.0:
			n.teleport(tgt, float(e[2]))
		else:
			n.global_position = n.global_position.lerp(tgt, 1.0 - exp(-12.0 * delta))
			n.yaw = lerp_angle(n.yaw, float(e[2]), 1.0 - exp(-12.0 * delta))
			n.visual.rotation.y = n.yaw
		n.moving = false


## O anfitrião saiu: este celular assume a partida de onde parou.
func _become_host(ev: Dictionary) -> void:
	var st := _last_state
	net["host"] = net.get("me", "")
	net["teams"] = ev.get("teams", net.get("teams", {}))
	var was_team := my_team
	my_team = "a"
	var swapped := was_team == "b"
	score_a = int(st.get("b" if swapped else "a", 0))
	score_b = int(st.get("a" if swapped else "b", 0))
	time_left = float(st.get("t", time_left))
	# os bonecos viram bots de verdade, cada um no seu papel
	team_a.clear()
	team_b.clear()
	keeper_a = null
	keeper_b = null
	var roles: Array = st.get("bots", [])
	for i in mini(_puppets.size(), roles.size()):
		var r := int((roles[i] as Array)[4])
		if swapped:
			r = [1, 0, 3, 2][r]
		var n := _puppets[i]
		n.visible = true
		match r:
			0: team_a.append(n)
			1: team_b.append(n)
			2: keeper_a = n
			3: keeper_b = n
	_puppets.clear()
	ball.freeze = false
	net_role = "host"
	_collect_humans()
	(net.players as Array).clear()
	for id in (net.teams as Dictionary).keys():
		(net.players as Array).append(id)
	hud.show_banner("Você é o anfitrião agora", "A partida continua no seu celular")
	_kickoff(0)


# ---------------------------------------------------------------- botões do colega

func _client_cmd(k: String, extra := {}) -> void:
	var f := _fwd(player)
	var d := {"k": k, "d": [snappedf(f.x, 0.01), snappedf(f.z, 0.01)]}
	d.merge(extra)
	NetworkManager.mg_send_relay(str(net.gid), d)


func hints() -> Dictionary:
	return {"start": "Chegue perto da bola para dominar. SEGURE Chutar para mais força e mire no canto!", "idle": "Corra até a bola. Com ela: verde passa, amarelo chuta. Sem ela: chegue perto e toque no verde para ROUBAR.", "miss": "Chute de perto e no canto do gol: o goleiro erra mais!"}
