class_name MinigameManager
extends Node
## Registra os minijogos, cria as "estações" no mapa (placas interativas
## visíveis no recreio), faz convites espontâneos de amigos e garante que
## só um minijogo rode por vez (e que acabe quando o recreio acaba).

signal game_started(id: String)
signal game_finished(result: Dictionary)

const GAMES := {
	"futebol": {"script": "res://scripts/minigames/football_match.gd", "title": "Futebol", "pos": Vector3(40, 0.05, -37.6), "yaw": PI, "color": Color("2ecc71"), "icon": "F", "desc": "Só com a turma (mín. 2), goleiros são bots. Passe rápido, roube e chute!"},
	"queimada": {"script": "res://scripts/minigames/dodgeball.gd", "title": "Queimada", "pos": Vector3(-40, 0.05, -42.6), "yaw": PI, "color": Color("e74c3c"), "icon": "Q", "desc": "Só com a turma (mín. 2). Pegue a bola, mire e queime o time todo!"},
	"gude": {"script": "res://scripts/minigames/marbles.gd", "title": "Bolinha de gude", "pos": Vector3(-43.6, 0.05, -9.0), "yaw": -PI * 0.5, "color": Color("3fa7d6"), "icon": "G", "desc": "Mire, carregue a força e tire as bolinhas do círculo."},
	"amarelinha": {"script": "res://scripts/minigames/hopscotch.gd", "title": "Amarelinha", "pos": Vector3(-14, 0.05, 0.8), "yaw": 0.0, "color": Color("f6e05e"), "icon": "1", "desc": "Jogue a pedrinha e pule as casas no ritmo, sem pisar na pedra."},
	"aviao": {"script": "res://scripts/minigames/paper_plane.gd", "title": "Aviãozinho", "pos": Vector3(12, 0.05, 3.2), "yaw": 0.0, "color": Color("ecf0f1"), "icon": "A", "desc": "Dobre bem o avião, mire e faça ele planar pelas argolas."},
	"corrida": {"script": "res://scripts/minigames/race.gd", "title": "Corrida", "pos": Vector3(-43.5, 0.05, -19.2), "yaw": PI * 0.5, "color": Color("ff8a3d"), "icon": "C", "desc": "80 metros contra dois colegas. Use o botão Correr!"},
	"corda": {"script": "res://scripts/minigames/jump_rope.gd", "title": "Pular corda", "pos": Vector3(-24, 0.05, 0.5), "yaw": 0.0, "color": Color("e84393"), "icon": "P", "desc": "Pule quando a corda passar pelo chão. Ela vai acelerando!"},
	"pontaria": {"script": "res://scripts/minigames/aim_bin.gd", "title": "Pontaria na lixeira", "pos": Vector3(24, 0.05, -17.0), "yaw": 0.0, "color": Color("27ae60"), "icon": "L", "desc": "Segure para mirar e acerte as lixeiras de reciclagem."},
	"basquete": {"script": "res://scripts/minigames/basketball.gd", "title": "Basquete", "pos": Vector3(ParkHill.COURT.x - 3.5, 0.05, ParkHill.COURT.y + 4.2), "yaw": PI, "color": Color("ff7a1a"), "icon": "B", "desc": "Arremesse na cesta de 3 distâncias. Segure para mirar e solte na força certa!"},
	"esconde": {"script": "res://scripts/minigames/hide_and_seek.gd", "title": "Esconde-esconde", "pos": Vector3(-4.0, 0.05, -80.5), "yaw": 0.0, "color": Color("14b8a6"), "icon": "E", "desc": "Conte até 10 e procure 5 colegas escondidos pelo Parque do Morro."},
	"cabo": {"script": "res://scripts/minigames/tug_of_war.gd", "title": "Cabo de guerra", "pos": Vector3(12.0, 0.05, -84.5), "yaw": 0.0, "color": Color("c0392b"), "icon": "K", "desc": "Seu time contra o outro: toque rápido e no PUXA! para ganhar."},
	"guerra": {"script": "res://scripts/minigames/paper_war.gd", "title": "Guerra de papel", "pos": Vector3(35.5, 0.05, -2.6), "yaw": 0.0, "color": Color("9b59b6"), "icon": "W", "desc": "Segure para mirar, solte para jogar. Desvie dos círculos vermelhos!"},
}
## Quem convida para o quê.
const INVITES := {
	"futebol": "futebol", "competitivo": "corrida", "agitado": "queimada", "colecionador": "gude",
	"estudioso": "aviao", "engracado": "guerra", "comilao": "pontaria", "timido": "corda", "comum": "corda",
}

