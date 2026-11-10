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

const RECESS_SECONDS := 480.0
## Prazo para chegar e sentar na carteira (chegada / volta do recreio).
const ARRIVAL_LIMIT := 90.0
const RETURN_LIMIT := 75.0  # 8 minutos de recreio
const LESSON_SIZE := [7, 5]
const MIN_CORRECT := [4, 3]
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
## Pique-pega online em andamento: o recreio espera a brincadeira acabar.
var hold_recess := false
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
var _deadline_shown := -1
var _talking_npc: NPC
var _marker: Node3D
var _marker_target: Variant = null
var _board_label: Label3D
var _gen: ClassroomTasks
var _subjects: Array = []
var discipline: Node = null
var _out_of_class := 0.0
var events: Node = null  # SchoolEvents
var quests: Node = null  # QuestSystem

## ---- relógio do servidor (online): a fase do dia é a mesma para a sala toda
var synced := false
var _server_day := -1
var _sync_room := ""
var _class_done := false
## Sentou na carteira de outra pessoa: segundos desde que sentou (-1 = não).
var _wrong_seat_t := -1.0
var _wrong_seat_warned := 0
## A 2ª aula do dia é na sala da matéria (aproveita a escola inteira).
## Os testes antigos desligam (aula sempre na Sala 5).
static var SPECIAL_ROOMS := true
const SUBJECT_ROOMS := {
	"Ciências": "Laboratório de Ciências", "Física": "Laboratório de Física", "Química": "Laboratório de Química",
	"Música": "Sala de Música", "Artes": "Sala de Artes", "Inglês": "Sala de Idiomas",
	"Geografia": "Biblioteca", "História": "Biblioteca", "Matemática": "Sala de Informática", "Português": "Sala de Leitura",
}
## Sala da aula de agora (Sala 5 ou a sala da matéria).
var class_room := NPCManager.CLASS_ROOM
const WRONG_SEAT_WARN2 := 8.0
const WRONG_SEAT_LIMIT := 18.0


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
	m.player_desk_changed.connect(_on_desk_changed)
	NetworkManager.clock_changed.connect(_on_clock)
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
	# online: quem manda é o relógio do servidor (entra na fase em que a sala está)
	if NetworkManager.is_online() and not NetworkManager.clock.is_empty():
		apply_clock(NetworkManager.clock)
		return
	_init_day()
	if player.mode == PlayerController.Mode.SITTING:
		player.force_stand()
	# o dia começa no portão de entrada da escola
	player.global_position = GATE + Vector3(0, 0, -1.5)
	player.yaw = PI
	player.velocity = Vector3.ZERO
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()
	npcs.begin_arrival()
	_set_phase(Phase.ARRIVAL)
	hud.show_banner("Dia %d" % day, "Bom dia! Vá para a %s." % NPCManager.CLASS_ROOM)
	_set_objective("Vá para a %s e sente na sua carteira" % NPCManager.CLASS_ROOM, npcs.player_desk)
	_waiting_seat = true


func _init_day() -> void:
	day = int(SaveManager.section("progress").get("days_completed", 0)) + 1
	_gen = ClassroomTasks.new(day * 7919 + randi() % 1000, Learning.level())
	_subjects = Learning.subjects_for_day(day)
	day_correct = 0
	day_total = 0
	_class_no = 0
	_class_done = false


# =================================================================== relógio do servidor

const PHASE_IDS := ["arrival", "class1", "recess", "return", "class2", "end"]


func _on_clock(st: Dictionary) -> void:
	if not GameManager.is_playing():
		return
	apply_clock(st)


## Recebe o relógio da sala. Na primeira vez (ou outra sala / outro dia no
## meio de uma fase) o jogador "entra" na fase atual; depois só segue as trocas.
func apply_clock(st: Dictionary) -> void:
	var p := PHASE_IDS.find(str(st.get("phase", "")))
	if p < 0:
		return
	var sday := int(st.get("day", 1))
	var room := NetworkManager.room
	if not synced or room != _sync_room or (sday != _server_day and p != Phase.ARRIVAL):
		synced = true
		_sync_room = room
		_server_day = sday
		_join_synced(p)
		return
	if p == phase and sday == _server_day:
		return
	_server_day = sday
	_goto_phase(p)


