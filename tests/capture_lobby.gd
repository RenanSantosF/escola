extends Node
## Prints do lobby: conta (primeira vez), escolha menino/menina e o lobby.

var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	SaveManager.section("online").clear()
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null or main._menu == null:
		await get_tree().process_frame
	await _secs(1.5)
	main._show_account()
	await _snap("lobby_conta")
	main._account_screen.show_gender()
	await _snap("lobby_genero")
	main._account_screen._set_gender(true)
	var sec: Dictionary = SaveManager.section("online")
	sec["token"] = "x"
	sec["registered"] = true
	sec["name"] = "Foguete_Azul"
	main._account_screen.visible = false
	main._show_menu()
	main._refresh_hello()
	await _secs(1.0)
	await _snap("lobby")
	main._open_lobby_look()
	await _secs(0.5)
	var pm = main.profile_menu
	for c in pm._content.get_children():
		pass
	pm._selected = "bone_vermelho" if ShopCatalog.get_item("bone_vermelho").size() > 0 else ""
	for it in ShopCatalog.ITEMS if "ITEMS" in ShopCatalog else []:
		if str(it.get("cat", "")) == "bone":
			pm._selected = it.id
			break
	pm._update_preview()
	await _secs(1.2)
	await _snap("lobby_visual")
	pm.close_menu()
	main._on_friends_pressed()
	await _secs(0.3)
	var om = main._online_menu
	om._refresh_t = 999.0
	om.friends = [{"id": "1", "name": "Ana_Foguete", "status": "incoming"},
		{"id": "2", "name": "Beto_Raio", "status": "friend", "online": true, "code": "4321", "players": 7},
		{"id": "3", "name": "Caio_Sol", "status": "friend", "online": false},
		{"id": "4", "name": "Duda_Lua", "status": "outgoing"}]
	om._build_list()
	await _snap("lobby_amigos")
	get_tree().quit()


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(n: String) -> void:
	await _secs(0.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
