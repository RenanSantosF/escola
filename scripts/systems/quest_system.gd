class_name QuestSystem
extends Node
## Missões guiadas e repetíveis ("sempre tem missão").
## - Quem tem missão mostra um "!" amarelo (3D e no minimapa).
## - Conversar mostra a proposta: Aceitar / Agora não.
## - Missão ativa: texto na HUD, marcador 3D azul, seta na borda da tela
##   e ponto azul no minimapa para cada etapa.
## - Horta e árvores plantadas persistem e crescem com os dias.

signal quest_started(id: String)
signal quest_completed(id: String)

const TREE_SPOTS := [Vector3(72, 0.05, -40), Vector3(78, 0.05, -44), Vector3(85, 0.05, -38), Vector3(73, 0.05, -56), Vector3(84, 0.05, -60),
	Vector3(-80, 0.05, 35), Vector3(-72, 0.05, 40), Vector3(-84, 0.05, -10), Vector3(64, 0.05, 40), Vector3(-30, 0.05, 60)]
const BEDS := [Vector3(-10, 0.45, -66), Vector3(-4.8, 0.45, -66), Vector3(0.4, 0.45, -66), Vector3(5.6, 0.45, -66)]
const LAB := Vector3(74.3, 0.05, -24.0)
const LIBRARY_DESK := Vector3(-42.2, 0.05, 39.6)
const CANTINA := Vector3(-21.0, 0.05, 12.0)
const BINS := Vector3(24, 0.05, -23.2)
const STAGE := Vector3(17.5, 0.65, 12.0)
const HALL_BOARD := Vector3(-8.6, 0.05, 28.5)
const MUSIC := Vector3(78.0, 0.05, 12.0)

