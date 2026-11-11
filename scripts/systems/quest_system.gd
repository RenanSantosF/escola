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
			{"t": "activity", "kind": "order", "text": "Monte o ciclo da planta", "data": {"title": "Ciclo de vida da planta", "hint": "O Seu Zé quer saber: em que ordem a planta cresce?",
				"items": ["Semente", "Broto", "Planta com folhas", "Flor", "Fruto (com novas sementes)"],
				"success": "Isso! E as sementes do fruto começam tudo de novo. É um ciclo!"}}]},
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
	"quimica_cores": {"giver": "teacher", "title": "Laboratório: mistura de cores", "xp": 40, "coins": 22, "min_level": 1,
		"intro": ["No laboratório tem tintas vermelha, amarela e azul.", "Descubra quais misturas fazem laranja, roxo e verde!"],
		"steps": [
			{"t": "goto", "pos": LAB, "r": 2.5, "text": "Vá ao Laboratório de Ciências (Bloco B)"},
			{"t": "activity", "kind": "mix", "text": "Misture as tintas e descubra as cores"}]},
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
	"fisica_velocidade": {"giver": "professor_ef", "title": "Física: quem é mais rápido?", "xp": 35, "coins": 18, "min_level": 4,
		"intro": ["Um aluno correu 100 metros em 20 segundos!", "Me ajuda a calcular a velocidade dele?"],
		"steps": [
			{"t": "choice", "question": "100 m em 20 s dá uma velocidade de...", "options": ["5 m/s", "2 m/s", "20 m/s"], "answer": 0, "success": "5 metros por segundo. Agora é a sua vez de correr!"},
			{"t": "goto", "pos": Vector3(38, 0.05, -21), "r": 3.0, "text": "Corra até o fim da pista pintada do pátio"}]},
	"biblioteca": {"giver": "bibliotecaria", "title": "Livros perdidos", "xp": 35, "coins": 20,
		"intro": ["Alguns alunos esqueceram livros pelo pátio...", "Me ajuda a recolher 3 e trazer de volta?"],
		"steps": [
			{"t": "collect", "item": "livro", "count": 3, "area": Rect2(-40, -20, 70, 40), "text": "Recolha 3 livros esquecidos no pátio"},
			{"t": "talk", "to": "bibliotecaria", "text": "Devolva os livros na biblioteca"}]},
	"reciclagem": {"giver": "inspector", "title": "Coleta seletiva", "xp": 40, "coins": 22,
		"intro": ["Tem lixo espalhado pelo pátio!", "Recolhe tudo e separa nas lixeiras coloridas? Cada cor é um material."],
		"steps": [
			{"t": "collect", "item": "paper_ball", "count": 5, "area": Rect2(-30, -22, 60, 30), "text": "Recolha 5 lixos jogados no pátio", "label": "Recolher lixo"},
			{"t": "spot", "spots": [BINS], "prompt": "Separar o lixo", "anim": "interact", "time": 0.4, "text": "Leve o lixo até as lixeiras coloridas"},
			{"t": "activity", "kind": "sort", "text": "Separe cada resíduo na lixeira certa"}]},
	"cantina_pratos": {"giver": "cook", "title": "Ajudando a Tia Rosa", "xp": 30, "coins": 20,
		"intro": ["Querido, ficaram pratos nas mesas do refeitório.", "Traz pra mim? Ganha um suco!"],
		"steps": [
			{"t": "collect", "item": "caderno", "count": 3, "area": Rect2(-20, 6, 26, 10), "text": "Recolha 3 bandejas nas mesas do pátio coberto", "label": "Pegar bandeja"},
			{"t": "talk", "to": "cook", "text": "Entregue as bandejas para a Tia Rosa"}]},
	"cacador_norte": {"giver": "inspector", "title": "Caça ao tesouro: pontos cardeais", "xp": 40, "coins": 25,
		"intro": ["Escondi pistas pela escola!", "A primeira está no muro do lado NORTE, no mural da natureza."],
		"steps": [
			{"t": "goto", "pos": Vector3(0, 0.05, -72.5), "r": 3.0, "text": "Pista 1: vá ao mural no lado NORTE da escola"},
			{"t": "goto", "pos": Vector3(-87.5, 0.05, -20), "r": 3.0, "text": "Pista 2: agora vá para o OESTE, no mural 'Recreio é alegria'"},
			{"t": "goto", "pos": Vector3(87.5, 0.05, -50), "r": 3.0, "text": "Pista 3: atravesse até o LESTE, no mural do esporte"},
			{"t": "choice", "question": "Se o sol nasce no leste, onde ele se põe?", "options": ["Oeste", "Norte", "Sul"], "answer": 0, "success": "Achou o tesouro: uma figurinha!", "fx": "sticker"}]},
	"historia_linha": {"giver": "teacher", "title": "Linha do tempo do Brasil", "xp": 40, "coins": 22, "min_level": 3,
		"intro": ["Montei uma linha do tempo no quadro de avisos do hall.", "Mas os cartões caíram! Coloca na ordem pra mim?"],
		"steps": [
			{"t": "goto", "pos": HALL_BOARD, "r": 2.5, "text": "Vá ao quadro de avisos do hall de entrada"},
			{"t": "activity", "kind": "order", "text": "Coloque os fatos em ordem", "data": {"title": "Linha do tempo do Brasil", "hint": "Toque do MAIS ANTIGO para o mais recente.",
				"items": ["Povos indígenas vivem aqui há milhares de anos", "Chegada dos portugueses (1500)", "Independência (1822)", "Fim da escravidão (1888)", "República (1889)"],
				"success": "Linha do tempo completa! A história do Brasil começa muito antes de 1500, com os povos indígenas."}}]},
	"musica_ensaio": {"giver": "professora_musica", "title": "Ensaio de piano", "xp": 40, "coins": 22,
		"intro": ["Vai ter apresentação na festa junina!", "Vamos ensaiar uma música no piano da sala de música?"],
		"steps": [
			{"t": "spot", "spots": [MUSIC], "prompt": "Sentar ao piano", "anim": "interact", "time": 0.5, "text": "Vá à Sala de Música (Bloco B) e sente ao piano"},
			{"t": "activity", "kind": "piano", "text": "Ouça e toque a música, trecho por trecho"},
			{"t": "choice", "question": "No piano, as notas da DIREITA são...", "options": ["Mais agudas (finas)", "Mais graves (grossas)", "Iguais às da esquerda"], "answer": 0, "success": "Isso! Para a direita o som fica mais agudo. Você arrasou no ensaio!", "fx": "confetti"}]},
	"ingles_etiquetas": {"giver": "teacher", "title": "Etiquetas em inglês", "xp": 30, "coins": 18,
		"intro": ["Quero colar etiquetas em inglês pela escola.", "Mas eu não sei as palavras... Me ajuda?"],
		"steps": [
			{"t": "choice", "question": "Como se diz ESCOLA em inglês?", "options": ["School", "House", "Door"], "answer": 0, "success": "School! Cole lá no portão."},
			{"t": "goto", "pos": Vector3(0, 0.05, 72), "r": 3.0, "text": "Cole a etiqueta 'School' no portão de entrada"},
			{"t": "quiz", "subject": "Inglês", "text": "Mais uma de inglês!"}]},
	"geografia_mapa": {"giver": "bibliotecaria", "title": "Geografia: capitais", "xp": 30, "coins": 18, "min_level": 3,
		"intro": ["Chegou um atlas novo na biblioteca!", "Vamos ver se você acerta duas capitais seguidas?"],
		"steps": [{"t": "quiz", "subject": "Geografia", "text": "Pergunta 1 do atlas"}, {"t": "quiz", "subject": "Geografia", "text": "Pergunta 2 do atlas"}]},
	"aquecimento": {"giver": "professor_ef", "title": "Aquecimento na quadra", "xp": 30, "coins": 15,
		"intro": ["Bora aquecer antes do jogo?", "Toca nos quatro cantos da quadra correndo!"],
		"steps": [
			{"t": "goto", "pos": Vector3(21, 0.05, -40), "r": 2.0, "text": "Canto 1 da quadra"},
			{"t": "goto", "pos": Vector3(59, 0.05, -40), "r": 2.0, "text": "Canto 2 da quadra"},
			{"t": "goto", "pos": Vector3(59, 0.05, -58), "r": 2.0, "text": "Canto 3 da quadra"},
			{"t": "goto", "pos": Vector3(21, 0.05, -58), "r": 2.0, "text": "Canto 4 da quadra"}]},
	"lanche_gui": {"giver": "jardineiro", "title": "Lanche pro Seu Zé", "xp": 25, "coins": 10,
		"intro": ["Trabalhei a manhã toda na horta...", "Pode pedir um pão de queijo na cantina pra mim?"],
		"steps": [{"t": "talk", "to": "cook", "text": "Peça um pão de queijo para a Tia Rosa"}, {"t": "talk", "to": "jardineiro", "text": "Leve o pão de queijo para o Seu Zé"}]},
	"ana_livro": {"giver": "teacher", "title": "Devolver o livro", "xp": 30, "coins": 15,
		"intro": ["Esqueci de devolver um livro na biblioteca...", "Leva lá pra mim? A Dona Lúcia vai te perguntar sobre ele!"],
		"steps": [{"t": "goto", "pos": Vector3(-48, 0.05, 42), "r": 3.0, "text": "Leve o livro até a Biblioteca"}, {"t": "quiz", "subject": "Português", "text": "A Dona Lúcia quer saber o que você leu"}]},
}
const GIVER_TEXT := {"jardineiro": "Seu Zé", "bibliotecaria": "Dona Lúcia", "professor_ef": "Prof. Marcos", "professora_musica": "Prof.ª Clara"}

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
var coach: NPC  # professor de Ed. Física (na quadra)
var music_teacher: NPC  # professora de música (na sala de música)


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
	coach = _staff({"id": "professor_ef", "name": "Prof. Marcos", "role": "coach", "seed": 912,
		"look": {"hair_style": "curto", "hair_color": "2b1d14", "shirt_color": "1f6fd6", "shirt_trim": "ffffff", "shirt_logo": true,
			"long_pants": true, "pants_color": "1c2b4a", "backpack": false, "cap": true, "cap_color": "1f6fd6", "height_scale": 1.22, "build": 1.05}},
		Vector3(45.5, 0.05, -36.4), PI)
	music_teacher = _staff({"id": "professora_musica", "name": "Prof.ª Clara", "role": "music", "seed": 913,
		"look": {"hair_style": "longo", "hair_color": "5b2a12", "shirt_color": "8e44ad", "shirt_trim": "f1c40f", "shirt_logo": false,
			"long_pants": true, "pants_color": "2c2c3a", "backpack": false, "height_scale": 1.18}},
		Vector3(74.5, 0.05, 14.0), -PI * 0.5)
	_marker = _make_marker()
	w.add_child(_marker)
	_garden_root = Node3D.new()
	w.add_child(_garden_root)
	_rebuild_garden()
	player.picked_up.connect(_on_picked)
	d.day_finished.connect(func(_s): _rebuild_garden())
	_setup_party_ui()
	d.phase_changed.connect(_on_day_phase)


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
		"professor_ef": return coach
		"professora_musica": return music_teacher
	for n in npcs.npcs:
		if n.data.get("id", "") == giver:
			return n
	return null


