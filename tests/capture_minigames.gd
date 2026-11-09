extends Node
## Capturas de tela dos minijogos. Uso: ... res://tests/capture_minigames.tscn -- --out=DIR

var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	Settings.set_value("quality", 1, false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.minigames == null:
		await get_tree().process_frame
	main._start_game()
	await _frames(10)
	var mm: MinigameManager = main.minigames
	for gid in ["futebol", "queimada", "gude", "aviao", "corda", "corrida"]:
		main.school_day._start_recess()
		await _frames(5)
		mm.start(gid)
		var g: Minigame = mm.active
		await _frames(260)
		if gid == "gude":
			g.on_play()
			await _frames(40)
		if gid == "aviao":
			for i in 3:
				g.on_play()
			g.on_play()
			await _frames(30)
			g._power = 0.95
			g.on_play()
			await _frames(25)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("mg_%s.png" % gid))
		print("snap ", gid)
		if mm.active:
			mm.active.end_game(0, "fim", 0, 0)
		await _frames(5)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
