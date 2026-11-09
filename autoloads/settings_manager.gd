extends Node
## Configurações do jogador (gráficos, áudio, controles).
## Persistidas em user://settings.cfg, separadas do progresso do jogo.

signal changed(key: String)

enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"quality": Quality.MEDIUM,
	"camera_sensitivity": 1.0,
	"invert_y": false,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"ambient_volume": 0.6,
	"show_fps": false,
	"fps_limit_30": false,
	"controls_opacity": 0.8,
	"run_toggle": true,
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()
	# Na primeira execução escolhe a qualidade pelo hardware.
	if not FileAccess.file_exists(PATH):
		values.quality = _detect_quality()
		save_settings()
	apply_all()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant, persist := true) -> void:
	if values.get(key) == value:
		return
	values[key] = value
	_apply(key)
	changed.emit(key)
	if persist:
		save_settings()


func quality() -> int:
	return int(values.quality)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in DEFAULTS.keys():
		var v = cfg.get_value("settings", key, DEFAULTS[key])
		# Garante o tipo correto mesmo com arquivo corrompido/editado.
		if typeof(v) == typeof(DEFAULTS[key]) or (typeof(DEFAULTS[key]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
			values[key] = v
	values.quality = clampi(int(values.quality), Quality.LOW, Quality.HIGH)
	values.camera_sensitivity = clampf(float(values.camera_sensitivity), 0.2, 3.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values.keys():
		cfg.set_value("settings", key, values[key])
	cfg.save(PATH)


func apply_all() -> void:
	for key in values.keys():
		_apply(key)


func _apply(key: String) -> void:
	match key:
		"fps_limit_30":
			Engine.max_fps = 30 if values.fps_limit_30 else 60
		"music_volume", "sfx_volume", "ambient_volume":
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").apply_volumes()


func _detect_quality() -> int:
	var os_name := OS.get_name()
	if os_name in ["Android", "iOS"]:
		var cores := OS.get_processor_count()
		var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
		if RenderingServer.get_rendering_device() == null or cores <= 4:
			return Quality.LOW
		if cores >= 8 and method == "mobile":
			return Quality.MEDIUM
		return Quality.LOW
	return Quality.HIGH
