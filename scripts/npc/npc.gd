class_name NPC
extends CharacterBody3D
## Personagem não jogável (alunos e adultos). Movimento cinemático por
## caminhos do NavGraph (sem física pesada), separação entre vizinhos,
## sentar/levantar, falas em balão e conversa com o jogador.
## O NPCManager chama tick() e controla o LOD de animação.

signal arrived(npc: NPC)

var data: Dictionary = {}
var manager: Node
var visual: CharacterVisual
var role := "student"
var personality := "comum"
var display_name := ""

var yaw := 0.0
var walk_speed := 1.6
var run_speed := 4.3
var running := false
var path: PackedVector3Array = []
var path_i := 0
var moving := false
var seat: Seat = null
var sitting := false
var activity := ""  # atividade atual (definida pelo manager)
var activity_data := {}
var look_at_target: Variant = null  # Vector3 para onde olhar parado
var separation := Vector3.ZERO
var interact_radius := 1.5
var talking_to_player := false
var active := true

var _speech: Label3D
var _speech_t := 0.0
var _hop_t := -1.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _prev_yaw := 0.0
var _cur_speed := 0.0
var _pending_seat: Seat = null
var _on_arrive: Callable
var _seat_tween: Tween


func setup(entry: Dictionary, mgr: Node) -> void:
	data = entry
	manager = mgr
	role = entry.get("role", "student")
	personality = entry.get("personality", role)
	display_name = entry.get("name", "Aluno")
	name = "NPC_" + str(entry.get("id", "x"))
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.27
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	visual = CharacterVisual.new()
	visual.appearance = NPCRoster.appearance_for(entry)
	visual.manual_update = true
	add_child(visual)
	visual.action_finished.connect(_on_action_finished)
	if role != "student":
		walk_speed = 1.35
		run_speed = 3.0
	elif personality == "agitado":
		walk_speed = 1.9
	_speech = Label3D.new()
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.font = UITheme.bold_font()
	_speech.font_size = 44
	_speech.pixel_size = 0.0055
	_speech.outline_size = 16
	_speech.modulate = Color("1f2a44")
	_speech.outline_modulate = Color(1, 1, 1, 0.95)
	_speech.position = Vector3(0, 2.15 * visual.appearance.height_scale, 0)
	_speech.no_depth_test = false
	_speech.fixed_size = false
	_speech.visible = false
	_speech.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_speech)
	add_to_group("npc")
	add_to_group("interactable")


func _ready() -> void:
	yaw = rotation.y
	rotation = Vector3.ZERO
	visual.rotation.y = yaw
	_prev_yaw = yaw
	_last_pos = global_position


# ------------------------------------------------------------- interface

func set_active(on: bool) -> void:
	active = on
	visible = on
	collision_layer = 4 if on else 0
	if on:
		add_to_group("interactable")
	elif is_in_group("interactable"):
		remove_from_group("interactable")


## Sai do assento imediatamente (sem animação/tween).
func force_unseat() -> void:
	if _seat_tween and _seat_tween.is_valid():
		_seat_tween.kill()
	if seat:
		seat.release()
	seat = null
	sitting = false
	_pending_seat = null
	visual.stop_action(false)
	visual.stop_upper(false)


func teleport(pos: Vector3, yaw_rad := 0.0) -> void:
	if sitting or (_seat_tween and _seat_tween.is_valid()):
		force_unseat()
	global_position = pos
	yaw = yaw_rad
	visual.rotation.y = yaw
	_prev_yaw = yaw
	path = PackedVector3Array()
	moving = false


func go_to(target: Vector3, run := false, on_arrive := Callable()) -> void:
	if sitting:
		_leave_seat()
	_pending_seat = null
	running = run
	_on_arrive = on_arrive
	path = manager.nav.path(global_position, target) if manager and manager.nav else PackedVector3Array([target])
	path_i = 0
	moving = true
	_stuck_t = 0.0
	look_at_target = null


func stop() -> void:
	moving = false
	path = PackedVector3Array()


func sit_on(s: Seat, run := false) -> void:
	if s == null:
		return
	if s.occupant != null and s.occupant != self:
		return
	s.occupy(self)
	go_to(s.global_position - s.global_basis.z * 0.0 + s.global_basis.z * 0.55, run)
	_pending_seat = s


func stand_up() -> void:
	if sitting:
		_leave_seat()


func _leave_seat() -> void:
	sitting = false
	visual.stop_upper()
	visual.play("stand_up")
	if seat:
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var out := seat.global_position + fwd * 0.45
		seat.release()
		seat = null
		_seat_tween = create_tween()
		_seat_tween.tween_interval(0.35)
		_seat_tween.tween_property(self, "global_position", out, 0.3)


func say(text: String, duration := 2.6) -> void:
	_speech.text = text
	_speech.visible = true
	_speech_t = duration


func hush() -> void:
	_speech.visible = false
	_speech_t = 0.0


