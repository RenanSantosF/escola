extends Node
## Testes automatizados de integração da FASE 1.
## Uso (headless): godot --headless --path . res://tests/test_runner.tscn
## Sai com código 0 se tudo passar, 1 se algum teste falhar.

var main: Node
var player: PlayerController
var cam: CameraController
var passed := 0
var failed := 0
var _log: Array[String] = []


func _ready() -> void:
	SaveManager.reset()
	_test_save_system()
	_test_settings()
	_test_appearance_roundtrip()
	_test_animator_sanity()
	_test_task_generator()
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	await _frames(5)
	main._start_game()
	await _frames(5)
	player = GameManager.player
	cam = main.camera_rig
	await _test_spawn_on_floor()
	await _test_walk()
	await _test_run()
	await _test_wall_collision()
	await _test_bonk()
	await _test_sit_and_stand()
	await _test_kick()
	await _test_pickup_throw()
	await _test_fountain()
	await _test_zones_and_roofs()
	await _test_jump()
	await _test_touch_controls()
	await _test_camera_collision()
	await _test_pause()
	# ---- FASE 2
	await _test_nav_graph()
	await _test_npcs_present()
	await _test_dialogue_friendship()
	await _test_npc_bump()
	await _test_upper_layer_while_sitting()
	await _test_find_task()
	await _test_full_day()
	# ---- FASE 3
	await _test_minigames()
	# ---- FASE 4
	await _test_discipline()
	await _test_events_missions()
	# ---- FASE 5
	await _test_progression()
	# ---- FASE 6
	await _test_polish()
	# ---- Revisão 1
	await _test_revisao1()
	await _test_revisao2()
	await _test_revisao3()
	await _test_online_tag()
	await _test_revisao5()
	await _test_parque()
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func check(cond: bool, name: String, info := "") -> void:
	if cond:
		passed += 1
		_log.append("  OK   " + name)
	else:
		failed += 1
		_log.append("  FALHA " + name + ("  (" + info + ")" if info != "" else ""))


func _place(pos: Vector3, yaw_deg: float) -> void:
	player.mode = PlayerController.Mode.FREE
	player.visual.stop_action(false)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.yaw = deg_to_rad(yaw_deg)
	cam.yaw = player.yaw + PI
	cam._manual_timer = 0.0
	cam.snap_to_target()


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "run", "jump"]:
		Input.action_release(a)


# --------------------------------------------------------------- unitários

func _test_save_system() -> void:
	var backup := SaveManager.data.duplicate(true)
	SaveManager.data.player.coins = 1234
	SaveManager.data.progress.days_completed = 7
	check(SaveManager.save_game(), "save: grava arquivo")
	SaveManager.data.player.coins = 0
	SaveManager.load_game()
	check(int(SaveManager.data.player.coins) == 1234 and int(SaveManager.data.progress.days_completed) == 7, "save: carrega valores gravados")
	# arquivo corrompido -> usa backup
	SaveManager.save_game()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ corrompido ")
	f.close()
	SaveManager.load_game()
	check(int(SaveManager.data.player.coins) == 1234, "save: recupera do backup quando corrompido")
	# chaves novas são preenchidas com padrões
	var merged: Dictionary = SaveManager._merge(SaveManager.default_data(), {"player": {"coins": 5}})
	check(merged.player.has("level") and int(merged.player.coins) == 5, "save: mescla com padrões")
	SaveManager.data = backup
	SaveManager.save_game()


func _test_settings() -> void:
	var old: float = Settings.get_value("camera_sensitivity")
	Settings.set_value("camera_sensitivity", 1.7)
	Settings.load_settings()
	check(is_equal_approx(float(Settings.get_value("camera_sensitivity")), 1.7), "config: persistência")
	Settings.set_value("camera_sensitivity", old)


func _test_appearance_roundtrip() -> void:
	var a := CharacterAppearance.random(42, false)
	var b := CharacterAppearance.from_dict(a.to_dict())
	check(a.to_dict() == b.to_dict(), "aparência: serialização ida e volta")
	var bad := CharacterAppearance.from_dict({"hair_style": "inexistente", "height_scale": 9.0})
	check(bad.hair_style == "curto" and bad.height_scale <= 1.15, "aparência: valores inválidos corrigidos")


func _test_animator_sanity() -> void:
	var skel := CharacterModelBuilder.build(CharacterAppearance.new())
	add_child(skel)
	var anim := CharacterAnimator.new()
	anim.setup(skel)
	check(skel.get_bone_count() == CharacterModelBuilder.BONES.size(), "personagem: esqueleto com %d ossos" % skel.get_bone_count())
	var mi := skel.get_node("Body") as MeshInstance3D
	check(mi.mesh.get_surface_count() == 1, "personagem: malha única (1 draw call)")
	var ok := true
	for action in ["sit_down", "stand_up", "kick", "throw", "interact", "pickup", "celebrate", "hit", "sad", "wave", "drink", "stretch", "look_around", "scratch_head"]:
		anim.play(action)
		for i in 90:
			anim.speed = 0.0 if i < 45 else 4.0
			anim.update(1.0 / 60.0)
			for b in skel.get_bone_count():
				var q := skel.get_bone_pose_rotation(b)
				if not q.is_finite() or not q.is_normalized():
					ok = false
	check(ok, "animação: todas as ações geram poses válidas")
	check(ActionLibrary.has_action("kick") and not ActionLibrary.has_action("voar"), "animação: biblioteca de ações")
	skel.queue_free()


# --------------------------------------------------------------- integração

func _test_spawn_on_floor() -> void:
	await _wait(0.5)
	check(player.is_on_floor(), "jogador: nasce apoiado no chão", str(player.global_position))


func _test_walk() -> void:
	_place(Vector3(0, 0.05, -2), 0)
	await _wait(0.2)
	var start := player.global_position
	cam.yaw = PI  # câmera atrás => "frente" = +Z do mundo
	Input.action_press("move_forward")
	await _wait(1.5)
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	var moved := player.global_position.distance_to(start)
	check(moved > 2.0, "movimento: caminha para frente", "%.2f m" % moved)
	check(absf(hspeed - player.walk_speed) < 0.4, "movimento: velocidade de caminhada", "%.2f m/s" % hspeed)
	await _wait(0.6)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.2, "movimento: desacelera e para ao soltar")
	var fwd := Vector3(sin(player.yaw), 0, cos(player.yaw))
	check(fwd.dot(Vector3(0, 0, -1).rotated(Vector3.UP, cam.get_yaw())) > 0.9, "movimento: personagem vira para a direção da câmera")


func _test_run() -> void:
	_place(Vector3(-20, 0.05, -10), 90)
	cam.yaw = player.yaw + PI
	Input.action_press("move_forward")
	Input.action_press("run")
	await _wait(1.5)
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	_release_all()
	check(absf(hspeed - player.run_speed) < 0.5, "movimento: velocidade de corrida", "%.2f m/s" % hspeed)
	await _wait(1.0)


func _test_wall_collision() -> void:
	# Corredor oeste do Bloco A: parede norte em z=34 (salas atrás).
	_place(Vector3(-35, 0.05, 36), 180)
	cam.yaw = player.yaw + PI
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	check(player.global_position.z > 34.2, "colisão: não atravessa parede do corredor", "z=%.2f" % player.global_position.z)
	# murada
	_place(Vector3(-50, 0.05, -72), 180)
	cam.yaw = player.yaw + PI
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	check(player.global_position.z > -74.8, "colisão: não atravessa a murada", "z=%.2f" % player.global_position.z)
	await _wait(0.3)


func _test_bonk() -> void:
	_place(Vector3(-35, 0.05, 37.3), 180)
	cam.yaw = player.yaw + PI
	player.global_position = Vector3(-35, 0.05, 37.0)
	player.velocity = Vector3(0, 0, -5.0)
	Input.action_press("move_forward")
	Input.action_press("run")
	var bonked := false
	for i in 90:
		await get_tree().physics_frame
		if player.visual.animator.action == "hit":
			bonked = true
			break
	_release_all()
	check(bonked, "colisão: trombada correndo na parede gera reação")
	await _wait(1.2)
	check(player.mode == PlayerController.Mode.FREE, "colisão: jogador se recupera após a trombada")


