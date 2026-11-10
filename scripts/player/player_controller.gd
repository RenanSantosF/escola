class_name PlayerController
extends CharacterBody3D
## Controle do personagem principal: movimento relativo à câmera com
## aceleração/desaceleração, giro suave, corrida, pulo, interação,
## sentar/levantar, pegar/arremessar, chutar bola e emotes.

signal context_changed(interact_label: String, play_label: String)
signal emote_started(emote: String)
signal sat(seat: Seat)
signal stood
signal picked_up(item: Node)

enum Mode { FREE, SITTING, BUSY }

@export var walk_speed := 2.0
@export var run_speed := 5.0
@export var acceleration := 12.0
@export var deceleration := 16.0
@export var air_control := 3.0
@export var turn_speed := 11.0
@export var jump_velocity := 4.4
@export var gravity := 13.0

var visual: CharacterVisual
var camera_rig: Node3D
var controls: Node  # MobileControls (opcional)
var world: Node  # SchoolWorld (opcional)

var mode := Mode.FREE
var yaw := 0.0
var run_active := false
## Direção forçada (mundo) usada por minijogos como a corrida.
var forced_dir := Vector3.ZERO
var input_enabled := true
## Minijogo ativo: recebe os botões antes do comportamento padrão.
var minigame: Node = null
## Trava só o deslocamento (o minijogo lê o joystick para mirar).
var movement_locked := false
## Veículo equipado ("" / skate / patinete / bike) e se está montado.
var vehicle := ""
var riding := false
var _vehicle_node: VehicleVisual
const VEHICLE_SPEED := {"skate": 7.0, "patinete": 7.6, "bike": 9.5}
var current_seat: Seat = null
var held_item: PickupItem = null
var nearby: Node = null
var nearby_ball: KickBall = null

var _prev_yaw := 0.0
var _prev_speed := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _bonk_cd := 0.0
var _scan_timer := 0.0
var _idle_time := 0.0
var _busy_action := ""
var _busy_target: Node = null
var _last_interact_label := ""
var _last_play_label := ""
var _air_time := 0.0
var _stop_timer := 0.0
var _npc_bump_cd := {}


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46.0)
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.62
	cs.shape = cap
	cs.position = Vector3(0, 0.81, 0)
	add_child(cs)
	visual = CharacterVisual.new()
	visual.name = "Visual"
	var app_dict: Dictionary = SaveManager.section("player").get("appearance", {})
	visual.appearance = CharacterAppearance.from_dict(app_dict) if not app_dict.is_empty() else CharacterAppearance.new()
	add_child(visual)
	visual.action_event.connect(_on_action_event)
	visual.action_finished.connect(_on_action_finished)
	visual.footstep.connect(_on_footstep)
	visual.animator.max_walk_speed = walk_speed
	visual.animator.max_run_speed = run_speed
	yaw = rotation.y
	rotation = Vector3.ZERO
	visual.rotation.y = yaw
	_prev_yaw = yaw
	GameManager.player = self


