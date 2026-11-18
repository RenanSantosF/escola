extends Node
## Fotos da loja nova, da vitrine e do passe. --out=DIR
var out_dir := "user://"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	while GameManager.player == null:
		await get_tree().process_frame
	for i in 5:
		await get_tree().process_frame
	main._start_game()
	for i in 20:
		await get_tree().process_frame
	GameManager.add_rewards(5000, 3000)
	var pm: ProfileMenu = main.hud.profile_menu if "profile_menu" in main.hud else get_tree().root.find_children("*", "ProfileMenu", true, false)[0]
	pm.open_tab("loja")
	pm._cat = "destaques"
	pm._refresh()
	await _snap("loja_destaques")
	pm._cat = "diamantes"
	pm._refresh()
	await _snap("loja_diamantes")
	pm._cat = "kart"
	pm._refresh()
	await _snap("loja_karts")
	var sc0 := ItemShowcase.open(pm, pm, "skin_princesa")
	await _snap("vitrine_princesa", 50)
	sc0.queue_free()
	pm._cat = "emote"
	pm._refresh()
	await _snap("loja_emojis")
	pm._cat = "skin"
	pm._refresh()
	await _snap("loja_skins")
	var sc := ItemShowcase.open(pm, pm, "skin_galaxia")
	await _snap("vitrine_skin", 40)
	sc.queue_free()
	sc = ItemShowcase.open(pm, pm, "emo_robot")
	await _snap("vitrine_emoji", 70)
	sc.queue_free()
	RecessPass.add_xp(1700)
	pm.open_tab("passe")
	await _snap("passe")
	get_tree().quit()
func _snap(n: String, frames := 25) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("s_%s.png" % n))
	print("shot ", n)