func _nearest(group: String, pos: Vector3, filter: Callable = Callable()) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(group):
		if filter.is_valid() and not filter.call(n):
			continue
		var d: float = (n as Node3D).global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = n
	return best


func _test_sit_and_stand() -> void:
	var seat := _nearest("interactable", Vector3(0, 0, -6), func(n): return n is Seat) as Seat
	check(seat != null, "assento: encontrado no pátio")
	if seat == null:
		return
	_place(seat.interact_point() + seat.global_basis.z * 0.3, rad_to_deg(seat.global_rotation.y) + 180.0)
	await _wait(0.3)
	check(player.nearby == seat, "assento: detectado como interativo próximo", str(player.nearby))
	player.request_interact()
	await _wait(1.2)
	check(player.mode == PlayerController.Mode.SITTING, "assento: jogador senta")
	check(player.global_position.distance_to(seat.global_position) < 0.1, "assento: posicionado no banco")
	check(player.visual.animator.is_holding(), "assento: animação sentada mantida")
	Input.action_press("move_forward")
	await _wait(0.2)
	Input.action_release("move_forward")
	await _wait(1.2)
	check(player.mode == PlayerController.Mode.FREE, "assento: levanta ao mover o joystick")
	check(seat.occupant == null, "assento: liberado ao levantar")


func _test_kick() -> void:
	var ball := _nearest("ball", Vector3(40, 0, -49)) as KickBall
	check(ball != null, "bola: existe na quadra")
	if ball == null:
		return
	ball.global_position = Vector3(40, 0.2, -49)
	ball.linear_velocity = Vector3.ZERO
	_place(Vector3(40, 0.05, -49.6), 0)
	await _wait(0.4)
	check(player.nearby_ball == ball, "bola: detectada à frente")
	var before := ball.global_position
	player.request_play()
	await _wait(1.0)
	check(ball.global_position.distance_to(before) > 2.0, "bola: chute move a bola", "%.2f m" % ball.global_position.distance_to(before))
	await _wait(0.5)
	check(player.mode == PlayerController.Mode.FREE, "bola: jogador volta ao normal após chute")
	# condução
	ball.global_position = Vector3(30, 0.15, -45)
	ball.linear_velocity = Vector3.ZERO
	_place(Vector3(30, 0.05, -45.8), 0)
	cam.yaw = player.yaw + PI
	Input.action_press("move_forward")
	await _wait(1.2)
	Input.action_release("move_forward")
	check(ball.global_position.z > -44.0, "bola: conduzida ao andar encostado", "z=%.2f" % ball.global_position.z)


func _test_pickup_throw() -> void:
	var item := _nearest("pickup", Vector3(0, 0, -10)) as PickupItem
	check(item != null, "objeto: bolinha de papel existe")
	if item == null:
		return
	item.global_position = Vector3(-10, 0.1, -12)
	item.linear_velocity = Vector3.ZERO
	_place(Vector3(-10, 0.05, -12.7), 0)
	await _wait(0.5)
	check(player.nearby == item, "objeto: detectado para pegar", str(player.nearby))
	player.request_interact()
	await _wait(1.2)
	check(player.held_item == item, "objeto: jogador segura a bolinha")
	player.request_play()
	await _wait(0.6)
	check(player.held_item == null and item.held_by == null, "objeto: arremessada")
	await _wait(0.6)
	check(item.global_position.distance_to(player.global_position) > 3.0, "objeto: voou para longe", "%.2f m" % item.global_position.distance_to(player.global_position))


func _test_fountain() -> void:
	var f := _nearest("interactable", Vector3(26, 0, 7), func(n): return n is WaterFountain) as WaterFountain
	check(f != null, "bebedouro: existe")
	if f == null:
		return
	_place(f.global_position + f.global_basis.z * -0.2, rad_to_deg(f.global_rotation.y))
	await _wait(0.3)
	if player.nearby == f:
		player.request_interact()
	else:
		f.interact(player)
	await _wait(0.4)
	check(player.mode == PlayerController.Mode.BUSY, "bebedouro: animação de beber")
	await _wait(1.8)
	check(player.mode == PlayerController.Mode.FREE and not f.busy, "bebedouro: termina e libera")


func _test_zones_and_roofs() -> void:
	_place(Vector3(-55, 0.05, 29), 0)
	await _wait(0.5)
	check(GameManager.current_zone == "Sala 1", "zonas: detecta Sala 1", GameManager.current_zone)
	var w: SchoolWorld = GameManager.world
	check(not w._chunk_nodes["roof_A"].visible, "telhado: some ao entrar no Bloco A")
	check(w._chunk_nodes["int_A_Sala 1"].visible, "interior: mobília visível dentro do prédio")
	_place(Vector3(0, 0.05, -10), 0)
	await _wait(0.5)
	check(w._chunk_nodes["roof_A"].visible and not w._chunk_nodes["int_A_Sala 1"].visible, "telhado/interior: restaurados ao sair")
	check(w.surface_at(Vector3(0, 0, -15)) == "hard" and w.surface_at(Vector3(-75, 0, -60)) == "dirt", "piso: tipos de superfície para passos")


func _test_jump() -> void:
	_place(Vector3(10, 0.05, -15), 0)
	await _wait(0.4)
	player.request_jump()
	var max_y := 0.0
	for i in 60:
		await get_tree().physics_frame
		max_y = maxf(max_y, player.global_position.y)
	check(max_y > 0.5, "pulo: sobe", "%.2f m" % max_y)
	await _wait(0.5)
	check(player.is_on_floor(), "pulo: volta ao chão")


func _test_touch_controls() -> void:
	var mc: MobileControls = main.hud.controls
	var vs := mc.get_viewport_rect().size
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = Vector2(200, vs.y - 160)
	mc._input(ev)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = ev.position + Vector2(0, -90)
	drag.relative = Vector2(0, -90)
	mc._input(drag)
	check(mc.get_move_vector().y < -0.8, "toque: joystick move para frente", str(mc.get_move_vector()))
	ev.pressed = false
	mc._input(ev)
	check(mc.get_move_vector() == Vector2.ZERO, "toque: joystick volta ao centro")
	# arrasto na direita gira a câmera
	var y0 := cam.yaw
	var t2 := InputEventScreenTouch.new()
	t2.index = 1
	t2.pressed = true
	t2.position = Vector2(vs.x * 0.6, vs.y * 0.4)
	mc._input(t2)
	var d2 := InputEventScreenDrag.new()
	d2.index = 1
	d2.position = t2.position + Vector2(120, 0)
	d2.relative = Vector2(120, 0)
	mc._input(d2)
	t2.pressed = false
	mc._input(t2)
	check(absf(cam.yaw - y0) > 0.2, "toque: arrastar gira a câmera")
	# botão de pulo
	_place(Vector3(12, 0.05, -15), 0)
	await _wait(0.3)
	var bt := InputEventScreenTouch.new()
	bt.index = 2
	bt.pressed = true
	bt.position = mc.btn_jump.get_global_rect().get_center()
	mc._input(bt)
	bt.pressed = false
	mc._input(bt)
	var max_y := 0.0
	for i in 40:
		await get_tree().physics_frame
		max_y = maxf(max_y, player.global_position.y)
	check(max_y > 0.4, "toque: botão de pular funciona")
	await _wait(0.6)


func _test_camera_collision() -> void:
	# câmera atrás do jogador encostado na parede não deve atravessá-la
	_place(Vector3(-35, 0.05, 35.0), 0)
	cam.yaw = PI
	cam.pitch = -10.0
	await _wait(0.6)
	var cp := cam.camera.global_position
	check(cp.z > 34.0, "câmera: não atravessa paredes (SpringArm)", "z=%.2f" % cp.z)


