extends Node
## Estatísticas ANÔNIMAS para o painel do site (/admin do servidor).
## Cada aparelho tem um id aleatório (não é nome, e-mail, telefone,
## localização nem ID de publicidade). Desligável em Configurações →
## Privacidade. Eventos ficam numa fila e são enviados a cada minuto; sem
## internet, a fila espera (limitada) e tenta depois.

const FLUSH_EVERY := 60.0
const MAX_QUEUE := 300

var _queue: Array = []
var _http: HTTPRequest
var _sending := false
var _t := 0.0
var _session_start := -1.0
var _active_seconds := 0.0
var enabled_in_tests := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	GameManager.level_up.connect(func(lv): track("level_up", {"level": lv}))
	GameManager.state_changed.connect(_on_state)


func _is_test() -> bool:
	return " ".join(OS.get_cmdline_args()).contains("res://tests/") and not enabled_in_tests


func enabled() -> bool:
	return bool(Settings.get_value("share_stats")) and NetworkManager.server_url() != "" and not _is_test()


func uid() -> String:
	var sec: Dictionary = SaveManager.section("online")
	if str(sec.get("uid", "")) == "":
		var b := PackedByteArray()
		for i in 12:
			b.append(randi() % 256)
		sec["uid"] = b.hex_encode()
	return str(sec.uid)


func track(type: String, data := {}) -> void:
	if not enabled():
		return
	_queue.append({"type": type, "at": int(Time.get_unix_time_from_system() * 1000.0), "data": data})
	if _queue.size() > MAX_QUEUE:
		_queue = _queue.slice(_queue.size() - MAX_QUEUE)


func _on_state(st: int) -> void:
	if st == GameManager.State.PLAYING and _session_start < 0.0:
		_session_start = Time.get_ticks_msec() / 1000.0
		_active_seconds = 0.0
		track("session_start", {"age": Learning.age(), "level": GameManager.level(),
			"online": NetworkManager.is_online(), "platform": OS.get_name(),
			"version": str(ProjectSettings.get_setting("application/config/version"))})


func _end_session() -> void:
	if _session_start < 0.0:
		return
	track("session_end", {"seconds": int(_active_seconds), "level": GameManager.level(), "coins": GameManager.coins()})
	_session_start = -1.0
	flush()


func _process(delta: float) -> void:
	if GameManager.is_playing():
		_active_seconds += delta
	_t += delta
	if _t >= FLUSH_EVERY:
		_t = 0.0
		if _session_start >= 0.0:
			# sessão longa: registra parcial para não perder se o app for morto
			track("heartbeat", {"seconds": int(_active_seconds)})
		flush()


func flush() -> void:
	if _sending or _queue.is_empty() or not enabled():
		return
	var batch := _queue.slice(0, 100)
	var body := JSON.stringify({"uid": uid(), "events": batch})
	var err := _http.request(NetworkManager.https_base() + "/api/events", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err == OK:
		_sending = true
		_queue = _queue.slice(batch.size())
		_pending = batch


var _pending: Array = []


func _on_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_sending = false
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500:
		# sem internet: devolve para a fila e tenta depois
		_queue = _pending + _queue
		if _queue.size() > MAX_QUEUE:
			_queue = _queue.slice(_queue.size() - MAX_QUEUE)
	_pending = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_session()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if GameManager.is_playing():
			_on_state(GameManager.State.PLAYING)