## Catálogo. steps: goto / spot / collect / talk / quiz / choice
const QUESTS := {
	"horta_plantar": {"giver": "jardineiro", "title": "Horta: plantar verduras", "xp": 35, "coins": 20,
		"intro": ["A horta está pronta para receber mudas!", "Planta três mudinhas pra mim? Depois a gente rega."],
		"steps": [
			{"t": "spot", "spots": [Vector3(-10, 0.45, -64), Vector3(-4.8, 0.45, -66), Vector3(0.4, 0.45, -68)], "prompt": "Plantar muda", "anim": "pickup", "time": 1.2, "text": "Plante 3 mudas nos canteiros da horta", "fx": "plant"},
			{"t": "spot", "spots": [Vector3(6, 0.05, -68.6)], "prompt": "Pegar o regador", "anim": "interact", "time": 0.8, "text": "Pegue o regador na casinha de ferramentas"},
			{"t": "spot", "spots": [Vector3(-10, 0.45, -64), Vector3(-4.8, 0.45, -66), Vector3(0.4, 0.45, -68)], "prompt": "Regar", "anim": "interact", "time": 1.0, "text": "Regue as 3 mudas", "fx": "water"},
			{"t": "quiz", "subject": "Ciências", "text": "Responda a pergunta do Seu Zé"}]},
	"horta_colher": {"giver": "jardineiro", "title": "Horta: dia de colheita", "xp": 40, "coins": 30, "needs": "garden_ready",
		"intro": ["Olha só! As verduras que você plantou cresceram.", "Vamos colher e levar para a Tia Rosa?"],
		"steps": [
			{"t": "spot", "spots": [Vector3(-10, 0.45, -64), Vector3(-4.8, 0.45, -66), Vector3(0.4, 0.45, -68)], "prompt": "Colher", "anim": "pickup", "time": 1.0, "text": "Colha as verduras dos canteiros", "fx": "harvest"},
			{"t": "talk", "to": "cook", "text": "Leve as verduras para a Tia Rosa na cantina"}]},
	"plantar_arvore": {"giver": "jardineiro", "title": "Plante uma árvore", "xp": 45, "coins": 25,
		"intro": ["Cada árvore deixa a escola mais fresquinha.", "Escolhi um lugar especial. Planta essa muda lá?"],
		"steps": [
			{"t": "spot", "spots": ["tree_spot"], "prompt": "Plantar a árvore", "anim": "pickup", "time": 1.6, "text": "Plante a muda de árvore no lugar marcado", "fx": "tree"},
			{"t": "quiz", "subject": "Ciências", "text": "Por que as árvores são importantes? Responda"}]},
	"quimica_cores": {"giver": "teacher", "title": "Química: mistura de cores", "xp": 35, "coins": 20, "min_level": 1,
		"intro": ["No laboratório tem uns frascos coloridos.", "Descubra como fazer a cor ROXA!"],
		"steps": [
			{"t": "goto", "pos": LAB, "r": 2.5, "text": "Vá ao Laboratório de Ciências (Bloco B)"},
			{"t": "choice", "question": "Quais frascos você mistura para fazer ROXO?", "options": ["Azul + vermelho", "Amarelo + azul", "Verde + amarelo"], "answer": 0, "success": "Ficou roxinho! Química é mágica... mas é ciência!", "fx": "sparkle"}]},
	"quimica_vulcao": {"giver": "teacher", "title": "Química: vulcão de espuma", "xp": 45, "coins": 25, "min_level": 3,
		"intro": ["Que tal fazer um vulcão que solta espuma?", "Use os ingredientes do laboratório."],
		"steps": [
			{"t": "goto", "pos": LAB, "r": 2.5, "text": "Vá ao Laboratório de Ciências"},
			{"t": "choice", "question": "O que você coloca no vulcão para fazer espuma?", "options": ["Vinagre + bicarbonato", "Água + açúcar", "Sal + areia"], "answer": 0, "success": "SHHHHH! A reação química soltou gás e virou espuma!", "fx": "confetti"},
			{"t": "quiz", "subject": "Química", "text": "Responda a pergunta de química"}]},
	"fisica_rampa": {"giver": "teacher", "title": "Física: a rampa", "xp": 40, "coins": 22, "min_level": 2,
		"intro": ["Vamos testar a gravidade!", "Solte uma bola do alto do palco e veja até onde ela rola."],
		"steps": [
			{"t": "spot", "spots": [STAGE], "prompt": "Soltar a bola na rampa", "anim": "throw", "time": 0.8, "text": "Suba no palco do pátio coberto e solte a bola", "fx": "ramp_ball"},
			{"t": "choice", "question": "Por que a bola desceu sozinha pela rampa?", "options": ["Por causa da gravidade", "Porque estava com medo", "Por causa da música"], "answer": 0, "success": "Isso! A gravidade puxa tudo para baixo."}]},
	"fisica_velocidade": {"giver": "lucas", "title": "Física: quem é mais rápido?", "xp": 35, "coins": 18, "min_level": 4,
		"intro": ["Corri 100 metros em 20 segundos!", "Me ajuda a calcular minha velocidade?"],
		"steps": [
			{"t": "choice", "question": "100 m em 20 s dá uma velocidade de...", "options": ["5 m/s", "2 m/s", "20 m/s"], "answer": 0, "success": "5 metros por segundo. Tô voando!"},
			{"t": "goto", "pos": Vector3(38, 0.05, -21), "r": 3.0, "text": "Corra até o fim da pista pintada do pátio"}]},
	"biblioteca": {"giver": "bibliotecaria", "title": "Livros perdidos", "xp": 35, "coins": 20,
		"intro": ["Alguns alunos esqueceram livros pelo pátio...", "Me ajuda a recolher 3 e trazer de volta?"],
		"steps": [
			{"t": "collect", "item": "livro", "count": 3, "area": Rect2(-40, -20, 70, 40), "text": "Recolha 3 livros esquecidos no pátio"},
			{"t": "talk", "to": "bibliotecaria", "text": "Devolva os livros na biblioteca"}]},
	"reciclagem": {"giver": "inspector", "title": "Reciclagem", "xp": 30, "coins": 18,
		"intro": ["Tem papel jogado no chão do pátio.", "Recolha e jogue nas lixeiras de reciclagem, por favor!"],
		"steps": [
			{"t": "collect", "item": "paper_ball", "count": 4, "area": Rect2(-30, -22, 60, 30), "text": "Recolha 4 papéis jogados no pátio"},
			{"t": "spot", "spots": [BINS], "prompt": "Jogar no lixo de papel", "anim": "throw", "time": 0.6, "text": "Leve o papel até as lixeiras coloridas"},
			{"t": "choice", "question": "Em qual lixeira vai o papel?", "options": ["Azul", "Vermelha", "Verde", "Amarela"], "answer": 0, "success": "Isso! Papel na azul, plástico na vermelha, vidro na verde e metal na amarela."}]},
	"cantina_pratos": {"giver": "cook", "title": "Ajudando a Tia Rosa", "xp": 30, "coins": 20,
		"intro": ["Querido, ficaram pratos nas mesas do refeitório.", "Traz pra mim? Ganha um suco!"],
		"steps": [
			{"t": "collect", "item": "caderno", "count": 3, "area": Rect2(-20, 6, 26, 10), "text": "Recolha 3 bandejas nas mesas do pátio coberto", "label": "Pegar bandeja"},
			{"t": "talk", "to": "cook", "text": "Entregue as bandejas para a Tia Rosa"}]},
	"cacador_norte": {"giver": "mari", "title": "Caça ao tesouro: pontos cardeais", "xp": 40, "coins": 25,
		"intro": ["Escondi pistas pela escola!", "A primeira está no muro do lado NORTE, no mural da natureza."],
		"steps": [
			{"t": "goto", "pos": Vector3(0, 0.05, -72.5), "r": 3.0, "text": "Pista 1: vá ao mural no lado NORTE da escola"},
			{"t": "goto", "pos": Vector3(-87.5, 0.05, -20), "r": 3.0, "text": "Pista 2: agora vá para o OESTE, no mural 'Recreio é alegria'"},
			{"t": "goto", "pos": Vector3(87.5, 0.05, -50), "r": 3.0, "text": "Pista 3: atravesse até o LESTE, no mural do esporte"},
			{"t": "choice", "question": "Se o sol nasce no leste, onde ele se põe?", "options": ["Oeste", "Norte", "Sul"], "answer": 0, "success": "Achou o tesouro: uma figurinha!", "fx": "sticker"}]},
	"historia_linha": {"giver": "teacher", "title": "Linha do tempo", "xp": 35, "coins": 20, "min_level": 4,
		"intro": ["Montei uma linha do tempo no quadro de avisos do hall.", "Vai lá e me diga qual veio primeiro."],
		"steps": [
			{"t": "goto", "pos": HALL_BOARD, "r": 2.5, "text": "Vá ao quadro de avisos do hall de entrada"},
			{"t": "choice", "question": "O que aconteceu PRIMEIRO no Brasil?", "options": ["Chegada dos portugueses (1500)", "Independência (1822)", "República (1889)"], "answer": 0, "success": "Muito bem, historiador!"}]},
	"musica_ensaio": {"giver": "julia", "title": "Ensaio de música", "xp": 30, "coins": 18,
		"intro": ["Vai ter apresentação na festa junina!", "Me ajuda a afinar o piano da sala de música?"],
		"steps": [
			{"t": "spot", "spots": [MUSIC], "prompt": "Tocar o piano", "anim": "interact", "time": 1.5, "text": "Vá à Sala de Música (Bloco B) e toque o piano"},
			{"t": "quiz", "subject": "Música", "text": "Responda a pergunta de música"}]},
	"ingles_etiquetas": {"giver": "pedro", "title": "Etiquetas em inglês", "xp": 30, "coins": 18,
		"intro": ["Quero colar etiquetas em inglês pela escola.", "Mas eu não sei as palavras... Me ajuda?"],
		"steps": [
			{"t": "choice", "question": "Como se diz ESCOLA em inglês?", "options": ["School", "House", "Door"], "answer": 0, "success": "School! Vou colar no portão."},
			{"t": "goto", "pos": Vector3(0, 0.05, 72), "r": 3.0, "text": "Cole a etiqueta 'School' no portão de entrada"},
			{"t": "quiz", "subject": "Inglês", "text": "Mais uma de inglês!"}]},
	"geografia_mapa": {"giver": "bia", "title": "Geografia: capitais", "xp": 30, "coins": 18, "min_level": 3,
		"intro": ["Aposto que você não sabe todas as capitais!", "Duvido acertar duas seguidas."],
		"steps": [{"t": "quiz", "subject": "Geografia", "text": "Pergunta 1 da Bia"}, {"t": "quiz", "subject": "Geografia", "text": "Pergunta 2 da Bia"}]},
	"aquecimento": {"giver": "rafa", "title": "Aquecimento na quadra", "xp": 30, "coins": 15,
		"intro": ["Bora aquecer antes do jogo?", "Toca nos quatro cantos da quadra correndo!"],
		"steps": [
			{"t": "goto", "pos": Vector3(21, 0.05, -40), "r": 2.0, "text": "Canto 1 da quadra"},
			{"t": "goto", "pos": Vector3(59, 0.05, -40), "r": 2.0, "text": "Canto 2 da quadra"},
			{"t": "goto", "pos": Vector3(59, 0.05, -58), "r": 2.0, "text": "Canto 3 da quadra"},
			{"t": "goto", "pos": Vector3(21, 0.05, -58), "r": 2.0, "text": "Canto 4 da quadra"}]},
	"lanche_gui": {"giver": "gui", "title": "Lanche pro Gui", "xp": 25, "coins": 10,
		"intro": ["Esqueci meu dinheiro do lanche...", "Pode ir na cantina e pedir um pão de queijo pra mim?"],
		"steps": [{"t": "talk", "to": "cook", "text": "Peça um pão de queijo para a Tia Rosa"}, {"t": "talk", "to": "gui", "text": "Leve o pão de queijo para o Gui"}]},
	"ana_livro": {"giver": "ana", "title": "Leitura com a Ana", "xp": 30, "coins": 15,
		"intro": ["Eu adoro a biblioteca...", "Me acompanha até lá? Tenho vergonha de ir sozinha."],
		"steps": [{"t": "goto", "pos": Vector3(-48, 0.05, 42), "r": 3.0, "text": "Vá com a Ana até a Biblioteca"}, {"t": "quiz", "subject": "Português", "text": "A Ana quer saber o que você aprendeu"}]},
}
const GIVER_TEXT := {"jardineiro": "Seu Zé", "bibliotecaria": "Dona Lúcia"}

