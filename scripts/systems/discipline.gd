class_name DisciplineSystem
extends Node
## Sistema disciplinar leve e bem-humorado.
## - Só conta o que um adulto VÊ (professora, diretor ou inspetora por perto
##   e com linha de visão).
## - Esbarrão andando = acidente (só reação). Correndo, ou repetido no
##   mesmo colega em poucos segundos = imprudência.
## - 1ª falta do dia: o adulto chama atenção. 2ª: ocorrência na diretoria.
## - Ocorrências: 1ª advertência; 2ª pais chamados + ajudar a Dona Cida;
##   3ª+ conversas diferentes e "pensar no banco do hall".
## - Reputação sobe com dias tranquilos e boas ações; ocorrências antigas
##   vão sendo perdoadas.

signal occurrence_started(count: int)
signal occurrence_finished(count: int)
signal reputation_changed(value: int)

const WEIGHTS := {
	"esbarrao_forte": 1.0, "esbarrao_repetido": 1.0, "correr_corredor": 1.0,
	"bolinha_em_colega": 1.0, "levantou_na_aula": 0.5, "bagunca_aula": 1.0,
}
const CALL_OUTS := {
	"esbarrao_forte": ["Ei! Olha a correria!", "Cuidado com os colegas!", "Devagar aí, mocinho!"],
	"esbarrao_repetido": ["Pare de empurrar o colega!", "Isso não é brincadeira!"],
	"correr_corredor": ["Sem correr no corredor!", "Andando, por favor!"],
	"bolinha_em_colega": ["Não jogue coisas nos colegas!", "Eu vi isso, hein!"],
	"levantou_na_aula": ["Sentado, por favor!"],
	"bagunca_aula": ["Comportamento!"],
}
const KIND_TEXT := {
	"matou_aula": "matar aula", "empurrao": "empurrar um colega", "empurrou_adulto": "empurrar um funcionário da escola",
	"esbarrao_forte": "sair esbarrando nos colegas", "esbarrao_repetido": "empurrar um colega de propósito",
	"correr_corredor": "correr pelo corredor", "bolinha_em_colega": "jogar bolinha de papel nos colegas",
	"levantou_na_aula": "levantar no meio da aula", "bagunca_aula": "bagunçar na aula",
}

var npcs: NPCManager
var player: PlayerController
var hud: HUD
var day: SchoolDay
var world: SchoolWorld
var strikes_today := 0.0
var restricted := false  # minijogos bloqueados (consequência)
var restriction_text := ""
var pending_kind := ""
var in_cutscene := false
var _bump_log := {}  # npc id -> último tempo
var _cooldown := {}
var _corridor_cd := 0.0
var _clean_day := true
var _parent: NPC
var _bench_t := -1.0
var _cleanup_left := 0


func setup(m: NPCManager, p: PlayerController, h: HUD, d: SchoolDay, w: SchoolWorld) -> void:
	npcs = m
	player = p
	hud = h
	day = d
	world = w
	m.npc_bumped.connect(_on_bump)
	m.npc_hit_by_object.connect(_on_hit_object)
	GameManager.behavior_reported.connect(_on_behavior)
	d.phase_changed.connect(_on_phase)
	d.day_finished.connect(_on_day_finished)
	var disc := data()
	if not disc.has("reputation"):
		disc["reputation"] = 60


static func data() -> Dictionary:
	return SaveManager.section("discipline")


static func reputation() -> int:
	return int(data().get("reputation", 60))


static func occurrences() -> int:
	return int(data().get("occurrences", 0))


func change_reputation(delta: int) -> void:
	var d := data()
	d["reputation"] = clampi(int(d.get("reputation", 60)) + delta, 0, 100)
	reputation_changed.emit(int(d.reputation))


# ------------------------------------------------------------- detecção

## Adulto que viu a cena (ou null).
func witness() -> NPC:
	var best: NPC = null
	var bd := 14.0
	for a in [npcs.teacher, npcs.director, npcs.inspector]:
		if a == null or not a.active:
			continue
		var d: float = a.global_position.distance_to(player.global_position)
		if d < bd and npcs.nav.is_clear(a.global_position, player.global_position):
			bd = d
			best = a
	return best


