extends Node
## Configurações do jogador (gráficos, áudio, controles).
## Persistidas em user://settings.cfg, separadas do progresso do jogo.

signal changed(key: String)

enum Quality { LOW, MEDIUM, HIGH }

static var PATH := "user://test_settings.cfg" if " ".join(OS.get_cmdline_args()).contains("res://tests/") else "user://settings.cfg"

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
	"online_enabled": false,
	"server_url": "",
	"share_stats": true,
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_settings()
	# Na primeira execução escolhe a qualidade pelo hardware.
	if not FileAccess.file_exists(PATH):
		values.quality = _detect_quality()
		# celular fraco: 30 quadros por segundo (esquenta menos e gasta menos bateria)
		if values.quality == Quality.LOW and OS.get_name() in ["Android", "iOS"]:
			values["fps_limit_30"] = true
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
			# 30 quadros: física também a 30 (um passo por quadro, metade do custo)
			Engine.physics_ticks_per_second = 30 if values.fps_limit_30 else 60
		"music_volume", "sfx_volume", "ambient_volume":
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").apply_volumes()


# ---------------------------------------------------------------- ajuste automático
# Jogando e o celular não aguenta (poucos quadros por segundo): baixa a
# qualidade sozinho, uma vez, e avisa. Na qualidade baixa ainda pesado:
# diminui a resolução interna do 3D.
var _perf_t := 0.0
var _perf_frames := 0
var _slow_secs := 0.0
var render_scale_low := 0.75


func _process(delta: float) -> void:
	if not has_node("/root/GameManager") or not get_node("/root/GameManager").is_playing():
		_slow_secs = 0.0
		return
	_perf_t += delta
	_perf_frames += 1
	if _perf_t < 2.0:
		return
	var fps := _perf_frames / _perf_t
	_perf_t = 0.0
	_perf_frames = 0
	var target := 24.0 if bool(values.get("fps_limit_30", false)) else 40.0
	if fps < target:
		_slow_secs += 2.0
	else:
		_slow_secs = maxf(_slow_secs - 2.0, 0.0)
	if _slow_secs < 10.0:
		return
	_slow_secs = 0.0
	if quality() > Quality.LOW:
		set_value("quality", quality() - 1)
		if quality() == Quality.LOW:
			set_value("fps_limit_30", true)
		get_node("/root/GameManager").show_toast("Ajustamos os gráficos para o jogo ficar mais leve no seu celular.")
	elif render_scale_low > 0.55:
		render_scale_low = maxf(render_scale_low - 0.1, 0.55)
		changed.emit("quality")


func _detect_quality() -> int:
	var os_name := OS.get_name()
	if os_name in ["Android", "iOS"]:
		var cores := OS.get_processor_count()
		# (usamos o renderizador de Compatibilidade/OpenGL: sem "rendering device")
		if cores <= 4:
			return Quality.LOW
		# placas de vídeo de entrada (Mali antigas, Adreno 3xx-50x, PowerVR)
		var gpu := RenderingServer.get_video_adapter_name().to_lower()
		for weak in ["mali-4", "mali-t", "mali-g31", "mali-g51", "mali-g52", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "powervr"]:
			if weak in gpu:
				return Quality.LOW
		if cores >= 8:
			return Quality.MEDIUM
		return Quality.LOW
	return Quality.HIGH
