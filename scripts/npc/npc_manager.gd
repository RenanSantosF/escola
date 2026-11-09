class_name NPCManager
extends Node3D
## Gerencia todos os NPCs: pool (criados uma vez, ativados quando
## necessários), LOD de animação, separação, rotinas por fase do dia e as
## atividades do recreio (futebol, fila da cantina, pega-pega, bolinha de
## gude, amarelinha, balanço, conversas, bancos, passeios).

signal dialogue_requested(npc: NPC, lines: Array)
signal npc_bumped(npc: NPC, intensity: float)

const CLASS_ROOM := "Sala 5"
const COUNTS := {0: [12, 6], 1: [16, 12], 2: [20, 20]}  # qualidade -> [colegas, outras turmas]
const VIS_RANGE := {0: 45.0, 1: 65.0, 2: 90.0}
const PATIO := Rect2(-58, -24, 116, 46)
const COURT := Rect2(20, -59, 40, 20)

var world: SchoolWorld
var nav: NavGraph
var player: Node3D
var day: Node  # SchoolDay (opcional)
var rng := RandomNumberGenerator.new()

var npcs: Array[NPC] = []
var classmates: Array[NPC] = []
var others: Array[NPC] = []
var teacher: NPC
var director: NPC
var inspector: NPC
var cook: NPC
var phase := ""

var room_seats := {}
var outdoor_seats: Array[Seat] = []
var swing_seats: Array[Seat] = []
var player_desk: Seat
var spots := {}
var football: KickBall
var _queue: Array[NPC] = []
var _chat_members := {}  # índice do spot -> Array[NPC]
var _think_i := 0
var _sep_frame := 0
var _bubble_t := 2.0
var _lod_t := 0.0
var _queue_t := 6.0
var _vis_range := 65.0


func setup(w: SchoolWorld, graph: NavGraph) -> void:
	world = w
	nav = graph
	rng.seed = 77
	var q := Settings.quality()
	_vis_range = VIS_RANGE[q]
	for s in w.seats:
		if s.room != "":
			if not room_seats.has(s.room):
				room_seats[s.room] = []
			room_seats[s.room].append(s)
		elif s.swing:
			swing_seats.append(s)
		elif s.global_position.y < 0.3:
			outdoor_seats.append(s)
	_pick_player_desk()
	for sp in w.builder.spots:
		var t: String = sp.type
		if not spots.has(t):
			spots[t] = []
		var e: Dictionary = sp.duplicate()
		e["taken"] = null
		spots[t].append(e)
	for b in get_tree().get_nodes_in_group("ball"):
		if (b as KickBall).kind == "football" and COURT.grow(4).has_point(Vector2(b.global_position.x, b.global_position.z)):
			football = b
	_spawn_all(COUNTS[q][0], COUNTS[q][1])


func _pick_player_desk() -> void:
	var list: Array = room_seats.get(CLASS_ROOM, [])
	var info: Dictionary = world.builder.classrooms.get(CLASS_ROOM, {})
	if list.is_empty() or info.is_empty():
		return
	var r: Rect2 = info.rect
	var target := Vector3(r.get_center().x, 0, r.get_center().y)
	var best: Seat = null
	for s in list:
		if best == null or s.global_position.distance_to(target) < best.global_position.distance_to(target):
			best = s
	player_desk = best


func _make(entry: Dictionary) -> NPC:
	var n := NPC.new()
	n.setup(entry, self)
	add_child(n)
	npcs.append(n)
	return n


func _spawn_all(n_class: int, n_other: int) -> void:
	var desks: Array = room_seats.get(CLASS_ROOM, []).duplicate()
	desks.erase(player_desk)
	desks.shuffle()
	var named := NPCRoster.STUDENTS.duplicate()
	for i in n_class:
		var entry: Dictionary = named[i] if i < named.size() else NPCRoster.generic_student(i)
		entry = entry.duplicate()
		entry["role"] = "student"
		var n := _make(entry)
		n.activity_data["desk"] = desks[i % desks.size()] if not desks.is_empty() else null
		n.activity_data["home"] = CLASS_ROOM
		classmates.append(n)
	var rooms: Array = world.builder.classrooms.keys().filter(func(r): return r != CLASS_ROOM)
	for i in n_other:
		var entry2 := NPCRoster.generic_student(100 + i)
		var n2 := _make(entry2)
		n2.activity_data["home"] = rooms[i % rooms.size()]
		n2.set_active(false)
		others.append(n2)
	teacher = _make(NPCRoster.ADULTS.teacher)
	director = _make(NPCRoster.ADULTS.director)
	inspector = _make(NPCRoster.ADULTS.inspector)
	cook = _make(NPCRoster.ADULTS.cook)
	cook.teleport(Vector3(-23.3, 0.05, 12.0), PI * 0.5)
	cook.activity = "cook"