var world: SchoolWorld
var npcs: NPCManager
var player: PlayerController
var hud: HUD
var day: SchoolDay
var active: Minigame = null
var discipline: Node = null
## Multiplicador de recompensa (eventos como "torneio relâmpago").
var reward_mult := 1.0
var stations := {}
var _invite_t := 35.0
var _inviter: NPC
var _labels: Array[Label3D] = []
## Brincadeiras com outros jogadores (só age quando está online).
var online_play: OnlinePlay


func setup(w: SchoolWorld, m: NPCManager, p: PlayerController, h: HUD, d: SchoolDay) -> void:
	world = w
	npcs = m
	player = p
	hud = h
	day = d
	for gid in GAMES.keys():
		var g: Dictionary = GAMES[gid]
		var st := MinigameStation.new()
		st.game_id = gid
		st.mgr = self
		st.prompt = "Jogar: %s" % g.title
		st.position = g.pos
		st.rotation.y = g.yaw
		world.add_child(st)
		stations[gid] = st
		_build_sign(st, g)
	d.phase_changed.connect(_on_phase)
	online_play = OnlinePlay.new()
	online_play.name = "OnlinePlay"
	add_child(online_play)
	online_play.setup(self)


## Placa de madeira colorida + anel no chão (fácil de achar e ler).
func _build_sign(st: Node3D, g: Dictionary) -> void:
	var col: Color = g.color
	var md := MeshData.new()
	md.cur_color = Color("8a5a32")
	md.add_box(Transform3D(Basis(), Vector3(0.9, 0.9, 0)), Vector3(0.1, 1.8, 0.1))
	md.cur_color = col.darkened(0.25)
	md.add_box(Transform3D(Basis(), Vector3(0.9, 2.0, 0)), Vector3(2.5, 0.8, 0.08))
	md.cur_color = col
	md.add_box(Transform3D(Basis(), Vector3(0.9, 2.0, 0)), Vector3(2.35, 0.67, 0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	st.add_child(mi)
	var ring_md := MeshData.new()
	ring_md.cur_color = col
	for k in 24:
		var a := k * TAU / 24.0
		ring_md.add_box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0.03, sin(a)) * 1.6), Vector3(0.08, 0.03, 0.3))
	var rmat := StandardMaterial3D.new()
	rmat.vertex_color_use_as_albedo = true
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.mesh = ring_md.build_mesh(rmat)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.name = "Ring"
	ring.visible = Settings.quality() != Settings.Quality.LOW  # anel no chão: só fora da qualidade baixa
	st.add_child(ring)
	for side: float in [1.0, -1.0]:
		var lb := Label3D.new()
		lb.text = g.title.to_upper()
		lb.font = UITheme.bold_font()
		# ajusta a fonte para nenhuma palavra ser quebrada no meio
		var fs := 64
		var longest := 0.0
		for wd in lb.text.split(" "):
			longest = maxf(longest, lb.font.get_string_size(wd, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x)
		if longest > 450.0:
			fs = int(64.0 * 450.0 / longest)
		lb.font_size = fs
		lb.pixel_size = 0.0045
		lb.outline_size = 10
		lb.modulate = Color("1f2a44") if col.get_luminance() > 0.6 else Color.WHITE
		lb.outline_modulate = Color(0, 0, 0, 0)
		lb.width = 490
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		lb.position = Vector3(0.9, 2.0, 0.06 * side)
		lb.rotation.y = 0.0 if side > 0 else PI
		lb.visibility_range_end = 26.0 if Settings.quality() == Settings.Quality.LOW else 45.0
		st.add_child(lb)


## Tutorial de primeira vez: [botão, explicação]
const TUTORIALS := {
	"futebol": [["Joystick", "Corra pelo campo com o analógico."], ["Amarelo", "Perto da bola, toque para CHUTAR (a mira ajuda)."], ["Verde", "Toque para PASSAR a bola para um colega."], ["", "Faça mais gols que o outro time!"]],
	"queimada": [["Verde", "Chegue perto da bola e toque para PEGAR."], ["Amarelo", "SEGURE para mirar (aparece a linha) e SOLTE para jogar."], ["Amarelo", "Sem a bola: toque para DESVIAR (pulinho para o lado)."], ["", "Queimado vai para o cemitério e só sai quando a partida acabar!"]],
	"gude": [["Joystick", "Gire para mirar. A linha mostra onde sua bolinha vai BATER e a seta verde, para onde a outra vai."], ["Amarelo", "SEGURE para dar força e SOLTE para jogar."], ["", "Tire as bolinhas do círculo: elas viram suas! Acertou? Joga de novo."]],
	"amarelinha": [["Amarelo", "SEGURE e SOLTE quando o círculo ficar VERDE: a pedrinha cai na casa certa."], ["Azul", "Pule no RITMO: toque quando o anel fechar e ficar verde = PERFEITO!"], ["", "O ritmo acelera a cada casa. Vá até o céu e volte pegando a pedrinha!"]],
	"aviao": [["Amarelo", "Toque quando a barra estiver no MEIO para dobrar bem (3 dobras, só uma vez)."], ["Amarelo", "SEGURE para dar força e SOLTE para lançar (a linha mostra o voo)."], ["Joystick", "No ar, faça CURVAS: são 4 argolas em zigue-zague. Todas = bônus!"]],
	"corrida": [["Amarelo", "TOQUE RÁPIDO em Correr! para ganhar velocidade."], ["Azul", "PULE as 3 barreiras: pulo limpo dá impulso, tropeçar atrasa."], ["", "Chegue primeiro nos 80 metros!"]],
	"corda": [["", "Os colegas batem a corda. A cada 10 pulos ela acelera."], ["Azul", "Pule quando a barra encher. No alto do pulo = PERFEITO (vale 2)."], ["", "3 vidas. Quantos pontos você faz?"]],
	"pontaria": [["Joystick", "Gire para mirar na lixeira."], ["Amarelo", "SEGURE para ver a curva e SOLTE para jogar. Bolinhas à vontade!"], ["", "40 segundos! A lixeira com x2 vale dobro, acertos seguidos fazem combo e os últimos 10 s valem dobro."]],
	"basquete": [["Amarelo", "SEGURE: a linha fica VERDE na força e mira certas. SOLTE para arremessar."], ["Joystick", "Gire para acertar o meio da cesta. Sem tocar no aro = CHUÁ (+1)!"], ["", "45 segundos, bolas à vontade. A cada 3 cestas você vai mais longe. Combo x2, x3!"]],
	"esconde": [["", "Você conta até 10 enquanto 5 colegas se escondem."], ["Joystick", "Siga o QUENTE ou FRIO: quanto mais perto, mais rápido o som."], ["", "Cuidado: alguns FOGEM quando você chega perto. Corra atrás!"]],
	"cabo": [["Amarelo", "Toque no PUXA! (quando a barra ENCHE): seguidos fazem combo e puxam mais forte."], ["", "Quando aparecer \"Eles vão puxar forte!\", acerte o ritmo para SEGURAR."], ["", "Puxe a fita até a marca do seu lado para ganhar!"]],
	"guerra": [["Joystick", "Ande e fuja dos círculos vermelhos: desviar de pertinho vale ponto!"], ["Amarelo", "SEGURE para mirar num colega e SOLTE para jogar a bolinha."], ["", "Acertos seguidos fazem combo e os últimos 10 s valem dobro!"]],
}
## Botões que somem em cada brincadeira (a tela fica só com o que usa).
const HIDE := {
	"amarelinha": ["run", "emote", "ride"], "aviao": ["run", "jump", "emote", "ride"], "corrida": ["run", "emote", "ride"],
	"corda": ["run", "emote", "ride"], "pontaria": ["run", "jump", "emote", "ride"], "gude": ["run", "emote", "ride"],
	"guerra": ["jump", "emote", "ride"], "basquete": ["run", "jump", "emote", "ride"], "esconde": ["emote", "ride"],
	"cabo": ["run", "jump", "emote", "ride"], "queimada": ["emote", "ride"], "futebol": ["emote", "ride"],
}

var _pending_gid := ""


static func _is_test() -> bool:
	return " ".join(OS.get_cmdline_args()).contains("res://tests/")


func show_tutorial(gid: String, on_done: Callable) -> void:
	var g: Dictionary = GAMES.get(gid, {})
	var ov := TutorialOverlay.new()
	hud.get_parent().add_child(ov)  # por cima de tudo (até da mochila)
	ov.setup(str(g.get("title", gid)), g.get("color", UITheme.YELLOW), TUTORIALS.get(gid, []))
	ov.done.connect(on_done)


func is_recess() -> bool:
	return day.phase == SchoolDay.Phase.RECESS


func _on_phase(_p: int) -> void:
	var rec := is_recess()
	if not rec and active:
		active.end_game(0, "O sinal tocou!", 5, 10)
	if not rec and online_play and online_play.in_session():
		online_play._reset(false)
	_invite_t = randf_range(30.0, 50.0)


func can_start() -> bool:
	if discipline and discipline.restricted:
		return false
	return active == null and _pending_gid == "" and is_recess() and player.mode != PlayerController.Mode.SITTING


func start(gid: String) -> bool:
	if discipline and discipline.restricted:
		GameManager.show_toast(discipline.restriction_text)
		return false
	if not can_start() or not GAMES.has(gid):
		return false
	# primeira vez: explica antes de começar
	if not TutorialOverlay.seen(gid) and not _is_test() and TUTORIALS.has(gid):
		_pending_gid = gid
		player.input_enabled = false
		hud.controls.visible = false
		show_tutorial(gid, func():
			TutorialOverlay.mark_seen(gid)
			_pending_gid = ""
			player.input_enabled = true
			hud.controls.visible = true
			start(gid))
		return true
	# online: a brincadeira é da turma (espera, fila, rodada ou time)
	if NetworkManager.is_online() and OnlinePlay.is_shared(gid):
		return online_play.request(gid)
	return start_local(gid, {})


## Começa a partida neste celular (net vazio = sozinho).
func start_local(gid: String, net: Dictionary) -> bool:
	if active != null or not GAMES.has(gid) or not is_recess():
		return false
	var script: GDScript = load(GAMES[gid].script)
	var g: Minigame = script.new()
	g.id = gid
	g.title = GAMES[gid].title
	add_child(g)
	g.setup(self)
	g.net = net
	g.finished.connect(_on_finished)
	active = g
	_show_stations(false)
	g.begin()
	game_started.emit(gid)
	return true


## Durante a brincadeira as placas somem (não tampam a câmera nem poluem).
func _show_stations(on: bool) -> void:
	for gid in stations.keys():
		(stations[gid] as Node3D).visible = on


func _on_finished(result: Dictionary) -> void:
	var g := active
	active = null
	_show_stations(true)
	if g:
		g.queue_free()
	Telemetry.track("minigame", {"id": str(result.get("id", "")), "won": int(result.get("won", 0)) > 0})
	game_finished.emit(result)
	if online_play:
		online_play.on_local_finished(result)


var guide_id := ""


## "Mostrar no mapa": guia até a estação escolhida.
func guide_to(gid: String) -> void:
	guide_id = gid
	GameManager.show_toast("Siga a seta azul até: %s" % GAMES[gid].title)


func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	var mk := []
	for gid in GAMES.keys():
		mk.append({"pos": GAMES[gid].pos, "color": GAMES[gid].color, "icon": GAMES[gid].icon})
	hud.minimap.set_markers("brincadeiras", mk)
	if guide_id != "":
		var gp: Vector3 = GAMES[guide_id].pos
		hud.set_mission_point(gp + Vector3(0, 1, 0))
		if player.global_position.distance_to(gp) < 3.0:
			guide_id = ""
			hud.set_mission_point(null)
	if active:
		active.hint_tick(delta)
		active.tick(delta)
		return
	if not is_recess() or day.dialogue.is_open():
		return
	_invite_t -= delta
	if _invite_t <= 0.0:
		_invite_t = randf_range(45.0, 75.0)
		_send_invite()


## Um amigo vem até o jogador e convida para brincar.
func _send_invite() -> void:
	var cands: Array[NPC] = []
	for n in npcs.classmates:
		if n.active and n.role == "student" and not n.talking_to_player and n.activity != "minigame" \
				and n.global_position.distance_to(player.global_position) < 45.0:
			cands.append(n)
	if cands.is_empty():
		return
	# amigos mais próximos têm preferência
	cands.sort_custom(func(a, b): return Friendship.points(a.data.id) > Friendship.points(b.data.id))
	var n: NPC = cands[randi() % mini(3, cands.size())]
	var gid: String = INVITES.get(n.personality, "corda")
	_inviter = n
	npcs._leave_activity(n)
	n.activity = "inviting"
	var target := player.global_position + (n.global_position - player.global_position).normalized() * 1.3
	n.go_to(target, true, func(): _invite_arrived(n, gid))


func _invite_arrived(n: NPC, gid: String) -> void:
	if not can_start() or n.global_position.distance_to(player.global_position) > 4.0 or day.dialogue.is_open():
		n.activity = "wander"
		return
	n.face(player.global_position)
	n.visual.play("wave")
	player.input_enabled = false
	hud.controls.visible = false
	var lines := ["Ei, %s!" % "você", "Bora jogar %s comigo?" % GAMES[gid].title.to_lower()]
	day.dialogue.open(n.display_name, lines, ["Bora!", "Agora não"])
	var cb := func(choice: int):
		player.input_enabled = true
		hud.controls.visible = true
		if choice == 0:
			Friendship.add(n.data.id, 3, "convite")
			n.say("Isso!", 1.5)
			start(gid)
		else:
			n.say("Tá bom, depois então!", 2.0)
			n.activity = "wander"
	day.dialogue.finished.connect(cb, CONNECT_ONE_SHOT)
