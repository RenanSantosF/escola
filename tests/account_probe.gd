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
	var nick := "Probe_%d" % (randi() % 900 + 100)
	var chk: Dictionary = await AccountManager.check_name(nick)
	var bad: Dictionary = await AccountManager.check_name("idiota")
	var names := [nick] if chk.available and not bad.available else []
	var reg: Dictionary = await AccountManager.signup(nick, "senha123", 10)
	SaveManager.section("player")["coins"] = 4321
	SaveManager.save_game()
	AccountManager.upload_progress()
	for i in 80:
		await get_tree().create_timer(0.1).timeout
		if not AccountManager.is_uploading():
			break
	var code := ""
	# outro celular: sem token e com save zerado
	SaveManager.section("online").clear()
	SaveManager.section("player")["coins"] = 0
	SaveManager.data["saved_at"] = 0  # celular novo: nunca salvou
	var rec: Dictionary = await AccountManager.login(nick.to_lower(), "senha123")
	var coins := int(SaveManager.section("player").get("coins", 0))
	print("names=", names.size(), " registered=", reg.get("ok"), " recovered=", rec.get("ok"), " imported=", rec.get("imported"), " coins=", coins, " nick=", AccountManager.nickname())
	var ok: bool = names.size() == 1 and reg.get("ok", false) and rec.get("ok", false) and coins == 4321 and AccountManager.nickname() == names[0]
	print("ACCOUNT_PROBE ", "OK" if ok else "FALHOU")
	get_tree().quit(0 if ok else 1)
