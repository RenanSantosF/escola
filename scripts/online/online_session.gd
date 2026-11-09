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


func setup(p: PlayerController, w: Node3D, ui_parent: Node, hud: HUD) -> void:
	player = p
	world = w
	chat_panel = ChatPanel.new()
	ui_parent.add_child(chat_panel)
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
				_remove_remote(id))
	nm.connect_to_server()


func _exit_tree() -> void:
	NetworkManager.disconnect_from_server()


func _on_welcome(m: Dictionary) -> void:
	chat_panel.setup_phrases(NetworkManager.quick_phrases, NetworkManager.free_chat)
	chat_panel.add_line("", "Você entrou na %s como %s." % [m.room, m.name], true)
	for p in m.get("players", []):
		_add_remote(p)


func _add_remote(p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	if id == "" or remotes.has(id) or id == NetworkManager.my_id:
		return
	var root := Node3D.new()
	root.name = "Online_" + id
	var vis := CharacterVisual.new()
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
	remotes[id] = {"root": root, "visual": vis, "label": label, "name": str(p.get("name", "")),
		"from": pos, "to": pos, "t": 1.0, "yaw": float(p.get("yaw", 0.0)), "anim": str(p.get("anim", "idle"))}


func _remove_remote(id: String) -> void:
	if not remotes.has(id):
		return
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
		r.anim = str(s.get("anim", "idle"))


func _on_chat(id: String, sender: String, text: String) -> void:
	var mine := id == NetworkManager.my_id
	chat_panel.add_line(id if not mine else "", ("Você" if mine else sender) + ": " + text, false)
	if remotes.has(id):
		remotes[id].label.text = text
		var r: Dictionary = remotes[id]
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(r.label):
				r.label.text = r.name)


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


static func _vec(a: Variant) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
