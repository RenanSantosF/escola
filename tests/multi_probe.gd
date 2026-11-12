extends Node
## Ponta a ponta com DOIS jogos de verdade na mesma sala (servidor local).
## O jogador A cria a sala; o B entra pelo código. Testa: relógio igual,
## carteiras diferentes, futebol com entrada no meio (B vira colega do
## anfitrião), gol, posse, chute do colega, fim para os dois; rodada
## (pontaria) com placar da turma; vez com fila (amarelinha).
##
## Uso (servidor com CLOCK_START=recess):
##   godot --headless --path . res://tests/multi_probe.tscn -- --role=A --dir=/tmp/x --url=ws://127.0.0.1:8150
##   godot --headless --path . res://tests/multi_probe.tscn -- --role=B --dir=/tmp/x --url=ws://127.0.0.1:8150

var role := "A"
var dir := "/tmp"
var url := "ws://127.0.0.1:8150"
var main: Node
var fails: Array = []
var oks := 0
var events: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--dir="):
			dir = a.substr(6)
		elif a.begins_with("--url="):
			url = a.substr(6)
	Settings.set_value("server_url", url, false)
	SaveManager.section("online").clear()
	NetworkManager.mg_event.connect(func(e): events.append(e))
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	await _frames(5)
	main._online_menu.visible = true
	if role == "A":
		main._join_online("create", "")
	else:
		var code := await _wait_file("code", 60.0)
		main._join_online("code", code)
	var t := 0.0
	while not (NetworkManager.is_online() and GameManager.is_playing()) and t < 20.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not NetworkManager.is_online():
		_done("não conectou")
		return
	if role == "A":
		_write("code", NetworkManager.room_code)
	_write("id_" + role, NetworkManager.my_id)
	await _secs(1.0)
	await _test_basics()
	await _test_football()
	await _test_round()
	await _test_turn()
	await _test_party()
	await _test_dodgeball()
	await _test_hide()
	await _test_switch_room()
	_done("")


## Convite de amigo: B vai para outra sala e volta para a do A ("Entrar" do convite).
func _test_switch_room() -> void:
	await barrier("switch0")
	var sess: OnlineSession = main.online
	var code_a := await _wait_file("code", 5.0)
	if role == "B":
		NetworkManager.leave()
		NetworkManager.join("create", "")
		var t := 0.0
		while (not NetworkManager.is_online() or NetworkManager.room_code == code_a) and t < 15.0:
			await _secs(0.2)
			t += 0.2
		check(NetworkManager.room_code != code_a, "trocar sala: B foi para outra sala")
		await _secs(1.0)
		check(not sess.remotes.has(_other_id()), "trocar sala: na outra sala o A não aparece")
		sess.switch_room(code_a)
		t = 0.0
		while not sess.remotes.has(_other_id()) and t < 15.0:
			await _secs(0.2)
			t += 0.2
		check(NetworkManager.room_code == code_a and sess.remotes.has(_other_id()), "trocar sala: B voltou para a sala do A e vê o A")
		check(GameManager.is_playing() and player_ok(), "trocar sala: B continua jogando (sem tela de queda)")
	await barrier("switch1")
	if role == "A":
		var t2 := 0.0
		while not sess.remotes.has(_other_id()) and t2 < 10.0:
			await _secs(0.2)
			t2 += 0.2
		check(sess.remotes.has(_other_id()), "trocar sala: A vê o B voltar")


func _other_id() -> String:
	var f := dir.path_join("id_" + ("B" if role == "A" else "A"))
	return FileAccess.get_file_as_string(f) if FileAccess.file_exists(f) else "?"


func player_ok() -> bool:
	var s: OnlineSession = main.online
	return GameManager.player.input_enabled and not (s._lost_panel and s._lost_panel.visible)


func check(cond: bool, name: String, detail := "") -> void:
	if cond:
		oks += 1
		print("  OK   [%s] %s" % [role, name])
	else:
		fails.append(name)
		print("  FALHA [%s] %s  (%s)" % [role, name, detail])


