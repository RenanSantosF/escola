class_name OnlinePlay
extends Node
## Brincadeiras com outros jogadores (o servidor organiza; ver server/src/games.js).
##
##  RODADA (round): cada um joga a própria partida ao mesmo tempo; o placar é
##    da rodada. Quem chega com a rodada rolando entra na hora.
##  VEZ (turn): um de cada vez, com fila; quem espera assiste e torce.
##  TIME (team): uma partida só, simulada pelo anfitrião (futebol, cabo).
##
## Mostra a espera (com "Começar agora" para quem chamou), a fila, o placar
## final e um botão "Entrar" quando alguém está brincando perto de você.

const KINDS := {
	"aviao": "round", "pontaria": "round", "basquete": "round", "gude": "round", "guerra": "round",
	"corrida": "round",
	"amarelinha": "turn", "corda": "turn",
	"futebol": "team", "cabo": "team", "queimada": "team",
	"esconde": "hide",
}
## Placar em que MENOR é melhor (tempo da corrida).
const LOWER_BETTER := ["corrida"]
const NEAR_FRIENDS := 30.0
const JOIN_RADIUS := 40.0
const LEAVE_DIST := 45.0

var mgr: MinigameManager
var hud: HUD
var player: PlayerController
var my_gid := ""
var _local_started := false
var _local_done := false
var _pending_t := 0.0
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _chip: Button
var _leave_btn: Button
var _chip_gid := ""
var _scan_t := 0.0
var _results: PanelContainer
## Tela atual da espera/fila (redesenhada a cada meio segundo com o tempo certo).
var _view := ""
var _view_g: Dictionary = {}
var _view_ms := 0
var _redraw_t := 0.0
## Recorde da sala em cada brincadeira: gid -> {id, name, score}.
var room_best := {}


func setup(m: MinigameManager) -> void:
	mgr = m
	hud = m.hud
	player = m.player
	NetworkManager.mg_states.connect(_on_states)
	NetworkManager.mg_event.connect(_on_event)
	NetworkManager.mg_error.connect(_on_error)
	NetworkManager.online_changed.connect(func(on):
		if not on:
			_reset(false))
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.11, 0.22, 0.9), 22, Color(1, 1, 1, 0.25), 2, 0))
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-270, 128)
	_panel.custom_minimum_size = Vector2(540, 0)
	_panel.visible = false
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_panel_box)
	hud.add_child(_panel)
	_chip = Button.new()
	_chip.focus_mode = Control.FOCUS_NONE
	_chip.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "focus"]:
		_chip.add_theme_stylebox_override(st, UITheme.box(Color("ff8a3d"), 26, Color("b85c1f"), 0, 4))
	_chip.add_theme_stylebox_override("pressed", UITheme.box(Color("e07020"), 26, Color("b85c1f"), 0, 1))
	_chip.add_theme_color_override("font_color", Color.WHITE)
	_chip.add_theme_color_override("font_hover_color", Color.WHITE)
	_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chip.position = Vector2(-230, 124)
	_chip.custom_minimum_size = Vector2(460, 56)
	_chip.visible = false
	_chip.pressed.connect(_on_chip)
	hud.add_child(_chip)
	_leave_btn = UITheme.make_button("Sair da partida", leave, 220)
	_leave_btn.custom_minimum_size = Vector2(220, 50)
	_leave_btn.visible = false
	hud.add_child(_leave_btn)
	UITheme.pin_top_right(_leave_btn, 240, 168, 220, 50)
	if hud.controls:
		hud.controls.blockers.append(_panel)
		hud.controls.blockers.append(_chip)
		hud.controls.blockers.append(_leave_btn)


func _exit_tree() -> void:
	for n in [_panel, _chip, _results, _leave_btn]:
		if is_instance_valid(n):
			n.queue_free()


static func is_shared(gid: String) -> bool:
	return KINDS.has(gid)


func in_session() -> bool:
	return my_gid != ""