func _state() -> Dictionary:
	return SaveManager.section("quests")


func is_available(qid: String) -> bool:
	if active_id != "" or not QUESTS.has(qid):
		return false
	# já tem uma missão de evento (recado/achado) em andamento
	if day and day.events and not day.events.mission.is_empty():
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


## Missões só no recreio e na saída: indo para a aula ou na aula, ninguém
## oferece missão (nem quando você passa perto).
func _free_phase() -> bool:
	return day.phase in [SchoolDay.Phase.RECESS, SchoolDay.Phase.DAY_END]


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
	lines.append("Recompensa: %d XP. (Moedas você ganha nas aulas!)" % [int(q.xp) + int(q.coins)])
	player.input_enabled = false
	player.velocity = Vector3.ZERO
	hud.controls.visible = false
	# quem oferece para de andar e conversa olhando para o jogador
	npc.talking_to_player = true
	if not npc.sitting:
		npc.stop()
		npc.face(player.global_position)
	npc.visual.play("talk")
	day.dialogue.open("%s — %s" % [npc.display_name, q.title], lines, ["Aceitar", "Agora não"])
	day.dialogue.finished.connect(func(choice: int):
		npc.talking_to_player = false
		npc.visual.stop_upper()
		player.input_enabled = true
		hud.controls.visible = true
		if choice == 0:
			start(qid)
		else:
			npc.say("Tudo bem, fica pra depois!", 2.0), CONNECT_ONE_SHOT)