func class_info() -> Dictionary:
	return world.builder.classrooms.get(CLASS_ROOM, {})


func teacher_spot() -> Transform3D:
	var info := class_info()
	return Transform3D(Basis(Vector3.UP, info.board_yaw), info.teacher)


# =================================================================== fases

func begin_arrival() -> void:
	phase = "arrival"
	_clear_spots()
	for o in others:
		o.set_active(false)
	var info := class_info()
	for i in classmates.size():
		var n := classmates[i]
		n.set_active(true)
		n.activity = "go_desk"
		var desk: Seat = n.activity_data.get("desk")
		if desk and desk.occupant and desk.occupant != n:
			desk = null
		if i % 3 == 0 and desk:
			# alguns já estão sentados
			n.teleport(desk.global_position, desk.global_rotation.y)
			desk.occupy(n)
			n.seat = desk
			n.sitting = true
			n.visual.play("sit_down")
		else:
			var start := Vector3(rng.randf_range(-6, 6), 0.05, rng.randf_range(40, 70))
			if i % 3 == 1:
				start = info.door_out + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(0.0, 2.5))
			n.teleport(start, PI)
			var dn := n
			var t := get_tree().create_timer(rng.randf_range(0.0, 6.0))
			t.timeout.connect(func():
				if dn.activity == "go_desk":
					dn.sit_on(desk))
	var ts := teacher_spot()
	teacher.teleport(ts.origin, ts.basis.get_euler().y)
	teacher.activity = "teach"
	director.teleport(Vector3(0, 0.05, 44), PI)
	director.activity = "director_idle"
	inspector.teleport(Vector3(0, 0.05, 52), PI)
	inspector.activity = "inspector_gate"
	cook.teleport(Vector3(-23.3, 0.05, 12.0), PI * 0.5)


func begin_class() -> void:
	phase = "class"
	for n in classmates:
		n.activity = "class"
		var desk: Seat = n.activity_data.get("desk")
		if n.sitting and n.seat == desk:
			continue
		if desk == null:
			continue
		# quem ainda não chegou corre para a carteira (ou aparece se estiver longe)
		if player and n.global_position.distance_to(player.global_position) > 18.0:
			if n.seat:
				n.seat.release()
			n.teleport(desk.global_position, desk.global_rotation.y)
			desk.occupy(n)
			n.seat = desk
			n.sitting = true
			n.visual.play("sit_down")
		else:
			n.sit_on(desk, true)
	var ts := teacher_spot()
	teacher.activity = "teach"
	teacher.go_to(ts.origin, false, func(): teacher.yaw = ts.basis.get_euler().y)
	director.activity = "director_office"
	director.go_to(Vector3(-25, 0.05, 44.4))
	inspector.activity = "inspector_hall"
	inspector.go_to(Vector3(3, 0.05, 30))


func begin_recess() -> void:
	phase = "recess"
	_clear_spots()
	_queue.clear()
	var delay := 0.0
	for n in classmates:
		var dn := n
		delay += rng.randf_range(0.05, 0.25)
		get_tree().create_timer(delay).timeout.connect(func(): _start_recess_for(dn, true))
	for o in others:
		var info: Dictionary = world.builder.classrooms.get(o.activity_data.home, {})
		var start: Vector3 = info.get("door_out", Vector3(0, 0.05, 30))
		o.teleport(start + Vector3(rng.randf_range(-1.5, 1.5), 0, 0), PI)
		o.set_active(true)
		var dn2 := o
		delay += rng.randf_range(0.05, 0.3)
		get_tree().create_timer(delay).timeout.connect(func(): _start_recess_for(dn2, true))
	teacher.activity = "break"
	var sofa := _seat_in_room("Sala dos Professores")
	if sofa:
		teacher.sit_on(sofa)
	director.activity = "patrol"
	_patrol(director)
	inspector.activity = "patrol"
	_patrol(inspector)