# ---------------------------------------------------------------- entrar

## Tocou na estação (ou no botão Entrar): entra/cria a brincadeira no servidor.
func request(gid: String) -> bool:
	if not NetworkManager.is_online():
		return false
	if my_gid != "" and my_gid != gid:
		NetworkManager.mg_leave(my_gid)
		_reset(false)
	var st := NetworkManager.game_state(gid)
	var fresh := st.is_empty() or str(st.get("state", "")) in ["results", "none"]
	var wait: bool = fresh and (_friends_near(gid) or KINDS.get(gid, "") == "hide")
	my_gid = gid
	_local_started = false
	_local_done = false
	_pending_t = 4.0
	NetworkManager.mg_join(gid, wait)
	_show_panel(mgr.GAMES[gid].title, ["Entrando..."], [])
	return true


func _friends_near(gid: String) -> bool:
	var s := get_tree().get_first_node_in_group("online_session")
	if s == null:
		return false
	var pos: Vector3 = mgr.GAMES[gid].pos
	for r in s.remotes.values():
		if (r.root as Node3D).global_position.distance_to(pos) < NEAR_FRIENDS:
			return true
	return false


func leave() -> void:
	if my_gid != "":
		NetworkManager.mg_leave(my_gid)
	_reset(true)


func _reset(end_local: bool) -> void:
	if end_local and mgr.active and _local_started and not mgr.active.net.is_empty():
		mgr.active.end_game(0, "Você saiu da brincadeira", 0, 0)
	my_gid = ""
	_local_started = false
	_local_done = false
	_panel.visible = false
	_view = ""


# ---------------------------------------------------------------- servidor

func _on_error(gid: String, text: String) -> void:
	_dbg("erro %s %s" % [gid, text])
	GameManager.show_toast(text)
	if gid == my_gid:
		_reset(false)


func _on_states(list: Array) -> void:
	for g in list:
		if str(g.get("gid", "")) == my_gid:
			_on_my_state(g)


func _dbg(t: String) -> void:
	if OS.has_environment("RECREIO_NET_DEBUG"):
		print("[online_play %s] %s" % [NetworkManager.my_name, t])


func _on_my_state(g: Dictionary) -> void:
	_dbg("estado %s %s players=%s local=%s done=%s" % [g.get("gid"), g.get("state"), str(g.get("players")), _local_started, _local_done])
	var me := NetworkManager.my_id
	var players: Array = g.get("players", [])
	var state := str(g.get("state", ""))
	if state == "none" or (not me in players and state != "results"):
		if _local_started and mgr.active and not mgr.active.net.is_empty():
			mgr.active.end_game(0, "A brincadeira acabou", 2, 4)
		_reset(false)
		return
	_pending_t = 0.0
	var kind := str(g.get("kind", "round"))
	match state:
		"lobby":
			_show_lobby(g)
		"playing":
			if kind == "turn":
				if str(g.get("current", "")) == me and not _local_started:
					_start_local(g)
				elif not _local_started or _local_done:
					_show_queue(g)
			elif not _local_started:
				_start_local(g)
			elif _local_done and kind == "round":
				_show_waiting(g)


func _on_event(ev: Dictionary) -> void:
	_dbg("evento %s" % str(ev))
	var gid := str(ev.get("gid", ""))
	var kind := str(ev.get("kind", ""))
	if gid != my_gid:
		# alguém começou uma brincadeira perto: avisa (o botão Entrar aparece)
		if kind == "start" and mgr.is_recess() and player.minigame == null and _near_station(gid, JOIN_RADIUS):
			GameManager.show_toast("Começou %s aqui perto! Toque em Entrar." % mgr.GAMES.get(gid, {}).get("title", gid))
		return
	match kind:
		"need_players":
			GameManager.show_toast("Precisa de pelo menos %d jogadores. Chame a turma!" % int(ev.get("min", 2)))
		"results":
			if mgr.active and mgr.active.has_method("on_net_event"):
				mgr.active.on_net_event(ev)
			_show_results(gid, ev)
			if _local_started and mgr.active and not mgr.active.net.is_empty() and not _local_done:
				mgr.active.end_game(0, "O tempo da brincadeira acabou", 3, 6)
			_reset(false)
		"closed":
			if ev.has("text"):
				GameManager.show_toast(str(ev.text))
			_reset(true)
		"host", "joined", "left":
			if mgr.active and mgr.active.has_method("on_net_event"):
				mgr.active.on_net_event(ev)