var npcs: NPCManager
var player: PlayerController
var hud: HUD
var day: SchoolDay
var world: SchoolWorld
var active_id := ""
var step_i := 0
var _step_left := 0
var _spawned: Array[Node] = []
var _spot_nodes: Array[Node] = []
var _marker: Node3D
var _bangs := {}  # npc -> Label3D "!"
var _refresh_t := 0.0
var _garden_root: Node3D
var _tree_spot := Vector3.ZERO
var _quiz_tries := 0
var gardener: NPC
var librarian: NPC


func setup(m: NPCManager, p: PlayerController, h: HUD, d: SchoolDay, w: SchoolWorld) -> void:
	npcs = m
	player = p
	hud = h
	day = d
	world = w
	gardener = _staff({"id": "jardineiro", "name": "Seu Zé", "role": "gardener", "seed": 910,
		"look": {"hair_style": "raspado", "hair_color": "8a8a8a", "shirt_color": "6b8e23", "shirt_trim": "556b2f", "shirt_logo": false,
			"long_pants": true, "pants_color": "6b4f2b", "backpack": false, "cap": true, "cap_color": "c98f12", "height_scale": 1.2, "build": 1.1}},
		Vector3(3, 0.05, -60), 0.0)
	librarian = _staff({"id": "bibliotecaria", "name": "Dona Lúcia", "role": "librarian", "seed": 911,
		"look": {"hair_style": "rabo", "hair_color": "5d4037", "shirt_color": "f06292", "shirt_trim": "c2185b", "shirt_logo": false,
			"long_pants": true, "pants_color": "37474f", "backpack": false, "glasses": true, "height_scale": 1.17}},
		Vector3(-42.2, 0.05, 40.6), PI)
	_marker = _make_marker()
	w.add_child(_marker)
	_garden_root = Node3D.new()
	w.add_child(_garden_root)
	_rebuild_garden()
	player.picked_up.connect(_on_picked)
	d.day_finished.connect(func(_s): _rebuild_garden())


