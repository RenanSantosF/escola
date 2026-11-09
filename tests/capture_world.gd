extends Node
## Captura screenshots de vários pontos da escola para revisão visual.
## Uso: godot --rendering-driver opengl3 --path . res://tests/capture_world.tscn -- --out=DIR [--shots=a,b]

var out_dir := "user://"
var only: PackedStringArray = []

# nome, posição do jogador, yaw do jogador, yaw da câmera (graus, relativo), pitch, distância
const SHOTS := [
	["entrada", Vector3(0, 0.05, 66), 180.0, 0.0, -14.0, 6.0],
	["hall", Vector3(0, 0.05, 40), 180.0, 0.0, -18.0, 4.0],
	["corredor", Vector3(-30, 0.05, 36), -90.0, 0.0, -14.0, 4.0],
	["sala", Vector3(-24, 0.05, 29), -90.0, 0.0, -30.0, 4.0],
	["patio_coberto", Vector3(-6, 0.05, 12), 180.0, 30.0, -16.0, 5.0],
	["patio", Vector3(0, 0.05, -2), 180.0, 20.0, -20.0, 7.0],
	["quadra", Vector3(36, 0.05, -40), 180.0, 10.0, -16.0, 7.0],
	["queimada", Vector3(-40, 0.05, -40), 180.0, 0.0, -18.0, 7.0],
	["parquinho", Vector3(-70, 0.05, -45), 200.0, 0.0, -18.0, 7.0],
	["biblioteca", Vector3(-50, 0.05, 41), 180.0, 0.0, -32.0, 4.0],
	["cantina", Vector3(-18, 0.05, 12), -90.0, 0.0, -14.0, 4.5],
	["blocob", Vector3(64, 0.05, -10), 0.0, 120.0, -15.0, 6.0],
	["aerea", Vector3(0, 0.05, 10), 180.0, 30.0, -55.0, 8.0],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--shots="):
			only = a.substr(8).split(",")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or not GameManager.is_playing():
		await get_tree().process_frame
	var player: PlayerController = GameManager.player
	var cam: CameraController = main.camera_rig
	for s in SHOTS:
		if not only.is_empty() and not s[0] in only:
			continue
		player.global_position = s[1]
		player.yaw = deg_to_rad(s[2])
		player.velocity = Vector3.ZERO
		cam.yaw = player.yaw + PI + deg_to_rad(s[3])
		cam.pitch = s[4]
		cam.distance = s[5]
		cam._cur_distance = s[5]
		cam.snap_to_target()
		for i in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("w_%s.png" % s[0]))
		print("shot ", s[0], " zona=", GameManager.current_zone)
	get_tree().quit()