func _start_local(g: Dictionary) -> void:
	_local_started = true
	_local_done = false
	_panel.visible = false
	var players: Array = g.get("players", [])
	var net := {"gid": str(g.gid), "kind": str(g.get("kind", "round")), "players": players, "host": str(g.get("host", "")),
		"teams": g.get("teams", {}), "opts": g.get("opts", {}), "me": NetworkManager.my_id, "index": players.find(NetworkManager.my_id)}
	if not mgr.start_local(str(g.gid), net):
		NetworkManager.mg_leave(str(g.gid))
		_reset(false)


## O jogo local acabou: manda o placar (e espera os outros na rodada).
func on_local_finished(result: Dictionary) -> void:
	_dbg("terminei %s my_gid=%s started=%s" % [result.get("id"), my_gid, _local_started])
	if my_gid == "" or str(result.get("id", "")) != my_gid or not _local_started:
		return
	_local_done = true
	var score: float = float(result.get("time", result.get("score", result.get("won", 0))))
	if not KINDS.get(my_gid, "") in ["team", "hide"]:
		NetworkManager.mg_score(my_gid, score, true)
	var g := NetworkManager.game_state(my_gid)
	if not g.is_empty() and str(g.get("state", "")) == "playing":
		if KINDS.get(my_gid, "") == "turn":
			_show_queue(g)
		elif KINDS.get(my_gid, "") == "round" and (g.get("players", []) as Array).size() > 1:
			_show_waiting(g)


# ---------------------------------------------------------------- telas

func _label(text: String, size := 22, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _show_panel(title: String, lines: Array, buttons: Array) -> void:
	for c in _panel_box.get_children():
		c.queue_free()
	var t := _label(title, 30, Color("ffd27a"))
	t.add_theme_font_override("font", UITheme.bold_font())
	_panel_box.add_child(t)
	for l in lines:
		_panel_box.add_child(_label(str(l)))
	if not buttons.is_empty():
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 10)
		for b in buttons:
			var btn := UITheme.make_button(str(b[0]), b[1], 220)
			btn.custom_minimum_size = Vector2(220, 54)
			h.add_child(btn)
		_panel_box.add_child(h)
	_panel.visible = true


func _names(ids: Array) -> String:
	var out: Array = []
	for id in ids:
		out.append(NetworkManager.name_of(str(id)))
	return ", ".join(out)


func _set_view(v: String, g: Dictionary) -> void:
	if v != _view or g != _view_g:
		_view_ms = Time.get_ticks_msec()
	_view = v
	_view_g = g


func _elapsed_s() -> int:
	return int((Time.get_ticks_msec() - _view_ms) / 1000)


func _show_lobby(g: Dictionary) -> void:
	_set_view("lobby", g)
	var gid := str(g.gid)
	var players: Array = g.get("players", [])
	var lines := ["Esperando a turma: começa em %d s" % maxi(int(g.get("lobbyLeft", 0)) - _elapsed_s(), 0)]
	if str(g.get("kind", "")) == "team":
		var a: Array = []
		var b: Array = []
		var teams: Dictionary = g.get("teams", {})
		for id in players:
			(a if str(teams.get(id, "a")) == "a" else b).append(id)
		lines.append("Time azul: " + _names(a))
		lines.append("Time laranja: " + (_names(b) if not b.is_empty() else "(bots)"))
	else:
		lines.append("Jogando: " + _names(players))
	if str(g.get("kind", "")) == "hide" and players.size() < 2:
		lines.append("Precisa de pelo menos 2 jogadores")
	var buttons: Array = []
	if str(g.get("host", "")) == NetworkManager.my_id:
		buttons.append(["Começar agora", func(): NetworkManager.mg_start(gid, g.get("opts", {}))])
	buttons.append(["Sair", leave])
	_show_panel(mgr.GAMES[gid].title, lines, buttons)


