extends Node
## Fotos: castigo no banco do hall (botão de vídeo) e loja com item por vídeo.

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
	await get_tree().create_timer(1.0).timeout
	main.school_day._start_recess()
	var mock = load("res://tests/mock_ads_provider.gd").new()
	AdsManager.enabled = true
	AdsManager.register_provider(mock)
	main.discipline._do_consequence(3)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("castigo_banco.png"))
	main.discipline._end_bench("")
	main.profile_menu.open_tab("loja")
	main.profile_menu._selected = "dec_estojo"
	main.profile_menu._refresh()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("loja_video.png"))
	main.profile_menu.close_menu()
	UpdateScreen.show_required("")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("atualizar.png"))
	get_tree().quit()
