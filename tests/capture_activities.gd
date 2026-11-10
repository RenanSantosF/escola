extends Node
## Prints das atividades de missão. Uso: ... res://tests/capture_activities.tscn -- --out=DIR

var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	main._start_game()
	await _frames(30)
	for k in ["piano", "sort", "mix", "order"]:
		var data: Dictionary = QuestSystem.QUESTS.historia_linha.steps[1].data if k == "order" else {}
		var a := QuestActivity.open(main.hud, k, data)
		await _frames(20)
		if k == "piano":
			await get_tree().create_timer(4.5).timeout
			a._press_key(int(a._song.parts[0][0]))
			a._press_key(5)
		if k == "mix":
			a._add_paint("azul")
			a._add_paint("vermelho")
		if k == "order":
			var first: String = data.items[0]
			for b in a.find_children("*", "Button", true, false):
				if (b as Button).text == first:
					a._pick_card(first, b)
		await _frames(10)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("act_%s.png" % k))
		a.queue_free()
		await _frames(3)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