## O sinal tocou: atividade/pergunta de missão aberta fecha (volta no recreio).
func _on_day_phase(p: int) -> void:
	var st := _step()
	if active_id == "" or st.is_empty():
		return
	var interactive: bool = st.get("t", "") in ["activity", "choice", "quiz"]
	if p == SchoolDay.Phase.RECESS:
		if interactive and hud.find_children("*", "QuestActivity", true, false).is_empty() and not day.dialogue.is_open():
			_begin_step()
		return
	if interactive:
		for a in hud.find_children("*", "QuestActivity", true, false):
			a.queue_free()
		player.input_enabled = true
		hud.controls.visible = true
		hud.set_mission("Missão: %s — continua no recreio" % QUESTS[active_id].title)


## Quem participa da missão ativa não pode sair da turma (dar lugar a jogador).
func protected_npc_ids() -> Array:
	if active_id == "":
		return []
	var out := [str(QUESTS[active_id].giver)]
	for st in QUESTS[active_id].steps:
		if st.get("t", "") == "talk":
			out.append(str(st.to))
	return out


func start(qid: String) -> void:
	active_id = qid
	step_i = 0
	_quiz_tries = 0
	AudioManager.play_ui("ui_confirm")
	hud.show_banner("Missão aceita!", QUESTS[qid].title)
	quest_started.emit(qid)
	_begin_step()