func _physics_process(delta: float) -> void:
	_bonk_cd = maxf(_bonk_cd - delta, 0.0)
	var move := _read_move_input() if input_enabled and GameManager.is_playing() and not movement_locked else Vector2.ZERO

	match mode:
		Mode.SITTING:
			velocity = Vector3.ZERO
			visual.rotation.y = yaw
			if move.length() > 0.5 and visual.animator.is_holding():
				stand_up()
			_update_animator(delta, 0.0)
			return
		Mode.BUSY:
			move = Vector2.ZERO

	# Direção desejada relativa à câmera
	var cam_yaw: float = camera_rig.get_yaw() if camera_rig and camera_rig.has_method("get_yaw") else 0.0
	var wish := Vector3(move.x, 0, move.y).rotated(Vector3.UP, cam_yaw)
	if forced_dir != Vector3.ZERO and mode == Mode.FREE:
		# corrida: segue a raia; o joystick só corrige para os lados
		var side := Vector3(-forced_dir.z, 0, forced_dir.x)
		var raw := _read_move_input() if input_enabled else Vector2.ZERO
		var rel := Vector3(raw.x, 0, raw.y).rotated(Vector3.UP, cam_yaw)
		wish = (forced_dir + side * rel.dot(side) * 0.35).normalized()
		run_active = true
	var mag := clampf(wish.length(), 0.0, 1.0)
	if mag < 0.1:
		_stop_timer += delta
	else:
		_stop_timer = 0.0
	var running := (run_active or Input.is_action_pressed("run")) and mag > 0.5
	var target_speed := mag * (run_speed if running else walk_speed)
	if riding:
		target_speed = mag * VEHICLE_SPEED.get(vehicle, 7.0)
		if world and world.get("player_indoor"):
			toggle_ride()
			GameManager.show_toast("Desceu: dentro dos prédios é a pé!")
	var target_vel := wish.normalized() * target_speed if mag > 0.01 else Vector3.ZERO

	# Aceleração horizontal
	var hv := Vector3(velocity.x, 0, velocity.z)
	var rate := acceleration if target_vel.length() > hv.length() else deceleration
	if not is_on_floor():
		rate = air_control
	hv = hv.move_toward(target_vel, rate * delta * maxf(target_speed, walk_speed))
	velocity.x = hv.x
	velocity.z = hv.z

	# Giro suave para a direção do movimento
	if mag > 0.1:
		var target_yaw := atan2(wish.x, wish.z)
		var k := 1.0 - exp(-(turn_speed * (0.45 if riding else 1.0)) * delta)
		yaw = lerp_angle(yaw, target_yaw, k)
		_idle_time = 0.0
	visual.rotation.y = yaw

	# Gravidade e pulo
	if is_on_floor():
		if _air_time > 0.45:
			Effects.burst(global_position + Vector3(0, 0.05, 0), "dust")
		_coyote = 0.12
		_air_time = 0.0
	else:
		_coyote -= delta
		_air_time += delta
		velocity.y -= gravity * delta
	_jump_buffer -= delta
	if _jump_buffer > 0.0 and _coyote > 0.0 and mode == Mode.FREE:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		if visual.animator.is_playing():
			visual.stop_action()

	var pre_vel := velocity
	move_and_slide()
	_check_bump(pre_vel)
	_push_ball(delta)

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_scan_interactables()

	# Para emotes de corpo inteiro se o jogador sair andando
	if mode == Mode.FREE and mag > 0.3 and visual.animator.is_playing() and not _is_upper_action(visual.animator.action):
		visual.stop_action()

	# Animações ociosas variadas
	if mode == Mode.FREE and hv.length() < 0.1 and is_on_floor() and not visual.animator.is_playing():
		_idle_time += delta
		if _idle_time > 9.0:
			_idle_time = -randf_range(4.0, 8.0)
			visual.play(["look_around", "stretch", "scratch_head"].pick_random())
	_update_animator(delta, Vector3(velocity.x, 0, velocity.z).length())
	if riding and _vehicle_node:
		_vehicle_node.spin(Vector3(velocity.x, 0, velocity.z).length(), delta)
		visual.position.y = 0.075 if vehicle != "bike" else 0.0


func _is_upper_action(a: String) -> bool:
	return ActionLibrary.get_def(a).get("mask", "full") == "upper"