func begin_return() -> void:
	phase = "return"
	_clear_spots()
	_queue.clear()
	for n in classmates:
		n.activity = "go_desk"
		if n.sitting:
			n.stand_up()
		var desk: Seat = n.activity_data.get("desk")
		var dn := n
		get_tree().create_timer(rng.randf_range(0.2, 2.0)).timeout.connect(func(): dn.sit_on(desk, rng.randf() < 0.4))
	for o in others:
		o.activity = "go_home"
		if o.sitting:
			o.stand_up()
		var info: Dictionary = world.builder.classrooms.get(o.activity_data.home, {})
		var on := o
		o.go_to(info.get("door_in", Vector3(0, 0.05, 30)), rng.randf() < 0.5, func(): on.set_active(false))
	var ts := teacher_spot()
	teacher.activity = "teach"
	teacher.go_to(ts.origin, false, func(): teacher.yaw = ts.basis.get_euler().y)
	director.activity = "director_office"
	director.go_to(Vector3(-25, 0.05, 44.4))
	inspector.activity = "inspector_hall"
	inspector.go_to(Vector3(3, 0.05, 30))


func begin_day_end() -> void:
	phase = "end"
	for n in classmates + others:
		if not n.active:
			continue
		n.activity = "leave"
		if n.sitting:
			n.stand_up()
		var nn := n
		get_tree().create_timer(rng.randf_range(0.3, 4.0)).timeout.connect(func():
			nn.go_to(Vector3(rng.randf_range(-3, 3), 0.05, 73.5), false, func(): nn.set_active(false)))


func _seat_in_room(room: String) -> Seat:
	var list: Array = room_seats.get(room, [])
	for s in list:
		if s.occupant == null:
			return s
	return null


func _patrol(n: NPC) -> void:
	if n.activity != "patrol":
		return
	var pts: Array
	if n == director:
		pts = [Vector3(0, 0.05, 36), Vector3(-40, 0.05, 36), Vector3(35, 0.05, 36), Vector3(0, 0.05, 14), Vector3(0, 0.05, -5)]
	else:
		pts = [Vector3(-20, 0.05, -10), Vector3(25, 0.05, -15), Vector3(-45, 0.05, -15), Vector3(40, 0.05, -32), Vector3(-40, 0.05, -38), Vector3(0, 0.05, 2)]
	var nn := n
	n.go_to(pts.pick_random(), false, func():
		get_tree().create_timer(rng.randf_range(2.0, 5.0)).timeout.connect(func(): _patrol(nn)))


# =================================================================== recreio

func _start_recess_for(n: NPC, from_class: bool) -> void:
	if phase != "recess" or not n.active:
		return
	if n.sitting and from_class:
		n.stand_up()
	var options: Array = []
	match n.personality:
		"futebol": options = ["football", "football", "football", "chat"]
		"competitivo": options = ["tag", "football", "hopscotch"]
		"engracado": options = ["chat", "chat", "tag"]
		"timido": options = ["sit", "sit", "swing"]
		"colecionador": options = ["chat", "sit", "marbles"]
		"comilao": options = ["queue", "queue", "chat"]
		"agitado": options = ["tag", "tag", "swing", "hopscotch"]
		"estudioso": options = ["sit", "chat", "marbles"]
		_: options = ["chat", "chat", "sit", "football", "queue", "marbles", "hopscotch", "swing", "tag", "wander"]
	options.shuffle()
	for opt in options:
		if _try_activity(n, opt, from_class):
			return
	_try_activity(n, "wander", from_class)


func _count(activity: String) -> int:
	var c := 0
	for n in npcs:
		if n.active and n.activity == activity:
			c += 1
	return c


