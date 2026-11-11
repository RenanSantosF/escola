class_name RoomActivity
extends Interactable
## Atividade curta numa sala que antes era só cenário (enfermaria, banheiro,
## brinquedoteca, xadrez, dança...): toca, o personagem faz a ação por alguns
## segundos e aparece o resultado. Dá XP uma vez por dia em cada atividade.

var key := ""
var anim := "interact"
var secs := 3.0
var xp := 5
var results: Array = []  ## frases do resultado (uma é sorteada); "%d" vira um número
var number_range := Vector2i(0, 0)
var _busy_p: PlayerController = null


func _ready() -> void:
	super._ready()
	interact_radius = 1.6


func can_interact(p: Node) -> bool:
	return _busy_p == null and (p as PlayerController).mode == PlayerController.Mode.FREE


func interact(player: Node) -> void:
	var p := player as PlayerController
	if p == null or _busy_p != null or p.minigame != null:
		return
	_busy_p = p
	p.input_enabled = false
	p.velocity = Vector3.ZERO
	var to := global_position - p.global_position
	if Vector2(to.x, to.z).length() > 0.1:
		p.yaw = atan2(to.x, to.z)
		p.visual.rotation.y = p.yaw
	var t := 0.0
	while t < secs:
		if not is_instance_valid(p):
			return
		if p.visual.animator.upper_action == "" and not p.visual.animator.is_playing():
			p.visual.play(anim)
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	if not is_instance_valid(p):
		return
	p.visual.stop_action()
	p.input_enabled = true
	_busy_p = null
	var txt: String = str(results.pick_random()) if not results.is_empty() else "Pronto!"
	if "%d" in txt:
		txt = txt % randi_range(number_range.x, number_range.y)
	# XP uma vez por dia em cada atividade (não dá para "farmar")
	var st: Dictionary = SaveManager.section("stats")
	var done: Dictionary = st.get("atividades_dia", {})
	var today := int(SaveManager.section("progress").get("days_completed", 0))
	if int(done.get(key, -1)) != today:
		done[key] = today
		st["atividades_dia"] = done
		GameManager.add_rewards(xp, 0)
		txt += "  (+%d XP)" % xp
		AudioManager.play_ui("reward", -6.0)
	else:
		AudioManager.play_ui("pickup", -8.0)
	GameManager.show_toast(txt)
	GameManager.add_stat("atividades_salas")
