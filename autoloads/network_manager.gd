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
signal emote_received(id: String, emote: String)
signal tag_state(st: Dictionary)
signal tag_event(ev: Dictionary)
## Relógio da escola (o servidor manda a fase do dia para a sala toda).
signal clock_changed(st: Dictionary)
## Carteiras reservadas na sala de aula: {id: índice}.
signal desks_changed(map: Dictionary)
## Brincadeiras compartilhadas: estados, eventos e repasse do anfitrião.
signal mg_states(list: Array)
signal mg_event(ev: Dictionary)
signal mg_relay(gid: String, from: String, d: Variant)
signal mg_error(gid: String, text: String)
## Mensagem direta de outro jogador (missão em grupo).
signal direct(from: String, from_name: String, kind: String, data: Variant)

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
## Canal da última mensagem recebida ("all" ou "near").
var last_channel := "all"
var room_private := false
var players_in_room := 1
var _retry_t := 0.0
var _mode := "quick"
var _code := ""
var _want_online := false
## Último relógio recebido e diferença de horário servidor - aparelho (ms).
var clock: Dictionary = {}
var clock_offset_ms := 0.0
var desks: Dictionary = {}
var my_desk := -1
var games := {}  # gid -> estado
var names := {}  # id -> nome dos jogadores da sala
## A última entrada foi uma RECONEXÃO (caiu/minimizou e voltou), não a primeira.
var reconnected := false
var _ever_welcomed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Voltou do app minimizado: a conexão costuma ter morrido; reconecta já.
var _paused_at := 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_paused_at = Time.get_unix_time_from_system()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _want_online:
		var away := Time.get_unix_time_from_system() - _paused_at
		if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or away > 8.0:
			# volta para a MESMA sala (o servidor guarda a sala e a carteira)
			if room_code != "":
				_mode = "code"
				_code = room_code
			my_id = ""
			connect_to_server()


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
	_ever_welcomed = false
	reconnected = false
	disconnect_from_server()
	room_code = ""
	clock = {}
	desks = {}
	my_desk = -1
	games.clear()


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
		if _retry_t > 2.0 and _want_online:
			_retry_t = 0.0
			connect_to_server()


func _send_hello() -> void:
	var sec: Dictionary = SaveManager.section("online")
	var p: Dictionary = SaveManager.section("player")
	var hello := {"t": "hello", "token": sec.get("token", ""), "age": Learning.age(),
		"level": int(p.get("level", 1)), "look": p.get("appearance", {}), "mode": _mode}
	if _mode == "code":
		hello["code"] = _code
	send(hello)