func _try_activity(n: NPC, act: String, hurry := false) -> bool:
	n.activity_data.erase("spot")
	var run := hurry or rng.randf() < 0.35
	match act:
		"football":
			if football == null or _count("football") >= 10:
				return false
			n.activity = "football"
			n.activity_data["team"] = _count("football") % 2
			n.go_to(Vector3(40 + rng.randf_range(-10, 10), 0.05, -49 + rng.randf_range(-6, 6)), true)
			return true
		"queue":
			if _queue.size() >= spots.get("queue", []).size():
				return false
			n.activity = "queue"
			_queue.append(n)
			_refresh_queue()
			return true
		"chat":
			var list: Array = spots.get("chat", [])
			var idx := -1
			var order := range(list.size())
			order.shuffle()
			for i in order:
				var members: Array = _chat_members.get(i, [])
				if members.size() < 4:
					idx = i
					break
			if idx == -1:
				return false
			if not _chat_members.has(idx):
				_chat_members[idx] = []
			_chat_members[idx].append(n)
			n.activity = "chat"
			n.activity_data["chat"] = idx
			var center: Vector3 = list[idx].pos
			var k: int = _chat_members[idx].size() - 1
			var a := k * TAU / 4.0 + idx
			var pos := center + Vector3(cos(a), 0, sin(a)) * 0.85
			var nn := n
			n.go_to(pos, run, func(): nn.face(center))
			return true
		"sit", "swing":
			var pool: Array = swing_seats if act == "swing" else outdoor_seats
			var free := pool.filter(func(s): return s.occupant == null)
			if free.is_empty():
				return false
			# prefere assentos perto do pátio
			free.sort_custom(func(a, b): return a.global_position.distance_to(n.global_position) < b.global_position.distance_to(n.global_position))
			var pick: Seat = free[mini(rng.randi() % 6, free.size() - 1)]
			n.activity = act
			n.sit_on(pick, run)
			return true
		"marbles", "hopscotch":
			for sp in spots.get(act, []):
				if sp.taken == null:
					sp.taken = n
					n.activity = act
					n.activity_data["spot"] = sp
					var nn := n
					var spd: Dictionary = sp
					n.go_to(sp.pos, run, func():
						nn.yaw = spd.get("yaw", nn.yaw)
						if act == "marbles":
							nn.visual.play("crouch"))
					return true
			return false
		"tag":
			if _count("tag") >= 6:
				return false
			n.activity = "tag"
			n.go_to(nav.random_point(rng, PATIO), true)
			return true
		"wander":
			n.activity = "wander"
			var sp2: Array = spots.get("wander", [])
			n.go_to(sp2.pick_random().pos if not sp2.is_empty() else nav.random_point(rng, PATIO), false)
			return true
	return false


func _refresh_queue() -> void:
	var slots: Array = spots.get("queue", [])
	for i in _queue.size():
		var n := _queue[i]
		var slot: Dictionary = slots[i]
		var nn := n
		n.go_to(slot.pos, false, func(): nn.yaw = -PI * 0.5)


func _clear_spots() -> void:
	for t in spots.keys():
		for sp in spots[t]:
			sp.taken = null
	_chat_members.clear()


func _leave_activity(n: NPC) -> void:
	if n.activity_data.has("spot"):
		n.activity_data.spot.taken = null
	if n.activity_data.has("chat"):
		var idx: int = n.activity_data.chat
		if _chat_members.has(idx):
			_chat_members[idx].erase(n)
		n.activity_data.erase("chat")
	if n.visual.animator.action == "crouch":
		n.visual.stop_action()


## Decide o que cada NPC faz (alguns por quadro, em rodízio).
func _think(n: NPC) -> void:
	match n.activity:
		"football":
			_think_football(n)
		"tag":
			if not n.moving:
				n.go_to(nav.random_point(rng, PATIO), true)
				if rng.randf() < 0.3:
					n.say(["Tá com você!", "Ninguém me pega!", "Corre!"].pick_random(), 1.6)
		"wander":
			if not n.moving and rng.randf() < 0.08:
				if rng.randf() < 0.4 and phase == "recess":
					_leave_activity(n)
					_start_recess_for(n, false)
				else:
					var sp: Array = spots.get("wander", [])
					n.go_to(sp.pick_random().pos if not sp.is_empty() else nav.random_point(rng, PATIO))
		"chat":
			if not n.moving and rng.randf() < 0.06 and not n.visual.animator.is_playing("talk"):
				n.visual.play(["talk", "talk", "clap", "scratch_head", "wave"].pick_random())
			if not n.moving and rng.randf() < 0.01 and phase == "recess":
				_leave_activity(n)
				_start_recess_for(n, false)
		"sit", "swing":
			if n.sitting and rng.randf() < 0.02:
				n.visual.play("talk")
			if rng.randf() < 0.006 and phase == "recess":
				_leave_activity(n)
				_start_recess_for(n, true)
		"marbles":
			if not n.moving and rng.randf() < 0.05:
				n.visual.play("flick")
		"hopscotch":
			if not n.moving and n._hop_t < 0.0:
				var sp: Dictionary = n.activity_data.get("spot", {})
				var hops: int = n.activity_data.get("hops", 0)
				if hops < 7:
					n.activity_data["hops"] = hops + 1
					n.hop()
					var fwd := Vector3(sin(n.yaw), 0, cos(n.yaw))
					var tw := create_tween()
					tw.tween_property(n, "global_position", n.global_position + fwd * 0.9, 0.42)
				elif sp:
					n.activity_data["hops"] = 0
					var nn := n
					n.go_to(sp.pos, false, func(): nn.yaw = sp.get("yaw", nn.yaw))
		"class":
			if n.sitting and rng.randf() < 0.03 and n.visual.animator.upper_action == "":
				n.visual.play(["write", "write", "talk", "look_around"].pick_random())
		"teach":
			if not n.moving and rng.randf() < 0.03 and n.visual.animator.upper_action == "":
				n.visual.play(["talk", "point_board"].pick_random())
		"cook":
			if rng.randf() < 0.02:
				n.visual.play("talk")