func hop() -> void:
	_hop_t = 0.0


func face(point: Vector3) -> void:
	look_at_target = point


func is_busy_animating() -> bool:
	return visual.animator.is_playing() and not sitting


# ------------------------------------------------------------- interação

func interact_point() -> Vector3:
	return global_position


func get_prompt(player: Node) -> String:
	if manager and manager.has_method("npc_prompt"):
		var p: String = manager.npc_prompt(self, player)
		if p != "":
			return p
	return "Conversar com %s" % display_name


func can_interact(_player: Node) -> bool:
	return active and not talking_to_player


func interact(player: Node) -> void:
	if manager and manager.has_method("on_npc_interact"):
		manager.on_npc_interact(self, player)


func on_hit_by_object(obj: Node) -> void:
	if manager and manager.has_method("on_npc_hit_by_object"):
		manager.on_npc_hit_by_object(self, obj)


func lines_for_talk() -> Array:
	var lines: Array = NPCRoster.talk_lines(personality).duplicate()
	if role == "student":
		var lv := Friendship.level(data.get("id", ""))
		if lv >= 4:
			lines.push_front("Meu melhor amigo! Bora fazer alguma coisa juntos?")
		elif lv >= 2:
			lines.push_front(["E aí, parceiro!", "Opa, chegou quem faltava!", "Oi de novo!"].pick_random())
	return lines


# ------------------------------------------------------------- atualização

## Chamado pelo manager no physics_process.
func tick(delta: float) -> void:
	if _speech_t > 0.0:
		_speech_t -= delta
		if _speech_t <= 0.0:
			_speech.visible = false
	var speed := 0.0
	if moving and not path.is_empty():
		var target := path[path_i]
		var to := target - global_position
		to.y = 0.0
		var d := to.length()
		var final := path_i == path.size() - 1
		if d < (0.25 if final else 0.6):
			path_i += 1
			if path_i >= path.size():
				_arrive()
				return
			# suaviza: pula pontos intermediários com linha de visão livre
			if manager and manager.nav:
				var tries := 0
				while path_i < path.size() - 1 and tries < 3 and manager.nav.is_clear(global_position, path[path_i + 1]):
					path_i += 1
					tries += 1
			return
		var spd := run_speed if running else walk_speed
		if final and d < 1.2:
			spd = minf(spd, maxf(d * 1.6, 0.6))
		var dir := to / d
		var vel := dir * spd + separation
		global_position += vel * delta
		global_position.y = target.y if final else global_position.y
		yaw = lerp_angle(yaw, atan2(vel.x, vel.z), 1.0 - exp(-8.0 * delta))
		speed = spd
		# destrava se ficar parado tempo demais
		_stuck_t += delta
		if _stuck_t > 0.8:
			if global_position.distance_to(_last_pos) < 0.3:
				global_position += dir * 0.6
			_last_pos = global_position
			_stuck_t = 0.0
	else:
		if separation.length() > 0.05 and not sitting:
			global_position += separation * delta * 0.6
		if look_at_target != null and not sitting:
			var lt: Vector3 = look_at_target
			var to2 := lt - global_position
			if Vector2(to2.x, to2.z).length() > 0.1:
				yaw = lerp_angle(yaw, atan2(to2.x, to2.z), 1.0 - exp(-5.0 * delta))
	_cur_speed = lerpf(_cur_speed, speed, 1.0 - exp(-10.0 * delta))
	visual.rotation.y = yaw
	# pulinhos (amarelinha / comemoração)
	if _hop_t >= 0.0:
		_hop_t += delta
		var k := _hop_t / 0.42
		visual.position.y = sin(PI * clampf(k, 0, 1)) * 0.28
		if k >= 1.0:
			_hop_t = -1.0
			visual.position.y = 0.0
	var anim := visual.animator
	anim.speed = _cur_speed
	anim.grounded = _hop_t < 0.0
	anim.vertical_velocity = 2.0 if _hop_t >= 0.0 and _hop_t < 0.2 else -2.0
	var dyaw := wrapf(yaw - _prev_yaw, -PI, PI)
	anim.yaw_rate = dyaw / maxf(delta, 0.0001)
	_prev_yaw = yaw


func _arrive() -> void:
	moving = false
	path = PackedVector3Array()
	if _pending_seat:
		var s := _pending_seat
		_pending_seat = null
		seat = s
		sitting = true
		_seat_tween = create_tween().set_parallel(true)
		var tw := _seat_tween
		tw.tween_property(self, "global_position", s.global_position, 0.35)
		var ty := s.global_rotation.y
		tw.tween_method(func(v: float): yaw = v, yaw, yaw + wrapf(ty - yaw, -PI, PI), 0.35)
		visual.play("sit_down")
	arrived.emit(self)
	if _on_arrive.is_valid():
		var cb := _on_arrive
		_on_arrive = Callable()
		cb.call()


func _on_action_finished(_a: String) -> void:
	pass
