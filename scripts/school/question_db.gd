class_name QuestionDB
extends RefCounted
## Perguntas que vêm do BANCO DE DADOS do servidor (/api/questions).
## O jogo baixa a lista ao abrir (quando tem internet), guarda uma cópia em
## user://questions.json e usa junto com as perguntas que já vêm no jogo.
## Formato de cada item (igual ao banco local):
## [nível mín, nível máx, pergunta, CERTA, errada1, errada2, errada3, explicação]

const CACHE := "user://questions.json"
## Cópia que já vem dentro do jogo (a mesma de server/data/questions.json):
## funciona sem internet; o servidor manda as novas.
const BUILTIN := "res://assets/data/questions.json"

static var _base: Dictionary = {}    # matéria -> perguntas que vêm no jogo
static var _remote: Dictionary = {}  # matéria -> perguntas baixadas do servidor
static var _merged: Dictionary = {}
static var _loaded := false
static var version := 0


static func for_subject(subject: String) -> Array:
	if not _loaded:
		_load_cache()
	if not _merged.has(subject):
		var seen := {}
		var out := []
		for q in (_remote.get(subject, []) as Array) + (_base.get(subject, []) as Array):
			if not seen.has(q[2]):
				seen[q[2]] = true
				out.append(q)
		_merged[subject] = out
	return _merged[subject]


static func count() -> int:
	if not _loaded:
		_load_cache()
	var n := 0
	for k in _base.keys() + _remote.keys():
		n += for_subject(k).size()
	return n


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null


static func _load_cache() -> void:
	_loaded = true
	var b: Variant = _read_json(BUILTIN)
	if b is Dictionary:
		_base = _parse(b)
	var c: Variant = _read_json(CACHE)
	if c is Dictionary:
		ingest(c)


## Recebe {version, questions: [{s, a, b, q, c, w: [3], e}]} do servidor.
static func ingest(data: Dictionary) -> int:
	if not _loaded:
		_load_cache()
	var out := _parse(data)
	if out.is_empty():
		return 0
	_remote = out
	_merged.clear()
	version = int(data.get("version", 0))
	var n := 0
	for k in out:
		n += (out[k] as Array).size()
	return n


static func _parse(data: Dictionary) -> Dictionary:
	var out := {}
	for it in data.get("questions", []):
		if not (it is Dictionary):
			continue
		var subj := str(it.get("s", ""))
		var q := str(it.get("q", ""))
		var c := str(it.get("c", ""))
		var w: Array = it.get("w", []) if it.get("w") is Array else []
		if subj == "" or q == "" or c == "" or w.size() < 3:
			continue
		if not out.has(subj):
			out[subj] = []
		out[subj].append([int(it.get("a", 1)), int(it.get("b", 9)), q, c, str(w[0]), str(w[1]), str(w[2]), str(it.get("e", ""))])
	return out


## Baixa a lista nova (se mudou) e salva a cópia. Chamado ao abrir o jogo.
static func refresh(parent: Node) -> void:
	if not NetworkManager.available():
		return
	var http := HTTPRequest.new()
	http.timeout = 15.0
	parent.add_child(http)
	var url := NetworkManager.https_base() + "/api/questions?v=%d" % version
	if http.request(url) != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary) or not data.has("questions"):
		return  # {"same": true}: já está atualizado
	if ingest(data) > 0:
		var f := FileAccess.open(CACHE, FileAccess.WRITE)
		if f:
			f.store_string(text)