func _staff(entry: Dictionary, pos: Vector3, yaw: float) -> NPC:
	var n := npcs._make(entry)
	n.teleport(pos, yaw)
	n.activity = "staff"
	return n


func _make_marker() -> Node3D:
	var m := Node3D.new()
	var md := MeshData.new()
	md.cur_color = Color("5ec8ff")
	md.add_sphere(Transform3D(Basis.from_scale(Vector3(0.5, 1, 0.5)), Vector3(0, 0.3, 0)), 0.32, 4, 2)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	var ring := MeshInstance3D.new()
	var rmd := MeshData.new()
	rmd.cur_color = Color(0.37, 0.78, 1.0)
	rmd.add_cylinder(Transform3D(), 0.9, 0.9, 0.02, 24, false)
	var rmat := mat.duplicate() as StandardMaterial3D
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.mesh = rmd.build_mesh(rmat)
	ring.name = "Ring"
	m.add_child(ring)
	m.visible = false
	return m


# ------------------------------------------------------------- disponibilidade

func _giver_node(giver: String) -> NPC:
	match giver:
		"teacher": return npcs.teacher
		"cook": return npcs.cook
		"inspector": return npcs.inspector
		"jardineiro": return gardener
		"bibliotecaria": return librarian
	for n in npcs.npcs:
		if n.data.get("id", "") == giver:
			return n
	return null


