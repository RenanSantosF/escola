extends Node
## Teste ponta a ponta do online: conecta dois clientes Godot (o
## NetworkManager e um WebSocketPeer cru) a um servidor local.
## Uso: node server/src/server.js (PORT=8131) e depois
## godot --headless --path . res://tests/online_probe.tscn -- --url=ws://127.0.0.1:8131

var url := "ws://127.0.0.1:8131"
var got_welcome := false
var got_chat := ""
var got_notice := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			url = a.substr(6)
	Settings.set_value("server_url", url, false)
	NetworkManager.welcomed.connect(func(_m): got_welcome = true)
	NetworkManager.chat.connect(func(_id, _n, t): got_chat = t)
	NetworkManager.notice.connect(func(t): got_notice = t)
	NetworkManager.connect_to_server()
	var other := WebSocketPeer.new()
	other.connect_to_url(url)
	var ok_other := false
	for i in 300:
		await get_tree().process_frame
		other.poll()
		if other.get_ready_state() == WebSocketPeer.STATE_OPEN and not ok_other:
			ok_other = true
			other.send_text(JSON.stringify({"t": "hello", "age": 9}))
		if got_welcome and ok_other:
			break
	print("welcome=", got_welcome, " url=", NetworkManager.server_url())
	NetworkManager.send_state(Vector3(1, 0, 2), 0.5, "idle")
	NetworkManager.send_quick(0)
	NetworkManager.send_chat("oi tudo bem")  # menor de 13: deve vir aviso
	var saw_state := false
	for i in 120:
		await get_tree().process_frame
		other.poll()
		while other.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(other.get_packet().get_string_from_utf8())
			if m is Dictionary and m.get("t") == "states":
				saw_state = true
	print("chat=", got_chat, " notice=", got_notice, " other_saw_state=", saw_state)
	var ok := got_welcome and got_chat == "Oi!" and got_notice != "" and saw_state
	print("ONLINE_PROBE ", "OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)
