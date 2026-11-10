extends Node
## Ponta a ponta das contas: cria conta, sobe progresso, "troca de celular"
## (apaga o token) e recupera com o código — o progresso volta.
## Uso: servidor local e godot --headless --path . res://tests/account_probe.tscn -- --url=ws://127.0.0.1:8135


func _ready() -> void:
	var url := "ws://127.0.0.1:8135"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			url = a.substr(6)
	Settings.set_value("server_url", url, false)
	SaveManager.section("online").clear()
	var names: Array = await AccountManager.fetch_names()
	var reg: Dictionary = await AccountManager.register(names[0], 10)
	SaveManager.section("player")["coins"] = 4321
	SaveManager.save_game()
	AccountManager.upload_progress()
	for i in 600:
		await get_tree().process_frame
		if not AccountManager.is_uploading():
			break
	var code := str(reg.get("code", ""))
	# outro celular: sem token e com save zerado
	SaveManager.section("online").clear()
	SaveManager.section("player")["coins"] = 0
	var rec: Dictionary = await AccountManager.recover(code)
	var coins := int(SaveManager.section("player").get("coins", 0))
	print("names=", names.size(), " registered=", reg.get("ok"), " recovered=", rec.get("ok"), " imported=", rec.get("imported"), " coins=", coins, " nick=", AccountManager.nickname())
	var ok: bool = names.size() == 6 and reg.get("ok", false) and rec.get("ok", false) and coins == 4321 and AccountManager.nickname() == names[0]
	print("ACCOUNT_PROBE ", "OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)