func _on_bump(npc: NPC, speed: float) -> void:
	var key := npc.get_instance_id()
	var now := Time.get_ticks_msec() * 0.001
	var last: float = _bump_log.get(key, -100.0)
	_bump_log[key] = now
	if speed > 3.5:
		_on_behavior("esbarrao_forte")
	elif now - last < 8.0:
		# esbarrou de novo no mesmo colega: de propósito
		_on_behavior("esbarrao_repetido")
		npc.say("Para de me empurrar!", 2.0)


func _on_hit_object(npc: NPC, obj: Node) -> void:
	if obj.get("thrower") == player and GameManager.player.minigame == null:
		_on_behavior("bolinha_em_colega")


func _on_behavior(kind: String) -> void:
	if in_cutscene or not WEIGHTS.has(kind):
		return
	var now := Time.get_ticks_msec() * 0.001
	if _cooldown.get(kind, -100.0) > now:
		return
	var w: NPC = npcs.teacher if kind in ["levantou_na_aula", "bagunca_aula"] else witness()
	if w == null:
		return  # ninguém viu... desta vez!
	_cooldown[kind] = now + 6.0
	_clean_day = false
	strikes_today += WEIGHTS[kind]
	change_reputation(-2)
	var line: String = CALL_OUTS.get(kind, ["Ei!"]).pick_random()
	w.say(line, 2.5)
	if strikes_today >= 2.0:
		strikes_today = 0.0
		_request_occurrence(kind, w)
	else:
		GameManager.show_toast("%s chamou sua atenção." % w.display_name)
		if not w.sitting and w.activity in ["patrol", "director_idle", "inspector_hall", "inspector_gate"]:
			w.stop()
			w.face(player.global_position)


func _process(delta: float) -> void:
	if not GameManager.is_playing() or in_cutscene:
		return
	if truant:
		_update_search(delta)
	# correr no corredor/hall
	_corridor_cd -= delta
	var z := GameManager.current_zone
	if _corridor_cd <= 0.0 and (z == "Corredor" or z == "Hall de Entrada") and Vector2(player.velocity.x, player.velocity.z).length() > player.run_speed * 0.8:
		_corridor_cd = 3.0
		pass  # correr no corredor é permitido (decisão de design: não ser chato)
	# castigo: pensar no banco
	if _bench_t >= 0.0:
		if player.mode == PlayerController.Mode.SITTING:
			_bench_t -= delta
			hud.set_mission("Pense no que fez... %d s" % int(ceil(_bench_t)))
			if _bench_t <= 0.0:
				_bench_t = -1.0
				_lift_restriction("Pode voltar a brincar. Comporte-se!")
		else:
			hud.set_mission("Sente no banco do hall por %d s" % int(ceil(_bench_t)))


# ------------------------------------------------------------- ocorrência

func _request_occurrence(kind: String, _w: NPC) -> void:
	if day.phase == SchoolDay.Phase.RECESS or day.phase == SchoolDay.Phase.ARRIVAL or day.phase == SchoolDay.Phase.RETURN:
		start_occurrence(kind)
	else:
		pending_kind = kind
		GameManager.show_toast("Depois da aula, passe na diretoria...")


func _on_phase(p: int) -> void:
	if p == SchoolDay.Phase.RECESS and pending_kind != "":
		var k := pending_kind
		pending_kind = ""
		get_tree().create_timer(1.5).timeout.connect(func(): start_occurrence(k))


## severity: faltas graves (empurrar, matar aula) contam em dobro.
func start_occurrence(kind: String, severity := 1) -> void:
	if in_cutscene:
		return
	in_cutscene = true
	stop_search()
	if player.minigame:
		player.minigame.end_game(0, "Chamado na diretoria!", 0, 0)
	if player.riding:
		player.toggle_ride()
	var d := data()
	d["occurrences"] = int(d.get("occurrences", 0)) + 1
	d["active"] = int(d.get("active", 0)) + severity
	var log: Array = d.get("log", [])
	log.append({"day": day.day, "kind": kind})
	d["log"] = log.slice(-20)
	var n := int(d.active)
	occurrence_started.emit(n)
	GameManager.unlock_achievement("primeira_ocorrencia")
	await _cutscene(kind, n)
	in_cutscene = false
	occurrence_finished.emit(n)


