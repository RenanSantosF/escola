class_name OnlineSession
extends Node
## Liga o mundo local ao NetworkManager: envia a posição do jogador (~10 Hz),
## cria/interpola os colegas online (CharacterVisual leve, sem física) e
## mostra o painel de chat seguro. Só existe quando o modo online está ativo.

const SEND_DT := 0.1

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
		"from": pos, "to": pos, "t": 1.0, "yaw": float(p.get("yaw", 0.0)), "anim": str(p.get("anim", "idle")), "seat": null}
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
		r.from = r.root.global_position
		r.to = _vec(s.get("pos", [0, 0, 0]))
		r.t = 0.0
		r.yaw = float(s.get("yaw", 0.0))
		var anim := str(s.get("anim", "idle"))
		if anim != r.anim:
			_on_remote_anim(r, r.anim, anim)
		r.anim = anim


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
	elif before == "sit":
		vis.play("stand_up")
		_release_seat(r)


func _release_seat(r: Dictionary) -> void:
	var st: Seat = r.get("seat")
	if st and is_instance_valid(st) and st.occupant == r.root:
		st.release()
	r["seat"] = null


func _on_chat(id: String, sender: String, text: String) -> void:
	var mine := id == NetworkManager.my_id
	chat_panel.add_line(id if not mine else "", ("Você" if mine else sender) + ": " + text, false, NetworkManager.last_channel)
	if remotes.has(id):
		remotes[id].label.text = text
		var r: Dictionary = remotes[id]
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(r.label):
				r.label.text = r.name_text)


func _process(delta: float) -> void:
	for r in remotes.values():
		r.t = minf(r.t + delta / SEND_DT, 1.6)
		var root: Node3D = r.root
		var prev := root.global_position
		root.global_position = r.from.lerp(r.to, minf(r.t, 1.0))
		var vis: CharacterVisual = r.visual
		vis.rotation.y = lerp_angle(vis.rotation.y, r.yaw, 1.0 - exp(-12.0 * delta))
		var sp := Vector2(root.global_position.x - prev.x, root.global_position.z - prev.z).length() / maxf(delta, 0.001)
		vis.animator.speed = lerpf(vis.animator.speed, sp, 1.0 - exp(-8.0 * delta))
		vis.animator.ride_mode = 2 if r.anim == "bike" else (1 if r.anim == "ride" else 0)
	_watch_connection(delta)
	# brincando: chat e pique-pega somem (não faz sentido no meio do futebol)
	if chat_panel and player:
		var busy := player.minigame != null
		if chat_panel.visible == busy:
			chat_panel.visible = not busy
	if not NetworkManager.is_online() or player == null:
		return
	_send_t += delta
	if _send_t >= SEND_DT:
		_send_t = 0.0
		var anim := "idle"
		if player.riding:
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