func _state() -> Dictionary:
	return SaveManager.section("quests")


func is_available(qid: String) -> bool:
	if active_id != "" or not QUESTS.has(qid):
		return false
	var q: Dictionary = QUESTS[qid]
	if Learning.level() < int(q.get("min_level", 1)):
		return false
	if q.get("needs", "") == "garden_ready" and not _garden_ready():
		return false
	if q.get("needs", "") == "" and qid == "horta_plantar" and _garden_planted():
		return false
	var last := int(_state().get(qid, {}).get("day", -99))
	return last < day.day  # uma vez por dia cada missão


func _free_phase() -> bool:
	return day.phase in [SchoolDay.Phase.ARRIVAL, SchoolDay.Phase.RECESS, SchoolDay.Phase.RETURN, SchoolDay.Phase.DAY_END]


func available_for(npc: NPC) -> String:
	if not _free_phase():
		return ""
	for qid in QUESTS.keys():
		if QUESTS[qid].giver == npc.data.get("id", "") or _giver_node(QUESTS[qid].giver) == npc:
			if is_available(qid):
				return qid
	return ""


func npc_prompt(npc: NPC) -> String:
	if active_id != "":
		var st := _step()
		if st.get("t", "") == "talk" and _giver_node(st.to) == npc:
			return "Falar com %s (missão)" % npc.display_name
		return ""
	var qid := available_for(npc)
	return "Missão: %s" % QUESTS[qid].title if qid != "" else ""


func npc_interact(npc: NPC) -> bool:
	if active_id != "":
		var st := _step()
		if st.get("t", "") == "talk" and _giver_node(st.to) == npc:
			npc.say("Obrigado(a)!", 2.0)
			npc.visual.play("clap")
			_advance()
			return true
		return false
	var qid := available_for(npc)
	if qid == "":
		return false
	offer(qid, npc)
	return true


## Mostra a proposta com Aceitar / Agora não.
func offer(qid: String, npc: NPC) -> void:
	var q: Dictionary = QUESTS[qid]
	var lines: Array = q.intro.duplicate()
	lines.append("Recompensa: %d moedas e %d XP." % [q.coins, q.xp])
	player.input_enabled = false
	hud.controls.visible = false
	npc.face(player.global_position)
	day.dialogue.open("%s — %s" % [npc.display_name, q.title], lines, ["Aceitar", "Agora não"])
	day.dialogue.finished.connect(func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		if choice == 0:
			start(qid)
		else:
			npc.say("Tudo bem, fica pra depois!", 2.0), CONNECT_ONE_SHOT)


func start(qid: String) -> void:
	active_id = qid
	step_i = 0
	_quiz_tries = 0
	AudioManager.play_ui("ui_confirm")
	hud.show_banner("Missão aceita!", QUESTS[qid].title)
	quest_started.emit(qid)
	_begin_step()


