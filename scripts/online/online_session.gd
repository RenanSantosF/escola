class_name OnlineSession
extends Node
## Liga o mundo local ao NetworkManager: envia a posição do jogador (~10 Hz),
## cria/interpola os colegas online (CharacterVisual leve, sem física) e
## mostra o painel de chat seguro. Só existe quando o modo online está ativo.

const SEND_DT := 0.1
const INTERP_DELAY := 0.2  # mostra os colegas 200 ms no passado: movimento liso
const SNAP_DIST := 8.0  # pulo maior que isso é teleporte de verdade

var player: PlayerController
var world: Node3D
var chat_panel: ChatPanel
var remotes := {}  # id -> {root, visual, label, from, to, t, yaw}
var _send_t := 0.0
var npcs: NPCManager
var day: SchoolDay
var tag: OnlineTag
var hud_ref: HUD
var _badge: Label
var _offline_t := 0.0
var _lost_panel: PanelContainer
var _was_online := false
var _lost_btns: HBoxContainer


func setup(p: PlayerController, w: Node3D, ui_parent: Node, hud: HUD) -> void:
	add_to_group("online_session")
	player = p
	world = w
	hud_ref = hud
	chat_panel = ChatPanel.new()
	chat_panel.player = p
	ui_parent.add_child(chat_panel)
	tag = OnlineTag.new()
	tag.name = "OnlineTag"
	add_child(tag)
	tag.setup(self, p, hud, day, ui_parent)
	chat_panel.tag_pressed.connect(tag.invite)
	# reações: o que eu faço os outros veem
	p.emote_started.connect(func(e):
		if NetworkManager.is_online():
			NetworkManager.send_emote(e))
	NetworkManager.emote_received.connect(func(id, e):
		if remotes.has(id):
			(remotes[id].visual as CharacterVisual).play(e))
	if hud and hud.controls:
		hud.controls.blockers.append(chat_panel)
	var nm := NetworkManager
	nm.welcomed.connect(_on_welcome)
	nm.player_joined.connect(_add_remote)
	nm.player_left.connect(_remove_remote)
	nm.states.connect(_on_states)
	nm.chat.connect(_on_chat)
	nm.notice.connect(func(t): chat_panel.add_line("", t, true))
	nm.friend_notice.connect(func(t):
		GameManager.show_toast(t)
		AudioManager.play_ui("reward", -6.0))
	nm.friend_request.connect(func(from, nm2):
		_ask("%s quer ser seu amigo!" % nm2, "Aceitar", func():
			var r: Dictionary = await AccountManager.friend_accept(from)
			GameManager.show_toast("Agora vocês são amigos!" if r.get("ok", false) else "Não deu para aceitar agora.")))
	nm.friend_invite.connect(func(from, nm2, code):
		_ask("%s te chamou para a sala %s!" % [nm2, code], "Entrar", func(): switch_room(code)))
	nm.online_changed.connect(func(on):
		if not on:
			for id in remotes.keys():
				_remove_remote(id)
		_refresh_badge())
	nm.look_changed.connect(func(id, look, lv):
		if remotes.has(id):
			var r: Dictionary = remotes[id]
			(r.visual as CharacterVisual).set_appearance(CharacterAppearance.from_dict(look))
			r.label.text = "%s  ·  nv %d" % [r.name, lv]
			r.name_text = r.label.text)
	nm.desks_changed.connect(func(map):
		if npcs:
			npcs.apply_desks(map, NetworkManager.my_id))
	nm.count_changed.connect(func(n):
		_refresh_badge()
		if npcs:
			npcs.set_online_players(n))
	# selo "Online · Sala 1234 · 3 jogadores" no topo da tela
	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 20)
	_badge.add_theme_color_override("font_color", Color.WHITE)
	_badge.add_theme_stylebox_override("normal", UITheme.box(Color(UITheme.BLUE, 0.9), 14, Color.WHITE, 2, 0))
	_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_badge.position = Vector2(-150, 74)
	_badge.custom_minimum_size = Vector2(300, 0)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_parent.add_child(_badge)
	_badge.visible = false  # o código da sala aparece no chat; tela limpa
	_refresh_badge()


