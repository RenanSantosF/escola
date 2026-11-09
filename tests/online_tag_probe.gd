extends Node
## Ponta a ponta do pique-pega online: o NetworkManager do jogo chama, um
## segundo cliente entra, começa, o segundo encosta e o servidor passa o
## pegador. Uso: servidor local na 8131 e
## godot --headless --path . res://tests/online_tag_probe.tscn -- --url=ws://127.0.0.1:8131

var url := "ws://127.0.0.1:8131"
var states: Array = []
var events: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			url = a.substr(6)
	Settings.set_value("server_url", url, false)
	NetworkManager.tag_state.connect(func(m): states.append(m))
	NetworkManager.tag_event.connect(func(m): events.append(m))
	NetworkManager.join("quick")
	var other := WebSocketPeer.new()
	other.connect_to_url(url)
	var other_id := ""
	var sent_hello := false
	for i in 400:
		await get_tree().process_frame
		other.poll()
		if other.get_ready_state() == WebSocketPeer.STATE_OPEN and not sent_hello:
			sent_hello = true
			other.send_text(JSON.stringify({"t": "hello", "age": 10, "mode": "quick"}))
		while other.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(other.get_packet().get_string_from_utf8())
			if m is Dictionary and m.get("t") == "welcome":
				other_id = str(m.id)
		if other_id != "" and NetworkManager.is_online():
			break
	NetworkManager.send_state(Vector3(0, 0, -10), 0.0, "idle")
	other.send_text(JSON.stringify({"t": "state", "pos": [8, 0, -10], "yaw": 0, "anim": "idle"}))
	NetworkManager.tag_invite()
	await _pump(other, 30)
	other.send_text(JSON.stringify({"t": "tag_join"}))
	await _pump(other, 30)
	NetworkManager.tag_start()
	await _pump(other, 30)
	var playing := states.any(func(s): return s.get("state") == "playing" and (s.get("players", []) as Array).size() == 2)
	# os dois se encostam várias vezes: alguém tem que ser pego
	for k in 4:
		other.send_text(JSON.stringify({"t": "state", "pos": [0.5, 0, -10], "yaw": 0, "anim": "run"}))
		await _pump(other, 100)
	var tagged := events.any(func(e): return e.get("kind") == "tagged")
	var invited := events.any(func(e): return e.get("kind") == "invite")
	print("invite=", invited, " playing=", playing, " tagged=", tagged)
	var ok := invited and playing and tagged
	print("TAG_PROBE ", "OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)


func _pump(ws: WebSocketPeer, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		ws.poll()
		while ws.get_available_packet_count() > 0:
			ws.get_packet()