func abandon() -> void:
	_cleanup_step()
	active_id = ""
	hud.set_mission("")
	hud.set_mission_point(null)
	_marker.visible = false


func _step() -> Dictionary:
	if active_id == "":
		return {}
	var steps: Array = QUESTS[active_id].steps
	return steps[step_i] if step_i < steps.size() else {}


func _begin_step() -> void:
	_cleanup_step()
	var st := _step()
	if st.is_empty():
		_complete()
		return
	hud.set_mission("Missão: %s — %s" % [QUESTS[active_id].title, st.text])
	match st.t:
		"spot":
			var spots: Array = st.spots
			_step_left = spots.size()
			for sp in spots:
				var pos: Vector3 = _tree_target() if str(sp) == "tree_spot" else sp
				var s := QuestSpot.new()
				s.prompt = st.prompt
				s.position = pos
				s.hold_time = st.get("time", 1.0)
				s.anim = st.get("anim", "interact")
				s.done.connect(_on_spot_done.bind(st.get("fx", "")))
				world.add_child(s)
				_spot_nodes.append(s)
		"collect":
			_step_left = int(st.count)
			var r := RandomNumberGenerator.new()
			r.randomize()
			var area: Rect2 = st.area
			for i in int(st.count):
				var pos := npcs.nav.random_point(r, area) + Vector3(0, 0.3, 0)
				var it: PickupItem = PickupItem.create_paper_ball() if st.item == "paper_ball" else PickupItem.create_item(st.item)
				if st.has("label"):
					it.prompt = st.label
				it.position = pos
				it.add_to_group("quest_item")
				world.get_node("Dynamic").add_child(it)
				_spawned.append(it)
		"quiz":
			_ask_quiz(st.subject)
		"choice":
			_ask_choice(st)
	_refresh_markers()


func _cleanup_step() -> void:
	for n in _spot_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_spot_nodes.clear()
	for n in _spawned:
		if is_instance_valid(n):
			if player.held_item == n:
				player.held_item = null
			n.queue_free()
	_spawned.clear()


func _advance() -> void:
	step_i += 1
	_quiz_tries = 0
	AudioManager.play_ui("pickup", -4.0)
	_begin_step()


func _complete() -> void:
	var q: Dictionary = QUESTS[active_id]
	_state()[active_id] = {"day": day.day, "count": int(_state().get(active_id, {}).get("count", 0)) + 1}
	GameManager.add_rewards(int(q.xp), int(q.coins))
	GameManager.add_stat("missoes")
	Effects.burst(player.global_position + Vector3(0, 2, 0), "confetti")
	hud.show_banner("Missão cumprida!", "%s  (+%d moedas, +%d XP)" % [q.title, q.coins, q.xp])
	var giver := _giver_node(q.giver)
	if giver and giver.role == "student":
		Friendship.add(giver.data.get("id", ""), 6, "missao")
	var done := active_id
	active_id = ""
	hud.set_mission("")
	hud.set_mission_point(null)
	_marker.visible = false
	quest_completed.emit(done)
	SaveManager.save_game()


# ------------------------------------------------------------- etapas

func _on_spot_done(spot: Node, fx: String) -> void:
	_spot_nodes.erase(spot)
	_apply_fx(fx, spot.global_position)
	spot.queue_free()
	_step_left -= 1
	if _step_left <= 0:
		_advance()
	else:
		_refresh_markers()


func _on_picked(item: Node) -> void:
	if item in _spawned and _step().get("t", "") == "collect":
		_spawned.erase(item)
		player.held_item = null
		item.queue_free()
		_step_left -= 1
		AudioManager.play_ui("pickup")
		if _step_left <= 0:
			_advance()
		else:
			hud.set_mission("Missão: %s — %s (faltam %d)" % [QUESTS[active_id].title, _step().text, _step_left])
			_refresh_markers()