func _done(err: String) -> void:
	if err != "":
		fails.append(err)
	print("MULTI_PROBE %s %s  ok=%d falhas=%d %s" % [role, "OK" if fails.is_empty() else "FALHOU", oks, fails.size(), str(fails)])
	_write("done_" + role, "1")
	await _secs(1.0)
	get_tree().quit(0 if fails.is_empty() else 1)


# ------------------------------------------------------------- sincronização

func _write(name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wait_file(name: String, timeout := 40.0) -> String:
	var t := 0.0
	while t < timeout:
		if FileAccess.file_exists(dir.path_join(name)):
			return FileAccess.get_file_as_string(dir.path_join(name))
		await _secs(0.1)
		t += 0.1
	fails.append("esperou demais por " + name)
	return ""


## Os dois chegam neste ponto antes de seguir.
func barrier(name: String) -> void:
	_write(name + "_" + role, "1")
	await _wait_file(name + "_" + ("B" if role == "A" else "A"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await _secs(0.1)
		t += 0.1
	return cond.call()


func _place(pos: Vector3) -> void:
	var p: PlayerController = GameManager.player
	if p.mode == PlayerController.Mode.SITTING:
		p.force_stand()
	p.global_position = pos
	p.velocity = Vector3.ZERO


# ------------------------------------------------------------- testes

func _test_basics() -> void:
	await barrier("joined")
	await _secs(1.0)
	var sd: SchoolDay = main.school_day
	check(sd.synced and sd.phase == SchoolDay.Phase.RECESS, "relógio: no recreio, igual ao servidor", "fase %d" % sd.phase)
	var npcm: NPCManager = main.npcs
	var seats := npcm.desk_seats()
	check(NetworkManager.my_desk >= 0 and npcm.player_desk == seats[NetworkManager.my_desk], "carteira: a minha é a reservada")
	check(npcm.desk_owner.size() == 1 and not npcm.desk_owner.has(npcm.player_desk), "carteira: a do colega é outra e eu sei de quem é")
	var s := get_tree().get_first_node_in_group("online_session")
	check(s != null and s.remotes.size() == 1, "vejo o colega na escola")
	var bots := 0
	for n in npcm.npcs:
		if n.active and n.role == "student" and not n in npcm.practice:
			bots += 1
	check(bots == 0, "escola sem alunos-bot: só jogadores de verdade", str(bots))


func _test_football() -> void:
	var mgr: MinigameManager = main.minigames
	if role == "A":
		_place(Vector3(40, 0.05, -40))
		await _secs(0.5)
		mgr.start("futebol")
		var lob := await _until(func(): return str(NetworkManager.game_state("futebol").get("state", "")) == "lobby", 5.0)
		check(lob and mgr.active == null, "futebol: sozinho espera a turma (sem bots)")
		await barrier("fb_lobby")
		await barrier("fb_in")
		NetworkManager.mg_start("futebol", {})
		var ok := await _until(func(): return mgr.active != null and mgr.active.net_role == "host", 6.0)
		check(ok, "futebol: com 2 jogadores começa e sou o anfitrião")
		var fb = mgr.active
		var got := await _until(func(): return fb != null and fb.humans_a.size() + fb.humans_b.size() == 1, 6.0)
		check(got, "futebol: o colega está no jogo")
		check(fb != null and fb.team_a.is_empty() and fb.team_b.is_empty() and fb.keeper_a != null, "futebol: sem bots na linha, só goleiros")
		await barrier("fb_started")
		await _secs(3.5)
		# gol do time do anfitrião
		fb._release(Vector3.ZERO, 0.0)
		fb.ball.global_position = Vector3(60.6, 0.3, -49)
		fb.ball.linear_velocity = Vector3(3, 0, 0)
		await _secs(0.4)
		check(fb.score_a == 1, "futebol: gol no anfitrião")
		await barrier("goal")
		await _secs(6.0)
		# a bola vai para o pé do colega
		var hs: Array = fb.humans_a + fb.humans_b
		var r: Node3D = hs[0] if not hs.is_empty() else null
		if r:
			fb._take(r)
		await barrier("given")
		await barrier("shot")
		await _secs(0.8)
		check(fb.holder != r, "futebol: o chute do colega chegou e a bola saiu do pé dele")
		fb._finish()
		await barrier("fb_end")
		check(mgr.active == null, "futebol: acabou no anfitrião")
	else:
		_place(Vector3(0, 0.05, -5))
		await barrier("fb_lobby")
		_place(Vector3(41, 0.05, -40))
		await _secs(0.3)
		mgr.start("futebol")
		await _until(func(): return (NetworkManager.game_state("futebol").get("players", []) as Array).size() == 2, 5.0)
		await barrier("fb_in")
		var ok2 := await _until(func(): return mgr.active != null and mgr.active.net_role == "client" and not mgr.active._last_state.is_empty(), 8.0)
		check(ok2, "futebol: entrei como colega e recebo o jogo do anfitrião")
		await barrier("fb_started")
		await barrier("goal")
		var fb = mgr.active
		var seen := await _until(func(): return fb != null and fb._my_score()[0] + fb._my_score()[1] == 1, 4.0)
		check(seen, "futebol: o colega vê o placar do gol")
		check(fb != null and fb._puppets.size() == 2, "futebol: o colega vê só os 2 goleiros (bots)", str(fb._puppets.size() if fb else -1))
		await barrier("given")
		var has := await _until(func(): return fb != null and is_instance_valid(fb) and fb.holder == GameManager.player, 3.0)
		check(has, "futebol: a bola chegou no meu pé")
		var bpos: Vector3 = fb.ball.global_position
		check(bpos.distance_to(GameManager.player.global_position) < 1.2, "futebol: bola colada no pé sem atraso")
		fb._charge = true
		fb._power = 0.8
		fb.on_play_release()
		await barrier("shot")
		var ended := await _until(func(): return mgr.active == null, 6.0)
		check(ended, "futebol: o fim do anfitrião encerra a minha partida")
		await barrier("fb_end")
	await _secs(1.0)


func _test_round() -> void:
	var mgr: MinigameManager = main.minigames
	events.clear()
	_place(Vector3(24, 0.05, -14) if role == "A" else Vector3(-30, 0.05, -5))
	await _secs(1.0)
	if role == "A":
		mgr.start("pontaria")
		var ok := await _until(func(): return mgr.active != null, 5.0)
		check(ok, "rodada: começa na hora (ninguém perto)")
		await barrier("pt")
	else:
		await barrier("pt")
		_place(Vector3(24.5, 0.05, -14))
		mgr.start("pontaria")
		var ok2 := await _until(func(): return mgr.active != null, 5.0)
		check(ok2, "rodada: entrei com a rodada rolando")
	await barrier("pt_both")
	if mgr.active:
		mgr.active.end_game(0, "fim", 0, 0, {"score": 10 if role == "A" else 20})
	var got := await _until(func(): return events.any(func(e): return e.get("kind") == "results" and e.get("gid") == "pontaria"), 6.0)
	check(got, "rodada: placar da turma no fim")
	if got:
		var ev: Dictionary = events.filter(func(e): return e.get("kind") == "results")[0]
		var rk: Array = ev.ranking
		check(rk.size() == 2 and float(rk[0].score) == 20.0, "rodada: os dois no placar e o melhor em 1º", str(rk))
	await barrier("pt_end")


func _test_turn() -> void:
	var mgr: MinigameManager = main.minigames
	events.clear()
	_place(Vector3(-14, 0.05, 3) if role == "A" else Vector3(30, 0.05, -5))
	await _secs(1.0)
	if role == "A":
		mgr.start("amarelinha")
		var ok := await _until(func(): return mgr.active != null, 5.0)
		check(ok, "vez: primeiro a jogar")
		await barrier("am")
		await barrier("am_queue")
		mgr.active.end_game(0, "fim", 0, 0, {"score": 5})
	else:
		await barrier("am")
		_place(Vector3(-13.5, 0.05, 3.5))
		mgr.start("amarelinha")
		var queued := await _until(func(): return (NetworkManager.game_state("amarelinha").get("queue", []) as Array).has(NetworkManager.my_id), 4.0)
		check(queued and mgr.active == null, "vez: entrei na fila e espero (sem jogar junto)")
		await barrier("am_queue")
		var mine := await _until(func(): return mgr.active != null, 6.0)
		check(mine, "vez: chegou a minha vez")
		if mgr.active:
			mgr.active.end_game(0, "fim", 0, 0, {"score": 7})
	var got := await _until(func(): return events.any(func(e): return e.get("kind") == "results" and e.get("gid") == "amarelinha"), 6.0)
	check(got, "vez: placar no fim da fila")
	await barrier("am_end")



func _test_party() -> void:
	var qs: QuestSystem = main.quests
	var npcm: NPCManager = main.npcs
	_place(Vector3(-5 if role == "A" else -3.5, 0.05, -8))
	await _secs(1.0)
	if role == "A":
		qs.start("reciclagem")
		await _secs(0.5)
		var others: Array = NetworkManager.names.keys().filter(func(k): return k != NetworkManager.my_id)
		var friend: String = others[0] if not others.is_empty() else ""
		NetworkManager.send_direct(friend, "party_invite", {"q": "reciclagem", "title": "Coleta"})
		var joined := await _until(func(): return qs.party_role == "host" and qs.party_members.size() == 1, 6.0)
		check(joined, "missão em grupo: colega aceitou")
		await barrier("party_in")
		await barrier("party_pick")
		var got := await _until(func(): return qs._step_left == 4, 3.0)
		check(got, "missão em grupo: o item que o colega pegou conta para o grupo", str(qs._step_left))
		# o dono pega o resto
		for it in qs._spawned.duplicate():
			qs._on_picked(it)
		await _secs(0.3)
		check(qs.step_i == 1, "missão em grupo: etapa seguinte")
		await barrier("party_step2")
		if not qs._spot_nodes.is_empty():
			qs._on_spot_done(qs._spot_nodes[0], "")
		await _secs(0.5)
		for a in main.hud.find_children("*", "QuestActivity", true, false):
			(a as QuestActivity)._finish(1.0)
		var done := await _until(func(): return qs.active_id == "", 4.0)
		check(done, "missão em grupo: concluída pelo dono")
		await barrier("party_end")
	else:
		# aceita o convite que vai chegar
		var dlg: DialogueUI = main.school_day.dialogue
		var asked := await _until(func(): return dlg.is_open(), 6.0)
		check(asked, "missão em grupo: recebi o convite")
		dlg._close(0)
		var synced := await _until(func(): return qs.active_id == "reciclagem" and qs._spawned.size() == 5, 6.0)
		check(synced, "missão em grupo: vejo os mesmos 5 lixos do dono", "%s %d" % [qs.active_id, qs._spawned.size()])
		await barrier("party_in")
		if not qs._spawned.is_empty():
			qs._on_picked(qs._spawned[0])
		await barrier("party_pick")
		var st2 := await _until(func(): return qs.step_i == 1, 4.0)
		check(st2, "missão em grupo: acompanho a etapa do dono")
		await barrier("party_step2")
		var coins_before := int(SaveManager.section("player").get("level", 1)) * 100000 + int(SaveManager.section("player").get("xp", 0))
		for a in main.hud.find_children("*", "QuestActivity", true, false):
			(a as QuestActivity)._finish(1.0)
		var done2 := await _until(func(): return qs.active_id == "" and qs._state().has("reciclagem"), 6.0)
		check(done2, "missão em grupo: concluída para mim também")
		check(int(SaveManager.section("player").get("level", 1)) * 100000 + int(SaveManager.section("player").get("xp", 0)) > coins_before, "missão em grupo: ganhei a recompensa (XP)")
		await barrier("party_end")



func _test_dodgeball() -> void:
	var mgr: MinigameManager = main.minigames
	if role == "A":
		_place(Vector3(-46, 0.05, -40))
		await _secs(0.5)
		mgr.start("queimada")
		var lob := await _until(func(): return str(NetworkManager.game_state("queimada").get("state", "")) == "lobby", 5.0)
		check(lob and mgr.active == null, "queimada: sozinho espera a turma (sem bots)")
		await barrier("qm_lobby")
		await barrier("qm_in")
		NetworkManager.mg_start("queimada", {})
		var ok := await _until(func(): return mgr.active != null and mgr.active.net_role == "host", 6.0)
		check(ok, "queimada: começa e sou o anfitrião")
		var q = mgr.active
		var got := await _until(func(): return q != null and q.humans_a.size() + q.humans_b.size() == 1, 6.0)
		check(got, "queimada: colega entrou no time")
		check(q != null and q.team_a.is_empty() and q.team_b.is_empty(), "queimada: nenhum bot")
		await barrier("qm_started")
		await _secs(3.5)
		var hs: Array = q.humans_a + q.humans_b
		if not hs.is_empty():
			q._holder = null
			q._grab(hs[0])
		await barrier("qm_given")
		await barrier("qm_thrown")
		var thrown := await _until(func(): return q._holder == null, 3.0)
		check(thrown, "queimada: o arremesso do colega chegou")
		q._finish()
		await barrier("qm_end")
	else:
		_place(Vector3(0, 0.05, -5))
		await barrier("qm_lobby")
		_place(Vector3(-40, 0.05, -40))
		await _secs(0.3)
		mgr.start("queimada")
		await _until(func(): return (NetworkManager.game_state("queimada").get("players", []) as Array).size() == 2, 5.0)
		await barrier("qm_in")
		var ok2 := await _until(func(): return mgr.active != null and mgr.active.net_role == "client" and not mgr.active._state.is_empty(), 8.0)
		check(ok2, "queimada: entrei e recebo o jogo")
		await barrier("qm_started")
		await barrier("qm_given")
		var q = mgr.active
		var has := await _until(func(): return q != null and q._holder == GameManager.player, 4.0)
		check(has, "queimada: a bola chegou na minha mão")
		if q:
			q._aiming = true
			q.on_play_release()
		await barrier("qm_thrown")
		var ended := await _until(func(): return mgr.active == null, 6.0)
		check(ended, "queimada: o fim vale para os dois")
		await barrier("qm_end")
	await _secs(1.0)


func _test_hide() -> void:
	var mgr: MinigameManager = main.minigames
	events.clear()
	_place(Vector3(-4, 0.05, -79) if role == "A" else Vector3(-2, 0.05, -79))
	await _secs(1.0)
	if role == "A":
		mgr.start("esconde")
		await _until(func(): return not NetworkManager.game_state("esconde").is_empty(), 4.0)
		await barrier("hs_lobby")
		await barrier("hs_in")
		NetworkManager.mg_start("esconde")
	else:
		await barrier("hs_lobby")
		mgr.start("esconde")
		await _until(func(): return (NetworkManager.game_state("esconde").get("players", []) as Array).size() == 2, 4.0)
		await barrier("hs_in")
	var started := await _until(func(): return mgr.active != null and mgr.active.is_net(), 6.0)
	check(started, "esconde: os dois começam juntos")
	var h: Dictionary = NetworkManager.game_state("esconde").get("hide", {})
	var seeker := str(h.get("seeker", ""))
	check(seeker != "", "esconde: o servidor escolheu quem procura")
	var me_seek := seeker == NetworkManager.my_id
	if me_seek:
		check(GameManager.player.movement_locked, "esconde: quem procura fica de olhos fechados")
	else:
		_place(Vector3(10, 0.05, -95))  # esconde
	# espera a fase de procurar (20 s)
	var seeking := await _until(func(): return str((NetworkManager.game_state("esconde").get("hide", {}) as Dictionary).get("phase", "")) == "seeking", 25.0)
	check(seeking, "esconde: depois de contar, começa a procurar")
	if me_seek:
		check(not GameManager.player.movement_locked, "esconde: quem procura pode andar")
		_place(Vector3(10.8, 0.05, -95))  # chega pertinho
	var got := await _until(func(): return events.any(func(e): return e.get("kind") == "found"), 6.0)
	check(got, "esconde: chegou perto = achou")
	var ended := await _until(func(): return mgr.active == null, 6.0)
	check(ended, "esconde: achou todo mundo, acabou para os dois")
	await barrier("hs_end")