func abandon() -> void:
	if party_role != "":
		_party_leave()
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


## forced: estado do dono da missão em grupo (posições dos itens/pontos).
func _begin_step(forced := {}) -> void:
	_cleanup_step()
	var st := _step()
	if st.is_empty():
		if party_role == "member":
			return  # quem conclui é o dono; o colega espera o "done"
		_complete()
		return
	hud.set_mission("Missão: %s — %s" % [QUESTS[active_id].title, st.text])
	match st.t:
		"spot":
			var spots: Array = st.spots
			if forced.has("spots"):
				spots = (forced.spots as Array).map(func(a): return _v(a))
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
			var forced_items: Array = forced.get("items", []) if forced.has("items") else []
			var n_items: int = forced_items.size() if forced.has("items") else int(st.count)
			_step_left = n_items
			for i in n_items:
				var pos := (_v(forced_items[i]) + Vector3(0, 0.15, 0)) if forced.has("items") else (npcs.nav.random_point(r, area) + Vector3(0, 0.3, 0))
				var it: PickupItem = PickupItem.create_paper_ball() if st.item == "paper_ball" else PickupItem.create_item(st.item)
				if st.has("label"):
					it.prompt = st.label
				it.position = pos - Vector3(0, 0.15, 0)
				it.add_to_group("quest_item")
				world.get_node("Dynamic").add_child(it)
				it.mark_as_goal()
				_spawned.append(it)
		"quiz":
			_ask_quiz(st.subject)
		"choice":
			_ask_choice(st)
		"activity":
			_open_activity(st)
	_refresh_markers()
	_party_broadcast()


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
	if party_role == "member":
		# avisa o dono uma vez por etapa (ex.: "chegar no lugar" seria a cada quadro)
		if _done_sent != "%s:%d" % [active_id, step_i]:
			_done_sent = "%s:%d" % [active_id, step_i]
			NetworkManager.send_direct(party_host, "party_step", {"kind": "done", "step": step_i, "q": active_id})
		return
	step_i += 1
	_quiz_tries = 0
	AudioManager.play_ui("pickup", -4.0)
	_begin_step()