func _cutscene(kind: String, n: int) -> void:
	player.input_enabled = false
	hud.controls.visible = false
	hud.set_objective("")
	await hud.fade(1.0).finished
	# monta a cena na diretoria
	var room: Rect2 = SchoolBuilder.R(-30, 38, -20, 48)
	var desk := Vector3(room.get_center().x, 0.025, room.end.y - 2.6)
	var chair: Seat = null
	for s in npcs.room_seats.get("Diretoria", []):
		if chair == null or s.global_position.x < chair.global_position.x:
			chair = s
	player.force_stand()
	if chair:
		player.global_position = chair.global_position
		player.sit_on(chair)
	var dir := npcs.director
	var prev_act := dir.activity
	dir.activity = "cutscene"
	dir.teleport(desk + Vector3(0, 0.03, 0.75), PI)
	for other in npcs.npcs:
		other.hush()
	if n >= 2:
		_parent = _make_parent()
		_parent.teleport(desk + Vector3(1.6, 0.03, -1.4), -PI * 0.75)
	# câmera normal atrás do aluno (dá para girar durante a conversa)
	player.camera_rig.yaw = player.yaw + PI
	player.camera_rig.pitch = -16.0
	player.camera_rig.snap_to_target()
	await get_tree().create_timer(0.6).timeout
	hud.fade(0.0)
	dir.visual.play("talk")
	var lines := _lines_for(kind, n)
	day.dialogue.open(dir.display_name, lines)
	await day.dialogue.finished
	dir.visual.stop_upper()
	_apply_consequence(n)
	await hud.fade(1.0).finished
	player.force_stand()
	player.global_position = Vector3(0, 0.05, 31)
	player.yaw = 0.0
	player.camera_rig.yaw = PI
	player.camera_rig.snap_to_target()
	dir.activity = prev_act
	dir.teleport(Vector3(-25, 0.05, 44.4), PI)
	if _parent:
		_parent.queue_free()
		npcs.npcs.erase(_parent)
		_parent = null
	player.input_enabled = true
	hud.controls.visible = true
	hud.fade(0.0)


func _make_parent() -> NPC:
	var mom := randf() < 0.5
	var entry := {"id": "responsavel", "name": "Sua mãe" if mom else "Seu pai", "role": "parent", "seed": 950 + int(mom),
		"look": {"hair_style": "longo" if mom else "curto", "shirt_color": "8e5bd1" if mom else "2c3e50", "shirt_logo": false,
			"long_pants": true, "pants_color": "34495e", "backpack": false, "height_scale": 1.22, "build": 1.08}}
	var p := NPC.new()
	p.setup(entry, npcs)
	npcs.add_child(p)
	p.activity = "cutscene"
	return p


func _lines_for(kind: String, n: int) -> Array:
	var what: String = KIND_TEXT.get(kind, "fazer bagunça")
	var dname := "Diretor Valdir"
	match n:
		1:
			return [[dname, "Sente-se, por favor. Me contaram que você andou %s." % what],
				[dname, "Aqui na escola a gente cuida uns dos outros, certo?"],
				["Você", "...Desculpa, diretor. Não vai acontecer de novo."],
				[dname, "Ótimo. Isso é só uma advertência. Pode voltar, e juízo!"]]
		2:
			var pn: String = _parent.display_name if _parent else "Responsável"
			return [[dname, "De novo por aqui? Desta vez foi %s." % what],
				[dname, "Por isso chamei seus responsáveis."],
				[pn, "Filho... eu precisei sair do trabalho correndo!"],
				[pn, "Lá em casa a gente conversa. E hoje você vai ajudar na escola."],
				[dname, "Isso. Ajude a Dona Cida a recolher 5 bolinhas de papel do pátio."],
				[dname, "Depois disso, pode voltar a brincar."]]
		_:
			var variants := [
				[[dname, "Olha só quem voltou. Já tem até cadeira com seu nome aqui."], [dname, "Motivo de hoje: %s." % what],
					["Você", "Foi sem querer... quer dizer, mais ou menos."], [dname, "Vai pensar um pouquinho no banco do hall. 45 segundos."]],
				[[dname, "Sabe o que eu fazia na sua idade quando aprontava?"], [dname, "Eu ia parar exatamente nessa cadeira."],
					[dname, "Então... %s, hein? Banco do hall, 45 segundos." % what]],
				[[dname, "Eu vou colocar seu nome no quadro de avisos..."], [dname, "...como 'aluno que mais visita a diretoria'. Brincadeira!"],
					[dname, "Mas é sério: %s não pode. Banco do hall, por favor." % what]],
			]
			return variants[n % variants.size()]


