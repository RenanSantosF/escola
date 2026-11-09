extends Node
## Áudio central: barramentos, pool de players (sem criar nós em tempo de jogo),
## variações de pitch para evitar repetição e ambiente com crossfade.

const AUDIO_DIR := "res://assets/audio/"
const POOL_3D := 10
const POOL_2D := 6

var _cache: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _ambient_a: AudioStreamPlayer
var _ambient_b: AudioStreamPlayer
var _ambient_current := ""
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 40.0
		p.attenuation_filter_cutoff_hz = 8000.0
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_pool2d.append(p)
	_ambient_a = AudioStreamPlayer.new()
	_ambient_b = AudioStreamPlayer.new()
	for p in [_ambient_a, _ambient_b]:
		p.bus = "Ambient"
		p.volume_db = -80.0
		add_child(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambient", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	_set_bus_linear("Music", settings.get_value("music_volume"))
	_set_bus_linear("SFX", settings.get_value("sfx_volume"))
	_set_bus_linear("UI", settings.get_value("sfx_volume"))
	_set_bus_linear("Ambient", settings.get_value("ambient_volume"))


func _set_bus_linear(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))


## Carrega um som. Nomes sem sufixo com variações (ex.: "step_hard")
## escolhem aleatoriamente entre step_hard_0..N.
func get_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		var entry = _cache[sound]
		if entry is Array:
			return entry.pick_random() if not entry.is_empty() else null
		return entry
	var path := AUDIO_DIR + sound + ".wav"
	if ResourceLoader.exists(path):
		_cache[sound] = load(path)
		return _cache[sound]
	var variants: Array = []
	for i in 8:
		var vp := AUDIO_DIR + "%s_%d.wav" % [sound, i]
		if not ResourceLoader.exists(vp):
			break
		variants.append(load(vp))
	_cache[sound] = variants
	if variants.is_empty():
		push_warning("AudioManager: som não encontrado: %s" % sound)
		return null
	return variants.pick_random()


func play_3d(sound: String, position: Vector3, volume_db := 0.0, pitch_variation := 0.08) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % POOL_3D
	p.stream = stream
	p.global_position = position
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


func play_ui(sound: String, volume_db := 0.0, pitch_variation := 0.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool2d[_next2d]
	_next2d = (_next2d + 1) % POOL_2D
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


## Troca o som ambiente com crossfade suave.
func set_ambient(sound: String, volume_db := -6.0, fade := 1.5) -> void:
	if sound == _ambient_current:
		return
	_ambient_current = sound
	var incoming := _ambient_b if _ambient_a.playing and _ambient_a.volume_db > -60.0 else _ambient_a
	var outgoing := _ambient_a if incoming == _ambient_b else _ambient_b
	if outgoing.playing:
		var tw := create_tween()
		tw.tween_property(outgoing, "volume_db", -80.0, fade)
		tw.tween_callback(outgoing.stop)
	if sound.is_empty():
		return
	var stream := get_stream(sound)
	if stream == null:
		return
	_make_loop(stream)
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	var tw2 := create_tween()
	tw2.tween_property(incoming, "volume_db", volume_db, fade)


func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