## Saiu do online: volta ao dia local (cada um no seu ritmo).
func unsync() -> void:
	synced = false
	_sync_room = ""
	_server_day = -1


func _place(pos: Vector3, yaw: float) -> void:
	# reconexão (minimizou o app e voltou): fica onde estava
	if NetworkManager.reconnected:
		return
	if player.mode == PlayerController.Mode.SITTING:
		player.force_stand()
	player.global_position = pos
	player.yaw = yaw
	player.velocity = Vector3.ZERO
	if player.camera_rig:
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()


## Entrou na sala (ou voltou depois de cair): vai direto para a fase atual.
func _join_synced(p: int) -> void:
	_init_day()
	_drop_lesson()
	_waiting_seat = false
	_exit_summary = {}
	_wrong_seat_t = -1.0
	var info := npcs.class_info()
	match p:
		Phase.ARRIVAL:
			_place(GATE + Vector3(0, 0, -1.5), PI)
			npcs.begin_arrival()
			_set_phase(Phase.ARRIVAL)
			hud.show_banner("Dia %d" % day, "Bom dia! Vá para a %s." % NPCManager.CLASS_ROOM)
			_set_objective("Vá para a %s e sente na sua carteira" % NPCManager.CLASS_ROOM, npcs.player_desk)
			_waiting_seat = true
		Phase.CLASS_1, Phase.CLASS_2:
			# chegou com a aula começada: aparece na porta da sala, sem bronca
			npcs.begin_arrival()
			_begin_class(0 if p == Phase.CLASS_1 else 1)
			if _special_room():
				_place(room_point(class_room) + Vector3(0, 0, 1.5), PI)
			else:
				_place(info.get("door_out", GATE) + Vector3(0, 0, 0.6), PI)
			_out_of_class = -45.0
			_waiting_seat = true
			hud.show_banner("A aula já começou!", "Sente na sua carteira (a da estrela)." if not _special_room() else "A aula de hoje é aqui no(a) %s." % class_room)
			if not _special_room():
				_set_objective("Sente na sua carteira", npcs.player_desk)
		Phase.RECESS:
			_place(Vector3(randf_range(-4, 4), 0.05, randf_range(-4, 2)), PI)
			_start_recess()
			hud.show_banner("RECREIO!", "A turma está no recreio. Faltam %s." % Minigame.fmt_time(NetworkManager.phase_left()))
		Phase.RETURN:
			_place(Vector3(randf_range(-3, 3), 0.05, 46.5), PI)
			_start_return()
		Phase.DAY_END:
			_place(GATE + Vector3(0, 0, -6.0), 0.0)
			npcs.begin_day_end()
			_set_phase(Phase.DAY_END)
			hud.show_banner("Fim das aulas de hoje", "O próximo dia já vai começar!")
			_set_objective("O próximo dia começa em instantes...", null)


## Troca de fase ao vivo (o sinal tocou para a sala toda).
func _goto_phase(p: int) -> void:
	_wrong_seat_t = -1.0
	match p:
		Phase.ARRIVAL:
			if not _exit_summary.is_empty():
				var s := _exit_summary
				_exit_summary = {}
				hud.show_day_summary(s, func(): pass)
			_init_day()
			_drop_lesson()
			npcs.begin_arrival()
			_set_phase(Phase.ARRIVAL)
			hud.show_banner("Dia %d" % day, "Bom dia! Vá para a %s." % NPCManager.CLASS_ROOM)
			_set_objective("Vá para a %s e sente na sua carteira" % NPCManager.CLASS_ROOM, npcs.player_desk)
			_waiting_seat = not _player_at_desk()
		Phase.CLASS_1, Phase.CLASS_2:
			ring_bell()
			_drop_lesson()
			_begin_class(0 if p == Phase.CLASS_1 else 1)
			if not _player_in_class():
				_waiting_seat = true
				GameManager.show_toast("A aula começou! Corra para a sala!")
				_set_objective("A aula começou! Vá para a %s" % class_room, _class_target())
		Phase.RECESS:
			_drop_lesson()
			_start_recess()
		Phase.RETURN:
			_drop_lesson()
			_start_return()
		Phase.DAY_END:
			_drop_lesson()
			_end_day()