func _complete() -> void:
	if party_role == "host":
		_party_broadcast({"done": true})
		GameManager.add_rewards(10, 0)
		GameManager.show_toast("Missão em grupo! Bônus de equipe: +10 XP")
		party_role = ""
		party_members.clear()
	var q: Dictionary = QUESTS[active_id]
	_state()[active_id] = {"day": day.day, "count": int(_state().get(active_id, {}).get("count", 0)) + 1}
	GameManager.add_rewards(int(q.xp) + int(q.coins), 0)  # moedas só nas aulas
	GameManager.add_stat("missoes")
	Telemetry.track("quest_done", {"id": active_id})
	Effects.burst(player.global_position + Vector3(0, 2, 0), "confetti")
	hud.show_banner("Missão cumprida!", "%s  (+%d XP)" % [q.title, int(q.xp) + int(q.coins)])
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
	if party_role == "member":
		NetworkManager.send_direct(party_host, "party_step", {"kind": "spot", "step": step_i, "q": active_id, "pos": _pos_list([spot])[0]})
		_spot_nodes.erase(spot)
		_apply_fx(fx, spot.global_position)
		spot.queue_free()
		_refresh_markers()
		return
	_spot_nodes.erase(spot)
	_apply_fx(fx, spot.global_position)
	spot.queue_free()
	_step_left -= 1
	if _step_left <= 0:
		_advance()
	else:
		_refresh_markers()
		_party_broadcast()


func _on_picked(item: Node) -> void:
	if item in _spawned and _step().get("t", "") == "collect" and party_role == "member":
		NetworkManager.send_direct(party_host, "party_step", {"kind": "pick", "step": step_i, "q": active_id, "pos": _pos_list([item])[0]})
		_spawned.erase(item)
		player.held_item = null
		item.queue_free()
		AudioManager.play_ui("pickup")
		_refresh_markers()
		return
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
			_party_broadcast()


