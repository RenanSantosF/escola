extends Node
## Capturas do menu da mochila. Uso: ... res://tests/capture_profile.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.profile_menu == null:
		await get_tree().process_frame
	main._start_game()
	SaveManager.section("player")["coins"] = 300
	for i in 90:
		await get_tree().process_frame
	var pm: ProfileMenu = main.profile_menu
	pm.open_menu()
	pm._cat = "skin"
	pm._selected = "skin_ninja"
	pm._selected = "cam_laranja"
	pm._refresh()
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("loja.png"))
	pm._tab = "colecoes"
	pm._refresh()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("colecoes.png"))
	get_tree().quit()
