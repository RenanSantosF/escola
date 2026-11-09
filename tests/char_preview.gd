extends Node3D
## Cena de verificação visual do personagem (usada nos testes de captura).
## Uso: godot --path . res://tests/char_preview.tscn -- --out=/caminho/

var out_dir := "user://"
var chars: Array[CharacterVisual] = []
var shots := [
	["idle", 0.0, ""], ["walk", 2.0, ""], ["run", 5.0, ""], ["sit", 0.0, "sit_down"],
	["kick", 0.0, "kick"], ["throw", 0.0, "throw"], ["celebrate", 0.0, "celebrate"], ["sad", 0.0, "sad"],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.85, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 10)
	floor_mi.mesh = pm
	add_child(floor_mi)
	for i in shots.size():
		var cv := CharacterVisual.new()
		cv.appearance = CharacterAppearance.random(i * 13 + 5, i % 2 == 0)
		if i == 0:
			cv.appearance = CharacterAppearance.new()
		cv.position = Vector3((i - 3.5) * 1.1, 0, 0)
		add_child(cv)
		chars.append(cv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 6.2)
	cam.fov = 60
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	await get_tree().process_frame
	for i in shots.size():
		var s: Array = shots[i]
		chars[i].animator.speed = s[1]
		if s[2] != "":
			chars[i].play(s[2])
	# Captura em instantes diferentes
	var times := {"a": 0.42, "b": 0.6}
	var elapsed := 0.0
	for tag in times.keys():
		while elapsed < times[tag]:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("char_%s.png" % tag))
	# Close-up do rosto
	cam.position = Vector3(-3.85, 1.6, 1.3)
	cam.look_at(Vector3(-3.85, 1.55, 0))
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("char_face.png"))
	get_tree().quit()