## O sinal tocou no meio das tarefas: fecha o que estava aberto.
func _drop_lesson() -> void:
	if _task_active or classroom_ui.visible:
		classroom_ui.hide_panel()
		hud.controls.visible = true
	_task_active = false
	if not _find_task.is_empty():
		if is_instance_valid(_find_item):
			if player.held_item == _find_item:
				player.held_item = null
			_find_item.queue_free()
		_find_item = null
		_find_task = {}
	_waiting_for_return_after_find = false


## Ajudante da aula (busca o apagador etc.): um jogador por aula, em rodízio,
## escolhido do mesmo jeito em todos os celulares.
func helper_id() -> String:
	var ids: Array = NetworkManager.desks.keys()
	if ids.size() <= 1:
		return NetworkManager.my_id
	ids.sort_custom(func(a, b): return int(NetworkManager.desks[a]) < int(NetworkManager.desks[b]))
	return str(ids[(maxi(_server_day, 1) * 2 + _class_no) % ids.size()])


func _on_desk_changed(seat: Seat) -> void:
	if _marker_target is Seat:
		_marker_target = seat


func _set_phase(p: int) -> void:
	phase = p
	if discipline and discipline.truant and p != Phase.CLASS_1 and p != Phase.CLASS_2:
		discipline.stop_search()
	if p != Phase.CLASS_1 and p != Phase.CLASS_2:
		classroom_ui.hide_panel()
		_task_active = false
		if not dialogue.is_open():
			hud.controls.visible = GameManager.is_playing()
	world.recess_active = p == Phase.RECESS
	world.refresh_ambient()
	match p:
		Phase.RECESS:
			AudioManager.play_music("music_recreio", -11.0)
		Phase.CLASS_1, Phase.CLASS_2:
			AudioManager.play_music("music_aula", -15.0)
		_:
			AudioManager.play_music("music_menu", -14.0)
	_phase_time = 0.0
	phase_changed.emit(p)
	_update_clock()


func _begin_class(n: int) -> void:
	_class_no = n
	_set_phase(Phase.CLASS_1 if n == 0 else Phase.CLASS_2)
	npcs.begin_class()
	_gen.level = Learning.level()
	var subj: String = _subjects[n] if n < _subjects.size() else ""
	lesson = _gen.make_lesson(LESSON_SIZE[n], true, subj)
	_class_done = false
	class_room = room_for_class(n)
	if _special_room():
		# na sala da matéria não tem "buscar coisa na sala de aula"
		for i in lesson.size():
			if lesson[i].type == "find":
				lesson[i] = _gen.make("quiz", subj)
	if synced and NetworkManager.desks.size() > 1:
		var hid := helper_id()
		if hid != NetworkManager.my_id:
			# só o ajudante busca coisas pela sala; os outros fazem outra tarefa
			for i in lesson.size():
				if lesson[i].type == "find":
					lesson[i] = _gen.make("quiz", subj)
			GameManager.show_toast("Ajudante desta aula: %s" % NetworkManager.name_of(hid))
		else:
			GameManager.show_toast("Você é o ajudante desta aula!")
	hud.show_banner("Aula de %s" % subj, "%s · nível ajustado para você" % Learning.grade_name())
	if _board_label:
		_board_label.text = "Aula de %s" % subj
	lesson_index = 0
	lesson_results = []
	extra_tasks = 0
	_set_objective("Faça as tarefas da aula", null)
	if _special_room():
		var rp := room_point(class_room)
		npcs.teacher.teleport(rp + Vector3(0, 0, -1.5), 0.0)
		npcs.teacher.activity = "teach"
		if not _player_in_class():
			_set_objective("Aula de %s no(a) %s" % [subj, class_room], rp)
	npcs.teacher.say("Bom dia, turma! Vamos começar." if n == 0 else "Bem-vindos! Hoje a aula é aqui no(a) %s." % class_room if _special_room() else "Bem-vindos de volta! Mais um pouquinho.", 3.0)
	get_tree().create_timer(2.0).timeout.connect(_present_task)