func _refresh_badge() -> void:
	if _badge == null:
		return
	_badge.visible = false
	if NetworkManager.is_online():
		_badge.text = "  Online · Sala %s · %d jogador%s  " % [NetworkManager.room_code, NetworkManager.players_in_room, "" if NetworkManager.players_in_room == 1 else "es"]
	else:
		_badge.text = "  Conectando...  "


func _exit_tree() -> void:
	if is_instance_valid(_badge):
		_badge.queue_free()
	if is_instance_valid(_lost_panel):
		_lost_panel.queue_free()
	if player and is_instance_valid(player):
		player.input_enabled = true
	if npcs:
		npcs.set_online_players(1)
		npcs.apply_desks({}, "")
	for id in remotes.keys():
		_release_seat(remotes[id])


func _on_welcome(m: Dictionary) -> void:
	chat_panel.setup_phrases(NetworkManager.quick_phrases, NetworkManager.free_chat)
	chat_panel.set_room(str(m.get("code", "")))
	chat_panel.add_line("", "Você entrou na sala %s como %s." % [m.get("code", ""), m.name], true)
	chat_panel.add_line("", "Código da sala para os amigos: %s" % m.get("code", ""), true)
	for p in m.get("players", []):
		_add_remote(p)
	_refresh_badge()
	if npcs:
		npcs.set_online_players(NetworkManager.players_in_room)