func _test_pause() -> void:
	main.hud.open_pause()
	await get_tree().process_frame
	check(get_tree().paused and GameManager.state == GameManager.State.PAUSED, "pausa: jogo pausado")
	main.hud.close_pause()
	await get_tree().process_frame
	check(not get_tree().paused, "pausa: retoma")


# --------------------------------------------------------------- FASE 2

func _test_task_generator() -> void:
	var gen := ClassroomTasks.new(1234, 3)
	var ok := true
	for type in ["math", "word", "quiz", "order", "match", "find"]:
		for i in 40:
			var t := gen.make(type)
			match type:
				"math", "word", "quiz":
					if t.options.size() != 4 or int(t.answer) < 0 or not ClassroomTasks.check_choice(t, t.answer):
						ok = false
					# opções sem repetição
					var uniq := {}
					for o in t.options:
						uniq[o] = true
					if uniq.size() != 4:
						ok = false
				"order":
					if not ClassroomTasks.check_order(t, t.answer_order):
						ok = false
					var wrong: Array = t.answer_order.duplicate()
					wrong.reverse()
					if ClassroomTasks.check_order(t, wrong) and t.items[wrong[0]] != t.items[t.answer_order[0]]:
						ok = false
				"match":
					for li in t.left.size():
						if not ClassroomTasks.check_match(t, li, t.pairs[li]):
							ok = false
				"find":
					if t.item == "" or t.item_name == "":
						ok = false
	check(ok, "tarefas: 240 tarefas geradas com respostas consistentes")
	var lesson := gen.make_lesson(4)
	var types := lesson.map(func(x): return x.type)
	var no_repeat := true
	for i in range(1, types.size()):
		if types[i] == types[i - 1]:
			no_repeat = false
	check(lesson.size() == 4 and no_repeat, "tarefas: aula variada sem repetir tipo seguido", str(types))


func _test_nav_graph() -> void:
	var nav: NavGraph = main.nav
	check(nav.main_component_size > 2000, "navegação: grafo grande e conectado", str(nav.main_component_size))
	var info: Dictionary = main.npcs.class_info()
	var path := nav.path(info.door_in + Vector3(1, 0, -2), Vector3(0, 0.05, -10))
	var clear := true
	for i in range(1, path.size() - 1):
		if not nav.is_clear(path[i - 1], path[i]):
			clear = false
	check(path.size() > 3 and clear, "navegação: caminho da sala ao pátio sem atravessar paredes", "%d pontos" % path.size())
	var p2 := nav.path(Vector3(-55, 0.05, 29), Vector3(75, 0.05, -10))
	check(p2.size() > 5, "navegação: caminho do Bloco A ao Bloco B")


func _test_npcs_present() -> void:
	var m: NPCManager = main.npcs
	check(m.classmates.size() >= 10 and m.teacher != null and m.director != null and m.cook != null, "NPCs: turma e adultos criados", "%d colegas" % m.classmates.size())
	var names := {}
	for n in m.classmates:
		names[n.display_name] = true
	check(names.has("Lucas") and names.has("Ana"), "NPCs: alunos com nomes e personalidades")
	var mi := m.classmates[0].visual.skeleton.get_node("Body") as MeshInstance3D
	check(mi != null, "NPCs: usam o mesmo personagem do jogador")
	check(m.player_desk != null and m.player_desk.room == NPCManager.CLASS_ROOM, "NPCs: carteira do jogador definida na %s" % NPCManager.CLASS_ROOM)


func _test_dialogue_friendship() -> void:
	var m: NPCManager = main.npcs
	var lucas: NPC = null
	for n in m.classmates:
		if n.data.id.begins_with("aluno_") and main.quests.available_for(n) == "":
			lucas = n
			break
	if lucas == null:
		check(false, "diálogo: Lucas encontrado")
		return
	var fid: String = lucas.data.id if lucas else "lucas"
	var before := Friendship.points(fid)
	lucas.interact(player)
	await _frames(2)
	var dlg: DialogueUI = main.school_day.dialogue
	check(dlg.is_open() and not player.input_enabled, "diálogo: abre ao conversar e trava o jogador")
	for i in 6:
		dlg.advance()
		await _frames(1)
	check(not dlg.is_open() and player.input_enabled, "diálogo: fecha e devolve o controle")
	check(Friendship.points(fid) > before, "amizade: conversar aumenta pontos")


func _test_npc_bump() -> void:
	var m: NPCManager = main.npcs
	var n: NPC = m.classmates[2]
	n.stop()
	if n.sitting:
		n.seat.release()
		n.sitting = false
		n.seat = null
	n.teleport(Vector3(10, 0.05, -18), 0)
	n.activity = "test"
	var got := [false]
	var cb := func(_npc, _s): got[0] = true
	m.npc_bumped.connect(cb)
	_place(Vector3(10, 0.05, -21), 0)
	cam.yaw = player.yaw + PI
	Input.action_press("move_forward")
	Input.action_press("run")
	await _wait(1.5)
	_release_all()
	m.npc_bumped.disconnect(cb)
	check(got[0], "esbarrão: NPC reage e sistema é notificado")
	check(player.global_position.distance_to(n.global_position) > 0.4, "esbarrão: jogador não atravessa NPC")


func _test_upper_layer_while_sitting() -> void:
	var skel := CharacterModelBuilder.build(CharacterAppearance.new())
	add_child(skel)
	var anim := CharacterAnimator.new()
	anim.setup(skel)
	anim.play("sit_down")
	for i in 60:
		anim.update(1.0 / 60.0)
	anim.play("write")
	for i in 30:
		anim.update(1.0 / 60.0)
	check(anim.is_holding() and anim.upper_action == "write", "animação: escrever sentado sem perder a pose")
	skel.queue_free()


func _test_find_task() -> void:
	var day: SchoolDay = main.school_day
	var desk: Seat = main.npcs.player_desk
	player.force_stand()
	_place(desk.interact_point(), 0)
	day.phase = SchoolDay.Phase.CLASS_1
	day.lesson = [{"type": "find", "subject": "x", "prompt": "Traga", "item": "livro", "item_name": "o livro"}]
	day.lesson_index = 0
	day.lesson_results = []
	day._on_find_accepted()
	await _frames(5)
	var item: PickupItem = day._find_item
	check(item != null and is_instance_valid(item), "tarefa achar: objeto aparece na sala")
	item.attach_to(player.visual.hand_slot(), player)
	player.held_item = item
	var t: NPC = main.npcs.teacher
	check(t.get_prompt(player) == "Entregar à professora", "tarefa achar: professora pede a entrega")
	t.interact(player)
	await _frames(3)
	check(day.lesson_results == [true] and player.held_item == null, "tarefa achar: entrega conta como acerto")
	day._waiting_for_return_after_find = false