func _present_task() -> void:
	if phase != Phase.CLASS_1 and phase != Phase.CLASS_2:
		return
	if not _player_in_class():
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
	Learning.record(ok)
	task_finished.emit(ok)
	hud.controls.visible = true
	lesson_index += 1
	if lesson_index >= lesson.size():
		var correct := lesson_results.count(true)
		var need: int = MIN_CORRECT[_class_no]
		if synced:
			_finish_lesson_synced()
		elif correct < need and extra_tasks < 3:
			extra_tasks += 1
			lesson.append(_gen.make(["math", "word", "quiz"].pick_random(), _subjects[_class_no] if _class_no < _subjects.size() else ""))
			npcs.teacher.say("Vamos fazer mais uma para liberar o recreio!" if _class_no == 0 else "Mais uma, vamos lá!", 2.6)
			get_tree().create_timer(2.6).timeout.connect(_present_task)
		else:
			_end_class()
	else:
		get_tree().create_timer(1.2).timeout.connect(_present_task)


## Online: terminou as tarefas antes do sinal; espera a turma.
func _finish_lesson_synced() -> void:
	_class_done = true
	_task_active = false
	npcs.teacher.say("Muito bem! Pode descansar até o sinal.", 2.6)
	if _board_label:
		_board_label.text = "Muito bem, turma!"
	_set_objective("Você terminou! Espere o sinal", null)


func _end_class() -> void:
	if synced:
		_finish_lesson_synced()
		return
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
	recess_left = NetworkManager.phase_left() if synced else RECESS_SECONDS
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
	var next_room := room_for_class(1)
	if next_room != NPCManager.CLASS_ROOM:
		_set_objective("Próxima aula: %s no(a) %s" % [_subjects[1], next_room], room_point(next_room))
	else:
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
	# saída: o aluno vai embora pelo portão (o resumo aparece lá)
	_exit_summary = summary
	hud.show_banner("Hora da saída!", "Vá até o portão para ir para casa")
	if player.mode == PlayerController.Mode.SITTING:
		player.stand_up()
	_set_objective("Hora da saída! Vá até o portão da escola", GATE)
	Telemetry.track("day_done", {"day": day})
	day_finished.emit(summary)


const GATE := Vector3(0, 0.05, 73.0)
var _exit_summary: Dictionary = {}


func _check_exit() -> void:
	if _exit_summary.is_empty():
		return
	var p := player.global_position
	if p.z > 70.5 and absf(p.x) < 6.0:
		var s := _exit_summary
		_exit_summary = {}
		_set_objective("", null)
		hud.show_day_summary(s, func():
			AdsManager.maybe_show_interstitial(day)
			if synced:
				_set_objective("O próximo dia começa quando o sinal tocar", null)
			else:
				start_day())


func ring_bell() -> void:
	AudioManager.play_ui("school_bell", -4.0)
	if player.camera_rig:
		player.camera_rig.shake(0.03)


# =================================================================== jogador

func room_for_class(n: int) -> String:
	if n == 0 or not SPECIAL_ROOMS or _subjects.size() < 2:
		return NPCManager.CLASS_ROOM
	var r: String = SUBJECT_ROOMS.get(_subjects[1], NPCManager.CLASS_ROOM)
	return r if not _room_zone(r).is_empty() else NPCManager.CLASS_ROOM


func _room_zone(room_name: String) -> Dictionary:
	for z in world.builder.zones:
		if str(z.name) == room_name:
			return z
	return {}


## Ponto no meio da sala (na altura do andar dela).
func room_point(room_name: String) -> Vector3:
	var z := _room_zone(room_name)
	if z.is_empty():
		return npcs.player_desk.global_position if npcs.player_desk else Vector3.ZERO
	var c: Vector2 = (z.rect as Rect2).get_center()
	return Vector3(c.x, float(z.get("y0", -0.5)) + 0.55, c.y)


func _special_room() -> bool:
	return class_room != NPCManager.CLASS_ROOM


## Está no lugar da aula? (Sala 5: sentado na carteira; outra sala: dentro dela)
func _player_in_class() -> bool:
	if _special_room():
		return str(world.zone_at(player.global_position).get("name", "")) == class_room
	return _player_at_desk()


## Destino do objetivo: a carteira (Sala 5) ou o meio da sala da matéria.
func _class_target() -> Variant:
	return room_point(class_room) if _special_room() else npcs.player_desk


func _player_at_desk() -> bool:
	return player.mode == PlayerController.Mode.SITTING and player.current_seat == npcs.player_desk