func _add_remote(p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	if id == "" or remotes.has(id) or id == NetworkManager.my_id:
		return
	var root := Node3D.new()
	root.name = "Online_" + id
	var vis := CharacterVisual.new()
	vis.detail = 0.5 if Settings.quality() == Settings.Quality.LOW else 0.75
	vis.manual_update = true  # LOD: a sessão decide quantas vezes anima
	var look: Variant = p.get("look", {})
	vis.appearance = CharacterAppearance.from_dict(look) if look is Dictionary and not look.is_empty() else CharacterAppearance.random(id.hash(), true)
	root.add_child(vis)
	var label := Label3D.new()
	label.text = "%s  ·  nv %d" % [p.get("name", "Colega"), int(p.get("level", 1))]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = UITheme.bold_font()
	label.font_size = 36
	label.pixel_size = 0.005
	label.outline_size = 12
	label.modulate = Color("2f6fd0")
	label.position = Vector3(0, 2.05, 0)
	root.add_child(label)
	world.add_child(root)
	var pos := _vec(p.get("pos", [0, 0, 70]))
	root.global_position = pos
	remotes[id] = {"root": root, "visual": vis, "label": label, "name": str(p.get("name", "")), "name_text": label.text,
		"from": pos, "to": pos, "t": 1.0, "yaw": float(p.get("yaw", 0.0)), "anim": str(p.get("anim", "idle")), "seat": null,
		"buf": [[_now(), pos]]}
	if remotes[id].anim == "sit":
		_on_remote_anim(remotes[id], "idle", "sit")


func _remove_remote(id: String) -> void:
	if not remotes.has(id):
		return
	_release_seat(remotes[id])
	remotes[id].root.queue_free()
	remotes.erase(id)


func _on_states(list: Array) -> void:
	for s in list:
		var r: Variant = remotes.get(str(s.get("id", "")))
		if r == null:
			continue
		var pos := _vec(s.get("pos", [0, 0, 0]))
		var buf: Array = r.buf
		var now := _now()
		# pulou longe (porta de sala, reconexão): vai direto, sem deslizar pelo mapa
		if buf.is_empty() or (buf[buf.size() - 1][1] as Vector3).distance_to(pos) > SNAP_DIST:
			buf.clear()
			r.root.global_position = pos
		buf.append([now, pos])
		while buf.size() > 12:
			buf.pop_front()
		r.to = pos
		r.yaw = float(s.get("yaw", 0.0))
		var anim := str(s.get("anim", "idle"))
		var rope := RopeShow.parse(anim)
		if not rope.is_empty():
			_rope_sync(rope)
			anim = "rope"
		if anim != r.anim:
			_on_remote_anim(r, r.anim, anim)
		r.anim = anim


var _rope_show: RopeShow = null


## Um colega está pulando corda: a corda aparece aqui também (quem está de fora vê).
func _rope_sync(v: Array) -> void:
	# eu mesmo pulando: a minha corda já está na tela
	if player and player.minigame != null and player.minigame.id == "corda":
		return
	if _rope_show == null or not is_instance_valid(_rope_show):
		_rope_show = RopeShow.new()
		_rope_show.angle = float(v[0])
		world.add_child(_rope_show)
	_rope_show.sync(float(v[0]), float(v[1]), int(v[2]))


## Colega online sentou/levantou: mostra a pose e ocupa o assento (ninguém senta no colo dele).
func _on_remote_anim(r: Dictionary, before: String, now: String) -> void:
	var vis: CharacterVisual = r.visual
	if now == "sit":
		vis.play("sit_down")
		var best: Seat = null
		var bd := 0.7
		for st in (world as SchoolWorld).seats if world is SchoolWorld else []:
			var d: float = (st as Seat).global_position.distance_to(r.to)
			if d < bd:
				bd = d
				best = st
		if best and best.occupant == null:
			best.occupy(r.root)
			r["seat"] = best
	elif now in ["slide", "coaster"]:
		vis.play("sit_down")  # descendo o tobogã / na montanha-russa
		if now == "coaster" and not r.has("cart"):
			# o carrinho anda junto com o colega (quem está de fora vê)
			var cart := RideTrack.make_cart()
			cart.top_level = true
			r.root.add_child(cart)
			cart.global_position = r.root.global_position - Vector3(0, 0.12, 0)
			r["cart"] = cart
	elif before == "sit":
		vis.play("stand_up")
		_release_seat(r)
	elif before in ["slide", "coaster"]:
		vis.stop_action()
	if before == "coaster" and now != "coaster" and r.has("cart"):
		(r.cart as Node3D).queue_free()
		r.erase("cart")


func _release_seat(r: Dictionary) -> void:
	var st: Seat = r.get("seat")
	if st and is_instance_valid(st) and st.occupant == r.root:
		st.release()
	r["seat"] = null


func _on_chat(id: String, sender: String, text: String) -> void:
	var mine := id == NetworkManager.my_id
	chat_panel.add_line(id if not mine else "", ("Você" if mine else sender) + ": " + text, false, NetworkManager.last_channel)
	# balãozinho em cima da cabeça de quem falou (eu também vejo o meu)
	var who: Node3D = null
	if mine and player:
		who = player
	elif remotes.has(id):
		who = remotes[id].root
	if who:
		var bubble := who.get_node_or_null("ChatBubble") as ChatBubble
		if bubble == null:
			bubble = ChatBubble.new()
			bubble.name = "ChatBubble"
			who.add_child(bubble)
			bubble.position = Vector3(0, 1.95 if who == player else 2.3, 0)  # colega: acima do nome
		bubble.show_text(text)


## Tempo local em segundos (para o buffer de interpolação).
static func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


## Posição do colega "um pouquinho no passado" (INTERP_DELAY): sempre há duas
## amostras para interpolar, então ele anda liso mesmo com a internet oscilando.
## Se as amostras atrasarem, continua andando na mesma direção por até 0,35 s.
static func _sample(buf: Array, t: float) -> Vector3:
	var n := buf.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1 or t <= float(buf[0][0]):
		return buf[0][1]
	for i in range(n - 1, 0, -1):
		var a: Array = buf[i - 1]
		var b: Array = buf[i]
		if t >= float(a[0]) and t <= float(b[0]):
			var span := maxf(float(b[0]) - float(a[0]), 0.001)
			return (a[1] as Vector3).lerp(b[1], (t - float(a[0])) / span)
	# passou da última amostra: extrapola um pouco
	var last: Array = buf[n - 1]
	var prev: Array = buf[n - 2]
	var dt := maxf(float(last[0]) - float(prev[0]), 0.001)
	var vel: Vector3 = ((last[1] as Vector3) - (prev[1] as Vector3)) / dt
	if vel.length() > 30.0:  # montanha-russa chega a 26 m/s
		vel = vel.normalized() * 30.0
	var ahead := minf(t - float(last[0]), 0.35)
	return (last[1] as Vector3) + vel * ahead


var _lod_t := 0.0


## Carrinho do colega: segue a posição e aponta para onde ele está indo.
func _move_cart(r: Dictionary, prev: Vector3, delta: float) -> void:
	var cart: Node3D = r.cart
	var pos: Vector3 = (r.root as Node3D).global_position
	cart.global_position = pos - Vector3(0, 0.12, 0)
	var dir := pos - prev
	if dir.length() > 0.02:
		dir = dir.normalized()
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
		var want := Basis.looking_at(dir, up)
		cart.global_basis = cart.global_basis.orthonormalized().slerp(want, 1.0 - exp(-12.0 * delta))
	cart.visible = (r.visual as Node3D).visible


## Colegas longe custam menos: sem sombra, animação mais espaçada, nome
## escondido e, além do alcance (ou dentro de sala fechada), nem são desenhados.
func _lod(r: Dictionary, cp: Vector3, fwd: Vector3, refresh: bool, delta: float) -> void:
	var root: Node3D = r.root
	var vis: CharacterVisual = r.visual
	var to := root.global_position - cp
	var d := to.length()
	if refresh:
		var far := 90.0 if Settings.quality() != Settings.Quality.LOW else 60.0
		var hidden := d > far or (world is SchoolWorld and (world as SchoolWorld).interior_hidden_at(root.global_position))
		vis.visible = not hidden
		vis.set_shadow(d < 20.0)
		(r.label as Label3D).visible = not hidden and d < 30.0
	if not vis.visible:
		return
	var behind := to.dot(fwd) < -1.0 and d > 6.0
	var interval := 0.0
	if d > 40.0 or behind:
		interval = 0.2
	elif d > 22.0:
		interval = 0.08
	elif d > 12.0:
		interval = 0.033
	vis.animator.update_interval = interval
	vis.animator.update(delta)


func _process(delta: float) -> void:
	var render_t := _now() - INTERP_DELAY
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	var fwd := -cam.global_basis.z if cam else Vector3.FORWARD
	_lod_t -= delta
	var refresh := _lod_t <= 0.0
	if refresh:
		_lod_t = 0.3
	for r in remotes.values():
		var root: Node3D = r.root
		var prev := root.global_position
		var target := _sample(r.buf, render_t)
		# suaviza a volta da extrapolação (sem tranco)
		root.global_position = prev.lerp(target, 1.0 - exp(-20.0 * delta)) if prev.distance_to(target) < SNAP_DIST else target
		var vis: CharacterVisual = r.visual
		vis.rotation.y = lerp_angle(vis.rotation.y, r.yaw, 1.0 - exp(-12.0 * delta))
		var sp := Vector2(root.global_position.x - prev.x, root.global_position.z - prev.z).length() / maxf(delta, 0.001)
		vis.animator.speed = lerpf(vis.animator.speed, sp, 1.0 - exp(-8.0 * delta))
		vis.animator.ride_mode = 2 if r.anim == "bike" else (1 if r.anim == "ride" else 0)
		if r.has("cart"):
			_move_cart(r, prev, delta)
		_lod(r, cp, fwd, refresh, delta)
	_watch_connection(delta)
	if _rope_show and is_instance_valid(_rope_show) and (_rope_show.is_stale() or (player and player.minigame != null and player.minigame.id == "corda")):
		_rope_show.queue_free()
		_rope_show = null
	# brincando: chat e pique-pega somem (não faz sentido no meio do futebol)
	if chat_panel and player:
		var busy := player.minigame != null
		if chat_panel.visible == busy:
			chat_panel.visible = not busy
	if not NetworkManager.is_online() or player == null:
		return
	_send_t += delta
	if _send_t >= SEND_DT:
		_send_t = minf(_send_t - SEND_DT, SEND_DT)
		var anim := "idle"
		var mg = player.minigame
		if mg != null and mg.id == "corda" and mg.running:
			anim = RopeShow.encode(float(mg.get("_angle")), float(mg.get("_speed")), int(mg.get("jumps")))
		elif player.has_meta("ride"):
			anim = str(player.get_meta("ride"))  # "slide" ou "coaster"
		elif player.riding:
			anim = "bike" if player.vehicle == "bike" else "ride"
		elif player.mode == PlayerController.Mode.SITTING:
			anim = "sit"
		NetworkManager.send_state(player.global_position, player.yaw, anim)


## O jogo é só online: caiu a internet, avisa; demorou, oferece sair.
func _watch_connection(delta: float) -> void:
	var on := NetworkManager.is_online()
	if on:
		if _offline_t > 3.0:
			GameManager.show_toast("Conectado de novo!")
		_offline_t = 0.0
		_was_online = true
		if _lost_panel and _lost_panel.visible:
			_lost_panel.visible = false
			player.input_enabled = true
		return
	if not _was_online:
		return
	_offline_t += delta
	# quedinha (lag) não mostra nada; caiu de verdade: aviso e não anda
	if _offline_t > 2.5 and (_lost_panel == null or not _lost_panel.visible):
		_show_lost()
	if _lost_btns:
		_lost_btns.visible = _offline_t > 20.0


## Aviso com dois botões (pedido de amizade, convite). Some sozinho em 20 s.
var _ask_panel: PanelContainer


func _ask(text: String, yes: String, on_yes: Callable) -> void:
	if _ask_panel and is_instance_valid(_ask_panel):
		_ask_panel.queue_free()
	var p := PanelContainer.new()
	_ask_panel = p
	var sb := UITheme.box(Color(1, 1, 1, 0.97), 22, Color("22c55e"), 4, 6)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -330
	p.offset_right = 330
	p.offset_top = 120
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var l := UITheme.title_label(text, 28, UITheme.DARK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var ok := UITheme.make_button(yes, func():
		p.queue_free()
		on_yes.call(), 220)
	ok.add_theme_stylebox_override("normal", UITheme.box(Color("22c55e"), 18, Color("15803d"), 0, 6))
	ok.add_theme_color_override("font_color", Color.WHITE)
	h.add_child(ok)
	h.add_child(UITheme.make_button("Agora não", func(): p.queue_free(), 200))
	chat_panel.get_parent().add_child(p)
	AudioManager.play_ui("ui_confirm", -4.0)
	get_tree().create_timer(20.0).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


var _switch_from := ""


## Vai para a sala de um amigo sem sair do jogo (a escola continua, só troca a turma).
func switch_room(code: String) -> void:
	if code == "" or code == NetworkManager.room_code:
		GameManager.show_toast("Vocês já estão na mesma sala!")
		return
	if player.minigame != null:
		player.minigame.end_game(0, "Mudou de sala", 0, 0)
	_switch_from = NetworkManager.room_code
	for id in remotes.keys().duplicate():
		_remove_remote(id)
	_was_online = false  # troca de sala não é "caiu a internet"
	NetworkManager.leave()
	NetworkManager.join("code", code)
	GameManager.show_toast("Indo para a sala %s..." % code)
	if not NetworkManager.join_error.is_connected(_on_switch_error):
		NetworkManager.join_error.connect(_on_switch_error, CONNECT_ONE_SHOT)


func _on_switch_error(text: String) -> void:
	GameManager.show_toast(text)
	if _switch_from != "":
		NetworkManager.join("code", _switch_from)  # volta para onde estava


func _show_lost() -> void:
	if _lost_panel == null:
		_lost_panel = PanelContainer.new()
		_lost_panel.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.CREAM, 0.98), 26, UITheme.RED, 4, 6))
		_lost_panel.set_anchors_preset(Control.PRESET_CENTER)
		_lost_panel.position = Vector2(-330, -150)
		_lost_panel.custom_minimum_size = Vector2(660, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		_lost_panel.add_child(v)
		v.add_child(UITheme.title_label("Reconectando...", 44, UITheme.BLUE))
		var l := Label.new()
		l.text = "A conexão caiu. Você volta para o mesmo lugar e a mesma sala assim que a internet voltar."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 24)
		v.add_child(l)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		h.visible = false
		_lost_btns = h
		v.add_child(h)
		h.add_child(UITheme.make_button("Tentar de novo", func():
			_offline_t = 0.0
			_lost_panel.visible = false
			player.input_enabled = true
			NetworkManager.connect_to_server(), 260))
		h.add_child(UITheme.make_button("Voltar ao menu", func():
			_lost_panel.visible = false
			if hud_ref and hud_ref.main_menu_cb.is_valid():
				hud_ref.main_menu_cb.call(), 260))
		chat_panel.get_parent().add_child(_lost_panel)
	_lost_panel.visible = true
	player.input_enabled = false
	player.velocity = Vector3.ZERO


static func _vec(a: Variant) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
