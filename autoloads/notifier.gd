extends Node
## Notificações (plugin RecessNotify do android_plugin):
##  • quando o jogo vai para segundo plano, agenda lembretes carinhosos para
##    voltar (no dia seguinte, em 3 dias e prêmio do passe esperando);
##    voltou para o jogo = cancela;
##  • "fulano está jogando agora!": com o jogo fechado, o Android pergunta ao
##    servidor de tempos em tempos; com o jogo aberto, aparece um aviso na tela.
## Dá para desligar em Configurações ("Notificações").

const ID_TOMORROW := 11
const ID_3DAYS := 12
const ID_PASS := 13

var _api: Object = null
var _asked := false


func _ready() -> void:
	if Engine.has_singleton("RecessNotify"):
		_api = Engine.get_singleton("RecessNotify")
		_api.set_foreground(true)
	NetworkManager.friend_online.connect(_on_friend_online)
	NetworkManager.welcomed.connect(func(_m): _sync_account())


func enabled() -> bool:
	return bool(Settings.get_value("notifications"))


## Pede a permissão (Android 13+) uma vez, depois que a criança já está jogando.
func ask_permission() -> void:
	if _api and not _asked and enabled():
		_asked = true
		_api.request_permission()


func _sync_account() -> void:
	if _api == null:
		return
	var token := str(SaveManager.section("online").get("token", ""))
	_api.set_account(NetworkManager.https_base(), token, enabled())


func _notification(what: int) -> void:
	if _api == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_api.set_foreground(false)
		if enabled():
			_schedule_reminders()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_api.set_foreground(true)
		for id in [ID_TOMORROW, ID_3DAYS, ID_PASS]:
			_api.cancel(id)


func _schedule_reminders() -> void:
	var name := str(SaveManager.section("player").get("name", ""))
	var hi := ("%s, " % name) if name != "" else ""
	_api.schedule(ID_TOMORROW, "O recreio está te esperando!", hi + "seus amigos já estão na quadra. Vem brincar!", 22 * 3600)
	_api.schedule(ID_3DAYS, "Sentimos sua falta no Recess Club", "Tem corrida de kart, montanha-russa e muitas brincadeiras novas!", 3 * 24 * 3600)
	if RecessPass.pending() > 0:
		_api.schedule(ID_PASS, "Prêmio esperando por você!", "Você tem %d prêmio(s) do Passe do Recreio para pegar." % RecessPass.pending(), 6 * 3600)


## Amigo entrou: aviso na tela (com o jogo aberto).
func _on_friend_online(id: String, name: String, code: String) -> void:
	if not enabled() or name == "":
		return
	GameManager.show_toast("Seu amigo %s acabou de entrar no jogo!" % name)
	AudioManager.play_ui("ui_confirm", -6.0)
	id = id
	code = code