func _handle(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"welcome":
			reconnected = _ever_welcomed
			_ever_welcomed = true
			my_id = str(m.id)
			my_name = str(m.name)
			room = str(m.room)
			free_chat = bool(m.get("freeChat", false))
			room_code = str(m.get("code", ""))
			room_private = bool(m.get("private", false))
			players_in_room = 1 + (m.get("players", []) as Array).size()
			names = {my_id: my_name}
			for pl in m.get("players", []):
				names[str(pl.get("id", ""))] = str(pl.get("name", ""))
			quick_phrases = m.get("quick", [])
			var sec: Dictionary = SaveManager.section("online")
			sec["token"] = str(m.token)
			sec["room"] = room
			my_desk = int(m.get("desk", -1))
			desks = m.get("desks", {}) if m.get("desks") is Dictionary else {}
			games.clear()
			for g in m.get("games", []):
				games[str(g.gid)] = g
			# reconexão: volta para a mesma sala pelo código
			_mode = "code"
			_code = room_code
			if m.get("clock") is Dictionary:
				clock = m.clock
				clock_offset_ms = float(m.clock.get("now", 0.0)) - Time.get_unix_time_from_system() * 1000.0
			online_changed.emit(true)
			welcomed.emit(m)
			desks_changed.emit(desks)
			if not clock.is_empty():
				clock_changed.emit(clock)
		"join_error":
			# reconexão numa sala que fechou: cai numa sala aberta
			if _mode == "code" and room_code != "" and _code == room_code:
				# a sala de antes fechou: entra numa aberta
				room_code = ""
				_mode = "quick"
				_send_hello()
				return
			join_error.emit(str(m.get("text", "Não deu para entrar.")))
		"emote":
			emote_received.emit(str(m.id), str(m.name))
		"clock":
			_set_clock(m)
		"desks":
			desks = m.get("map", {}) if m.get("map") is Dictionary else {}
			if desks.has(my_id):
				my_desk = int(desks[my_id])
			desks_changed.emit(desks)
		"mg":
			var list: Array = m.get("list", [])
			for g in list:
				if str(g.get("state", "")) == "none":
					games.erase(str(g.gid))
				else:
					games[str(g.gid)] = g
			mg_states.emit(list)
		"mg_event":
			mg_event.emit(m)
		"mg_relay":
			mg_relay.emit(str(m.get("gid", "")), str(m.get("from", "")), m.get("d"))
		"mg_error":
			mg_error.emit(str(m.get("gid", "")), str(m.get("text", "")))
		"direct":
			direct.emit(str(m.get("from", "")), str(m.get("fromName", "")), str(m.get("kind", "")), m.get("data"))
		"tag":
			tag_state.emit(m)
		"tag_event":
			tag_event.emit(m)
		"look":
			look_changed.emit(str(m.id), m.get("look", {}), int(m.get("level", 1)))
		"count":
			players_in_room = int(m.get("n", 1))
			count_changed.emit(players_in_room)
		"join":
			names[str(m.player.get("id", ""))] = str(m.player.get("name", ""))
			player_joined.emit(m.player)
		"leave":
			names.erase(str(m.id))
			player_left.emit(str(m.id))
		"states":
			states.emit(m.get("list", []))
		"chat":
			last_channel = str(m.get("ch", "all"))
			chat.emit(str(m.id), str(m.name), str(m.text))
		"notice":
			notice.emit(str(m.text))


func _set_clock(st: Dictionary) -> void:
	clock = st
	clock_offset_ms = float(st.get("now", 0.0)) - Time.get_unix_time_from_system() * 1000.0
	clock_changed.emit(st)


## Horário do servidor agora (ms).
func server_now_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + clock_offset_ms


## Segundos que faltam para a fase atual acabar (pelo relógio do servidor).
func phase_left() -> float:
	if clock.is_empty():
		return 0.0
	return maxf((float(clock.get("endsAt", 0.0)) - server_now_ms()) / 1000.0, 0.0)


func phase_elapsed() -> float:
	if clock.is_empty():
		return 0.0
	return maxf((server_now_ms() - float(clock.get("startedAt", 0.0))) / 1000.0, 0.0)


func name_of(id: String) -> String:
	return "Você" if id == my_id else str(names.get(id, "Colega"))


func game_state(gid: String) -> Dictionary:
	return games.get(gid, {})


func mg_join(gid: String, wait := false, opts := {}) -> void:
	var m := {"t": "mg_join", "gid": gid, "wait": wait}
	if not opts.is_empty():
		m["opts"] = opts
	send(m)


func mg_leave(gid: String) -> void:
	send({"t": "mg_leave", "gid": gid})


func mg_start(gid: String, opts := {}) -> void:
	send({"t": "mg_start", "gid": gid, "opts": opts})


func mg_opts(gid: String, opts: Dictionary) -> void:
	send({"t": "mg_opts", "gid": gid, "opts": opts})


func mg_score(gid: String, score: float, final: bool) -> void:
	send({"t": "mg_score", "gid": gid, "score": score, "final": final})


func mg_team_result(gid: String, a: int, b: int) -> void:
	send({"t": "mg_team_result", "gid": gid, "a": a, "b": b})


func mg_send_relay(gid: String, d: Variant) -> void:
	send({"t": "mg_relay", "gid": gid, "d": d})


func send_direct(to: String, kind: String, data: Variant) -> void:
	send({"t": "direct", "to": to, "kind": kind, "data": data})


func send(obj: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(obj))


func send_state(pos: Vector3, yaw: float, anim: String) -> void:
	send({"t": "state", "pos": [pos.x, pos.y, pos.z], "yaw": yaw, "anim": anim})


func send_look() -> void:
	var p: Dictionary = SaveManager.section("player")
	send({"t": "look", "look": p.get("appearance", {}), "level": int(p.get("level", 1))})


func send_quick(i: int, ch := "all") -> void:
	send({"t": "quick", "i": i, "ch": ch})


func send_emote(emote_name: String) -> void:
	send({"t": "emote", "name": emote_name})


func tag_invite() -> void:
	send({"t": "tag_invite"})


func tag_join() -> void:
	send({"t": "tag_join"})


func tag_leave() -> void:
	send({"t": "tag_leave"})


func tag_start() -> void:
	send({"t": "tag_start"})


func send_chat(text: String, ch := "all") -> void:
	# filtro local antes de enviar (o servidor filtra de novo)
	var r := ChatFilter.check(text)
	if not r.ok:
		notice.emit(r.reason)
		return
	send({"t": "chat", "text": r.text, "ch": ch})


func report(target: String, reason: String) -> void:
	send({"t": "report", "target": target, "reason": reason})


func block(target: String) -> void:
	send({"t": "block", "target": target})
