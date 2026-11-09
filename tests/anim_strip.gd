extends Node3D
## Gera uma tira de quadros (vista lateral) de caminhada e corrida para
## revisar a naturalidade da animação. Uso: ... res://tests/anim_strip.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.88, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 60, 0)
	add_child(sun)
	var chars: Array[CharacterVisual] = []
	for i in 2:
		var cv := CharacterVisual.new()
		cv.position = Vector3(-1.0 + i * 2.0, 0, 0)
		cv.rotation.y = PI * 0.5
		add_child(cv)
		chars.append(cv)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.6
	cam.position = Vector3(0, 1.0, 0)
	add_child(cam)
	cam.position = Vector3(0, 0.95, 0)
	cam.rotation = Vector3.ZERO
	cam.position = Vector3(0, 0.95, 8)
	await get_tree().process_frame
	chars[0].animator.speed = 2.0
	chars[1].animator.speed = 5.0
	for i in 90:
		await get_tree().process_frame
	var frames: Array[Image] = []
	for f in 8:
		for k in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frames.append(get_viewport().get_texture().get_image())
	var w := 300
	var strip := Image.create(w * frames.size(), 720, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var img := frames[i]
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(640 - w / 2, 0, w, 720), Vector2i(i * w, 0))
	strip.save_png(out_dir.path_join("anim_strip.png"))
	get_tree().quit()
