extends Node
## Cliente online (WebSocket) do Recreio. DESLIGADO por padrão: só conecta
## quando o jogador ativa o modo online nas configurações e existe um
## SERVER_URL. O token da conta fica no save ("online") — a criança não
## digita e-mail, senha ou nome real. Protocolo em server/src/server.js.

signal online_changed(on: bool)
signal welcomed(info: Dictionary)
signal player_joined(p: Dictionary)
signal player_left(id: String)
signal states(list: Array)
signal chat(id: String, sender: String, text: String)
signal notice(text: String)

## URL do servidor no Railway (ex.: wss://recreio-production.up.railway.app).
## Vazio = modo online indisponível nesta build.
const SERVER_URL := ""

var _ws: WebSocketPeer
var _was_open := false
var my_id := ""
var my_name := ""
var room := ""
var free_chat := false
var quick_phrases: Array = []
var _retry_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Endereço efetivo: o das configurações (colado por um adulto) ou o fixo.
## Aceita "https://x.up.railway.app" e converte para wss://.
func server_url() -> String:
	var u := str(Settings.get_value("server_url")).strip_edges()
	if u == "":
		u = SERVER_URL
	if u == "":
		return ""
	if u.begins_with("https://"):
		u = "wss://" + u.substr(8)
	elif u.begins_with("http://"):
		u = "ws://" + u.substr(7)
	elif not (u.begins_with("wss://") or u.begins_with("ws://")):
		u = "wss://" + u
	return u.trim_suffix("/")


func available() -> bool:
	return server_url() != ""


func is_online() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and my_id != ""


func connect_to_server(url := "") -> void:
	if url == "":
		url = server_url()
	if url == "":
		return
	disconnect_from_server()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	if _ws.connect_to_url(url) != OK:
		_ws = null


func disconnect_from_server() -> void:
	if _ws:
		_ws.close()
	_ws = null
	if my_id != "":
		my_id = ""
		online_changed.emit(false)
	_was_open = false


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_send_hello()
		while _ws.get_available_packet_count() > 0:
			var txt := _ws.get_packet().get_string_from_utf8()
			var m: Variant = JSON.parse_string(txt)
			if m is Dictionary:
				_handle(m)
	elif st == WebSocketPeer.STATE_CLOSED:
		var had := my_id != ""
		_was_open = false
		my_id = ""
		if had:
			online_changed.emit(false)
			notice.emit("Conexão perdida. Tentando de novo...")
		_retry_t += delta
		if _retry_t > 5.0:
			_retry_t = 0.0
			connect_to_server()


func _send_hello() -> void:
	var sec: Dictionary = SaveManager.section("online")
	var p: Dictionary = SaveManager.section("player")
	send({"t": "hello", "token": sec.get("token", ""), "age": Learning.age(),
		"level": int(p.get("level", 1)), "look": p.get("appearance", {}), "room": sec.get("room", "")})


func _handle(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"welcome":
			my_id = str(m.id)
			my_name = str(m.name)
			room = str(m.room)
			free_chat = bool(m.get("freeChat", false))
			quick_phrases = m.get("quick", [])
			var sec: Dictionary = SaveManager.section("online")
			sec["token"] = str(m.token)
			sec["room"] = room
			online_changed.emit(true)
			welcomed.emit(m)
		"join":
			player_joined.emit(m.player)
		"leave":
			player_left.emit(str(m.id))
		"states":
			states.emit(m.get("list", []))
		"chat":
			chat.emit(str(m.id), str(m.name), str(m.text))
		"notice":
			notice.emit(str(m.text))


func send(obj: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(obj))


func send_state(pos: Vector3, yaw: float, anim: String) -> void:
	send({"t": "state", "pos": [pos.x, pos.y, pos.z], "yaw": yaw, "anim": anim})


func send_quick(i: int) -> void:
	send({"t": "quick", "i": i})


func send_chat(text: String) -> void:
	# filtro local antes de enviar (o servidor filtra de novo)
	var r := ChatFilter.check(text)
	if not r.ok:
		notice.emit(r.reason)
		return
	send({"t": "chat", "text": r.text})


func report(target: String, reason: String) -> void:
	send({"t": "report", "target": target, "reason": reason})


func block(target: String) -> void:
	send({"t": "block", "target": target})
