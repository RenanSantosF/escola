class_name MinigameManager
extends Node
## Registra os minijogos, cria as "estações" no mapa (placas interativas
## visíveis no recreio), faz convites espontâneos de amigos e garante que
## só um minijogo rode por vez (e que acabe quando o recreio acaba).

signal game_started(id: String)
signal game_finished(result: Dictionary)

const GAMES := {
	"futebol": {"script": "res://scripts/minigames/football_match.gd", "title": "Futebol", "pos": Vector3(40, 0.05, -37.6), "yaw": PI},
	"queimada": {"script": "res://scripts/minigames/dodgeball.gd", "title": "Queimada", "pos": Vector3(-40, 0.05, -42.6), "yaw": PI},
	"gude": {"script": "res://scripts/minigames/marbles.gd", "title": "Bolinha de gude", "pos": Vector3(-43.6, 0.05, -9.0), "yaw": -PI * 0.5},
	"aviao": {"script": "res://scripts/minigames/paper_plane.gd", "title": "Aviãozinho", "pos": Vector3(12, 0.05, 3.2), "yaw": 0.0},
	"corrida": {"script": "res://scripts/minigames/race.gd", "title": "Corrida", "pos": Vector3(-43.5, 0.05, -19.2), "yaw": PI * 0.5},
	"corda": {"script": "res://scripts/minigames/jump_rope.gd", "title": "Pular corda", "pos": Vector3(-24, 0.05, 0.5), "yaw": 0.0},
	"pontaria": {"script": "res://scripts/minigames/aim_bin.gd", "title": "Pontaria na lixeira", "pos": Vector3(24, 0.05, -17.0), "yaw": 0.0},
	"guerra": {"script": "res://scripts/minigames/paper_war.gd", "title": "Guerra de papel", "pos": Vector3(35.5, 0.05, -2.6), "yaw": 0.0},
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
var stations := {}
var _invite_t := 35.0
var _inviter: NPC
var _labels: Array[Label3D] = []


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
		var lb := Label3D.new()
		lb.text = g.title.to_upper()
		lb.font = UITheme.bold_font()
		lb.font_size = 56
		lb.pixel_size = 0.006
		lb.outline_size = 14
		lb.modulate = Color("ffcf3f")
		lb.outline_modulate = Color("1f2a44")
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = g.pos + Vector3(0, 2.4, 0)
		lb.visibility_range_end = 40.0
		lb.visible = false
		world.add_child(lb)
		_labels.append(lb)
	d.phase_changed.connect(_on_phase)


func is_recess() -> bool:
	return day.phase == SchoolDay.Phase.RECESS


func _on_phase(_p: int) -> void:
	var rec := is_recess()
	for lb in _labels:
		lb.visible = rec
	if not rec and active:
		active.end_game(0, "O sinal tocou!", 5, 10)
	_invite_t = randf_range(30.0, 50.0)


func can_start() -> bool:
	return active == null and is_recess() and player.mode != PlayerController.Mode.SITTING


func start(gid: String) -> bool:
	if not can_start() or not GAMES.has(gid):
		return false
	var script: GDScript = load(GAMES[gid].script)
	var g: Minigame = script.new()
	g.id = gid
	g.title = GAMES[gid].title
	add_child(g)
	g.setup(self)
	g.finished.connect(_on_finished)
	active = g
	g.begin()
	game_started.emit(gid)
	return true


func _on_finished(result: Dictionary) -> void:
	var g := active
	active = null
	if g:
		g.queue_free()
	game_finished.emit(result)


func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return
	if active:
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
