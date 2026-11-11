extends Node

var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main._menu == null:
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	main._start_game()
	main._menu.visible = false
	var gen := ClassroomTasks.new(5, 3)
	var ui: ClassroomUI = main.school_day.classroom_ui
	for t in ["quiz", "math", "order", "match", "word"]:
		var task := gen.make(t, "Ciências")
		ui.show_task(task, 1, 7, [true])
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("task_%s.png" % t))
		ui.hide_panel()
	get_tree().quit()