func _update_animator(delta: float, speed: float) -> void:
	var anim := visual.animator
	anim.speed = speed
	anim.grounded = is_on_floor() or mode == Mode.SITTING or _air_time < 0.08
	anim.vertical_velocity = velocity.y
	var dyaw := wrapf(yaw - _prev_yaw, -PI, PI)
	anim.yaw_rate = dyaw / maxf(delta, 0.0001)
	anim.forward_accel = (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_yaw = yaw
	_prev_speed = speed


func _read_move_input() -> Vector2:
	var v := Vector2.ZERO
	if controls and controls.has_method("get_move_vector"):
		v = controls.get_move_vector()
	# digitando no chat: as teclas não andam com o personagem
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return v.limit_length(1.0)
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if kb.length() > v.length():
		v = kb
	return v.limit_length(1.0)


# ------------------------------------------------------------- entradas

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_playing() or not input_enabled:
		return
	if event.is_action_pressed("jump"):
		request_jump()
	elif event.is_action_pressed("interact"):
		request_interact()
	elif event.is_action_pressed("play"):
		request_play()
	elif event.is_action_released("play"):
		request_play_release()
	elif event.is_action_released("interact"):
		request_interact_release()
	elif event.is_action_pressed("emote"):
		emote("wave")


func set_vehicle(kind: String) -> void:
	if riding:
		toggle_ride()
	vehicle = kind
	if controls and controls.has_method("set_ride_available"):
		controls.set_ride_available(kind != "")


func toggle_ride() -> void:
	if vehicle == "":
		return
	if not riding:
		if mode != Mode.FREE or minigame != null:
			return
		if world and world.get("player_indoor"):
			GameManager.show_toast("Não pode andar de %s dentro dos prédios!" % vehicle.replace("bike", "bicicleta"))
			return
		riding = true
		_vehicle_node = VehicleVisual.create(vehicle)
		visual.add_child(_vehicle_node)
		visual.animator.ride_mode = 2 if vehicle == "bike" else 1
		AudioManager.play_ui("pickup", -4.0)
	else:
		riding = false
		if _vehicle_node:
			_vehicle_node.queue_free()
			_vehicle_node = null
		visual.animator.ride_mode = 0
		visual.position.y = 0.0


func read_move_raw() -> Vector2:
	return _read_move_input()


func request_jump() -> void:
	if minigame and minigame.on_jump():
		return
	if mode == Mode.SITTING:
		stand_up()
		return
	_jump_buffer = 0.15


func toggle_run() -> void:
	run_active = not run_active


func request_interact() -> void:
	if minigame and minigame.on_interact():
		return
	if mode == Mode.SITTING:
		stand_up()
		return
	if mode != Mode.FREE or not is_on_floor():
		return
	if nearby and is_instance_valid(nearby) and nearby.can_interact(self):
		nearby.interact(self)
	elif held_item:
		drop_item()


func request_interact_release() -> void:
	if minigame and minigame.has_method("on_interact_release"):
		minigame.on_interact_release()


func request_play_release() -> void:
	if minigame and minigame.has_method("on_play_release"):
		minigame.on_play_release()


func request_play() -> void:
	if minigame and minigame.on_play():
		return
	if mode != Mode.FREE or not is_on_floor():
		return
	if held_item:
		_start_busy("throw", null)
	elif nearby_ball:
		_start_busy("kick", nearby_ball)
	elif _shove_target():
		_shove(_shove_target())
	else:
		emote("celebrate")


## NPC bem à frente (para empurrar).
func _shove_target() -> NPC:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	for n in get_tree().get_nodes_in_group("npc"):
		var npc := n as NPC
		if not npc.active or npc.sitting or npc.activity in ["cutscene", "minigame"]:
			continue
		var to := npc.global_position - global_position
		to.y = 0
		if to.length() < 1.25 and fwd.dot(to.normalized()) > 0.7:
			return npc
	return null


func _shove(npc: NPC) -> void:
	mode = Mode.BUSY
	_busy_action = "push"
	visual.play("push")
	var dir := (npc.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	get_tree().create_timer(0.25).timeout.connect(func():
		npc.stop()
		npc.visual.play("hit")
		var tw := npc.create_tween()
		tw.tween_property(npc, "global_position", npc.global_position + dir * 1.2, 0.35).set_ease(Tween.EASE_OUT)
		AudioManager.play_3d("bonk", npc.global_position + Vector3.UP, -6.0)
		GameManager.report_shove(npc))


func emote(name: String) -> void:
	if mode != Mode.FREE or not is_on_floor():
		return
	if visual.play(name):
		emote_started.emit(name)
		if name == "celebrate":
			AudioManager.play_3d("celebrate", global_position + Vector3.UP, -6.0, 0.02)
			Effects.burst(global_position + Vector3(0, 1.8, 0), "confetti")
		if not _is_upper_action(name):
			velocity.x = 0.0
			velocity.z = 0.0


func _start_busy(action: String, target: Node) -> void:
	mode = Mode.BUSY
	_busy_action = action
	_busy_target = target
	velocity.x *= 0.3
	velocity.z *= 0.3
	if target is Node3D:
		var to: Vector3 = (target as Node3D).global_position - global_position
		to.y = 0
		if to.length() > 0.05:
			yaw = atan2(to.x, to.z)
	visual.play(action)


# ------------------------------------------------------------- sentar

func sit_on(seat: Seat) -> void:
	if mode == Mode.FREE and seat.occupant != null:
		seat.free_for_owner()
	if mode != Mode.FREE or seat.occupant != null:
		return
	if riding:
		toggle_ride()
	mode = Mode.SITTING
	current_seat = seat
	seat.occupy(self)
	velocity = Vector3.ZERO
	collision_mask = 0
	var target_pos := seat.global_position
	var target_yaw := seat.global_rotation.y
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", target_pos, 0.35)
	tw.tween_method(func(v: float): yaw = v, yaw, yaw + wrapf(target_yaw - yaw, -PI, PI), 0.35)
	visual.play("sit_down")
	GameManager.add_stat("sits")
	get_tree().create_timer(0.4).timeout.connect(func():
		if mode == Mode.SITTING and current_seat == seat:
			sat.emit(seat))


func stand_up() -> void:
	if mode != Mode.SITTING or visual.animator.is_playing("stand_up"):
		return
	visual.play("stand_up")


func _finish_stand() -> void:
	mode = Mode.FREE
	if current_seat:
		current_seat.release()
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var out := global_position + fwd * 0.35
	out.y = maxf(out.y, 0.02)
	current_seat = null
	var tw := create_tween()
	tw.tween_property(self, "global_position", out, 0.15)
	tw.tween_callback(func(): collision_mask = 1 | 4 | 8)
	stood.emit()


## Levanta imediatamente (troca de dia, teleporte).
func force_stand() -> void:
	if current_seat:
		current_seat.release()
	current_seat = null
	mode = Mode.FREE
	visual.stop_action(false)
	collision_mask = 1 | 4 | 8


# ------------------------------------------------------------- bebedouro

func use_fountain(f: WaterFountain) -> void:
	if mode != Mode.FREE:
		f.stop_water()
		return
	var target := f.global_position
	target.y = global_position.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", target, 0.25)
	var fy := f.global_rotation.y
	tw.tween_method(func(v: float): yaw = v, yaw, yaw + wrapf(fy - yaw, -PI, PI), 0.25)
	_start_busy("drink", f)


# ------------------------------------------------------------- objetos

func pick_up(item: PickupItem) -> void:
	if held_item or mode != Mode.FREE:
		return
	_start_busy("pickup", item)


func drop_item() -> void:
	if held_item == null:
		return
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	held_item.throw_from(_world_parent(), visual.hand_position(), fwd * 0.5)
	held_item = null
	_emit_context(true)


func _world_parent() -> Node:
	return world.get_node("Dynamic") if world and world.has_node("Dynamic") else get_parent()


func _on_action_event(action: String, event: String) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	match [action, event]:
		["kick", "impact"]:
			var ball := _busy_target as KickBall
			if ball and is_instance_valid(ball) and ball.global_position.distance_to(global_position + fwd * 0.4) < 1.0:
				var power := 9.5 if _prev_speed > walk_speed + 0.5 else 7.5
				ball.kick(fwd, power, 2.6)
				Effects.burst(ball.global_position, "dust")
				GameManager.add_stat("kicks")
				if camera_rig and camera_rig.has_method("shake"):
					camera_rig.shake(0.05)
			else:
				AudioManager.play_3d("whoosh", global_position + Vector3.UP * 0.4, -10.0)
		["throw", "release"]:
			if held_item:
				var item := held_item
				held_item = null
				item.thrower = self
				var aim := fwd
				var vel := aim * 11.0 + Vector3.UP * 3.2
				item.throw_from(_world_parent(), visual.hand_position() + fwd * 0.15, vel + Vector3(velocity.x, 0, velocity.z) * 0.5)
				AudioManager.play_3d("whoosh", global_position + Vector3.UP, -4.0)
				GameManager.add_stat("throws")
				_emit_context(true)
		["pickup", "grab"]:
			var it := _busy_target as PickupItem
			if it and is_instance_valid(it) and it.held_by == null and it.global_position.distance_to(global_position) < 2.0:
				it.attach_to(visual.hand_slot(), self)
				held_item = it
				picked_up.emit(it)
				AudioManager.play_3d("pickup", global_position + Vector3.UP, -4.0)
				_emit_context(true)
		["drink", "use"]:
			var f := _busy_target as WaterFountain
			if f:
				f.start_water()


func _on_action_finished(action: String) -> void:
	match action:
		"stand_up":
			_finish_stand()
		"kick", "throw", "pickup", "drink", "hit", "push":
			if action == "drink" and _busy_target is WaterFountain:
				(_busy_target as WaterFountain).stop_water()
			if mode == Mode.BUSY:
				mode = Mode.FREE
			_busy_target = null
			_busy_action = ""


# ------------------------------------------------------------- colisões

## Detecta trombadas em paredes/objetos quando correndo (reação cômica).
func _check_bump(pre_vel: Vector3) -> void:
	if mode != Mode.FREE:
		return
	var hspeed := Vector2(pre_vel.x, pre_vel.z).length()
	# esbarrões em outros personagens (acidental andando / forte correndo)
	for i in get_slide_collision_count():
		var npc := get_slide_collision(i).get_collider() as NPC
		if npc and hspeed > 0.6:
			var key := npc.get_instance_id()
			if _npc_bump_cd.get(key, 0.0) < Time.get_ticks_msec() * 0.001:
				_npc_bump_cd[key] = Time.get_ticks_msec() * 0.001 + 2.0
				if npc.manager:
					npc.manager.on_player_bump(npc, hspeed)
				if hspeed > run_speed * 0.8:
					velocity.x *= -0.3
					velocity.z *= -0.3
	if _bonk_cd > 0.0:
		return
	if hspeed < run_speed * 0.85:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) > 0.5:
			continue
		var hv := Vector3(pre_vel.x, 0, pre_vel.z).normalized()
		if col.get_collider() is NPC:
			continue
		if hv.dot(-Vector3(n.x, 0, n.z).normalized()) > 0.75:
			_bonk(n)
			return


func _bonk(normal: Vector3) -> void:
	_bonk_cd = 2.0
	mode = Mode.BUSY
	_busy_action = "hit"
	velocity = Vector3(normal.x, 0, normal.z) * 2.5 + Vector3.UP * 1.5
	run_active = false
	visual.play("hit")
	AudioManager.play_3d("bonk", global_position + Vector3.UP * 1.5, -2.0)
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(0.18)
	GameManager.show_toast("Ai! Cuidado por onde corre!")


func on_hit_by_object(_obj: Node) -> void:
	if mode == Mode.FREE and _bonk_cd <= 0.0:
		_bonk_cd = 1.0
		visual.play("hit")


## Condução de bola: encostar nela a empurra para frente.
func _push_ball(_delta: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() < 0.5:
		return
	for b in get_tree().get_nodes_in_group("ball"):
		var ball := b as KickBall
		var to := ball.global_position - global_position
		to.y = 0
		var d := to.length()
		if d < 0.28 + ball.radius + 0.12 and to.normalized().dot(hv.normalized()) > 0.3:
			var push_dir := (to.normalized() * 0.4 + hv.normalized() * 0.6).normalized()
			var rel := hv.length() - Vector3(ball.linear_velocity.x, 0, ball.linear_velocity.z).dot(push_dir)
			if rel > 0.0:
				ball.nudge(push_dir, rel * 1.25)


# ------------------------------------------------------------- interativos

func _scan_interactables() -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var best: Node = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		if n == held_item or not n.has_method("interact_point"):
			continue
		var p: Vector3 = n.interact_point()
		var to := p - global_position
		if absf(to.y) > 1.8:
			continue
		to.y = 0
		var d := to.length()
		var radius: float = n.interact_radius
		if d > radius:
			continue
		var facing := fwd.dot(to.normalized()) if d > 0.1 else 1.0
		if facing < -0.3:
			continue
		if not n.can_interact(self):
			continue
		var score := d - facing * 0.4
		# a MINHA carteira sempre ganha de bolinhas/objetos em volta
		if n.has_meta("my_desk"):
			score -= 1.5
		if score < best_score:
			best_score = score
			best = n
	nearby = best
	# bola mais próxima à frente
	nearby_ball = null
	var best_ball := 1.6
	for b in get_tree().get_nodes_in_group("ball"):
		var to: Vector3 = b.global_position - global_position
		if absf(to.y) > 1.2:
			continue
		to.y = 0
		var d := to.length()
		if d < best_ball and (d < 0.7 or fwd.dot(to.normalized()) > 0.2):
			best_ball = d
			nearby_ball = b
	_emit_context()


func _emit_context(force := false) -> void:
	var il := ""
	var pl := ""
	if mode == Mode.SITTING:
		il = "Levantar"
	elif nearby and is_instance_valid(nearby):
		il = nearby.get_prompt(self)
	elif held_item:
		il = "Soltar"
	if held_item:
		pl = "Arremessar"
	elif nearby_ball:
		pl = "Chutar"
	elif _shove_target():
		pl = "Empurrar"
	else:
		pl = "Comemorar"
	if minigame:
		var mil: String = minigame.interact_label()
		var mpl: String = minigame.play_label()
		if mil != "":
			il = mil
		if mpl != "":
			pl = mpl
	if force or il != _last_interact_label or pl != _last_play_label:
		_last_interact_label = il
		_last_play_label = pl
		context_changed.emit(il, pl)


func _on_footstep(_side: int) -> void:
	var surface := "hard"
	if world and world.has_method("surface_at"):
		surface = world.surface_at(global_position)
	var snd := "step_grass" if surface in ["grass", "dirt"] else "step_hard"
	var vol := -14.0 if _prev_speed < walk_speed + 0.5 else -9.0
	AudioManager.play_3d(snd, global_position, vol, 0.12)


func set_appearance(a: CharacterAppearance) -> void:
	visual.set_appearance(a)
	SaveManager.section("player")["appearance"] = a.to_dict()