func _show_queue(g: Dictionary) -> void:
	_set_view("queue", g)
	var gid := str(g.gid)
	var me := NetworkManager.my_id
	var queue: Array = g.get("queue", [])
	var cur := str(g.get("current", ""))
	var lines: Array = []
	if cur != "":
		lines.append("Vez de %s · %d s" % [NetworkManager.name_of(cur), maxi(int(g.get("turnLeft", 0)) - _elapsed_s(), 0)])
	var pos := queue.find(me)
	if pos >= 0:
		lines.append("Você é o %dº da fila. Assista e torça!" % (pos + 1))
	elif _local_done:
		lines.append("Sua vez acabou. Placar: " + _score_line(g))
	_show_panel(mgr.GAMES[gid].title, lines, [["Sair da fila" if pos >= 0 else "Sair", leave]])


func _show_waiting(g: Dictionary) -> void:
	_set_view("waiting", g)
	_show_panel(mgr.GAMES[str(g.gid)].title, ["Esperando os outros terminarem...", _score_line(g)], [["Sair", leave]])


func _score_line(g: Dictionary) -> String:
	var sc: Dictionary = g.get("scores", {})
	var parts: Array = []
	for id in sc.keys():
		parts.append("%s %s" % [NetworkManager.name_of(str(id)), _fmt_score(str(g.gid), float(sc[id]))])
	return " · ".join(parts) if not parts.is_empty() else "ninguém terminou ainda"


func _fmt_score(gid: String, v: float) -> String:
	return "%.1f s" % v if gid in LOWER_BETTER else str(int(v))


func _show_results(gid: String, ev: Dictionary) -> void:
	_set_view("", {})
	var me := NetworkManager.my_id
	var lines: Array = []
	var ranking: Variant = ev.get("ranking")
	var won := false
	if ranking is Dictionary and (ranking as Dictionary).has("team"):
		var t: Dictionary = ranking.team
		var teams: Dictionary = ev.get("teams", {})
		var mine := str(teams.get(me, "a"))
		var mine_score := int(t.get(mine, 0))
		var other := int(t.get("b" if mine == "a" else "a", 0))
		lines.append("Seu time %d x %d" % [mine_score, other])
		won = mine_score > other
	elif ranking is Array:
		var arr: Array = ranking
		for i in mini(arr.size(), 6):
			var r: Dictionary = arr[i]
			lines.append("%dº  %s  ·  %s" % [i + 1, NetworkManager.name_of(str(r.id)), _fmt_score(gid, float(r.score))])
		won = arr.size() > 1 and str(arr[0].id) == me
		if not arr.is_empty():
			var top: Dictionary = arr[0]
			var old: Dictionary = room_best.get(gid, {})
			var better: bool = old.is_empty() or (float(top.score) < float(old.score) if gid in LOWER_BETTER else float(top.score) > float(old.score))
			if better:
				room_best[gid] = {"id": str(top.id), "name": NetworkManager.name_of(str(top.id)), "score": float(top.score)}
				if not old.is_empty():
					lines.append("NOVO RECORDE DA SALA!")
	if won:
		lines.append("Você foi o campeão! +35 XP")
		GameManager.add_rewards(35, 0)
		player.visual.play("celebrate")
	# jogar de novo: abre outra espera para quem quiser
	var again := func():
		_panel.visible = false
		if mgr.can_start() and mgr.is_recess():
			mgr.start(gid)
	_show_panel("Placar · " + str(mgr.GAMES.get(gid, {}).get("title", gid)), lines, [["Jogar de novo", again], ["Fechar", func(): _panel.visible = false]])
	var p := _panel
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(p) and my_gid == "":
			p.visible = false)