func _on_player_sat(seat: Seat) -> void:
	if seat != npcs.player_desk:
		if seat.room == NPCManager.CLASS_ROOM and _teacher_watching():
			_wrong_seat_t = 0.0
			_wrong_seat_warned = 0
			_warn_wrong_seat(seat)
		return
	_wrong_seat_t = -1.0
	_out_of_class = 0.0
	if discipline and discipline.truant:
		discipline.stop_search()
		npcs.teacher.say("Onde você estava?! Não saia mais da aula!", 3.0)
		discipline.strikes_today += 1.0
		discipline.change_reputation(-5)
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
				if not synced:
					get_tree().create_timer(1.2).timeout.connect(func(): _begin_class(0))
			Phase.RETURN:
				if not synced:
					get_tree().create_timer(1.2).timeout.connect(func(): _begin_class(1))
			Phase.CLASS_1, Phase.CLASS_2:
				if _find_task.is_empty() and not _class_done and lesson_index < lesson.size():
					get_tree().create_timer(0.8).timeout.connect(_present_task)


func _on_player_stood() -> void:
	_wrong_seat_t = -1.0
	if player.camera_rig:
		player.camera_rig.distance = 4.6
	if _special_room():
		return  # na sala da matéria pode ficar em pé
	if (phase == Phase.CLASS_1 or phase == Phase.CLASS_2) and _find_task.is_empty() and not _class_done:
		_set_objective("Volte para a sua carteira", npcs.player_desk)
		if not _task_active:
			_waiting_seat = true
		GameManager.report_behavior("levantou_na_aula")


# =================================================================== lugar do colega

func _teacher_watching() -> bool:
	return phase in [Phase.ARRIVAL, Phase.CLASS_1, Phase.RETURN, Phase.CLASS_2]


## De quem é esta carteira (nome do colega online ou do bot), ou "".
func desk_owner_name(seat: Seat) -> String:
	if npcs.desk_owner.has(seat):
		return NetworkManager.name_of(str(npcs.desk_owner[seat]))
	for n in npcs.classmates:
		if n.activity_data.get("desk") == seat:
			return n.display_name
	return ""


func _warn_wrong_seat(seat: Seat) -> void:
	var owner := desk_owner_name(seat)
	npcs.teacher.say("Ei! Esse não é o seu lugar! Sente na SUA carteira." if owner == "" else "Ei! Esse é o lugar de %s! Vá para a sua carteira." % owner, 3.0)
	npcs.teacher.visual.play("point_board")
	GameManager.show_toast("Esse lugar não é seu! A sua carteira tem a estrela.")
	_set_objective("Vá para a SUA carteira", npcs.player_desk)
	for n in npcs.classmates:
		if n.activity_data.get("desk") == seat and n.global_position.distance_to(player.global_position) < 6.0:
			n.say("Ei, esse é o meu lugar!", 2.5)
			n.visual.play("sad")


func _update_wrong_seat(delta: float) -> void:
	if _wrong_seat_t < 0.0:
		return
	if not (player.mode == PlayerController.Mode.SITTING and player.current_seat != npcs.player_desk and _teacher_watching()):
		_wrong_seat_t = -1.0
		return
	_wrong_seat_t += delta
	if _wrong_seat_t >= WRONG_SEAT_WARN2 and _wrong_seat_warned == 0:
		_wrong_seat_warned = 1
		npcs.teacher.say("Última vez: vá para o SEU lugar, senão vai para a diretoria!", 3.2)
		GameManager.show_toast("Saia do lugar do colega ou vai para a diretoria!")
	if _wrong_seat_t >= WRONG_SEAT_LIMIT:
		_wrong_seat_t = -1.0
		npcs.teacher.say("Para a diretoria, agora!", 2.5)
		if discipline:
			discipline.start_occurrence("lugar_colega")


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
	if quests:
		var qp: String = quests.npc_prompt(npc)
		if qp != "":
			return qp
	if npc == npcs.teacher and not _find_task.is_empty() and p.get("held_item") and p.held_item == _find_item:
		return "Entregar à professora"
	return ""