# ------------------------------------------------------------- matar aula

signal truant_caught

var truant := false
var _searchers: Array[NPC] = []
var _chasing := {}  # npc -> segundos sem ver o jogador
var _search_think := 0.0
const SEARCH_POINTS := [Vector3(-70, 0.05, -60), Vector3(-75, 0.05, -50), Vector3(0, 0.05, -10), Vector3(40, 0.05, -48),
	Vector3(-40, 0.05, -50), Vector3(78, 0.05, -50), Vector3(-0, 0.05, -64), Vector3(38, 0.05, 43), Vector3(46, 0.05, 43),
	Vector3(-30, 0.05, 12), Vector3(-75, 0.05, 20), Vector3(60, 0.05, 30), Vector3(-50, 0.05, 36), Vector3(30, 0.05, 36)]


func start_search() -> void:
	if truant:
		return
	truant = true
	_searchers = [npcs.director, npcs.inspector]
	_chasing.clear()
	for s in _searchers:
		s.stop()
		s.activity = "search"
		s.run_speed = 4.6
		s.say("Cadê aquele aluno?!", 2.5)
	hud.show_banner("Matando aula!", "O diretor e a Dona Cida estão procurando você...")
	AudioManager.play_ui("whistle", -6.0)


func stop_search() -> void:
	if not truant:
		return
	truant = false
	for s in _searchers:
		s.activity = "director_office" if s == npcs.director else "inspector_hall"
		s.run_speed = 3.0
		s.running = false
		s.go_to(Vector3(-25, 0.05, 44.4) if s == npcs.director else Vector3(3, 0.05, 30))
	_searchers.clear()
	_chasing.clear()


## Adulto vê o jogador? (distância, campo de visão e linha livre)
func _sees(n: NPC) -> bool:
	var to := player.global_position - n.global_position
	to.y = 0
	var d := to.length()
	if d > 17.0:
		return false
	var fwd := Vector3(sin(n.yaw), 0, cos(n.yaw))
	if d > 3.0 and fwd.angle_to(to.normalized()) > deg_to_rad(65):
		return false
	return npcs.nav.is_clear(n.global_position, player.global_position)


func _update_search(delta: float) -> void:
	_search_think -= delta
	for s in _searchers:
		if s.global_position.distance_to(player.global_position) < 1.15 and _chasing.has(s):
			s.say("Peguei você!", 2.5)
			truant_caught.emit()
			start_occurrence("matou_aula", 2)
			return
		if _chasing.has(s):
			if _sees(s):
				_chasing[s] = 0.0
			else:
				_chasing[s] += delta
				if _chasing[s] > 9.0:
					_chasing.erase(s)
					s.say("Sumiu... ele estava aqui!", 2.0)
		elif _sees(s):
			_chasing[s] = 0.0
			s.say(["Ei! Você aí! Volta pra sala!", "Parado aí, mocinho!"].pick_random(), 2.5)
			AudioManager.play_ui("whistle", -4.0)
	if _search_think > 0.0:
		return
	_search_think = 0.35
	for s in _searchers:
		if _chasing.has(s):
			s.running = true
			s.go_to(player.global_position, true)
		elif not s.moving:
			s.go_to(SEARCH_POINTS.pick_random(), true)


# ------------------------------------------------------------- empurrar

## O jogador empurrou alguém (botão amarelo perto de alguém).
func on_shove(target: NPC) -> void:
	var adult := target.role != "student"
	var w := witness()
	if adult or w != null:
		if w:
			w.say("EU VI ISSO! Diretoria, agora!", 3.0)
		change_reputation(-20 if adult else -15)
		start_occurrence("empurrou_adulto" if adult else "empurrao", 2)
	else:
		strikes_today += 1.0
		change_reputation(-6)
		Friendship.add(target.data.get("id", ""), -12, "empurrao")
		target.say("Vou contar pra professora!", 2.5)
		GameManager.show_toast("Ninguém viu... mas o colega ficou muito chateado.")