func _ask_quiz(subject: String) -> void:
	var gen := ClassroomTasks.new(randi(), Learning.level())
	var t := gen.make("quiz", subject)
	var opts: Array = t.options
	player.input_enabled = false
	hud.controls.visible = false
	day.dialogue.open(t.subject, [t.prompt], opts)
	day.dialogue.finished.connect(func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		var ok := choice == int(t.answer)
		Learning.record(ok)
		if ok:
			GameManager.show_toast("Resposta certa!")
			_advance()
		else:
			_quiz_tries += 1
			GameManager.show_toast("A resposta era: %s" % opts[t.answer])
			if _quiz_tries >= 2:
				_advance()
			else:
				get_tree().create_timer(1.2).timeout.connect(func(): _ask_quiz(subject)), CONNECT_ONE_SHOT)


func _ask_choice(st: Dictionary) -> void:
	player.input_enabled = false
	hud.controls.visible = false
	day.dialogue.open(QUESTS[active_id].title, [st.question], st.options)
	day.dialogue.finished.connect(func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		if choice == int(st.answer):
			day.dialogue.open(QUESTS[active_id].title if active_id != "" else "", [st.success])
			_apply_fx(st.get("fx", ""), player.global_position + Vector3(0, 1.2, 0))
			_advance()
		else:
			GameManager.show_toast("Hmm, não foi isso. Tente de novo!")
			get_tree().create_timer(1.0).timeout.connect(func(): _ask_choice(st)), CONNECT_ONE_SHOT)


func _apply_fx(fx: String, pos: Vector3) -> void:
	match fx:
		"plant":
			_garden_state()["planted_day"] = day.day
			_garden_state()["stage"] = 1
			_rebuild_garden()
			Effects.burst(pos, "dust")
		"water":
			_garden_state()["watered"] = true
			Effects.burst(pos, "sparkle")
		"harvest":
			_garden_state()["stage"] = 0
			_garden_state()["planted_day"] = -1
			_rebuild_garden()
			GameManager.add_stat("colheitas")
		"tree":
			var trees: Array = SaveManager.section("garden").get("trees", [])
			trees.append({"x": pos.x, "z": pos.z, "day": day.day})
			SaveManager.section("garden")["trees"] = trees
			_rebuild_garden()
			GameManager.add_stat("arvores")
		"ramp_ball":
			var b := KickBall.create("football")
			b.position = STAGE + Vector3(-1.0, 0.5, 0)
			world.get_node("Dynamic").add_child(b)
			b.linear_velocity = Vector3(-3.5, 0, 0)
			get_tree().create_timer(8.0).timeout.connect(b.queue_free)
		"sticker":
			Stickers.give_random(false)
		"confetti", "sparkle":
			Effects.burst(pos, fx)


# ------------------------------------------------------------- horta e árvores

func _garden_state() -> Dictionary:
	return SaveManager.section("garden")


func _garden_planted() -> bool:
	return int(_garden_state().get("stage", 0)) >= 1


func _garden_ready() -> bool:
	return _garden_planted() and int(_garden_state().get("planted_day", 99999)) < day.day


func _tree_target() -> Vector3:
	var planted: Array = _garden_state().get("trees", [])
	for sp in TREE_SPOTS:
		var used := false
		for t in planted:
			if Vector2(t.x, t.z).distance_to(Vector2(sp.x, sp.z)) < 1.0:
				used = true
		if not used:
			_tree_spot = sp
			return sp
	_tree_spot = TREE_SPOTS[randi() % TREE_SPOTS.size()] + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	return _tree_spot


