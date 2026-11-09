class_name SchoolDay
extends Node
## Ciclo do dia escolar:
## CHEGADA → AULA 1 (tarefas) → RECREIO (cronometrado) → VOLTA → AULA 2 → FIM.
## Coordena NPCs, professora, interface de tarefas, sinal, objetivos e
## recompensas. Ciclo curto (~8–10 min) pensado para sessões no celular.

signal phase_changed(phase: int)
signal task_finished(correct: bool)
signal day_finished(summary: Dictionary)

enum Phase { ARRIVAL, CLASS_1, RECESS, RETURN, CLASS_2, DAY_END }

const RECESS_SECONDS := 210.0
const LESSON_SIZE := [4, 2]
const MIN_CORRECT := [2, 1]
const PHASE_NAMES := ["Chegada", "Aula", "Recreio", "Volta para a sala", "Aula", "Saída"]

var world: SchoolWorld
var npcs: NPCManager
var player: PlayerController
var hud: HUD
var classroom_ui: ClassroomUI
var dialogue: DialogueUI

var phase: int = Phase.ARRIVAL
var day := 1
var recess_left := 0.0
var lesson: Array = []
var lesson_index := 0
var lesson_results: Array = []
var extra_tasks := 0
var day_correct := 0
var day_total := 0
var _class_no := 0
var _task_active := false
var _waiting_seat := false
var _find_task: Dictionary = {}
var _find_item: PickupItem
var _find_timer := 0.0
var _nag_timer := 0.0
var _phase_time := 0.0
var _talking_npc: NPC
var _marker: Node3D
var _marker_target: Variant = null
var _board_label: Label3D
var _gen: ClassroomTasks
var events: Node = null  # SchoolEvents


func setup(w: SchoolWorld, m: NPCManager, p: PlayerController, h: HUD) -> void:
	world = w
	npcs = m
	player = p
	hud = h
	m.day = self
	classroom_ui = ClassroomUI.new()
	hud.add_child(classroom_ui)
	hud.move_child(classroom_ui, 1)
	classroom_ui.answered.connect(_on_answered)
	classroom_ui.find_accepted.connect(_on_find_accepted)
	dialogue = DialogueUI.new()
	hud.add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	m.dialogue_requested.connect(_on_dialogue_requested)
	p.sat.connect(_on_player_sat)
	p.stood.connect(_on_player_stood)
	_marker = _make_marker()
	w.add_child(_marker)
	var info := npcs.class_info()
	var bl: int = info.get("board_label", -1)
	if bl >= 0 and bl < world._labels.size():
		_board_label = world._labels[bl][0]