func _apply_consequence(n: int) -> void:
	match n:
		1:
			change_reputation(-8)
			GameManager.show_toast("Advertência registrada. Reputação caiu um pouco.")
		2:
			change_reputation(-12)
			_start_cleanup_task()
		_:
			change_reputation(-12)
			restricted = true
			restriction_text = "Castigo: sentar no banco do hall"
			_bench_t = 45.0
			hud.set_mission("Sente no banco do hall por 45 s")


const CLEANUP_COUNT := 5
var _cleanup_items: Array = []
var _cleanup_bin: Node = null


func _start_cleanup_task() -> void:
	restricted = true
	restriction_text = "Ajude a Dona Cida antes de brincar"
	_cleanup_left = CLEANUP_COUNT
	hud.set_mission("Recolha %d bolinhas de papel do pátio (setas amarelas)" % CLEANUP_COUNT)
	# espalha bolinhas só em pontos alcançáveis do pátio
	var r := RandomNumberGenerator.new()
	r.randomize()
	for i in CLEANUP_COUNT:
		var item := PickupItem.create_paper_ball()
		item.position = npcs.nav.random_point(r, Rect2(-24, -22, 48, 22)) + Vector3(0, 0.15, 0)
		item.add_to_group("cleanup")
		world.get_node("Dynamic").add_child(item)
		item.mark_as_goal()
		_cleanup_items.append(item)
	set_process(true)


## Alvo atual da tarefa de limpeza (para a seta/minimapa).
func cleanup_target() -> Variant:
	if _cleanup_bin and is_instance_valid(_cleanup_bin):
		return (_cleanup_bin as Node3D).global_position
	var best: Variant = null
	for it in _cleanup_items:
		if is_instance_valid(it) and (best == null or (it as Node3D).global_position.distance_to(player.global_position) < (best as Vector3).distance_to(player.global_position)):
			best = (it as Node3D).global_position
	return best


## Chamado pelo jogador ao pegar um objeto.
func on_player_picked(item: Node) -> void:
	if _cleanup_left > 0 and item.is_in_group("cleanup"):
		# vai direto para o saquinho: não precisa segurar um por vez
		_cleanup_items.erase(item)
		player.held_item = null
		item.queue_free()
		_cleanup_left -= 1
		AudioManager.play_ui("pickup")
		if _cleanup_left <= 0:
			hud.set_mission("Agora jogue os papéis na lixeira azul (seta amarela)")
			GameManager.show_toast("Todos recolhidos! Agora é só jogar na lixeira.")
			var s := QuestSpot.new()
			s.prompt = "Jogar no lixo"
			s.position = QuestSystem.BINS
			s.hold_time = 0.6
			s.anim = "throw"
			s.done.connect(func(_sp):
				if is_instance_valid(_cleanup_bin):
					_cleanup_bin.queue_free()
				_cleanup_bin = null
				npcs.inspector.say("Muito bem! Obrigada pela ajuda.", 2.5)
				change_reputation(5)
				_lift_restriction("A Dona Cida agradeceu! Pode brincar."))
			world.add_child(s)
			_cleanup_bin = s
		else:
			hud.set_mission("Recolha as bolinhas de papel do pátio — faltam %d" % _cleanup_left)


func _lift_restriction(msg: String) -> void:
	restricted = false
	restriction_text = ""
	_cleanup_left = 0
	for it in _cleanup_items:
		if is_instance_valid(it):
			it.queue_free()
	_cleanup_items.clear()
	if is_instance_valid(_cleanup_bin):
		_cleanup_bin.queue_free()
	_cleanup_bin = null
	hud.set_mission("")
	GameManager.show_toast(msg)


func _on_day_finished(_s: Dictionary) -> void:
	var d := data()
	if _clean_day:
		change_reputation(6)
		if int(d.get("active", 0)) > 0 and reputation() >= 65:
			d["active"] = int(d.active) - 1
			GameManager.show_toast("Bom comportamento! Uma ocorrência foi perdoada.")
		d["clean_days"] = int(d.get("clean_days", 0)) + 1
		if int(d.clean_days) >= 5:
			GameManager.unlock_achievement("aluno_exemplar")
	else:
		d["clean_days"] = 0
	_clean_day = true
	strikes_today = 0.0
	if _bench_t >= 0.0 or restricted:
		_bench_t = -1.0
		_lift_restriction("Um novo dia, uma nova chance!")
