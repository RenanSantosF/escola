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
	["andando", Vector3(5, 0.05, -12), 90.0, 70.0, -10.0, 3.2],
	["sentado", Vector3(0, 0.05, -12), 0.0, 40.0, -12.0, 3.0],
	["fonte", Vector3(0, 0.05, 66), 180.0, 0.0, -20.0, 7.0],
	["mapa", Vector3(0, 0.05, -6), 180.0, 0.0, -20.0, 4.0],
	["rosto", Vector3(6, 0.05, -2), 200.0, 180.0, -4.0, 2.2],
	["turma", Vector3(0, 0.05, 44), 180.0, 180.0, -8.0, 3.0],
	["parque", Vector3(0, 0.05, -66), 180.0, 0.0, -12.0, 6.0],
	["morro", Vector3(-22, 0.05, -90), -115.0, 0.0, -10.0, 6.5],
	["lago", Vector3(10, 0.05, -90), 140.0, 0.0, -16.0, 6.5],
	["anfiteatro", Vector3(-2, 0.05, -97), 180.0, 0.0, -14.0, 6.0],
	["lago_alto", Vector3(28, 0.05, -87), 180.0, 0.0, -50.0, 9.0],
	["mirante_morro", Vector3(-42, 7.0, -103), 70.0, 0.0, -14.0, 6.0],
	["blococ_escada", Vector3(-66, 0.05, 26), -90.0, 0.0, -18.0, 3.0],
	["mirante", Vector3(-70, 3.9, 40), 90.0, 0.0, -18.0, 3.5],
	["amarelinha", Vector3(-14, 0.05, 3), 180.0, 0.0, -24.0, 6.0],
	["fachada", Vector3(0, 0.05, 62), 180.0, 0.0, -6.0, 10.0],
	["fundos", Vector3(-20, 0.05, 8), 0.0, 180.0, -6.0, 9.0],
	["hall_escada", Vector3(0, 0.05, 47), 180.0, 0.0, -10.0, 3.0],
	["tobogã", Vector3(-38, 0.05, -84), -140.0, 0.0, -12.0, 12.0],
	["montanha_russa", Vector3(31, 0.05, -80), 180.0, 0.0, -14.0, 12.0],
	["camas", Vector3(-34, 0.05, -62), 180.0, 0.0, -20.0, 7.0],
	["mezanino", Vector3(5, 3.9, 30), 0.0, 180.0, -18.0, 3.5],
	["sala_1andar", Vector3(-12, 3.9, 29), -90.0, 0.0, -28.0, 4.0],
	["brinquedoteca", Vector3(14, 0.05, 30), -90.0, 0.0, -28.0, 4.0],
	["auditorio", Vector3(-12, 0.05, 30), -90.0, 0.0, -22.0, 4.0],
	["corredor_1andar", Vector3(-30, 3.9, 36), -90.0, 0.0, -14.0, 4.0],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--shots="):
			only = a.substr(8).split(",")
		elif a.begins_with("--quality="):
			Settings.set_value("quality", int(a.substr(10)), false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	if "--menu" in OS.get_cmdline_user_args():
		while GameManager.state != GameManager.State.MENU:
			await get_tree().process_frame
		for i in 60:
			await get_tree().process_frame
		await _snap("menu")
		main._open_menu_settings()
		for i in 10:
			await get_tree().process_frame
		await _snap("config")
		main._menu_settings.closed.emit()
		main._start_game()
	while GameManager.player == null or not GameManager.is_playing():
		await get_tree().process_frame
	var player: PlayerController = GameManager.player
	var cam: CameraController = main.camera_rig
	for s in SHOTS:
		if not only.is_empty() and not s[0] in only:
			continue
		player.global_position = s[1]
		if s[1].y < 0.5:
			player.global_position.y = ParkHill.height(s[1].x, s[1].z) + 0.1
		player.yaw = deg_to_rad(s[2])
		player.velocity = Vector3.ZERO
		cam.yaw = player.yaw + PI + deg_to_rad(s[3])
		cam.pitch = s[4]
		cam.distance = s[5]
		cam._cur_distance = s[5]
		cam.snap_to_target()
		main.hud.minimap.open_full(s[0] == "mapa")
		if s[0] == "andando":
			Input.action_press("move_forward")
		if s[0] == "sentado":
			Input.action_release("move_forward")
			var best: Seat = null
			for n in get_tree().get_nodes_in_group("interactable"):
				if n is Seat and (best == null or n.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
					best = n
			player.sit_on(best)
			for i in 60:
				await get_tree().process_frame
		for i in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("w_%s.png" % s[0]))
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("shot %-14s zona=%-24s draw_calls=%d objetos=%d triângulos=%d" % [s[0], GameManager.current_zone, dc, objs, prims])
	if "--menu" in OS.get_cmdline_user_args():
		main.hud.open_pause()
		for i in 10:
			await get_tree().process_frame
		await _snap("pausa")
	get_tree().quit()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("w_%s.png" % name))
