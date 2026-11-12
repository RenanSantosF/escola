extends Node
## Fotos das telas dos jogos de mesa (xadrez, pingue-pongue, velha, memória).

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
	for k in ["xadrez", "pingpong", "velha", "memoria"]:
		var t := TableGames.open(main.hud, k, func(_w): pass)
		await get_tree().create_timer(0.5).timeout
		if k == "xadrez":
			var b: Control = t._board
			for mv in [[52, 36], [12, 28], [62, 45]]:
				b.st = ChessRules.apply(b.st, mv)
			b.sel = 51
			b.targets = ChessRules.legal_moves(b.st).filter(func(m): return m[0] == 51)
			b.queue_redraw()
		elif k == "memoria":
			var m: Control = t._board
			m.shown[0] = 1
			m.shown[5] = 2
			m.shown[6] = 2
			m.queue_redraw()
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("mesa_%s.png" % k))
		t.close()
		await get_tree().process_frame
	# balão de chat em cima da cabeça
	var pl: PlayerController = GameManager.player
	var bub := ChatBubble.new()
	pl.add_child(bub)
	bub.position = Vector3(0, 2.4, 0)
	bub.show_text("Oi! Bora jogar queimada no recreio?")
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("chat_balao.png"))
	get_tree().quit()