func _rebuild_garden() -> void:
	for c in _garden_root.get_children():
		c.queue_free()
	var md := MeshData.new()
	var g := _garden_state()
	if _garden_planted():
		var grown := _garden_ready()
		for bed in BEDS.slice(0, 3):
			for k in 6:
				var p: Vector3 = bed + Vector3(-1.0 + (k % 3) * 1.0, 0.02, -2.5 + (k / 3) * 5.0)
				md.cur_color = Color("3d9b35") if grown else Color("7cc15a")
				md.add_sphere(Transform3D(Basis.from_scale(Vector3(1, 0.7, 1)), p + Vector3(0, 0.1, 0)), 0.28 if grown else 0.1, 8, 5)
				if grown:
					md.cur_color = Color("e53935") if k % 2 == 0 else Color("ff9800")
					md.add_sphere(Transform3D(Basis(), p + Vector3(0.1, 0.3, 0)), 0.08, 6, 4)
	for t in g.get("trees", []):
		var age := clampi(day.day - int(t.day), 0, 6)
		var s := 0.35 + age * 0.12
		var base := Vector3(float(t.x), 0.0, float(t.z))
		md.cur_color = Color("6e4a2e")
		md.add_cylinder(Transform3D(Basis(), base + Vector3(0, 1.0 * s, 0)), 0.08 * s, 0.12 * s, 2.0 * s, 6)
		md.cur_color = Color("3f8a3a")
		md.add_sphere(Transform3D(Basis(), base + Vector3(0, 2.3 * s, 0)), 1.1 * s, 8, 6)
		md.cur_color = Color("8a5a32")
		md.add_cylinder(Transform3D(Basis(), base + Vector3(0, 0.08, 0)), 0.5, 0.55, 0.16, 10)
	if md.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_garden_root.add_child(mi)


# ------------------------------------------------------------- marcadores

func _target_pos() -> Variant:
	var st := _step()
	if st.is_empty():
		return null
	match st.t:
		"goto":
			return st.pos
		"spot":
			for n in _spot_nodes:
				if is_instance_valid(n):
					return (n as Node3D).global_position
		"collect":
			var best: Variant = null
			for n in _spawned:
				if is_instance_valid(n) and (best == null or (n as Node3D).global_position.distance_to(player.global_position) < (best as Vector3).distance_to(player.global_position)):
					best = (n as Node3D).global_position
			return best
		"talk":
			var g := _giver_node(st.to)
			return g.global_position if g else null
	return null


func _refresh_markers() -> void:
	# "!" sobre quem tem missão
	var givers := []
	for qid in QUESTS.keys():
		var g := _giver_node(QUESTS[qid].giver)
		if g and g.active and is_available(qid) and _free_phase():
			if not g in givers:
				givers.append(g)
	for n in _bangs.keys():
		if not n in givers or not is_instance_valid(n):
			if is_instance_valid(_bangs[n]):
				_bangs[n].queue_free()
			_bangs.erase(n)
	var mm := []
	for g in givers:
		if not _bangs.has(g):
			var lb := Label3D.new()
			lb.text = "!"
			lb.font = UITheme.bold_font()
			lb.font_size = 140
			lb.pixel_size = 0.006
			lb.outline_size = 22
			lb.modulate = Color("ffcf3f")
			lb.outline_modulate = Color("1f2a44")
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.position = Vector3(0, 2.55 * g.visual.appearance.height_scale, 0)
			g.add_child(lb)
			_bangs[g] = lb
		mm.append({"pos": g.global_position, "color": Color("ffcf3f"), "icon": "!"})
	hud.minimap.set_markers("missoes", mm)
	var tp: Variant = _target_pos()
	if tp != null:
		hud.minimap.set_markers("missao_ativa", [{"pos": tp, "color": Color("5ec8ff"), "icon": "M"}])
	else:
		hud.minimap.set_markers("missao_ativa", [])


func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.5
		_refresh_markers()
		for n in [gardener, librarian]:
			if n and not n.moving and n.visual.animator.upper_action == "" and randf() < 0.1:
				n.visual.play("talk")
	if active_id == "":
		hud.set_mission_point(null)
		_marker.visible = false
		return
	var st := _step()
	if st.get("t", "") == "goto" and player.global_position.distance_to(st.pos) < float(st.r):
		_advance()
		return
	var tp: Variant = _target_pos()
	if tp == null:
		_marker.visible = false
		hud.set_mission_point(null)
		return
	var pos: Vector3 = tp
	_marker.visible = player.global_position.distance_to(pos) > 1.0
	_marker.global_position = pos + Vector3(0, 2.2 + sin(Time.get_ticks_msec() * 0.004) * 0.12, 0)
	_marker.get_node("Ring").global_position = pos + Vector3(0, 0.04, 0)
	_marker.rotate_y(delta * 2.0)
	hud.set_mission_point(pos + Vector3(0, 1.0, 0))
