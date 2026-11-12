extends Node
## "Robô jogador": passa um dia inteiro fazendo coisas aleatórias como uma
## criança (interage com tudo, entra e sai de brincadeiras apertando botões,
## anda nas atrações, pula, senta, responde a aula) e registra problemas:
## caiu do mapa, controle não voltou, preso no mesmo lugar, jogo não fecha.
## Uso: godot --headless --path . res://tests/soak_probe.tscn -- --steps=400 --seed=1

var main: Node
var player: PlayerController
var problems: Array = []
var rng := RandomNumberGenerator.new()
var steps := 300


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steps="):
			steps = int(a.substr(8))
		if a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
	Settings.set_value("quality", 1, false)
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.school_day == null:
		await get_tree().process_frame
	await _frames(5)
	main._start_game()
	await _frames(10)
	player = GameManager.player
	var sd: SchoolDay = main.school_day
	var mm: MinigameManager = main.minigames
	sd._start_recess()
	await _frames(5)
	var interactables: Array = get_tree().get_nodes_in_group("interactable")
	print("SOAK: %d interativos, %d passos" % [interactables.size(), steps])
	for i in steps:
		var act := rng.randi() % 10
		var what := ""
		match act:
			0, 1, 2:
				# vai até um interativo qualquer e usa
				var it: Node3D = interactables[rng.randi() % interactables.size()]
				if not is_instance_valid(it):
					continue
				what = "usar %s (%s)" % [it.name, it.get_class()]
				await _free()
				player.global_position = it.global_position + Vector3(rng.randf_range(-0.8, 0.8), 0.1, rng.randf_range(-0.8, 0.8))
				await _frames(3)
				player.request_interact()
				await _frames(2)
				player.request_interact_release()
				await _secs(rng.randf_range(0.3, 2.5))
			3, 4:
				# brincadeira: começa, aperta botões e sai
				if not sd.phase == SchoolDay.Phase.RECESS:
					sd._start_recess()
					await _frames(3)
				var gids: Array = MinigameManager.GAMES.keys()
				var gid: String = gids[rng.randi() % gids.size()]
				what = "brincadeira %s" % gid
				await _free()
				if mm.start(gid):
					var g: Minigame = mm.active
					for k in rng.randi_range(5, 40):
						if mm.active != g or g == null:
							break
						match rng.randi() % 6:
							0: g.on_play()
							1: g.on_play_release()
							2: player.request_jump()
							3: g.on_interact()
							4: g.on_interact_release()
							5: Input.action_press("move_forward")
						await _secs(rng.randf_range(0.05, 0.6))
						Input.action_release("move_forward")
					if mm.active:
						mm.active.end_game(0, "robô saiu", 0, 0)
					await _frames(5)
					if mm.active != null:
						_problem("brincadeira %s não fechou" % gid)
				else:
					what += " (não começou)"
			5:
				# anda e pula muito
				what = "andar e pular"
				await _free()
				Input.action_press("move_forward")
				for k in 10:
					player.request_jump()
					player.yaw += rng.randf_range(-1.0, 1.0)
					await _secs(0.25)
				Input.action_release("move_forward")
			6:
				# troca de fase do dia (como se o tempo passasse)
				var ph := rng.randi() % 4
				what = "fase %d" % ph
				match ph:
					0: sd._start_recess()
					1: sd._start_return()
					2: sd._begin_class(0)
					3: sd._begin_class(1)
				await _secs(1.0)
				# na aula, responde o que aparecer
				if main.school_day.classroom_ui.visible:
					main.school_day.classroom_ui.answered.emit(rng.randf() < 0.6)
			7:
				what = "atração"
				var rides: Array = main.world.rides
				if not rides.is_empty():
					var rt: RideTrack = rides[rng.randi() % rides.size()]
					await _free()
					player.global_position = rt.global_position
					await _frames(2)
					rt.interact(player)
					Engine.time_scale = 8.0
					var t0 := Time.get_ticks_msec()
					while rt._rider != null and Time.get_ticks_msec() - t0 < 25000:
						await _frames(1)
					Engine.time_scale = 1.0
					if rt._rider != null:
						_problem("atração %s não terminou" % rt.kind)
						rt.eject()
			8:
				what = "mochila"
				main.profile_menu.open_menu()
				await _frames(3)
				for tab in ["loja", "visual", "colecoes", "amigos", "conquistas"]:
					main.profile_menu._tab = tab
					main.profile_menu._refresh()
					await _frames(2)
				main.profile_menu.close_menu()
			9:
				what = "emoji"
				await _free()
				player.emote(["wave", "celebrate", "clap"][rng.randi() % 3])
				await _secs(0.8)
		await _frames(2)
		_check(what, i)
	print("SOAK_DONE problemas=%d" % problems.size())
	for p in problems:
		print("  PROBLEMA: ", p)
	get_tree().quit()


## Antes de cada ação: em pé, livre (como uma criança que já saiu do que fazia).
func _free() -> void:
	# jogo de mesa aberto: aperta "Sair" (e confere que o controle voltou)
	for c in main.hud.get_children():
		if c is TableGames:
			(c as TableGames).close()
			await _frames(2)
			if not player.input_enabled:
				_problem("jogo de mesa: saiu e o controle não voltou")
				player.input_enabled = true
	if player.mode == PlayerController.Mode.SITTING:
		player.force_stand()
	if main.discipline and main.discipline.in_cutscene:
		return
	if main.school_day.dialogue.is_open():
		for k in 6:
			main.school_day.dialogue.advance()


var _last_pos := Vector3.ZERO
var _stuck_n := 0


func _check(what: String, i: int) -> void:
	var p := player.global_position
	if p.y < -3.0 or p.y > 40.0:
		_problem("passo %d (%s): posição estranha %s" % [i, what, p])
		player.global_position = Vector3(0, 0.1, -2)
		player.velocity = Vector3.ZERO
	var busy: bool = player.minigame != null or player.has_meta("ride") or main.school_day.dialogue.is_open() \
		or (main.discipline and main.discipline.in_cutscene) or main.school_day.classroom_ui.visible or main.profile_menu.visible
	if not busy and (not player.input_enabled or player.movement_locked):
		_problem("passo %d (%s): controle travado (input=%s locked=%s modo=%d)" % [i, what, player.input_enabled, player.movement_locked, player.mode])
		player.input_enabled = true
		player.movement_locked = false
	if GameManager.overlay_open and not main.profile_menu.visible:
		_problem("passo %d (%s): overlay_open ficou ligado" % [i, what])
		GameManager.overlay_open = false
	if get_tree().paused:
		_problem("passo %d (%s): jogo ficou pausado" % [i, what])
		get_tree().paused = false
	if not player.is_inside_tree():
		_problem("passo %d (%s): jogador saiu da árvore!" % [i, what])


func _problem(t: String) -> void:
	problems.append(t)
	print("PROBLEMA: ", t)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
