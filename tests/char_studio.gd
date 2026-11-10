extends Node3D
## Estúdio de personagem: mesma luz do jogo, vários ângulos e aparências.
## godot --rendering-driver opengl3 --path . res://tests/char_studio.tscn -- --out=ARQUIVO.png


func _ready() -> void:
	var out := "user://studio.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1f6fd8")
	sky_mat.sky_horizon_color = Color("9fd0f5")
	sky_mat.ground_horizon_color = Color("b9dcef")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("b9d3ee")
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.16
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("fbfcff")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("98a3b1")
	floor.material_override = fm
	add_child(floor)
	# fileira: frente, 3/4, lado, costas + variações
	var looks := [
		[{}, 0.0], [{}, 0.7], [{}, 1.57], [{}, 3.14],
		[{"hair_style": "longo", "hair_color": "d9b25f", "skin": "f2c9a5", "shirt_color": "ff7eb6", "shirt_logo": false, "backpack": false}, 0.35],
		[{"hair_style": "cacheado", "hair_color": "1d1612", "skin": "8d5a3b", "shirt_color": "ffd21f", "shirt_trim": "1f9e4a", "long_pants": true}, -0.35],
		[{"hair_style": "black_power", "hair_color": "1d1612", "skin": "6b4226", "glasses": true, "shirt_color": "5ec8ff", "shirt_logo": false}, 0.2],
		[{"hair_style": "rabo", "hair_color": "a32e1d", "skin": "f6d3b3", "cap": false, "shirt_color": "8e5bd1", "shirt_logo": false}, 2.6],
		[{"hair_style": "espetado", "cap": false, "skin": "c98b62"}, -0.6],
		[{"hair_style": "franja", "cap": true, "cap_color": "e04a3a", "skin": "e8b48f"}, 0.5],
	]
	for i in looks.size():
		var v := CharacterVisual.new()
		var d := CharacterAppearance.new().to_dict()
		d.merge(looks[i][0], true)
		v.appearance = CharacterAppearance.from_dict(d)
		add_child(v)
		v.position = Vector3(-4.05 + i * 0.9, 0, 0)
		v.rotation.y = looks[i][1]
		if i == 5:
			v.animator.speed = 4.0
		if i == 8:
			v.play("wave")
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30
	cam.position = Vector3(0, 1.0, 9.6)
	cam.look_at(Vector3(0, 0.85, 0))
	for k in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	# close do rosto
	cam.fov = 22
	cam.position = Vector3(-4.05 + 0.45, 1.45, 3.4)
	cam.look_at(Vector3(-4.05 + 0.45, 1.3, 0))
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.replace(".png", "_face.png"))
	get_tree().quit()
