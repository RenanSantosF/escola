extends Node
## Capturas para a página da Play Store (1920x1080, sem avisos passageiros).
## Uso: xvfb-run ... godot --rendering-driver opengl3 --resolution 1920x1080 --path . res://tests/capture_store.tscn -- --out=DIR

var out_dir := "user://"
var main: Node
var player: PlayerController


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	Settings.set_value("quality", 2, false)  # gráficos no máximo para a vitrine
	Settings.set_process(false)  # sem o ajuste automático (o computador das fotos é lento)
	SaveManager.section("online").clear()
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main._menu == null:
		await get_tree().process_frame
	await _secs(1.5)
	# 1) menu com o personagem
	var sec: Dictionary = SaveManager.section("online")
	sec["token"] = "x"
	sec["registered"] = true
	sec["name"] = "Foguete_Azul"
	main._account_screen.visible = false
	main._show_menu()
	main._refresh_hello()
	await _secs(1.5)
	await _snap("01_menu")
	main._start_game()
	main._menu.visible = false
	player = GameManager.player
	await _secs(1.0)
	main.school_day._start_recess()
	await _secs(0.5)
	# 2) pátio no recreio
	await _view(Vector3(2, 0.05, -4), 200.0, 25.0, -16.0, 7.5)
	await _snap("02_patio")
	# 3) montanha-russa no alto da subida
	var coaster: RideTrack = null
	var slide: RideTrack = null
	for r in main.world.rides:
		if r.kind == "coaster":
			coaster = r
		else:
			slide = r
	player.global_position = coaster.global_position
	await _frames(2)
	coaster.interact(player)
	coaster._s = coaster._total * 0.24
	coaster._v = 14.0
	await _frames(6)
	player.camera_rig.distance = 6.5
	player.camera_rig.pitch = -12.0
	player.camera_rig.yaw = player.yaw + PI + deg_to_rad(35)
	player.camera_rig.snap_to_target()
	await _frames(20)
	await _snap("03_montanha_russa")
	coaster.eject()
	await _frames(5)
	# 4) tobogã gigante descendo a espiral
	player.global_position = slide.global_position
	await _frames(2)
	slide.interact(player)
	slide._phase = "ride"
	slide._s = 22.0
	slide._v = 9.0
	await _frames(6)
	player.camera_rig.distance = 6.0
	player.camera_rig.pitch = -20.0
	player.camera_rig.snap_to_target()
	await _frames(20)
	await _snap("04_tobogan")
	slide.eject()
	await _frames(5)
	# 5) futebol (times completados com bots)
	var mm: MinigameManager = main.minigames
	main.school_day._start_recess()
	await _secs(0.3)
	player.force_stand()
	mm.start_local("futebol", {"gid": "futebol", "kind": "team", "players": ["eu"], "host": "eu", "teams": {"eu": "a"}, "me": "eu", "bots": 4})
	await _secs(5.0)
	var fb = mm.active
	if fb:
		fb._take(player)
		player.global_position = Vector3(46, 0.05, -48)
		player.yaw = PI * 0.5
		player.camera_rig.yaw = player.yaw + PI
		player.camera_rig.snap_to_target()
		await _secs(0.8)
		await _snap("05_futebol")
		fb.end_game(0, "foto", 0, 0)
	await _secs(1.0)
	_clear_result()
	# 6) queimada
	main.school_day._start_recess()
	await _secs(0.3)
	player.force_stand()
	mm.start_local("queimada", {"gid": "queimada", "kind": "team", "players": ["eu"], "host": "eu", "teams": {"eu": "a"}, "me": "eu", "bots": 4})
	await _secs(6.0)
	var dg = mm.active
	if dg:
		player.camera_rig.yaw = player.yaw + PI + deg_to_rad(20)
		player.camera_rig.snap_to_target()
		await _secs(0.4)
		await _snap("06_queimada")
		dg.end_game(0, "foto", 0, 0)
	await _secs(1.0)
	_clear_result()
	# 7) aula com pergunta
	var gen := ClassroomTasks.new(5, 3)
	var ui: ClassroomUI = main.school_day.classroom_ui
	var desk: Seat = main.npcs.player_desk
	player.force_stand()
	player.global_position = desk.global_position
	player.sit_on(desk)
	await _secs(1.0)
	ui.show_task(gen.make("quiz", "Ciências"), 2, 7, [true, true])
	await _secs(1.0)
	await _snap("07_aula")
	ui.hide_panel()
	player.force_stand()
	# 8) xadrez na Sala de Jogos
	var t := TableGames.open(main.hud, "xadrez", func(_w): pass)
	await _secs(0.5)
	var b: Control = t._board
	for mv in [[52, 36], [12, 28], [62, 45], [1, 18], [61, 34]]:
		b.st = ChessRules.apply(b.st, mv)
	b.sel = 45
	b.targets = ChessRules.legal_moves(b.st).filter(func(m): return m[0] == 45)
	b.queue_redraw()
	await _secs(0.4)
	await _snap("08_xadrez")
	t.close()
	# 9) fundo do gráfico de recursos: parque com a montanha-russa, sem interface
	main.hud.visible = false
	await _view(Vector3(22, 0.05, -74), 160.0, 0.0, -6.0, 9.0)
	player.visible = false
	await _frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("_bg_feature.png"))
	get_tree().quit()


func _view(pos: Vector3, yaw: float, cam_yaw: float, pitch: float, dist: float) -> void:
	player.force_stand()
	player.global_position = pos
	player.yaw = deg_to_rad(yaw)
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = player.yaw + PI + deg_to_rad(cam_yaw)
	player.camera_rig.pitch = pitch
	player.camera_rig.distance = dist
	player.camera_rig._cur_distance = dist
	player.camera_rig.snap_to_target()
	await _frames(30)


func _clear_result() -> void:
	if main.hud._result and is_instance_valid(main.hud._result):
		main.hud._result.queue_free()
	main.hud._result = null


## Esconde banner, aviso e dica passageiros antes da foto.
func _snap(name: String) -> void:
	_clear_result()
	if main.hud._banner_tween:
		main.hud._banner_tween.kill()
	if main.hud._toast_tween:
		main.hud._toast_tween.kill()
	main.hud._banner.modulate.a = 0.0
	main.hud._toast.modulate.a = 0.0
	main.hud.hide_hint()
	await _frames(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("foto ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