func _think_football(n: NPC) -> void:
	if football == null:
		return
	var bp := football.global_position
	var team: int = n.activity_data.get("team", 0)
	var goal := Vector3(60.0 if team == 0 else 20.0, 0, -49)
	var gdir := (goal - bp)
	gdir.y = 0
	gdir = gdir.normalized()
	# só o mais próximo de cada time persegue a bola
	var closest := true
	for o in npcs:
		if o != n and o.active and o.activity == "football" and o.activity_data.get("team", 0) == team:
			if o.global_position.distance_to(bp) < n.global_position.distance_to(bp):
				closest = false
				break
	if closest:
		var behind := bp - gdir * 0.45
		var to := bp - n.global_position
		to.y = 0
		if to.length() < 0.75 and to.normalized().dot(gdir) > 0.2 and not n.visual.animator.is_playing("kick"):
			n.stop()
			n.yaw = atan2(gdir.x, gdir.z)
			n.visual.play("kick")
			var dir := gdir.rotated(Vector3.UP, rng.randf_range(-0.35, 0.35))
			var power := rng.randf_range(5.5, 9.0)
			get_tree().create_timer(0.35).timeout.connect(func():
				if football.global_position.distance_to(n.global_position) < 1.3:
					football.kick(dir, power, rng.randf_range(1.0, 2.6)))
			if rng.randf() < 0.15:
				n.say(["Toca!", "Chuta!", "Vai!"].pick_random(), 1.2)
		elif n.global_position.distance_to(bp) > 8.0:
			if not n.moving or n.path.size() <= 1:
				n.go_to(Vector3(behind.x, 0.05, behind.z), true)
		elif n.global_position.distance_to(behind) > 0.4:
			n.running = true
			n.moving = true
			n.path = PackedVector3Array([Vector3(behind.x, 0.05, behind.z)])
			n.path_i = 0
	else:
		# posicionamento: acompanha a bola no seu lado do campo
		var home_x := 32.0 if team == 0 else 48.0
		var target := Vector3(lerpf(home_x, bp.x, 0.5), 0.05, clampf(bp.z + (2.5 if hash(n.name) % 2 == 0 else -2.5), -57.0, -41.0))
		if n.global_position.distance_to(target) > 2.0 and not n.moving:
			n.go_to(target, rng.randf() < 0.5)
		elif not n.moving:
			n.face(bp)
	# bola fora da quadra: o mais próximo busca
	if not COURT.grow(3).has_point(Vector2(bp.x, bp.z)) and closest and team == 0:
		if bp.distance_to(n.global_position) < 1.0:
			football.reset_ball()


# =================================================================== laço

func _physics_process(delta: float) -> void:
	if not GameManager.is_playing() and GameManager.state != GameManager.State.PAUSED:
		pass
	_sep_frame += 1
	if _sep_frame % 3 == 0:
		_compute_separation()
	for n in npcs:
		if n.active:
			n.tick(delta)
	# pensa em alguns NPCs por quadro
	var count := npcs.size()
	if count > 0:
		for k in 4:
			_think_i = (_think_i + 1) % count
			var n := npcs[_think_i]
			if n.active and not n.talking_to_player:
				_think(n)
	# fila da cantina anda
	if phase == "recess" and not _queue.is_empty():
		_queue_t -= delta
		if _queue_t <= 0.0:
			_queue_t = rng.randf_range(6.0, 10.0)
			var front: NPC = _queue.pop_front()
			if not front.moving:
				front.say(["Valeu, Tia Rosa!", "Hmm, coxinha!", "Obrigado!"].pick_random(), 2.0)
				cook.say(NPCRoster.ambient_line("cook"), 2.0)
				front.activity = "chat"
				_leave_activity(front)
				_try_activity(front, "chat")
				_refresh_queue()
			else:
				_queue.push_front(front)


