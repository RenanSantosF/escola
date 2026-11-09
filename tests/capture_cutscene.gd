extends Node
## Captura a cena da diretoria. Uso: ... res://tests/capture_cutscene.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	Settings.set_value("quality", 1, false)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.discipline == null:
		await get_tree().process_frame
	main._start_game()
	main.school_day._start_recess()
	SaveManager.section("discipline")["active"] = 1
	main.discipline.start_occurrence("esbarrao_forte")
	for i in 150:
		await get_tree().process_frame
	main.school_day.dialogue.advance()
	main.school_day.dialogue.advance()
	main.school_day.dialogue.advance()
	main.school_day.dialogue.advance()
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("cutscene.png"))
	get_tree().quit()