func npc_interact(npc: NPC, p: Node) -> bool:
	if events and events.npc_interact(npc):
		return true
	if quests and quests.npc_interact(npc):
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
	if phase == Phase.DAY_END:
		_check_exit()
	_update_wrong_seat(delta)
	match phase:
		Phase.RECESS:
			var before := recess_left
			if synced:
				recess_left = NetworkManager.phase_left()
			elif not hold_recess:
				recess_left -= delta
			if recess_left <= 20.0 and before > 20.0:
				GameManager.show_toast("O recreio está acabando!")
			if recess_left <= 0.0 and not synced:
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
			elif _special_room() and _waiting_seat and _player_in_class() and not _task_active and not _class_done and lesson_index < lesson.size():
				# chegou na sala da matéria: a tarefa aparece
				_waiting_seat = false
				_set_objective("Faça as tarefas da aula", null)
				get_tree().create_timer(0.6).timeout.connect(_present_task)
			elif _waiting_for_return_after_find and _player_at_desk():
				_waiting_for_return_after_find = false
				_set_objective("Faça as tarefas da aula", null)
				if lesson_index >= lesson.size():
					_end_class()
				else:
					get_tree().create_timer(1.0).timeout.connect(_present_task)
			elif not _player_in_class() and not _task_active and _find_task.is_empty() and not _class_done:
				# saiu da sala durante a aula = matando aula
				var zn: String = world.zone_at(player.global_position).get("name", "")
				if zn != class_room:
					_out_of_class += delta
					if _out_of_class > 4.0 and discipline and not discipline.truant:
						discipline.start_search()
					if _out_of_class > 100.0:
						_out_of_class = 0.0
						npcs.teacher.say("Vou continuar sem ele...", 2.0)
						lesson_index = lesson.size()
						_end_class()
				else:
					_out_of_class = 0.0
				_nag_timer -= delta
				if _nag_timer <= 0.0:
					_nag_timer = 7.0
					npcs.teacher.say("Volte para o seu lugar, por favor!", 2.5)
	_update_deadline()
	_update_clock()
	_update_marker(delta)


## Prazo para sentar: contagem na tela; acabou o tempo, a aula começa sem
## o aluno (e quem ficar fora da sala é procurado por matar aula).
func _update_deadline() -> void:
	var next_room := room_for_class(1) if phase == Phase.RETURN else NPCManager.CLASS_ROOM
	var there := _player_at_desk() if next_room == NPCManager.CLASS_ROOM else str(world.zone_at(player.global_position).get("name", "")) == next_room
	if not (phase == Phase.ARRIVAL or phase == Phase.RETURN) or not _waiting_seat or there:
		_deadline_shown = -1
		return
	var limit := ARRIVAL_LIMIT if phase == Phase.ARRIVAL else RETURN_LIMIT
	var left := int(ceil(limit - _phase_time))
	if synced:
		left = int(ceil(NetworkManager.phase_left()))
	if left != _deadline_shown:
		_deadline_shown = left
		if next_room == NPCManager.CLASS_ROOM:
			hud.set_objective("Vá para a %s e sente na carteira · %d:%02d" % [next_room, maxi(left, 0) / 60, maxi(left, 0) % 60])
		else:
			hud.set_objective("Próxima aula no(a) %s · %d:%02d" % [next_room, maxi(left, 0) / 60, maxi(left, 0) % 60])
		if left == 20:
			GameManager.show_toast("Faltam 20 segundos para a aula começar!")
	if left <= 0 and synced:
		return  # o sinal do servidor começa a aula para todos
	if left <= 0:
		_deadline_shown = -1
		GameManager.show_toast("A aula começou sem você! Corra para a sala!")
		npcs.teacher.say("Vamos começar. Quem não chegou, perdeu o começo!", 3.0)
		_begin_class(0 if phase == Phase.ARRIVAL else 1)
		_set_objective("A aula começou! Vá para a %s" % class_room, _class_target())


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
		hud.minimap.set_markers("objetivo", [])
		return
	var pos: Vector3 = tgt if tgt is Vector3 else (tgt as Node3D).global_position
	var top := 1.25 if tgt is Seat else 2.3
	# sem marcador flutuante: a trilha no chão já mostra o caminho
	_marker.visible = false
	_marker.global_position = pos + Vector3(0, top + sin(Time.get_ticks_msec() * 0.004) * 0.12, 0)
	_marker.rotate_y(delta * 2.0)
	hud.set_objective_point(pos + Vector3(0, 1.0, 0))
	hud.minimap.set_markers("objetivo", [{"pos": pos, "color": Color("ffcf3f"), "icon": "★"}])


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
