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
signal join_error(text: String)
signal count_changed(n: int)
signal look_changed(id: String, look: Dictionary, level: int)

## Servidor oficial no Railway.
const SERVER_URL := "wss://escola-production-061f.up.railway.app"

var _ws: WebSocketPeer
var _was_open := false
var my_id := ""
var my_name := ""
var room := ""
var free_chat := false
var quick_phrases: Array = []
var room_code := ""
var room_private := false
var players_in_room := 1
var _retry_t := 0.0
var _mode := "quick"
var _code := ""
var _want_online := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Endereço efetivo: o fixo do jogo (ou um de teste passado pela linha de comando).
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


## Entra no online: mode = "quick" (sala aberta), "create" (sala com
## amigos) ou "code" (entrar com o código de 4 números).
func join(mode: String, code := "") -> void:
	_mode = mode
	_code = code
	_want_online = true
	_retry_t = 0.0
	connect_to_server()


func leave() -> void:
	_want_online = false
	disconnect_from_server()
	room_code = ""


func https_base() -> String:
	return server_url().replace("wss://", "https://").replace("ws://", "http://")


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
		if _retry_t > 5.0 and _want_online:
			_retry_t = 0.0
			# volta para a mesma sala depois de cair
			if room_code != "":
				_mode = "code"
				_code = room_code
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
			room_code = str(m.get("code", ""))
			room_private = bool(m.get("private", false))
			players_in_room = 1 + (m.get("players", []) as Array).size()
			quick_phrases = m.get("quick", [])
			var sec: Dictionary = SaveManager.section("online")
			sec["token"] = str(m.token)
			sec["room"] = room
			online_changed.emit(true)
			welcomed.emit(m)
		"join_error":
			# reconexão numa sala que fechou: cai numa sala aberta
			if _mode == "code" and room_code != "" and _code == room_code:
				room_code = ""
				_mode = "quick"
				_send_hello()
				return
			join_error.emit(str(m.get("text", "Não deu para entrar.")))
		"look":
			look_changed.emit(str(m.id), m.get("look", {}), int(m.get("level", 1)))
		"count":
			players_in_room = int(m.get("n", 1))
			count_changed.emit(players_in_room)
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


func send_look() -> void:
	var p: Dictionary = SaveManager.section("player")
	send({"t": "look", "look": p.get("appearance", {}), "level": int(p.get("level", 1))})


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
