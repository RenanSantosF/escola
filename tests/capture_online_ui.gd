extends Node
## Prints das telas da turma (espera, Entrar, placar, guia). Dados simulados.

var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main.school_day == null:
		await get_tree().process_frame
	await _frames(5)
	main._start_game()
	await _frames(20)
	main.school_day._start_recess()
	await _frames(10)
	var op: OnlinePlay = main.minigames.online_play
	NetworkManager.my_id = "eu"
	NetworkManager.names = {"eu": "Você", "ana": "Ana_Foguete", "leo": "Leo10"}
	op.my_gid = "futebol"
	op._show_lobby({"gid": "futebol", "kind": "team", "state": "lobby", "host": "eu", "players": ["eu", "ana", "leo"], "teams": {"eu": "a", "ana": "b", "leo": "a"}, "lobbyLeft": 9})
	main.quests.guide_on = true
	main.quests._guide_btn.visible = true
	main.quests._guide_btn.text = "Guia ligado ✓"
	await _snap("ui_lobby")
	var gb: Button = main.quests._guide_btn
	print("GUIA vis=", gb.visible, " pos=", gb.position, " gpos=", gb.global_position, " size=", gb.size, " fase=", main.school_day.phase)
	var card: Control = main.hud._obj_card
	print("CARD ", card.size, " min ", card.get_combined_minimum_size())
	for c in card.find_children("*", "Control", true, false):
		if (c as Control).visible and (c as Control).get_combined_minimum_size().y > 60:
			print("  ", c.name, " ", c.get_class(), " min ", (c as Control).get_combined_minimum_size(), " ", (c as Control).size)
	op._panel.visible = false
	op.my_gid = ""
	op._chip.text = "Entrar: Futebol (Ana_Foguete e mais 1) · Ir até lá"
	op._chip.visible = true
	main.quests._invite_btn.text = "Chamar Leo10"
	main.quests._invite_btn.visible = true
	await _snap("ui_chip")
	op._chip.visible = false
	op._show_results("pontaria", {"ranking": [{"id": "eu", "score": 42}, {"id": "ana", "score": 30}, {"id": "leo", "score": 12}]})
	await _snap("ui_results")
	get_tree().quit()


func _snap(n: String) -> void:
	await _frames(15)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