func _ask_quiz(subject: String) -> void:
	var gen := ClassroomTasks.new(randi(), Learning.level())
	var t := gen.make("quiz", subject)
	var opts: Array = t.options
	player.input_enabled = false
	hud.controls.visible = false
	day.dialogue.open(t.subject, [t.prompt], opts)
	var q0 := active_id
	var s0 := step_i
	day.dialogue.finished.connect(func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		if active_id != q0 or step_i != s0:
			return  # o grupo já passou desta etapa
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
	var q0 := active_id
	var s0 := step_i
	day.dialogue.finished.connect(func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		if active_id != q0 or step_i != s0:
			return
		if choice == int(st.answer):
			day.dialogue.open(QUESTS[active_id].title if active_id != "" else "", [st.success])
			_apply_fx(st.get("fx", ""), player.global_position + Vector3(0, 1.2, 0))
			_advance()
		else:
			GameManager.show_toast("Hmm, não foi isso. Tente de novo!")
			get_tree().create_timer(1.0).timeout.connect(func(): _ask_choice(st)), CONNECT_ONE_SHOT)


## Atividade jogável (piano, coleta seletiva, cores). Bônus de moedas pelo desempenho.
func _open_activity(st: Dictionary) -> void:
	player.input_enabled = false
	hud.controls.visible = false
	var a := QuestActivity.open(hud, str(st.kind), st.get("data", {}))
	var q0 := active_id
	var s0 := step_i
	a.finished.connect(func(score: float):
		player.input_enabled = true
		hud.controls.visible = true
		var bonus := int(round(score * 10.0))
		if bonus > 0:
			GameManager.add_rewards(bonus, 0)
			GameManager.show_toast("Bônus de capricho: +%d XP" % bonus)
		Learning.record(score >= 0.6)
		if active_id != "" and active_id == q0 and step_i == s0:
			_advance())


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


## Destino das missões rápidas de evento (recado, objeto perdido).
func _event_target() -> Variant:
	# castigo da Dona Cida (papéis + lixeira)
	if day and day.discipline and day.discipline.restricted:
		var ct: Variant = day.discipline.cleanup_target()
		if ct != null:
			return ct
	if day == null or day.events == null or day.events.mission.is_empty():
		return null
	var m: Dictionary = day.events.mission
	if m.type == "deliver" and is_instance_valid(m.target_npc):
		return m.target_npc.global_position
	if m.type == "fetch":
		if is_instance_valid(m.item_node) and player.held_item != m.item_node:
			return m.item_node.global_position
		if is_instance_valid(m.giver):
			return m.giver.global_position
	return null


func _refresh_markers() -> void:
	# "!" sobre quem tem missão
	var givers := []
	for qid in QUESTS.keys():
		var g := _giver_node(QUESTS[qid].giver)
		if g and g.active and is_available(qid) and _free_phase() and player.minigame == null:
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
	if tp == null:
		tp = _event_target()
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
		for n in [gardener, librarian, coach, music_teacher]:
			if n and not n.moving and n.visual.animator.upper_action == "" and randf() < 0.1:
				n.visual.play("talk")
	_update_party_ui(delta)
	if active_id == "":
		var ep: Variant = _event_target()
		if ep == null:
			ep = _guide_target()
		if ep != null:
			var epos: Vector3 = ep
			hud.set_mission_point(epos + Vector3(0, 1.0, 0))
			_marker.visible = player.global_position.distance_to(epos) > 1.5
			_marker.get_child(0).visible = false
			_marker.global_position = epos + Vector3(0, 2.6, 0)
			_marker.get_node("Ring").global_position = epos + Vector3(0, 0.04, 0)
		else:
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
	_marker.get_child(0).visible = false  # só o anel no chão (sem gota flutuante)
	_marker.global_position = pos + Vector3(0, 2.2 + sin(Time.get_ticks_msec() * 0.004) * 0.12, 0)
	_marker.get_node("Ring").global_position = pos + Vector3(0, 0.04, 0)
	_marker.rotate_y(delta * 2.0)
	hud.set_mission_point(pos + Vector3(0, 1.0, 0))


# ================================================================ guia e grupo
# "Me guie": o jogo sugere a próxima missão e leva até quem oferece.
# Missão em grupo (online): quem tem a missão chama um colega que está
# perto; o progresso (itens, pontos, etapas) é do grupo e todos ganham.
# Quem chamou é o "dono" do progresso; os outros mandam o que fizeram.

var guide_on := false
var _guide_btn: Button
var _invite_btn: Button
var _invite_target := ""
var party_role := ""  # "", "host", "member"
var party_host := ""
var party_members: Array = []
var _ui_t := 0.0
var _party_t := 0.0
var _done_sent := ""


func _setup_party_ui() -> void:
	_guide_btn = _small_button("Me guie: missão", func():
		guide_on = not guide_on
		_guide_btn.text = "Guia ligado ✓" if guide_on else "Me guie: missão"
		GameManager.show_toast("O jogo vai te levar até a próxima missão." if guide_on else "Guia de missões desligado."))
	UITheme.pin_top_right(_guide_btn, 250, 232, 236, 50)
	_invite_btn = _small_button("Chamar para a missão", func():
		if _invite_target == "":
			return
		if active_id == "":
			_offer_mission_to(_invite_target)
			return
		NetworkManager.send_direct(_invite_target, "party_invite", {"q": active_id, "title": QUESTS[active_id].title})
		GameManager.show_toast("Convite enviado para %s!" % NetworkManager.name_of(_invite_target))
		_invite_btn.visible = false)
	UITheme.pin_top_right(_invite_btn, 250, 290, 236, 50)
	NetworkManager.direct.connect(_on_direct)


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(236, 50)
	b.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.box(Color("5ec8ff"), 22, Color("2f8bc0"), 0, 3))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color("3fb0ea"), 22, Color("2f8bc0"), 0, 1))
	b.add_theme_color_override("font_color", UITheme.DARK)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		cb.call())
	b.visible = false
	hud.add_child(b)
	if hud.controls:
		hud.controls.blockers.append(b)
	return b


## Missão sugerida: a disponível com quem está mais perto.
func suggestion() -> Dictionary:
	if active_id != "" or not _free_phase():
		return {}
	var best := {}
	var bd := INF
	for qid in QUESTS.keys():
		if not is_available(qid):
			continue
		var g := _giver_node(QUESTS[qid].giver)
		if g == null or not g.active:
			continue
		var d := g.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = {"qid": qid, "giver": g}
	return best


