extends Node
## Fotos com câmera livre: --cams="nome:x,y,z:lx,ly,lz;..." --out=DIR
var out_dir := "user://"
var cams := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--cams="):
			for c in a.substr(7).split(";"):
				var p := c.split(":")
				var e := p[1].split(",")
				var l := p[2].split(",")
				cams.append([p[0], Vector3(float(e[0]), float(e[1]), float(e[2])), Vector3(float(l[0]), float(l[1]), float(l[2]))])
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	main._start_game()
	while not GameManager.is_playing():
		await get_tree().process_frame
	var cam: CameraController = main.camera_rig
	var player: PlayerController = GameManager.player
	for c in cams:
		player.global_position = Vector3(c[1].x, 0.1, c[1].z)
		var xf := Transform3D(Basis(), c[1]).looking_at(c[2], Vector3.UP)
		cam.set_override(xf)
		cam.override_cam.far = 600.0
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("c_%s.png" % c[0]))
		print("shot ", c[0])
	get_tree().quit()
