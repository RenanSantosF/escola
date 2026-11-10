extends Node
## Salvamento local do progresso.
## - Escrita atômica (arquivo temporário + renomear) para não corromper o save.
## - Mantém um backup da versão anterior.
## - Versão de esquema + mesclagem com valores padrão para migrações futuras.

signal saved
signal loaded

## Testes automatizados usam arquivos separados para não tocar no save real.
static var _prefix := "user://test_" if " ".join(OS.get_cmdline_args()).contains("res://tests/") else "user://"
static var SAVE_PATH := _prefix + "save.json"
static var TEMP_PATH := _prefix + "save.json.tmp"
static var BACKUP_PATH := _prefix + "save.backup.json"
const SCHEMA_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_game()


static func default_data() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"player": {
			"name": "Você",
			"level": 1,
			"xp": 0,
			"coins": 50,
			"appearance": {},
		},
		"progress": {
			"days_completed": 0,
			"activities": {},
		},
		"inventory": {"owned": [], "equipped": {}},
		"collections": {},
		"friendships": {},
		"missions": {},
		"achievements": {},
		"stats": {"play_time": 0.0, "kicks": 0, "throws": 0, "sits": 0},
	}


func load_game() -> void:
	var loaded_data := _read(SAVE_PATH)
	if loaded_data.is_empty():
		loaded_data = _read(BACKUP_PATH)
	data = _merge(default_data(), loaded_data)
	data.version = SCHEMA_VERSION
	loaded.emit()


func save_game() -> bool:
	data["saved_at"] = int(Time.get_unix_time_from_system() * 1000.0)
	var json := JSON.stringify(data, "\t")
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: não foi possível escrever %s (%s)" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(json)
	f.close()
	# Valida o que foi escrito antes de substituir o save real.
	if _read(TEMP_PATH).is_empty():
		push_error("SaveManager: arquivo temporário inválido, save abortado.")
		return false
	if FileAccess.file_exists(SAVE_PATH):
		# só vira backup se o save atual for válido
		if not _read(SAVE_PATH).is_empty():
			DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		DirAccess.remove_absolute(SAVE_PATH)
	var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveManager: falha ao renomear save (%s)" % err)
		return false
	saved.emit()
	return true


## Progresso para a nuvem (sem a parte "online", que tem o token).
func export_progress() -> Dictionary:
	var out := data.duplicate(true)
	out.erase("online")
	return out


## Aplica o progresso que veio do servidor (mantém o token local).
func import_progress(d: Dictionary, saved_at: int) -> void:
	var online: Dictionary = section("online").duplicate(true)
	data = _merge(default_data(), d)
	data.version = SCHEMA_VERSION
	data["online"] = online
	save_game()
	data["saved_at"] = saved_at
	loaded.emit()


func saved_at() -> int:
	return int(data.get("saved_at", 0))


func reset() -> void:
	data = default_data()
	save_game()


func section(name: String) -> Dictionary:
	if not data.has(name) or typeof(data[name]) != TYPE_DICTIONARY:
		data[name] = {}
	return data[name]


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


## Mescla recursivamente: chaves do save sobrescrevem os padrões,
## chaves novas dos padrões são adicionadas, tipos inválidos são ignorados.
func _merge(defaults: Dictionary, saved_data: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for key in saved_data.keys():
		var v = saved_data[key]
		if not out.has(key):
			out[key] = v
		elif typeof(out[key]) == TYPE_DICTIONARY and typeof(v) == TYPE_DICTIONARY:
			if out[key].is_empty():
				out[key] = v
			else:
				out[key] = _merge(out[key], v)
		elif typeof(out[key]) == typeof(v) or (typeof(out[key]) in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT]):
			out[key] = v
	return out