func _make_marker() -> Node3D:
	var m := Node3D.new()
	m.name = "ObjectiveMarker"
	var mi := MeshInstance3D.new()
	var md := MeshData.new()
	md.cur_color = Color("ffcf3f")
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.25, 0)), 0.0, 0.22, 0.5, 12)
	md.cur_color = Color("ff8a3d")
	md.add_cylinder(Transform3D(Basis(), Vector3(0, 0.7, 0)), 0.09, 0.09, 0.45, 10)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.mesh = md.build_mesh(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	m.visible = false
	return m


# =================================================================== fases

func start_day() -> void:
	day = int(SaveManager.section("progress").get("days_completed", 0)) + 1
	_gen = ClassroomTasks.new(day * 7919 + randi() % 1000, day)
	day_correct = 0
	day_total = 0
	_class_no = 0
	if player.mode == PlayerController.Mode.SITTING:
		player.force_stand()
	player.global_position = Vector3(-2, 0.05, 38.5)
	player.yaw = PI * 1.5
	player.velocity = Vector3.ZERO
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()
	npcs.begin_arrival()
	_set_phase(Phase.ARRIVAL)
	hud.show_banner("Dia %d" % day, "Bom dia! Vá para a %s." % NPCManager.CLASS_ROOM)
	_set_objective("Vá para a %s e sente na sua carteira" % NPCManager.CLASS_ROOM, npcs.player_desk)
	_waiting_seat = true


func _set_phase(p: int) -> void:
	phase = p
	_phase_time = 0.0
	phase_changed.emit(p)
	_update_clock()


func _begin_class(n: int) -> void:
	_class_no = n
	_set_phase(Phase.CLASS_1 if n == 0 else Phase.CLASS_2)
	npcs.begin_class()
	lesson = _gen.make_lesson(LESSON_SIZE[n], true)
	lesson_index = 0
	lesson_results = []
	extra_tasks = 0
	_set_objective("Faça as tarefas da aula", null)
	npcs.teacher.say("Bom dia, turma! Vamos começar." if n == 0 else "Bem-vindos de volta! Mais um pouquinho.", 3.0)
	get_tree().create_timer(2.0).timeout.connect(_present_task)


func _present_task() -> void:
	if phase != Phase.CLASS_1 and phase != Phase.CLASS_2:
		return
	if not _player_at_desk():
		_waiting_seat = true
		return
	var task: Dictionary = lesson[lesson_index]
	_task_active = true
	npcs.teacher.visual.play("point_board")
	if _board_label:
		_board_label.text = task.prompt.split("\n")[0] if task.type != "find" else "Ajudantes do dia :)"
	for n in npcs.classmates:
		if n.sitting and randf() < 0.2:
			n.visual.play("raise_hand")
	hud.controls.visible = false
	classroom_ui.show_task(task, lesson_index, lesson.size(), lesson_results)


func _on_answered(ok: bool) -> void:
	_task_active = false
	lesson_results.append(ok)
	day_total += 1
	if ok:
		day_correct += 1
		GameManager.add_stat("acertos")
		npcs.teacher.visual.play("clap")
		npcs.teacher.say(["Muito bem!", "Isso mesmo!", "Excelente!", "Parabéns!"].pick_random(), 2.0)
		GameManager.add_rewards(10, 2)
	else:
		npcs.teacher.say(["Quase! Vamos tentar a próxima.", "Tudo bem, errar faz parte!", "Presta atenção na próxima!"].pick_random(), 2.4)
	task_finished.emit(ok)
	hud.controls.visible = true
	lesson_index += 1
	if lesson_index >= lesson.size():
		var correct := lesson_results.count(true)
		var need: int = MIN_CORRECT[_class_no]
		if correct < need and extra_tasks < 3:
			extra_tasks += 1
			lesson.append(_gen.make(["math", "word", "quiz"].pick_random()))
			npcs.teacher.say("Vamos fazer mais uma para liberar o recreio!" if _class_no == 0 else "Mais uma, vamos lá!", 2.6)
			get_tree().create_timer(2.6).timeout.connect(_present_task)
		else:
			_end_class()
	else:
		get_tree().create_timer(1.2).timeout.connect(_present_task)


func _end_class() -> void:
	_set_objective("", null)
	if _board_label:
		_board_label.text = "Muito bem, turma!" if _class_no == 0 else "Até amanhã!"
	if _class_no == 0:
		npcs.teacher.say("Muito bem! Podem ir para o recreio!", 2.5)
		get_tree().create_timer(1.5).timeout.connect(_start_recess)
	else:
		npcs.teacher.say("Por hoje é só. Até amanhã!", 2.5)
		get_tree().create_timer(1.5).timeout.connect(_end_day)


func _start_recess() -> void:
	ring_bell()
	_set_phase(Phase.RECESS)
	recess_left = RECESS_SECONDS
	hud.show_banner("RECREIO!", "Aproveite! Volte quando o sinal tocar.")
	if player.mode == PlayerController.Mode.SITTING:
		player.stand_up()
	npcs.begin_recess()
	_set_objective("Aproveite o recreio!", null)


func _start_return() -> void:
	ring_bell()
	_set_phase(Phase.RETURN)
	hud.show_banner("Fim do recreio", "Hora de voltar para a sala!")
	npcs.begin_return()
	_set_objective("Volte para a %s e sente na sua carteira" % NPCManager.CLASS_ROOM, npcs.player_desk)
	_waiting_seat = true


func _end_day() -> void:
	ring_bell()
	_set_phase(Phase.DAY_END)
	npcs.begin_day_end()
	var coins := day_correct * 5 + 10
	var xp := day_correct * 10 + 20
	var lvl_before := GameManager.level()
	GameManager.add_rewards(xp, coins)
	var prog: Dictionary = SaveManager.section("progress")
	prog["days_completed"] = day
	var best: Dictionary = prog.get("activities", {})
	best["tarefas_certas"] = int(best.get("tarefas_certas", 0)) + day_correct
	best["tarefas_feitas"] = int(best.get("tarefas_feitas", 0)) + day_total
	prog["activities"] = best
	SaveManager.save_game()
	var summary := {"day": day, "correct": day_correct, "total": day_total, "coins": coins, "xp": xp,
		"level_up": GameManager.level() > lvl_before}
	_set_objective("", null)
	get_tree().create_timer(2.0).timeout.connect(func():
		hud.show_day_summary(summary, start_day))
	day_finished.emit(summary)


func ring_bell() -> void:
	AudioManager.play_ui("school_bell", -4.0)
	if player.camera_rig:
		player.camera_rig.shake(0.03)


# =================================================================== jogador

func _player_at_desk() -> bool:
	return player.mode == PlayerController.Mode.SITTING and player.current_seat == npcs.player_desk


func _on_player_sat(seat: Seat) -> void:
	if seat != npcs.player_desk:
		return
	# câmera mais próxima e alta para enxergar a lousa por cima dos colegas
	if player.camera_rig:
		player.camera_rig.distance = 2.4
		player.camera_rig.pitch = -24.0
		player.camera_rig.yaw = player.yaw + PI
	_set_objective("" if phase != Phase.ARRIVAL and phase != Phase.RETURN else "Aguarde a professora...", null)
	if _waiting_seat:
		_waiting_seat = false
		match phase:
			Phase.ARRIVAL:
				get_tree().create_timer(1.2).timeout.connect(func(): _begin_class(0))
			Phase.RETURN:
				get_tree().create_timer(1.2).timeout.connect(func(): _begin_class(1))
			Phase.CLASS_1, Phase.CLASS_2:
				if _find_task.is_empty():
					get_tree().create_timer(0.8).timeout.connect(_present_task)


func _on_player_stood() -> void:
	if player.camera_rig:
		player.camera_rig.distance = 4.6
	if (phase == Phase.CLASS_1 or phase == Phase.CLASS_2) and _find_task.is_empty():
		_set_objective("Volte para a sua carteira", npcs.player_desk)
		if not _task_active:
			_waiting_seat = true
		GameManager.report_behavior("levantou_na_aula")


# =================================================================== tarefa "achar"

func _on_find_accepted() -> void:
	_find_task = lesson[lesson_index]
	var info := npcs.class_info()
	var spots: Array = info.get("item_spots", [])
	var pos: Vector3 = spots.pick_random() if not spots.is_empty() else info.teacher_desk + Vector3(0, 1, 0)
	_find_item = PickupItem.create_item(_find_task.item)
	_find_item.position = pos + Vector3(0, 0.1, 0)
	world.get_node("Dynamic").add_child(_find_item)
	_find_timer = 0.0
	hud.controls.visible = true
	_set_objective("Ache %s e entregue à professora" % _find_task.item_name, null)
	player.stand_up()


func _finish_find(ok: bool) -> void:
	if is_instance_valid(_find_item):
		if _find_item.held_by and player.held_item == _find_item:
			player.held_item = null
		_find_item.queue_free()
	_find_item = null
	_find_task = {}
	_set_objective("Volte para a sua carteira", npcs.player_desk)
	_waiting_seat = false
	lesson_results.append(ok)
	day_total += 1
	if ok:
		day_correct += 1
		GameManager.add_stat("acertos")
		GameManager.add_rewards(15, 3)
		AudioManager.play_ui("ui_confirm")
		npcs.teacher.visual.play("clap")
	task_finished.emit(ok)
	lesson_index += 1
	_waiting_for_return_after_find = true


var _waiting_for_return_after_find := false


func npc_prompt(npc: NPC, p: Node) -> String:
	if events:
		var e: String = events.npc_prompt(npc)
		if e != "":
			return e
	if npc == npcs.teacher and not _find_task.is_empty() and p.get("held_item") and p.held_item == _find_item:
		return "Entregar à professora"
	return ""


func npc_interact(npc: NPC, p: Node) -> bool:
	if events and events.npc_interact(npc):
		return true
	if npc == npcs.teacher and not _find_task.is_empty() and p.get("held_item") and p.held_item == _find_item:
		npc.say("Obrigada! Pode sentar.", 2.2)
		_finish_find(true)
		return true
	if (phase == Phase.CLASS_1 or phase == Phase.CLASS_2) and npc.role == "student" and npc.sitting:
		npc.say("Psiu! A professora tá olhando!", 2.0)
		return true
	return false


# =================================================================== diálogo

func _on_dialogue_requested(npc: NPC, lines: Array) -> void:
	_talking_npc = npc
	player.input_enabled = false
	hud.controls.visible = false
	dialogue.open(npc.display_name, lines)


func _on_dialogue_finished(_choice: int) -> void:
	if _talking_npc:
		npcs.end_talk(_talking_npc)
		Friendship.on_talk(_talking_npc)
	_talking_npc = null
	player.input_enabled = true
	hud.controls.visible = not classroom_ui.visible


# =================================================================== laço

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	_phase_time += delta
	match phase:
		Phase.RECESS:
			recess_left -= delta
			if recess_left <= 20.0 and recess_left + delta > 20.0:
				GameManager.show_toast("O recreio está acabando!")
			if recess_left <= 0.0:
				_start_return()
		Phase.CLASS_1, Phase.CLASS_2:
			if not _find_task.is_empty():
				_find_timer += delta
				if _find_timer > 20.0 and is_instance_valid(_find_item) and _find_item.held_by == null:
					_marker_target = _find_item
				if is_instance_valid(_find_item) and _find_item.held_by == player:
					_marker_target = npcs.teacher
				if _find_timer > 75.0:
					npcs.teacher.say("Tudo bem, depois eu procuro.", 2.4)
					_finish_find(false)
			elif _waiting_for_return_after_find and _player_at_desk():
				_waiting_for_return_after_find = false
				_set_objective("Faça as tarefas da aula", null)
				if lesson_index >= lesson.size():
					_end_class()
				else:
					get_tree().create_timer(1.0).timeout.connect(_present_task)
			elif not _player_at_desk() and not _task_active and _find_task.is_empty():
				_nag_timer -= delta
				if _nag_timer <= 0.0:
					_nag_timer = 7.0
					npcs.teacher.say("Volte para o seu lugar, por favor!", 2.5)
	_update_clock()
	_update_marker(delta)


func _set_objective(text: String, target: Variant) -> void:
	hud.set_objective(text)
	_marker_target = target


func _update_marker(delta: float) -> void:
	var tgt: Variant = _marker_target
	if tgt is Object and not is_instance_valid(tgt):
		tgt = null
		_marker_target = null
	if tgt == null:
		_marker.visible = false
		hud.set_objective_point(null)
		return
	var pos: Vector3 = tgt if tgt is Vector3 else (tgt as Node3D).global_position
	var top := 1.25 if tgt is Seat else 2.3
	_marker.visible = player.global_position.distance_to(pos) > 1.2
	_marker.global_position = pos + Vector3(0, top + sin(Time.get_ticks_msec() * 0.004) * 0.12, 0)
	_marker.rotate_y(delta * 2.0)
	hud.set_objective_point(pos + Vector3(0, 1.0, 0))


func _update_clock() -> void:
	var minutes := 7 * 60
	match phase:
		Phase.ARRIVAL:
			minutes = 7 * 60 + mini(int(_phase_time / 6.0), 9)
		Phase.CLASS_1:
			minutes = 7 * 60 + 15 + int(float(lesson_index) / maxf(lesson.size(), 1) * 130.0)
		Phase.RECESS:
			minutes = 9 * 60 + 30 + int((1.0 - recess_left / RECESS_SECONDS) * 20.0)
		Phase.RETURN:
			minutes = 9 * 60 + 50 + mini(int(_phase_time / 8.0), 9)
		Phase.CLASS_2:
			minutes = 10 * 60 + int(float(lesson_index) / maxf(lesson.size(), 1) * 110.0)
		Phase.DAY_END:
			minutes = 12 * 60
	var txt := "Dia %d · %02d:%02d · %s" % [day, minutes / 60, minutes % 60, PHASE_NAMES[phase]]
	if phase == Phase.RECESS:
		txt += " (%d:%02d)" % [int(recess_left) / 60, int(recess_left) % 60]
	hud.set_day_text(txt)