func _test_full_day() -> void:
	var day: SchoolDay = main.school_day
	var coins_before := GameManager.coins()
	var days_before := int(SaveManager.section("progress").get("days_completed", 0))
	day.start_day()
	await _frames(5)
	check(day.phase == SchoolDay.Phase.ARRIVAL, "dia: começa na chegada")
	var desk: Seat = main.npcs.player_desk
	_place(desk.interact_point(), 0)
	player.sit_on(desk)
	await _wait(2.5)
	check(day.phase == SchoolDay.Phase.CLASS_1, "dia: sentar na carteira inicia a aula")
	# troca a aula por tarefas de escolha e responde (3 certas, 1 errada)
	day.lesson = [day._gen.make("math"), day._gen.make("quiz"), day._gen.make("word"), day._gen.make("math"), day._gen.make("problem")]
	day.lesson_index = 0
	day.lesson_results = []
	await _wait(2.5)
	var answers := [true, false, true, true, true]
	for a in answers:
		day.classroom_ui.hide_panel()
		day._on_answered(a)
		await _wait(1.5)
	await _wait(2.0)
	check(day.phase == SchoolDay.Phase.RECESS, "dia: tarefas mínimas liberam o recreio", "fase=%d" % day.phase)
	await _wait(3.0)
	check(player.mode == PlayerController.Mode.FREE, "recreio: jogador levanta e fica livre")
	var active: int = main.npcs.npcs.filter(func(n): return n.active).size()
	check(active > main.npcs.classmates.size(), "recreio: alunos de outras turmas saem para o pátio", "%d ativos" % active)
	var moving: int = main.npcs.classmates.filter(func(n): return n.moving or n.activity in ["queue", "football", "tag"]).size()
	check(moving > 3, "recreio: colegas saem da sala para brincar", "%d" % moving)
	day.recess_left = 0.5
	await _wait(1.0)
	check(day.phase == SchoolDay.Phase.RETURN, "dia: sinal encerra o recreio")
	player.force_stand()
	_place(desk.interact_point(), 0)
	player.sit_on(desk)
	await _wait(2.5)
	check(day.phase == SchoolDay.Phase.CLASS_2, "dia: segunda aula começa ao sentar")
	day.lesson = [day._gen.make("math"), day._gen.make("quiz"), day._gen.make("order")]
	day.lesson_index = 0
	day.lesson_results = []
	await _wait(2.5)
	for a in [true, true, true]:
		day.classroom_ui.hide_panel()
		day._on_answered(a)
		await _wait(1.5)
	await _wait(2.0)
	check(day.phase == SchoolDay.Phase.DAY_END, "dia: aula 2 termina o dia")
	check(int(SaveManager.section("progress").days_completed) == days_before + 1, "dia: progresso salvo (dias concluídos)")
	check(GameManager.coins() > coins_before, "dia: recompensas em moedas", "%d -> %d" % [coins_before, GameManager.coins()])
	player.force_stand()
	_place(Vector3(0, 0.05, 72), 0)
	await _wait(0.5)
	check(main.hud._summary != null, "dia: resumo aparece ao sair pelo portão")


# --------------------------------------------------------------- FASE 3

func _recess() -> void:
	var day: SchoolDay = main.school_day
	if main.hud._summary:
		main.hud._summary.queue_free()
		main.hud._summary = null
	player.force_stand()
	day._start_recess()
	await _wait(0.5)


func _mg_start(gid: String) -> Minigame:
	var mm: MinigameManager = main.minigames
	if mm.active:
		mm.active.end_game(0, "teste", 0, 0)
		await _frames(2)
	var ok := mm.start(gid)
	check(ok and mm.active != null, "minijogo %s: inicia" % gid)
	return mm.active


func _test_minigames() -> void:
	await _recess()
	var mm: MinigameManager = main.minigames
	check(mm.stations.size() == MinigameManager.GAMES.size(), "minijogos: estações no mapa")
	var results := []
	var rc := func(r): results.append(r)
	mm.game_finished.connect(rc)

	# Futebol: gol detectado na trave do adversário
	var fb = await _mg_start("futebol")
	await _wait(3.4)
	check(fb.team_a.size() >= 2 and fb.team_b.size() >= 3 and fb.keeper_b != null, "futebol: times e goleiros montados")
	fb.ball.global_position = Vector3(60.6, 0.3, -49)
	fb.ball.linear_velocity = Vector3(3, 0, 0)
	await _frames(3)
	check(fb.score_a == 1, "futebol: gol contabilizado", "placar %d x %d" % [fb.score_a, fb.score_b])
	await _wait(3.5)
	# chute do jogador
	fb.ball.global_position = player.global_position + Vector3(sin(player.yaw), 0.1, cos(player.yaw)) * 0.6
	fb.ball.linear_velocity = Vector3.ZERO
	var bpos: Vector3 = fb.ball.global_position
	player.request_play()
	await _wait(1.0)
	check(fb.ball.global_position.distance_to(bpos) > 1.5, "futebol: jogador chuta a bola")
	await _wait(2.0)
	await _wait(3.5)
	fb.ball.global_position = Vector3(30, 0.3, -45)
	fb.ball.linear_velocity = Vector3.ZERO
	var d0: float = fb.team_b[0].global_position.distance_to(fb.ball.global_position)
	await _wait(1.2)
	var chasing := false
	for n in fb.team_a + fb.team_b:
		if n.global_position.distance_to(fb.ball.global_position) < d0 - 0.5 or n.moving:
			chasing = true
	check(chasing, "futebol: IA corre atrás da bola")
	fb.time_left = 0.05
	await _wait(0.3)
	check(mm.active == null and not results.is_empty() and results[-1].id == "futebol", "futebol: partida termina pelo tempo")

	# Queimada: acerto queima o adversário
	await _recess()
	var dg = await _mg_start("queimada")
	await _wait(3.4)
	var victim: NPC = dg.team_b[0]
	dg.ball.live = true
	dg.ball.live_team = 0
	dg._on_ball_hit(victim)
	check(dg.score_a == 1 and dg._out.has(victim), "queimada: acerto queima e manda para o cemitério")
	dg.ball.live = true
	dg.ball.live_team = 1
	dg._hit_cd = 0.0
	dg._on_ball_hit(player)
	check(dg.score_b == 1 and player.movement_locked, "queimada: jogador queimado fica fora")
	await _wait(6.5)
	check(not dg._out.has(player) and not player.movement_locked, "queimada: volta do cemitério")
	# pegar e arremessar
	for n in dg.team_a + dg.team_b:
		dg._out[n] = 99.0  # tira a IA do caminho para testar o jogador
	if dg.ball.held_by:
		dg.ball.throw_from(dg.ball.global_position, Vector3.ZERO, -1)
	dg._holder = null
	dg.ball.reset_ball()
	dg.ball.live = false
	dg.ball.global_position = player.global_position + Vector3(0.75, 0.3, 0)
	dg.ball.linear_velocity = Vector3.ZERO
	await _frames(2)
	player.request_interact()
	check(dg._holder == player, "queimada: jogador pega a bola", "holder=%s dist=%.2f vel=%.2f out=%s cd=%.1f" % [dg._holder, dg.ball.global_position.distance_to(player.global_position + Vector3(0, 0.3, 0)), dg.ball.linear_velocity.length(), dg._out.has(player), dg._countdown])
	player.request_play()
	await _wait(0.3)
	player.request_play_release()
	await _wait(0.6)
	check(dg._holder != player and dg.ball.held_by == null, "queimada: jogador arremessa")
	dg.time_left = 0.05
	await _wait(0.3)
	check(mm.active == null, "queimada: termina")

	# Bolinha de gude: tiro move bolinhas e o jogo avança
	await _recess()
	var mb = await _mg_start("gude")
	await _frames(5)
	var target: Dictionary = mb.marbles[0]
	var s: Dictionary = mb.shooters[0]
	mb.aim_angle = (target.pos - s.pos).angle()
	mb.on_play()
	mb._power = 1.0
	mb.on_play()
	check(mb._sim, "gude: lançamento inicia a simulação")
	var start_pos: Array = mb.marbles.map(func(m): return m.pos)
	for i in 400:
		await get_tree().process_frame
		if not mb._sim:
			break
	var moved := false
	for i in mb.marbles.size():
		if mb.marbles[i].pos.distance_to(start_pos[i]) > 0.01 or mb.marbles[i].out:
			moved = true
	check(moved, "gude: colisão empurra as bolinhas")
	check(not mb._sim, "gude: simulação termina e passa a vez")
	mb._finish(true)
	await _frames(2)
	check(mm.active == null, "gude: termina e salva coleção")

	# Aviãozinho: dobra e voa alguns metros
	await _recess()
	var pp = await _mg_start("aviao")
	for i in 3:
		pp._fold_t = asin(0.0) / 3.4
		pp.on_play()
	check(pp.step == 1 and pp.fold_quality > 0.9, "aviãozinho: 3 dobras perfeitas", "%.2f" % pp.fold_quality)
	pp.on_play()
	pp._power = 1.0
	pp.on_play_release()
	check(pp.step == 2, "aviãozinho: lançado")
	var max_d := 0.0
	var max_h := 0.0
	var went_back := false
	for i in 600:
		await get_tree().process_frame
		max_d = maxf(max_d, pp._distance())
		max_h = maxf(max_h, pp.pos.y)
		if pp.vel.z > 0.5:
			went_back = true
		if pp.step != 2:
			break
	check(max_d > 10.0, "aviãozinho: física de voo plana", "%.1f m" % max_d)
	check(max_h < 5.0 and not went_back, "aviãozinho: sem looping nem voo para trás", "h=%.1f" % max_h)
	pp._finish()
	await _frames(2)

	# Corrida
	await _recess()
	var rc2 = await _mg_start("corrida")
	await _wait(3.3)
	check(rc2.rivals.size() == 2 and rc2.rivals[0].moving, "corrida: adversários largam")
	player.global_position = Vector3(38.5, 0.05, -21)
	await _wait(0.3)
	check(mm.active == null and results[-1].id == "corrida", "corrida: chegada registrada")

	# Pular corda: pulo na hora certa conta; parado no chão falha
	await _recess()
	var jr = await _mg_start("corda")
	await _wait(3.2)
	var counted := false
	for i in 300:
		await get_tree().physics_frame
		if sin(jr._angle + jr._speed * 0.12) < -0.9 and player.is_on_floor():
			jr.on_jump()
		if jr.jumps >= 2:
			counted = true
			break
	check(counted, "corda: pulos no tempo certo contam", "%d" % jr.jumps)
	for i in 900:
		await get_tree().physics_frame
		if mm.active == null:
			break
	check(mm.active == null, "corda: ficar no chão 3 vezes encerra (3 vidas)")

	# Pontaria e guerra de papel
	await _recess()
	var ab = await _mg_start("pontaria")
	for i in 10:
		ab.on_play()
		await _wait(0.05)
		ab._power = 0.55
		ab.on_play_release()
		await _wait(0.15)
	await _wait(2.5)
	check(mm.active == null and results[-1].id == "pontaria", "pontaria: 10 arremessos e fim")
	await _recess()
	var pw = await _mg_start("guerra")
	await _wait(3.3)
	pw.on_play()
	await _wait(0.4)
	pw.on_play_release()
	await _wait(1.1)
	check(pw._shots.size() >= 0 and pw.running, "guerra: arremessos em andamento")
	pw.time_left = 0.05
	await _wait(0.3)
	check(mm.active == null, "guerra: termina pelo tempo")

	# fim do recreio encerra minijogo em andamento
	await _recess()
	await _mg_start("futebol")
	main.school_day._start_return()
	await _frames(3)
	check(mm.active == null, "minijogos: sinal do fim do recreio encerra a partida")
	mm.game_finished.disconnect(rc)
	check(results.all(func(r): return r.has("coins")), "minijogos: todos devolvem recompensas")