func _update_party_ui(delta: float) -> void:
	# o dono reenvia o estado de tempos em tempos (se uma mensagem se perder, ninguém trava)
	if party_role == "host":
		_party_t -= delta
		if _party_t <= 0.0:
			_party_t = 2.0
			_party_broadcast()
	_ui_t -= delta
	if _ui_t > 0.0:
		return
	_ui_t = 0.4
	var free_now := player.minigame == null and not day.dialogue.is_open()
	_guide_btn.visible = free_now and active_id == "" and _free_phase()
	# chamar colega que está pertinho para a missão
	_invite_target = ""
	var can_offer := active_id == "" and _free_phase() and party_role == ""
	if NetworkManager.is_online() and (active_id != "" or can_offer) and party_role != "member" and free_now:
		var s := get_tree().get_first_node_in_group("online_session")
		if s:
			var bd := 8.0
			for id in s.remotes.keys():
				if id in party_members:
					continue
				var d: float = (s.remotes[id].root as Node3D).global_position.distance_to(player.global_position)
				if d < bd:
					bd = d
					_invite_target = id
	_invite_btn.visible = _invite_target != ""
	if _invite_target != "":
		_invite_btn.text = ("Chamar %s" if active_id != "" else "Missão com %s") % NetworkManager.name_of(_invite_target)


## Guia: aponta para quem oferece a missão sugerida.
func _guide_target() -> Variant:
	if not guide_on:
		return null
	var sg := suggestion()
	if sg.is_empty():
		return null
	var g: NPC = sg.giver
	hud.set_mission("Sugestão: fale com %s — %s" % [g.display_name, QUESTS[sg.qid].title])
	return g.global_position


