extends Node
## Foto do mapa aberto (pista do kart em volta da escola). --out=DIR
var out_dir := "user://"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.hud == null:
		await get_tree().process_frame
	main._start_game()
	for i in 60:
		await get_tree().process_frame
	main.hud.minimap.open_full(true)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("mapa.png"))
	main.hud.minimap.open_full(false)
	GameManager.player.global_position = Vector3(-80, 0.1, 60)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("minimapa.png"))
	get_tree().quit()
