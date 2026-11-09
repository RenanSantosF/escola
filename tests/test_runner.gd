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
		if n.data.id == "lucas":
			lucas = n
	if lucas == null:
		check(false, "diálogo: Lucas encontrado")
		return
	var before := Friendship.points("lucas")
	lucas.interact(player)
	await _frames(2)
	var dlg: DialogueUI = main.school_day.dialogue
	check(dlg.is_open() and not player.input_enabled, "diálogo: abre ao conversar e trava o jogador")
	for i in 6:
		dlg.advance()
		await _frames(1)
	check(not dlg.is_open() and player.input_enabled, "diálogo: fecha e devolve o controle")
	check(Friendship.points("lucas") > before, "amizade: conversar aumenta pontos")


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
	day.lesson = [day._gen.make("math"), day._gen.make("quiz"), day._gen.make("word"), day._gen.make("math")]
	day.lesson_index = 0
	day.lesson_results = []
	await _wait(2.5)
	var answers := [true, false, true, true]
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
	day.lesson = [day._gen.make("math"), day._gen.make("quiz")]
	day.lesson_index = 0
	day.lesson_results = []
	await _wait(2.5)
	for a in [true, true]:
		day.classroom_ui.hide_panel()
		day._on_answered(a)
		await _wait(1.5)
	await _wait(2.0)
	check(day.phase == SchoolDay.Phase.DAY_END, "dia: aula 2 termina o dia")
	check(int(SaveManager.section("progress").days_completed) == days_before + 1, "dia: progresso salvo (dias concluídos)")
	check(GameManager.coins() > coins_before, "dia: recompensas em moedas", "%d -> %d" % [coins_before, GameManager.coins()])
	await _wait(2.5)
	check(main.hud._summary != null, "dia: resumo do dia exibido")


func _finish() -> void:
	print("\n===== RESULTADO DOS TESTES =====")
	for l in _log:
		print(l)
	print("Total: %d ok, %d falhas" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