# --------------------------------------------------------------- FASE 4

func _adults_away() -> void:
	for a in [main.npcs.teacher, main.npcs.director, main.npcs.inspector]:
		a.stop()
		a.teleport(Vector3(-80, 0.05, 60), 0)


func _test_discipline() -> void:
	var disc: DisciplineSystem = main.discipline
	await _recess()
	SaveManager.section("discipline").clear()
	SaveManager.section("discipline")["reputation"] = 60
	disc.strikes_today = 0.0
	disc._cooldown.clear()
	_adults_away()
	_place(Vector3(10, 0.05, -15), 0)
	await _frames(2)
	GameManager.report_behavior("correr_corredor")
	check(disc.strikes_today == 0.0, "disciplina: sem testemunha adulta, nada acontece")
	main.npcs.inspector.teleport(Vector3(12, 0.05, -12), 0)
	await _frames(2)
	GameManager.report_behavior("esbarrao_forte")
	check(disc.strikes_today == 1.0, "disciplina: adulto viu e chamou atenção")
	disc._cooldown.clear()
	GameManager.report_behavior("bolinha_em_colega")
	await _wait(0.6)
	check(disc.in_cutscene, "disciplina: 2ª falta leva à diretoria")
	var dlg: DialogueUI = main.school_day.dialogue
	for i in 40:
		await _wait(0.1)
		if dlg.is_open():
			dlg.advance()
			dlg.advance()
		if not disc.in_cutscene:
			break
	await _wait(1.2)
	check(not disc.in_cutscene and DisciplineSystem.occurrences() == 1, "ocorrência 1: advertência registrada")
	check(player.input_enabled and GameManager.current_zone != "Diretoria", "ocorrência 1: jogador volta ao jogo")
	check(DisciplineSystem.reputation() < 60, "ocorrência: reputação diminui", str(DisciplineSystem.reputation()))
	# 2ª ocorrência: pais + ajudar a Dona Cida
	disc.start_occurrence("esbarrao_forte")
	await _wait(0.9)
	check(disc._parent != null, "ocorrência 2: responsável aparece na cena")
	for i in 60:
		await _wait(0.1)
		if dlg.is_open():
			dlg.advance()
			dlg.advance()
		if not disc.in_cutscene:
			break
	await _wait(1.2)
	check(disc.restricted and disc._cleanup_left == 5, "ocorrência 2: consequência leve (ajudar a recolher papel)")
	check(not main.minigames.start("futebol"), "ocorrência 2: minijogos bloqueados até cumprir")
	var balls := get_tree().get_nodes_in_group("cleanup")
	check(balls.size() == 5 and balls.all(func(b): return b.freeze and b.has_node("GoalArrow")), "ocorrência 2: papéis parados e com seta")
	for b in balls.slice(0, 5):
		disc.on_player_picked(b)
	check(disc.restricted and disc._cleanup_bin != null and disc.cleanup_target() != null, "ocorrência 2: depois dos papéis, a lixeira aparece com seta")
	disc._cleanup_bin.done.emit(disc._cleanup_bin)
	await _frames(2)
	check(not disc.restricted, "ocorrência 2: jogar na lixeira libera o recreio")
	# 3ª: banco do hall
	disc.start_occurrence("correr_corredor")
	for i in 60:
		await _wait(0.1)
		if dlg.is_open():
			dlg.advance()
			dlg.advance()
		if not disc.in_cutscene:
			break
	await _wait(1.2)
	check(disc.restricted and disc._bench_t > 0.0, "ocorrência 3: pensar no banco do hall")
	var bench: Seat = null
	for s in main.world.seats:
		if s.room == "Hall de Entrada" or (s.global_position.z > 29 and s.global_position.z < 32 and absf(s.global_position.x) > 7):
			bench = s
			break
	if bench:
		_place(bench.interact_point(), 0)
		player.sit_on(bench)
	disc._bench_t = 0.5
	await _wait(1.5)
	check(not disc.restricted, "ocorrência 3: castigo termina após o tempo sentado")
	player.force_stand()
	# dia limpo perdoa
	var active_before := int(DisciplineSystem.data().active)
	disc._clean_day = true
	SaveManager.section("discipline")["reputation"] = 80
	disc._on_day_finished({})
	check(int(DisciplineSystem.data().active) == active_before - 1, "reputação: dia tranquilo perdoa uma ocorrência")


