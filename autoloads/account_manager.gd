extends Node
## Conta da criança e progresso na nuvem.
## - Criar conta: apelido escolhido de uma lista do servidor + idade.
## - Código de recuperação (palavras + número) para entrar em outro celular.
## - Progresso (moedas, itens, nível...) enviado ao servidor a cada salvamento
##   (com intervalo mínimo) e ao sair; ao entrar, se o da nuvem for mais novo,
##   ele é baixado.
## Sem e-mail, senha, telefone ou nome real.

signal account_changed

const UPLOAD_MIN_GAP := 20.0

var _http: HTTPRequest
var _busy := false
var _upload_pending := false
var _upload_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.saved.connect(func(): _upload_pending = true)


func _process(delta: float) -> void:
	_upload_t -= delta
	if _upload_pending and _upload_t <= 0.0 and has_account() and not _busy:
		_upload_pending = false
		_upload_t = UPLOAD_MIN_GAP
		upload_progress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_account():
			upload_progress()


func _sec() -> Dictionary:
	return SaveManager.section("online")


func has_account() -> bool:
	return str(_sec().get("token", "")) != "" and bool(_sec().get("registered", false))


func nickname() -> String:
	return str(_sec().get("name", ""))


## Requisição HTTP simples (cada chamada usa o próprio HTTPRequest).
func _request(method: int, path: String, body: Variant = null, auth := false) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := ["Content-Type: application/json"]
	if auth:
		headers.append("x-token: " + str(_sec().get("token", "")))
	var err := http.request(NetworkManager.https_base() + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "error": "Sem conexão com a internet."}
	var res: Array = await http.request_completed
	http.queue_free()
	var status: int = res[1]
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var out: Dictionary = parsed if parsed is Dictionary else {}
	out["status"] = status
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		out["ok"] = false
		out["error"] = "Sem conexão com o servidor. Confira a internet."
	elif not out.has("ok"):
		out["ok"] = status >= 200 and status < 300
	return out


func fetch_names() -> Array:
	var r := await _request(HTTPClient.METHOD_GET, "/api/account/names")
	return r.get("names", [])


## Cria a conta. Retorna {ok, code} ou {ok:false, error}.
func register(nick: String, age: int) -> Dictionary:
	var r := await _request(HTTPClient.METHOD_POST, "/api/account/register", {"name": nick, "age": age})
	if r.get("ok", false):
		_store(r)
		# o progresso local deste aparelho vira o da conta nova
		SaveManager.save_game()
		upload_progress()
	return r


## Entra com o código de recuperação. Se a nuvem tiver progresso, aplica.
## Retorna {ok, imported: bool} ou {ok:false, error}.
func recover(code: String) -> Dictionary:
	var r := await _request(HTTPClient.METHOD_POST, "/api/account/recover", {"code": code})
	if not r.get("ok", false):
		if int(r.get("status", 0)) == 404 and not r.has("error"):
			r["error"] = "Código não encontrado."
		return r
	_store(r)
	var acc: Dictionary = r.get("account", {})
	var prog: Variant = acc.get("progress")
	r["imported"] = false
	if prog is Dictionary and not (prog as Dictionary).is_empty():
		SaveManager.import_progress(prog, int(acc.get("progressAt", 0)))
		r["imported"] = true
	else:
		SaveManager.save_game()
	return r


## Ao abrir o jogo: se a nuvem tiver progresso mais novo que o deste
## aparelho (jogou em outro celular), baixa. Retorna true se trocou o save.
func sync_on_start() -> bool:
	if not has_account():
		return false
	var r := await _request(HTTPClient.METHOD_GET, "/api/account/me", null, true)
	if not r.get("ok", false):
		return false
	var acc: Dictionary = r.get("account", {})
	var prog: Variant = acc.get("progress")
	var at := int(acc.get("progressAt", 0))
	if prog is Dictionary and at > SaveManager.saved_at() + 2000:
		SaveManager.import_progress(prog, at)
		return true
	upload_progress()
	return false


func upload_progress() -> void:
	if not has_account():
		return
	if _busy:
		# já tem um envio a caminho: manda de novo logo depois (nada se perde)
		_upload_pending = true
		_upload_t = 0.0
		return
	_busy = true
	await _request(HTTPClient.METHOD_PUT, "/api/progress", {"save": SaveManager.export_progress(), "savedAt": SaveManager.saved_at()}, true)
	_busy = false


func is_uploading() -> bool:
	return _busy or _upload_pending


func delete_account() -> bool:
	var r := await _request(HTTPClient.METHOD_DELETE, "/api/account", null, true)
	if r.get("ok", false):
		var sec := _sec()
		sec.clear()
		SaveManager.reset()
		account_changed.emit()
		return true
	return false


func _store(r: Dictionary) -> void:
	var acc: Dictionary = r.get("account", {})
	var sec := _sec()
	sec["token"] = str(r.get("token", ""))
	sec["registered"] = true
	sec["name"] = str(acc.get("name", ""))
	sec["id"] = str(acc.get("id", ""))
	if acc.has("age"):
		Learning.set_age(int(acc.age))
	SaveManager.save_game()
	account_changed.emit()
