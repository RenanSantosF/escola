extends Node
## Captura o fluxo do dia: chegada, aula com tarefa, recreio com NPCs.
## Uso: godot --rendering-driver opengl3 --path . res://tests/capture_flow.tscn -- --out=DIR

var out_dir := "user://"
var main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	Settings.set_value("quality", 1, false)
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.school_day == null:
		await get_tree().process_frame
	main._start_game()
	var p: PlayerController = GameManager.player
	var cam: CameraController = main.camera_rig
	await _frames(90)
	await _snap("f_chegada")
	# senta na carteira -> começa a aula
	var desk: Seat = main.npcs.player_desk
	p.global_position = desk.interact_point()
	p.sit_on(desk)
	await _frames(240)
	await _snap("f_aula_tarefa")
	# responde a tarefa (escolha a certa se for de escolha)
	var ui: ClassroomUI = main.school_day.classroom_ui
	await _frames(30)
	await _snap("f_aula_tarefa2")
	# pula para o recreio
	ui.hide_panel()
	main.school_day._start_recess()
	await _frames(200)
	p.force_stand()
	p.global_position = Vector3(0, 0.05, -2)
	p.yaw = PI
	cam.yaw = 0.0
	cam.pitch = -22.0
	cam.distance = 9.0
	await _frames(600)
	await _snap("f_recreio_patio")
	p.global_position = Vector3(40, 0.05, -36)
	p.yaw = PI
	cam.yaw = 0.0
	await _frames(240)
	await _snap("f_recreio_quadra")
	p.global_position = Vector3(-16, 0.05, 14)
	p.yaw = -PI * 0.5
	cam.yaw = PI * 0.5
	cam.distance = 6.0
	await _frames(120)
	await _snap("f_recreio_cantina")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("snap ", name, " zona=", GameManager.current_zone)