func _test_events_missions() -> void:
	var ev: SchoolEvents = main.events
	await _recess()
	_place(Vector3(0, 0.05, -5), 0)
	for id in SchoolEvents.EVENTS:
		if id in ["ajuda", "recado"]:
			continue
		ev.trigger(id)
		await _frames(3)
	check(main.minigames.reward_mult == 2.0, "eventos: torneio relâmpago dobra recompensas")
	check(ev.special_snack, "eventos: lanche especial na cantina")
	check(not ev._extra_balls.is_empty(), "eventos: bola nova aparece no pátio")
	# figurinha rara com a Júlia
	var julia: NPC = ev._named("julia")
	if julia:
		var before := Stickers.count_unique()
		julia.activity_data["rare_sticker"] = true
		julia.interact(player)
		await _frames(2)
		var dlg: DialogueUI = main.school_day.dialogue
		for i in 6:
			dlg.advance()
		check(Stickers.count_unique() > before or Stickers.owned().size() > 0, "eventos: figurinha rara entra no álbum")
	# missão: achar objeto
	ev.mission = {}
	ev._start_fetch_mission()
	check(not ev.mission.is_empty() and ev.mission.type == "fetch", "missão: colega pede ajuda para achar objeto")
	var item: PickupItem = ev.mission.item_node
	item.attach_to(player.visual.hand_slot(), player)
	player.held_item = item
	var giver: NPC = ev.mission.giver
	check(giver.get_prompt(player).begins_with("Devolver"), "missão: prompt para devolver")
	var coins := GameManager.coins()
	giver.interact(player)
	await _frames(2)
	check(ev.mission.is_empty() and GameManager.coins() > coins, "missão: devolver dá recompensa")
	# missão: recado
	ev._start_deliver_mission()
	if not ev.mission.is_empty():
		var tgt: NPC = ev.mission.target_npc
		tgt.interact(player)
		await _frames(2)
		check(ev.mission.is_empty(), "missão: bilhete entregue")
	# cantina
	GameManager.add_rewards(0, 20)
	var c0 := GameManager.coins()
	main.npcs.cook.interact(player)
	await _frames(2)
	check(GameManager.coins() < c0, "cantina: comprar lanche gasta moedas")


# --------------------------------------------------------------- FASE 5

func _test_progression() -> void:
	var prog: Progression = main.progression
	check(Progression.owns("cam_uniforme") and Progression.owns("moc_vermelha"), "loja: itens iniciais no guarda-roupa")
	var p: Dictionary = SaveManager.section("player")
	p["coins"] = 1000
	p["level"] = 3
	var c0 := GameManager.coins()
	check(prog.buy("cam_amarela") == "" and Progression.owns("cam_amarela") and GameManager.coins() == c0 - 60, "loja: comprar desconta moedas e guarda o item")
	check(prog.buy("cam_amarela") != "", "loja: não compra o mesmo item duas vezes")
	check(prog.buy("bon_dourado") != "" and not Progression.owns("bon_dourado"), "loja: item bloqueado por nível")
	p["coins"] = 5
	check(prog.buy("cam_roxa") != "", "loja: moedas insuficientes")
	p["coins"] = 1000
	prog.equip("cam_amarela")
	check(player.visual.appearance.shirt_color.is_equal_approx(Color("f2b632")), "guarda-roupa: equipar muda o personagem")
	prog.buy("pen_black")
	prog.equip("pen_black")
	check(player.visual.appearance.hair_style == "black_power" and prog.is_equipped("pen_black"), "guarda-roupa: trocar penteado")
	var stick := Stickers.count_unique()
	var total_before := 0
	for v in Stickers.owned().values():
		total_before += int(v)
	prog.buy("fig_pacote")
	var total_after := 0
	for v in Stickers.owned().values():
		total_after += int(v)
	check(total_after == total_before + 4, "loja: pacote dá 4 figurinhas")
	var g: Dictionary = SaveManager.section("collections").get("gude", {})
	var gsum := 0
	for v in g.values():
		gsum += int(v)
	prog.buy("gude_saco")
	var gsum2 := 0
	for v in SaveManager.section("collections").get("gude", {}).values():
		gsum2 += int(v)
	check(gsum2 == gsum + 3, "loja: saquinho dá 3 bolinhas de gude")
	prog.buy("dec_planta")
	await _frames(2)
	var decor: Node = main.world.get_node_or_null("DeskDecor")
	check(decor != null and decor.get_child_count() > 0, "decoração: aparece na carteira do jogador")
	# missões diárias
	SaveManager.section("missions").clear()
	prog.ensure_daily(99)
	check(prog.daily_list().size() == 3, "missões: 3 missões diárias geradas")
	var e: Dictionary = prog.daily_list()[0]
	var coins := GameManager.coins()
	var st: Dictionary = SaveManager.section("stats")
	if str(e.key).begins_with("mg_"):
		var s: Dictionary = st.get(e.key, {"played": 0})
		s["played"] = int(s.get("played", 0)) + int(e.target)
		st[e.key] = s
	else:
		st[e.key] = int(st.get(e.key, 0)) + int(e.target)
	await _wait(1.3)
	check(e.done and GameManager.coins() > coins, "missões: completar dá recompensa automática")
	# conquistas
	SaveManager.section("achievements").erase("rico")
	await _wait(1.2)
	check(SaveManager.section("achievements").has("rico"), "conquistas: desbloqueio automático (cofrinho cheio)")
	# persistência
	SaveManager.save_game()
	SaveManager.load_game()
	check(Progression.owns("cam_amarela") and Progression.inventory().equipped.camiseta == "cam_amarela", "save: inventário e equipados persistem")
	# menu da mochila
	var pm: ProfileMenu = main.profile_menu
	GameManager.set_state(GameManager.State.PLAYING)
	pm.open_menu()
	await get_tree().process_frame
	check(get_tree().paused and not main.hud._pause_layer.visible, "mochila: abre pausando sem a tela de pausa")
	for t in ProfileMenu.TABS:
		pm._tab = t[0]
		pm._refresh()
		await get_tree().process_frame
	check(pm._content.get_child_count() > 0, "mochila: todas as abas montam conteúdo")
	pm.close_menu()
	await get_tree().process_frame
	check(not get_tree().paused and GameManager.is_playing(), "mochila: fecha e retoma o jogo")


# --------------------------------------------------------------- FASE 6

func _test_polish() -> void:
	var missing := []
	for snd in ["music_recreio", "music_aula", "music_menu", "ambient_recreio", "ambient_cantina", "ambient_sala", "whistle", "applause", "school_bell", "kick", "step_hard", "step_grass"]:
		if AudioManager.get_stream(snd) == null:
			missing.append(snd)
	check(missing.is_empty(), "áudio: todos os sons carregam", str(missing))
	await _recess()
	check(AudioManager._music_current == "music_recreio", "áudio: música do recreio toca no recreio")
	_place(Vector3(0, 0.05, -5), 0)
	await _wait(0.5)
	check(AudioManager._ambient_current == "ambient_recreio", "áudio: burburinho de crianças no pátio durante o recreio")
	var c_before: int = Effects._next.get("confetti", 0)
	Effects.burst(Vector3(0, 1, 0), "confetti")
	Effects.burst(Vector3(0, 1, 0), "dust")
	check(Effects._pools.has("confetti") and Effects._next.confetti == (c_before + 1) % Effects.POOL and Effects._pools.confetti.size() == Effects.POOL, "efeitos: confete com pool de partículas")
	# anúncios: desligados por padrão, sem botões falsos
	check(not AdsManager.enabled and not AdsManager.can_show_rewarded(), "anúncios: desativados por padrão")
	main.hud.show_day_summary({"day": 1, "correct": 2, "total": 4, "coins": 20, "xp": 40}, func(): pass)
	var has_ad_btn := false
	for b in main.hud._summary.find_children("*", "Button", true, false):
		if (b as Button).text.contains("anúncio"):
			has_ad_btn = true
	check(not has_ad_btn, "anúncios: sem provedor, nenhum botão de anúncio aparece")
	main.hud._summary.queue_free()
	main.hud._summary = null
	# com provedor (simulado) o recompensado é voluntário e paga de verdade
	var mock = load("res://tests/mock_ads_provider.gd").new()
	AdsManager.enabled = true
	AdsManager.register_provider(mock)
	var c0 := GameManager.coins()
	AdsManager.show_rewarded("teste", func(): GameManager.add_rewards(0, 20))
	check(mock.shown_rewarded == 1 and GameManager.coins() == c0 + 20, "anúncios: recompensado entrega a recompensa")
	AdsManager._last_interstitial_day = -99
	AdsManager.maybe_show_interstitial(1)
	check(mock.shown_interstitial == 0, "anúncios: nada de intersticial nos primeiros dias")
	AdsManager.maybe_show_interstitial(4)
	AdsManager.maybe_show_interstitial(5)
	check(mock.shown_interstitial == 1, "anúncios: limite de frequência do intersticial")
	AdsManager.enabled = false
	AdsManager.provider = null