# ---------------------------------------------------------------- botão "Entrar"

func _near_station(gid: String, r: float) -> bool:
	return mgr.GAMES.has(gid) and player.global_position.distance_to(mgr.GAMES[gid].pos) < r


func _on_chip() -> void:
	if _chip_gid == "":
		return
	if _near_station(_chip_gid, 10.0):
		if mgr.can_start():
			request(_chip_gid)
	else:
		mgr.guide_to(_chip_gid)


func _process(delta: float) -> void:
	_leave_btn.visible = my_gid != "" and _local_started and not _local_done and KINDS.get(my_gid, "") == "team"
	if not NetworkManager.is_online():
		_chip.visible = false
		return
	if _pending_t > 0.0:
		_pending_t -= delta
		if _pending_t <= 0.0 and my_gid != "" and not _local_started:
			GameManager.show_toast("O servidor não respondeu. Tente de novo.")
			_reset(false)
	# saiu de perto da espera/fila: sai da brincadeira
	if my_gid != "" and not _local_started and not _near_station(my_gid, LEAVE_DIST):
		GameManager.show_toast("Você se afastou e saiu de %s." % mgr.GAMES[my_gid].title)
		leave()
	_redraw_t -= delta
	if _redraw_t <= 0.0 and _panel.visible and my_gid != "":
		_redraw_t = 0.5
		match _view:
			"lobby":
				_show_lobby(_view_g)
			"queue":
				_show_queue(_view_g)
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = 0.5
	_update_stations()
	_update_chip()


## Placas: "Jogar: X" ou "Entrar: X (3 jogando)".
func _update_stations() -> void:
	for gid in mgr.stations.keys():
		var st: MinigameStation = mgr.stations[gid]
		var g := NetworkManager.game_state(gid)
		var n := (g.get("players", []) as Array).size()
		if not g.is_empty() and str(g.get("state", "")) in ["lobby", "playing"] and n > 0:
			st.prompt = ("Entrar na fila: %s (%d)" if KINDS.get(gid, "") == "turn" else "Entrar: %s (%d jogando)") % [mgr.GAMES[gid].title, n]
		else:
			st.prompt = "Jogar: %s" % mgr.GAMES[gid].title
			var rb: Dictionary = room_best.get(gid, {})
			if not rb.is_empty():
				st.prompt += "  ·  recorde: %s %s" % [rb.name, _fmt_score(gid, float(rb.score))]


func _update_chip() -> void:
	_chip_gid = ""
	if my_gid == "" and player.minigame == null and mgr.is_recess():
		var best := INF
		for gid in NetworkManager.games.keys():
			var g: Dictionary = NetworkManager.games[gid]
			if not mgr.GAMES.has(gid) or not str(g.get("state", "")) in ["lobby", "playing"]:
				continue
			var players: Array = g.get("players", [])
			if players.is_empty() or players.size() >= int(g.get("max", 99)):
				continue
			var d := player.global_position.distance_to(mgr.GAMES[gid].pos)
			if d < JOIN_RADIUS and d < best:
				best = d
				_chip_gid = gid
	if _chip_gid == "":
		_chip.visible = false
		return
	var g2: Dictionary = NetworkManager.games[_chip_gid]
	var ids: Array = g2.get("players", [])
	var who := NetworkManager.name_of(str(ids[0])) + ("" if ids.size() == 1 else " e mais %d" % (ids.size() - 1))
	var verb := "Entrar na fila" if KINDS.get(_chip_gid, "") == "turn" else "Entrar"
	_chip.text = "%s: %s (%s)" % [verb, mgr.GAMES[_chip_gid].title, who]
	if not _near_station(_chip_gid, 10.0):
		_chip.text += " · Ir até lá"
	_chip.visible = true