## Sem missão: escolhe uma das disponíveis e convida o colega para fazerem juntos.
func _offer_mission_to(id: String) -> void:
	var opts: Array = []
	for qid in QUESTS.keys():
		if is_available(qid) and opts.size() < 3:
			opts.append(qid)
	if opts.is_empty():
		GameManager.show_toast("Não tem missão disponível agora.")
		return
	var titles: Array = opts.map(func(q): return QUESTS[q].title)
	titles.append("Agora não")
	player.input_enabled = false
	hud.controls.visible = false
	day.dialogue.open("Missão com %s" % NetworkManager.name_of(id), ["Qual missão vocês querem fazer juntos?"], titles)
	day.dialogue.finished.connect(func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		if choice < 0 or choice >= opts.size() or active_id != "":
			return
		start(opts[choice])
		NetworkManager.send_direct(id, "party_invite", {"q": opts[choice], "title": QUESTS[opts[choice]].title})
		GameManager.show_toast("Convite enviado para %s!" % NetworkManager.name_of(id)), CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- grupo: mensagens

func _on_direct(from: String, from_name: String, kind: String, data: Variant) -> void:
	var d: Dictionary = data if data is Dictionary else {}
	if OS.has_environment("RECREIO_NET_DEBUG"):
		print("[missão %s] %s de %s: %s (papel=%s etapa=%d)" % [NetworkManager.my_name, kind, from_name, str(d).left(160), party_role, step_i])
	match kind:
		"party_invite":
			var qid := str(d.get("q", ""))
			if not QUESTS.has(qid) or active_id != "" or player.minigame != null or day.dialogue.is_open() or not _free_phase():
				NetworkManager.send_direct(from, "party_decline", {"why": "ocupado"})
				return
			player.input_enabled = false
			hud.controls.visible = false
			day.dialogue.open("Missão em grupo", ["%s te chamou para a missão \"%s\"." % [from_name, QUESTS[qid].title], "Vamos juntos? Todo mundo ganha a recompensa!"], ["Bora!", "Agora não"])
			day.dialogue.finished.connect(func(choice: int):
				player.input_enabled = true
				hud.controls.visible = true
				if choice == 0 and active_id == "":
					party_role = "member"
					party_host = from
					active_id = qid
					step_i = -1
					hud.set_mission("Missão em grupo com %s: %s" % [from_name, QUESTS[qid].title])
					NetworkManager.send_direct(from, "party_accept", {"q": qid})
				else:
					NetworkManager.send_direct(from, "party_decline", {}), CONNECT_ONE_SHOT)
		"party_accept":
			if active_id == str(d.get("q", "")) and party_role != "member":
				party_role = "host"
				if not from in party_members:
					party_members.append(from)
				GameManager.show_toast("%s entrou na sua missão!" % from_name)
				_party_broadcast()
		"party_decline":
			GameManager.show_toast("%s não pode agora." % from_name)
		"party_leave":
			party_members.erase(from)
			GameManager.show_toast("%s saiu da missão em grupo." % from_name)
			if party_members.is_empty():
				party_role = ""
		"party_step":
			if party_role == "host" and from in party_members:
				_party_member_step(from_name, d)
		"party_state":
			if party_role == "member" and from == party_host:
				_party_apply(d)


func _pos_list(nodes: Array) -> Array:
	var out: Array = []
	for n in nodes:
		if is_instance_valid(n):
			var p: Vector3 = (n as Node3D).global_position
			out.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
	return out


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _party_broadcast(extra := {}) -> void:
	if party_role != "host":
		return
	var d := {"q": active_id, "step": step_i, "items": _pos_list(_spawned), "spots": _pos_list(_spot_nodes)}
	d.merge(extra)
	for id in party_members:
		NetworkManager.send_direct(id, "party_state", d)


## Dono: um colega fez algo (pegou item, fez ponto, terminou etapa).
func _party_member_step(from_name: String, d: Dictionary) -> void:
	if int(d.get("step", -1)) != step_i or str(d.get("q", "")) != active_id:
		return
	var kind := str(d.get("kind", ""))
	var pos: Array = d.get("pos", [])
	match kind:
		"pick":
			for it in _spawned.duplicate():
				if is_instance_valid(it) and pos.size() == 3 and (it as Node3D).global_position.distance_to(_v(pos)) < 0.6:
					_spawned.erase(it)
					if player.held_item == it:
						player.held_item = null
					it.queue_free()
					_step_left -= 1
					break
			GameManager.show_toast("%s pegou um item da missão" % from_name)
			if _step_left <= 0:
				_advance()
			else:
				_refresh_markers()
				_party_broadcast()
		"spot":
			for sp in _spot_nodes.duplicate():
				if is_instance_valid(sp) and pos.size() == 3 and (sp as Node3D).global_position.distance_to(_v(pos)) < 0.6:
					_on_spot_done(sp, str(_step().get("fx", "")))
					break
		"done":
			GameManager.show_toast("%s completou uma etapa!" % from_name)
			_advance()


## Colega: segue o progresso do dono.
func _party_apply(d: Dictionary) -> void:
	if bool(d.get("end", false)):
		party_role = ""
		party_host = ""
		abandon()
		GameManager.show_toast("A missão em grupo acabou.")
		return
	if bool(d.get("done", false)):
		party_role = ""
		party_host = ""
		_complete()
		GameManager.add_rewards(10, 0)
		GameManager.show_toast("Bônus de equipe: +10 XP")
		return
	var q := str(d.get("q", ""))
	if not QUESTS.has(q):
		return
	var step := int(d.get("step", 0))
	if q != active_id or step != step_i:
		active_id = q
		step_i = step
		_quiz_tries = 0
		_begin_step(d)
		return
	# mesma etapa: tira o que o grupo já fez
	for it in _spawned.duplicate():
		if is_instance_valid(it) and not _in_list((it as Node3D).global_position, d.get("items", [])):
			_spawned.erase(it)
			if player.held_item == it:
				player.held_item = null
			it.queue_free()
	for sp in _spot_nodes.duplicate():
		if is_instance_valid(sp) and not _in_list((sp as Node3D).global_position, d.get("spots", [])):
			_spot_nodes.erase(sp)
			sp.queue_free()
	_refresh_markers()


func _in_list(p: Vector3, list: Array) -> bool:
	for a in list:
		if (a as Array).size() == 3 and p.distance_to(_v(a)) < 0.6:
			return true
	return false


func _party_leave() -> void:
	if party_role == "host":
		_party_broadcast({"end": true})
	elif party_role == "member" and party_host != "":
		NetworkManager.send_direct(party_host, "party_leave", {})
	party_role = ""
	party_host = ""
	party_members.clear()