func _compute_separation() -> void:
	var list: Array[NPC] = []
	for n in npcs:
		if n.active and not n.sitting:
			list.append(n)
			n.separation = Vector3.ZERO
	var pp: Vector3 = player.global_position if player else Vector3(9999, 0, 0)
	for i in list.size():
		var a := list[i]
		for j in range(i + 1, list.size()):
			var b := list[j]
			var d := a.global_position - b.global_position
			d.y = 0
			var l := d.length()
			if l < 0.7 and l > 0.001:
				var push := d / l * (0.7 - l) * 2.5
				a.separation += push
				b.separation -= push
		var dp := a.global_position - pp
		dp.y = 0
		var lp := dp.length()
		if lp < 0.75 and lp > 0.001:
			a.separation += dp / lp * (0.75 - lp) * 3.0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var fwd := -cam.global_basis.z
	_lod_t -= delta
	var refresh_vis := _lod_t <= 0.0
	if refresh_vis:
		_lod_t = 0.4
	for n in npcs:
		if not n.active:
			continue
		var to := n.global_position - cp
		var d := to.length()
		if refresh_vis:
			var hidden := d > _vis_range or world.interior_hidden_at(n.global_position)
			n.visual.visible = not hidden
		if not n.visual.visible:
			continue
		var behind := to.dot(fwd) < -1.0 and d > 6.0
		var interval := 0.0
		if d > 40.0 or behind:
			interval = 0.2
		elif d > 22.0:
			interval = 0.08
		elif d > 12.0:
			interval = 0.033
		n.visual.animator.update_interval = interval
		n.visual.animator.update(delta)
	# falas espontâneas perto do jogador
	_bubble_t -= delta
	if _bubble_t <= 0.0 and player:
		_bubble_t = rng.randf_range(1.5, 3.5)
		var near: Array[NPC] = []
		for n in npcs:
			if n.active and n.visual.visible and not n.talking_to_player and n.global_position.distance_to(player.global_position) < 14.0:
				near.append(n)
		if not near.is_empty() and not (phase == "class" and rng.randf() < 0.85) and not player.input_enabled == false:
			var pick: NPC = near.pick_random()
			pick.say(NPCRoster.ambient_line(pick.personality if pick.role == "student" else pick.role))


# =================================================================== interação

func npc_prompt(npc: NPC, p: Node) -> String:
	if day and day.has_method("npc_prompt"):
		return day.npc_prompt(npc, p)
	return ""


func on_npc_interact(npc: NPC, p: Node) -> void:
	if day and day.has_method("npc_interact") and day.npc_interact(npc, p):
		return
	start_talk(npc, npc.lines_for_talk())


func start_talk(npc: NPC, lines: Array) -> void:
	npc.talking_to_player = true
	if not npc.sitting:
		npc.stop()
		npc.face(player.global_position)
	npc.visual.play("talk")
	dialogue_requested.emit(npc, lines)


func end_talk(npc: NPC) -> void:
	npc.talking_to_player = false
	npc.visual.stop_upper()
	if phase == "recess" and npc.role == "student" and npc.activity in ["chat", "wander"] and not npc.moving:
		pass


signal npc_hit_by_object(npc: NPC, obj: Node)


func on_npc_hit_by_object(npc: NPC, obj: Node) -> void:
	if npc.talking_to_player or npc.activity == "minigame":
		return
	if not npc.sitting:
		npc.visual.play("hit")
	npc.say(["Ei! Quem jogou isso?", "Aiii!", "Para com isso!"].pick_random(), 2.0)
	npc_hit_by_object.emit(npc, obj)


## Reação a esbarrões do jogador (o sistema disciplinar usa o sinal).
func on_player_bump(npc: NPC, speed: float) -> void:
	if npc.talking_to_player:
		return
	var intense := speed > 3.5
	if intense:
		if not npc.sitting:
			npc.visual.play("hit")
		npc.say(["Ei! Olha por onde anda!", "Aiii!", "Cuidado!"].pick_random(), 2.0)
	else:
		npc.say(["Opa!", "Com licença...", "Ei!"].pick_random(), 1.4)
	npc_bumped.emit(npc, speed)