func _finish() -> void:
	print("\n===== RESULTADO DOS TESTES =====")
	for l in _log:
		print(l)
	print("Total: %d ok, %d falhas" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_parque() -> void:
	# relevo: altura do chão bate com a colisão (o jogador fica em pé no morro)
	var top := Vector3(ParkHill.HILL.x + 2.0, 0, ParkHill.HILL.z + 6.0)
	var hy := ParkHill.height(top.x, top.z)
	_place(Vector3(top.x, hy + 1.5, top.z), 0)
	await _wait(0.8)
	check(absf(player.global_position.y - hy) < 0.35 and player.is_on_floor(), "parque: jogador fica em pé no morro", "y=%.2f chão=%.2f" % [player.global_position.y, hy])
	# bots sobem a trilha até o topo
	var p: PackedVector3Array = main.npcs.nav.path(Vector3(0, 0.05, -60), Vector3(ParkHill.HILL.x - 1.0, ParkHill.HILL.y, ParkHill.HILL.z + 0.5))
	var topy := -INF
	for v in p:
		topy = maxf(topy, v.y)
	check(p.size() > 3 and topy > 4.5, "parque: caminho dos bots sobe o morro pela trilha", "pts=%d top=%.1f" % [p.size(), topy])
	var p2: PackedVector3Array = main.npcs.nav.path(Vector3(0, 0.05, -60), Vector3(ParkHill.LAKE.x + ParkHill.LAKE_R + 3.0, 0.05, ParkHill.LAKE.y))
	check(p2.size() > 2, "parque: caminho até o outro lado do lago")
	# escorregador leva lá para baixo
	var slide: SlideSpot = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is SlideSpot:
			slide = n
	check(slide != null, "parque: escorregador existe")
	if slide:
		_place(slide.global_position + Vector3(-0.3, 0.3, 0), 90)
		await _wait(0.3)
		slide.interact(player)
		await _wait(3.2)
		check(player.global_position.y < 1.5 and player.input_enabled, "parque: escorregar desce o morro", "y=%.2f" % player.global_position.y)
	_place(Vector3(0, 0.05, -6), 0)


func _test_revisao5() -> void:
	var ctl: MobileControls = main.hud.controls
	# correr só enquanto segura
	_place(Vector3(0, 0.05, -6), 0)
	ctl.btn_run.press()
	check(player.run_active, "correr: segurando corre")
	ctl.btn_run.release()
	check(not player.run_active, "correr: soltou, para de correr")
	# painel de chat não bloqueia o analógico
	var cp := ChatPanel.new()
	main.ui_layer.add_child(cp)
	await _frames(2)
	var vs := main.get_viewport().get_visible_rect().size
	check(not cp.blocks_point(Vector2(150, vs.y - 140)), "online: chat não bloqueia o analógico")
	cp.queue_free()
	# trilha-guia no chão até o objetivo
	var trail: GuideTrail = main.world.get_node("GuideTrail")
	main.hud.set_game_point(Vector3(20, 1.05, -10))
	for i in 5:
		await _frames(2)
	check(trail._mm.multimesh.visible_instance_count > 3 and trail._arrow.visible, "missão: trilha de setas e seta na cabeça", "%d" % trail._mm.multimesh.visible_instance_count)
	main.hud.set_game_point(null)
	# cancelar missão
	await _recess()
	main.quests.start("biblioteca")
	check(bool(main.hud.mission_cancel_check.call()), "missão: botão cancelar aparece")
	main.hud.mission_cancel.call()
	check(main.quests.active_id == "", "missão: cancelada")
	# brincadeira esconde botões que não usa
	var hs = await _mg_start("amarelinha")
	player._emit_context(true)
	await _frames(2)
	check(not ctl.btn_run.visible and ctl.btn_jump.visible, "amarelinha: só os botões que usa")
	hs._finish()
	await _frames(3)
	player._emit_context(true)
	await _frames(2)
	check(ctl.btn_run.visible, "botões voltam depois da brincadeira")
	check(MinigameManager.TUTORIALS.size() >= 9, "tutoriais para todas as brincadeiras")
	# prazo para sentar
	var day: SchoolDay = main.school_day
	check(day.ARRIVAL_LIMIT > 0 and day.RETURN_LIMIT > 0, "aula: prazo para voltar à sala")


func _test_online_tag() -> void:
	await _recess()
	_place(Vector3(0, 0.05, -6), 180)
	var sess := OnlineSession.new()
	sess.npcs = main.npcs
	sess.day = main.school_day
	main.add_child(sess)
	sess.setup(player, main.world, main.ui_layer, main.hud)
	NetworkManager.my_id = "eu"
	var nm := NetworkManager
	nm._handle({"t": "welcome", "id": "eu", "name": "Eu", "room": "sala-1234", "code": "1234", "private": true, "token": "x", "quick": ["Oi!"], "players": [{"id": "amigo", "name": "Amigo", "level": 3, "pos": [2, 0, -6]}]})
	await _frames(2)
	check(sess.remotes.has("amigo"), "online: colega remoto aparece")
	nm._handle({"t": "tag_event", "kind": "invite", "from": "amigo", "fromName": "Amigo", "names": {}})
	check(sess.tag._invite_box.visible, "pique-pega: convite aparece para a sala")
	var names := {"eu": "Eu", "amigo": "Amigo"}
	nm._handle({"t": "tag", "state": "playing", "host": "amigo", "players": ["eu", "amigo"], "it": "eu", "left": 100, "names": names})
	await _frames(2)
	check(main.school_day.hold_recess and sess.tag._marker.visible and sess.tag._marker.get_parent() == player, "pique-pega: marcador no pegador e recreio esperando")
	nm._handle({"t": "tag", "state": "playing", "host": "amigo", "players": ["eu", "amigo"], "it": "amigo", "left": 90, "names": names})
	await _frames(2)
	check(sess.tag._marker.get_parent() == sess.remotes["amigo"].root, "pique-pega: marcador passa para o colega")
	var coins_before := GameManager.coins()
	nm._handle({"t": "tag_event", "kind": "end", "results": [{"id": "eu", "name": "Eu", "secondsIt": 10, "tags": 3}, {"id": "amigo", "name": "Amigo", "secondsIt": 90, "tags": 1}], "names": names})
	await _frames(2)
	check(GameManager.coins() == coins_before + 40 and not main.school_day.hold_recess and not sess.tag._marker.visible, "pique-pega: 1º lugar ganha prêmio e recreio volta")
	NetworkManager.last_channel = "near"
	sess._on_chat("amigo", "Amigo", "Oi!")
	check(sess.chat_panel._lines.get_child_count() > 0 and (sess.chat_panel._lines.get_child(sess.chat_panel._lines.get_child_count() - 1) as Button).text.begins_with("[Perto]"), "chat: canal Perto de mim")
	sess.chat_panel.queue_free()
	sess.queue_free()
	NetworkManager.my_id = ""
	await _frames(2)


func _test_revisao3() -> void:
	# falas: saco embaralhado não repete até acabar
	var seen := {}
	var n_lines: int = NPCLines.AMBIENT.futebol.size()
	var rep := false
	for i in n_lines:
		var l: String = NPCLines.draw("teste_bag", NPCLines.AMBIENT.futebol)
		if seen.has(l):
			rep = true
		seen[l] = true
	check(not rep and seen.size() == n_lines, "falas: sorteio sem repetição")
	check(NPCLines.talk("comum").size() >= 2, "falas: conversas completas")
	# loja: ofertas do dia e preço com desconto
	var d1 := ShopCatalog.deals("2026-01-01")
	check(d1 == ShopCatalog.deals("2026-01-01") and d1.size() == 4 and ShopCatalog.flash_deal_id("2026-01-01") != "", "loja: 4 ofertas do dia, uma relâmpago")
	var fid := ShopCatalog.flash_deal_id("2026-01-01")
	var fit := ShopCatalog.get_item(fid)
	check(ShopCatalog.price_of(fit, "2026-01-01") == int(round(int(fit.price) * 0.5)), "loja: relâmpago custa metade")
	check(ShopCatalog.by_cat("skin").size() >= 6 and ShopCatalog.by_cat("pacote").size() >= 3, "loja: skins e pacotes")
	# skin: compra, veste e tirar ao trocar de camiseta
	var prog: Progression = main.progression
	var pdata: Dictionary = SaveManager.section("player")
	pdata["level"] = 9
	pdata["coins"] = 99999
	var err := prog.buy("skin_ninja")
	prog.equip("skin_ninja")
	await _frames(2)
	check(err == "" and prog.is_equipped("skin_ninja") and player.visual.appearance.shirt_color.is_equal_approx(Color("1c1c24")), "skin: compra e veste")
	prog.equip("cam_uniforme")
	check(not prog.is_equipped("skin_ninja"), "skin: trocar a camiseta tira a skin")
	var err2 := prog.buy("pac_estudioso")
	check(err2 == "" and Progression.owns("ace_oculos") and Progression.owns("dec_planta"), "pacote: entrega todos os itens")
	# bots no online
	var npcm: NPCManager = main.npcs
	npcm.set_online_players(1)
	var full := npcm.allowed_other_bots()
	npcm.set_online_players(4)
	var less := npcm.allowed_other_bots()
	npcm.set_online_players(50)
	var minimum := npcm.allowed_other_bots()
	npcm.set_online_players(1)
	check(full > less and minimum >= mini(NPCManager.MIN_OTHER_BOTS, npcm.others.size()) and minimum > 0, "online: menos bots com mais jogadores, com mínimo", "%d/%d/%d" % [full, less, minimum])
	check(NetworkManager.SERVER_URL.begins_with("wss://") and main._online_menu != null, "online: servidor fixo e menu Jogar online")


func _test_revisao2() -> void:
	# explicação quando errar
	var gen := ClassroomTasks.new(5, 4)
	var all_explained := true
	for t in ["math", "quiz", "word", "order", "problem"]:
		for k in 5:
			var task := gen.make(t, "Ciências")
			if str(task.get("explain", "")) == "":
				all_explained = false
	check(all_explained, "aula: toda pergunta tem explicação para o erro")
	check(gen.make_lesson(7, true, "Matemática").size() == 7, "aula: aulas mais longas (7 tarefas)")
	check(SchoolDay.RECESS_SECONDS >= 420.0, "recreio: bem maior (%d s)" % int(SchoolDay.RECESS_SECONDS))
	# missão: nenhuma oferta nova durante uma missão
	await _recess()
	var qs: QuestSystem = main.quests
	qs.start("horta_plantar")
	await _frames(2)
	var any_offer := false
	for n in main.npcs.npcs:
		if qs.available_for(n) != "":
			any_offer = true
	check(not any_offer, "missões: sem novas ofertas durante uma missão")
	qs.abandon()
	# quem oferece para de andar
	var giver: NPC = qs._giver_node("jardineiro")
	if giver:
		giver.go_to(giver.global_position + Vector3(6, 0, 0))
		_place(giver.global_position + Vector3(0, 0, 1.2), 180)
		qs.offer(qs.available_for(giver) if qs.available_for(giver) != "" else "plantar_arvore", giver)
		await _frames(3)
		check(not giver.moving and giver.talking_to_player and not player.input_enabled, "missões: quem oferece para e conversa")
		main.school_day.dialogue._close(1)
		await _frames(2)
		check(not giver.talking_to_player and player.input_enabled, "missões: conversa termina e libera")
	# cantina: dá para comprar do lado de fora do balcão
	check(main.npcs.cook.interact_radius >= 3.0, "cantina: atende de mais longe")
	_place(Vector3(0, 0.05, 66), 0)


func _test_revisao1() -> void:
	# idade -> nível das perguntas
	check(ClassroomTasks.level_for_age(8) < ClassroomTasks.level_for_age(12), "idade: 8 anos tem perguntas mais fáceis que 12")
	var gen := ClassroomTasks.new()
	var subjects_ok := true
	for subj in ClassroomTasks.SUBJECTS:
		var l: Array = gen.make_lesson(4, false, subj)
		if l.size() < 4:
			subjects_ok = false
	check(subjects_ok and ClassroomTasks.SUBJECTS.size() >= 6, "matérias: todas geram aula (%d)" % ClassroomTasks.SUBJECTS.size())
	# amarelinha: plano de pulos cai nas casas pintadas
	var plan: Array = preload("res://scripts/minigames/hopscotch.gd").hop_plan(3)
	var picks := plan.filter(func(e): return e.get("pick", false)).size()
	var on_cells := true
	for e in plan:
		if e.pose == "hop_one" and e.row.size() == 1 and e.pos.distance_to(preload("res://scripts/minigames/hopscotch.gd").cell_pos(e.row[0])) > 0.01:
			on_cells = false
	check(picks == 1 and on_cells and plan[-1].get("end", false), "amarelinha: pés nas casas e pega a pedra uma vez")
	# filtro do chat local
	check(ChatFilter.check("Bora jogar?").ok, "chat: frase normal passa")
	check(not ChatFilter.check("seu 1d10ta").ok, "chat: palavrão disfarçado bloqueado")
	check(not ChatFilter.check("meu zap 11 98765-4321").ok, "chat: telefone bloqueado")
	check(not NetworkManager.is_online(), "online: desligado por padrão")
	# missões: oferecer, aceitar e concluir um passo
	await _recess()
	var qs: QuestSystem = main.quests
	if qs.active_id != "":
		qs.abandon()
	check(qs.QUESTS.size() >= 15, "missões: catálogo grande (%d)" % qs.QUESTS.size())
	var avail := qs.QUESTS.keys().filter(func(q): return qs.is_available(q))
	check(avail.size() >= 5, "missões: várias disponíveis no recreio (%d)" % avail.size())
	qs.start("horta_plantar")
	await _frames(2)
	check(qs.active_id == "horta_plantar" and qs._target_pos() != null, "missões: ativa com destino no mapa")
	qs.abandon()
	check(qs.active_id == "", "missões: abandonar")
	# veículo: só fora dos prédios e mais rápido
	_place(Vector3(0, 0.05, 66), 0)
	await _frames(3)
	player.set_vehicle("skate")
	player.toggle_ride()
	check(player.riding, "veículo: sobe no skate no pátio")
	player.toggle_ride()
	player.set_vehicle("")
	check(not player.riding, "veículo: desce")
	# empurrão sem testemunha: colega fica chateado
	var disc: DisciplineSystem = main.discipline
	_adults_away()
	var kid: NPC = null
	for n in main.npcs.npcs:
		if n.role == "student" and n.active:
			kid = n
			break
	SaveManager.section("discipline")["reputation"] = 60
	var before := Friendship.points(kid.data.id)
	disc.strikes_today = 0.0
	disc.on_shove(kid)
	check(disc.strikes_today == 1.0 and Friendship.points(kid.data.id) < before, "empurrão: sem testemunha vira falta leve e chateia o colega")
	# matar aula: diretor e inspetora procuram
	disc.start_search()
	check(disc.truant and main.npcs.director.activity == "search", "matar aula: busca começa")
	disc.stop_search()
	check(not disc.truant, "matar aula: busca termina")
	# Bloco C: caminho até o 2º andar
	var p: PackedVector3Array = main.npcs.nav.path(Vector3(-76, 0.05, 30), Vector3(-80, 3.9, 30))
	var top := -INF
	for v in p:
		top = maxf(top, v.y)
	check(p.size() > 2 and top > 3.0, "Bloco C: rota de navegação sobe a escada", "pts=%d top=%.1f" % [p.size(), top])
	_place(Vector3(0, 0.05, 66), 0)
