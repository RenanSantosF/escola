extends Minigame
## Bolinha de gude no círculo de terra. Simulação 2D própria (discos com
## atrito e colisões elásticas) — leve e estável no celular. Mire com o
## joystick (esquerda/direita gira a mira, cima/baixo muda a posição na
## borda), toque no botão amarelo para começar a carregar a força e de novo
## para lançar. Bolinhas que saem do círculo são suas. Turnos alternados.

const CENTER := Vector2(-46, -9)
const RING := 1.2
const R := 0.045
const FRICTION := 0.55
const REST := 0.9
const TYPES := [
	{"id": "leitosa", "name": "Leitosa", "color": Color("f5f2ea")},
	{"id": "olho_de_gato", "name": "Olho-de-gato", "color": Color("3fa7d6")},
	{"id": "furta_cor", "name": "Furta-cor", "color": Color("b388eb")},
	{"id": "verdinha", "name": "Verdinha", "color": Color("4caf50")},
	{"id": "rubi", "name": "Rubi", "color": Color("e53935")},
	{"id": "ambar", "name": "Âmbar", "color": Color("ffb300")},
	{"id": "galaxia", "name": "Galáxia (rara)", "color": Color("283593")},
]

var opponent: NPC
var marbles: Array = []  # {pos: Vector2, vel: Vector2, type, node, out}
var shooters := []  # [jogador, oponente] {pos, vel, node}
var turn := 0  # 0 jogador, 1 oponente
var captured := [0, 0]
var captured_types: Array = []
var aim_angle := 0.0
var edge_angle := PI * 0.5
var on_edge := [true, true]
var _charging := false
var _power := 0.0
var _power_dir := 1.0
var _sim := false
var _sim_t := 0.0
var _captured_this_shot := 0
var _npc_t := 0.0
var _root: Node3D
var _aim_line: MeshInstance3D
var _mat: StandardMaterial3D


func begin() -> void:
	var opp: Array[NPC] = students(1, Vector3(-43.6, 0.05, -12.0), ["julia"])
	if not opp.is_empty():
		opponent = opp[0]
	take_npcs([opponent])
	# quem já brincava no círculo dá lugar à partida
	for n in npcs.npcs:
		if n.active and n.activity == "marbles":
			npcs._leave_activity(n)
			npcs._try_activity(n, "chat")
	_root = Node3D.new()
	world.add_child(_root)
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.15
	_mat.metallic_specular = 0.9
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.45)
		var t: Dictionary = TYPES[rng.randi() % (TYPES.size() - 1)] if rng.randf() > 0.08 else TYPES[-1]
		marbles.append({"pos": CENTER + p, "vel": Vector2.ZERO, "type": t, "node": _marble_node(t.color), "out": false})
	for k in 2:
		shooters.append({"pos": CENTER, "vel": Vector2.ZERO, "node": _marble_node(Color("ffffff") if k == 0 else Color("ff7eb6"), 1.25)})
	_aim_line = MeshInstance3D.new()
	_root.add_child(_aim_line)
	player.force_stand()
	player.movement_locked = true
	turn = 0
	_place_on_edge(0, PI * 0.5)
	_place_on_edge(1, -PI * 0.5)
	_sync_nodes()
	_setup_turn()
	super.begin()


func _marble_node(c: Color, scale := 1.0) -> MeshInstance3D:
	var md := MeshData.new()
	md.cur_color = c
	md.add_sphere(Transform3D(), R * scale, 10, 7)
	md.cur_color = c.lightened(0.5)
	md.add_sphere(Transform3D(Basis(), Vector3(R * 0.3, R * 0.4, R * 0.2) * scale), R * 0.3 * scale, 6, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi


## Câmera alta, quase de cima, ao lado da bolinha atiradora.
func _cam_xf() -> Transform3D:
	var s: Dictionary = shooters[turn]
	var d := Vector3(cos(aim_angle), 0, sin(aim_angle))
	var side := Vector3(-d.z, 0, d.x)
	var cam_pos := Vector3(s.pos.x, 0, s.pos.y) - d * 0.7 + side * 0.6 + Vector3(0, 2.3, 0)
	var look := Vector3(CENTER.x, 0, CENTER.y).lerp(Vector3(s.pos.x, 0, s.pos.y), 0.35)
	return Transform3D(Basis(), cam_pos).looking_at(look, Vector3.UP)


func _place_on_edge(k: int, ang: float) -> void:
	shooters[k].pos = CENTER + Vector2.from_angle(ang) * (RING + 0.05)
	shooters[k].vel = Vector2.ZERO
	on_edge[k] = true


func _setup_turn() -> void:
	var s: Dictionary = shooters[turn]
	var to_center: Vector2 = CENTER - s.pos
	aim_angle = to_center.angle()
	_power = 0.0
	_charging = false
	var who: Node3D = player if turn == 0 else opponent
	var pos3 := Vector3(s.pos.x, 0.05, s.pos.y) - Vector3(cos(aim_angle), 0, sin(aim_angle)) * 0.45
	var yaw := atan2(cos(aim_angle), sin(aim_angle))
	if turn == 0:
		player.global_position = pos3
		player.yaw = yaw
		player.visual.rotation.y = yaw
		player.visual.play("crouch")
	else:
		opponent.teleport(pos3, yaw)
		opponent.visual.play("crouch")
		_npc_t = 1.5
	# câmera de cima, atrás da bolinha
	player.camera_rig.set_override(_cam_xf())
	_update_hud()


func _update_hud() -> void:
	var who := "Sua vez" if turn == 0 else "Vez de %s" % opponent.display_name
	hud.set_minigame_text("Bolinha de gude  ·  Você %d x %d %s  ·  %s" % [captured[0], captured[1], opponent.display_name, who])


func play_label() -> String:
	if turn != 0 or _sim:
		return "Aguarde"
	return "Soltar!" if _charging else "Segure: força"


func interact_label() -> String:
	return "Sair do jogo"


func on_interact() -> bool:
	_finish(true)
	return true


func on_play() -> bool:
	if turn != 0 or _sim:
		return true
	if not _charging:
		_charging = true
		_power = 0.0
		_power_dir = 1.0
	return true


## Segure para carregar a força e SOLTE para lançar (igual às outras brincadeiras).
func on_play_release() -> bool:
	if turn == 0 and not _sim and _charging:
		_shoot(maxf(_power, 0.08))
	return true


func on_jump() -> bool:
	return true


func _shoot(power: float) -> void:
	_charging = false
	hud.set_meter(-1.0)
	var s: Dictionary = shooters[turn]
	s.vel = Vector2.from_angle(aim_angle) * lerpf(0.4, 3.2, power)
	on_edge[turn] = false
	_sim = true
	_sim_t = 0.0
	_captured_this_shot = 0
	var who: CharacterVisual = player.visual if turn == 0 else opponent.visual
	who.play("flick")
	AudioManager.play_ui("ui_click", -6.0, 0.2)


func tick(delta: float) -> void:
	if not running:
		return
	if turn == 0 and not _sim:
		var mv := player.read_move_raw()
		aim_angle += mv.x * delta * 1.6
		if on_edge[0] and absf(mv.y) > 0.3:
			edge_angle = (shooters[0].pos - CENTER).angle() + mv.y * delta * 0.8
			_place_on_edge(0, edge_angle)
			var s: Dictionary = shooters[0]
			player.camera_rig.set_override(_cam_xf())
			player.global_position = Vector3(s.pos.x, 0.05, s.pos.y) - Vector3(cos(aim_angle), 0, sin(aim_angle)) * 0.45
		if _charging:
			_power += _power_dir * delta * 0.9
			if _power >= 1.0 or _power <= 0.0:
				_power_dir *= -1.0
				_power = clampf(_power, 0.0, 1.0)
			hud.set_meter(_power)
		_draw_aim()
		player._emit_context()
	elif turn == 1 and not _sim:
		_npc_t -= delta
		if _npc_t <= 0.0:
			_npc_shot()
	if _sim:
		# passos fixos para estabilidade
		var steps := 4
		for i in steps:
			_step(delta / steps)
		_sim_t += delta
		if _all_stopped() or _sim_t > 6.0:
			_end_shot()
	_sync_nodes()


func _bodies() -> Array:
	var list := []
	for m in marbles:
		if not m.out:
			list.append(m)
	list.append(shooters[0])
	list.append(shooters[1])
	return list


func _step(dt: float) -> void:
	var list := _bodies()
	for b in list:
		var v: Vector2 = b.vel
		var sp := v.length()
		if sp > 0.0:
			var ns := maxf(sp - FRICTION * dt, 0.0)
			b.vel = v / sp * ns
			b.pos += b.vel * dt
	# colisões entre discos (elásticas, massas iguais)
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a: Dictionary = list[i]
			var b: Dictionary = list[j]
			var d: Vector2 = b.pos - a.pos
			var dist := d.length()
			var min_d := R * 2.0 * 1.1
			if dist < min_d and dist > 0.0001:
				var n := d / dist
				var overlap := min_d - dist
				a.pos -= n * overlap * 0.5
				b.pos += n * overlap * 0.5
				var rel: float = (a.vel - b.vel).dot(n)
				if rel > 0.0:
					var imp := rel * (1.0 + REST) * 0.5
					a.vel -= n * imp
					b.vel += n * imp
					if rel > 0.25:
						AudioManager.play_3d("clack", Vector3(a.pos.x, 0.1, a.pos.y), -14.0 + minf(rel * 6.0, 10.0), 0.25)
	# bolinhas que saíram do círculo
	for m in marbles:
		if not m.out and m.pos.distance_to(CENTER) > RING:
			m.out = true
			captured[turn] += 1
			_captured_this_shot += 1
			if turn == 0:
				captured_types.append(m.type)
			m.node.visible = false
			if turn == 0:
				add_combo()
				popup(Vector3(m.pos.x, 0.3, m.pos.y), "+1 %s" % m.type.name, m.type.color.lightened(0.2), 48)
			else:
				AudioManager.play_ui("pickup", -8.0)
			_update_hud()


func _all_stopped() -> bool:
	for b in _bodies():
		if b.vel.length() > 0.01:
			return false
	return true


func _end_shot() -> void:
	_sim = false
	for b in _bodies():
		b.vel = Vector2.ZERO
	# bolinha atiradora fora do círculo volta para a borda
	for k in 2:
		if shooters[k].pos.distance_to(CENTER) > RING:
			_place_on_edge(k, (shooters[k].pos - CENTER).angle())
	if marbles.all(func(m): return m.out):
		_finish(false)
		return
	if _captured_this_shot == 0:
		if turn == 0:
			break_combo()
		turn = 1 - turn
	elif turn == 0:
		GameManager.show_toast("Pegou! Jogue de novo.")
	_setup_turn()


func _npc_shot() -> void:
	# mira na bolinha mais perto da borda, com erro humano
	var s: Dictionary = shooters[1]
	var best: Dictionary = {}
	var best_d := -1.0
	for m in marbles:
		if m.out:
			continue
		var dd: float = m.pos.distance_to(CENTER)
		if dd > best_d:
			best_d = dd
			best = m
	if best.is_empty():
		return
	if on_edge[1]:
		# vai para o lado oposto da bolinha alvo
		var opp: Vector2 = (best.pos - CENTER).normalized()
		_place_on_edge(1, (-opp).angle() + randf_range(-0.5, 0.5))
	var to: Vector2 = best.pos - s.pos
	aim_angle = to.angle() + randf_range(-0.08, 0.08)
	var need := clampf(to.length() / 1.6 + 0.35, 0.3, 1.0)
	turn = 1
	_shoot(clampf(need + randf_range(-0.15, 0.15), 0.1, 1.0))
	if randf() < 0.3:
		opponent.say(["Essa é minha!", "Olha a mira!", "Vai!"].pick_random(), 1.2)


## Mira estilo sinuca: linha até a primeira bolinha que vai bater, um
## "fantasma" no ponto do choque e a direção para onde ela será empurrada.
func _draw_aim() -> void:
	var s: Dictionary = shooters[0]
	var dir2 := Vector2.from_angle(aim_angle)
	var hit_t := RING * 2.2
	var hit_m: Dictionary = {}
	for m in marbles + [shooters[1]]:
		if m.get("out", false):
			continue
		var rel: Vector2 = m.pos - s.pos
		var along: float = rel.dot(dir2)
		if along <= 0.0:
			continue
		var perp: float = absf(rel.cross(dir2))
		var rr := R * 2.0 * 1.1
		if perp < rr:
			var t: float = along - sqrt(rr * rr - perp * perp)
			if t < hit_t:
				hit_t = t
				hit_m = m
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.03
	var a: Vector3 = Vector3(s.pos.x, y, s.pos.y)
	var d3 := Vector3(dir2.x, 0, dir2.y)
	var reach := minf(hit_t, 0.25 + _power * 2.2) if not hit_m.is_empty() else 0.25 + _power * 2.2
	var col := Color(1, 1, 1, 0.95)
	var k := 0.04
	while k < reach:
		_quad(im, a + d3 * k, a + d3 * minf(k + 0.06, reach), 0.012, col)
		k += 0.1
	if not hit_m.is_empty() and hit_t <= 0.25 + _power * 2.2 + 0.4:
		var ghost: Vector2 = s.pos + dir2 * hit_t
		var g3 := Vector3(ghost.x, y, ghost.y)
		for j in 12:
			var a0 := j * TAU / 12.0
			var a1 := (j + 1) * TAU / 12.0
			_quad(im, g3 + Vector3(cos(a0), 0, sin(a0)) * R, g3 + Vector3(cos(a1), 0, sin(a1)) * R, 0.008, Color(1, 1, 1, 0.8))
		var push: Vector2 = (hit_m.pos - ghost).normalized()
		var m3 := Vector3(hit_m.pos.x, y, hit_m.pos.y)
		_quad(im, m3, m3 + Vector3(push.x, 0, push.y) * 0.35, 0.016, Color("6be36b"))
	im.surface_end()
	_aim_line.mesh = im
	if _aim_line.material_override == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		_aim_line.material_override = m
	_aim_line.visible = true


func _quad(im: ImmediateMesh, p0: Vector3, p1: Vector3, w: float, c: Color) -> void:
	var d := p1 - p0
	var side := Vector3(-d.z, 0, d.x).normalized() * w
	im.surface_set_color(c)
	im.surface_add_vertex(p0 - side)
	im.surface_add_vertex(p1 - side)
	im.surface_add_vertex(p1 + side)
	im.surface_add_vertex(p0 - side)
	im.surface_add_vertex(p1 + side)
	im.surface_add_vertex(p0 + side)


func _sync_nodes() -> void:
	for m in marbles:
		m.node.global_position = Vector3(m.pos.x, 0.02 + R, m.pos.y)
	for k in 2:
		shooters[k].node.global_position = Vector3(shooters[k].pos.x, 0.02 + R * 1.25, shooters[k].pos.y)
	if _sim or turn != 0:
		_aim_line.visible = false


func _finish(quit: bool) -> void:
	if not running:
		return
	var won := 1 if captured[0] > captured[1] else (0 if captured[0] == captured[1] else -1)
	if quit and captured[0] == 0:
		won = -1
	# bolinhas ganhas vão para a coleção
	var col: Dictionary = SaveManager.section("collections")
	var gude: Dictionary = col.get("gude", {})
	for t in captured_types:
		gude[t.id] = int(gude.get(t.id, 0)) + 1
	col["gude"] = gude
	if captured_types.any(func(t): return t.id == "galaxia"):
		GameManager.unlock_achievement("gude_rara")
	var names := ", ".join(captured_types.map(func(t): return t.name).slice(0, 4))
	end_game(won, "Você ganhou %d bolinha(s)%s" % [captured[0], (": " + names) if names != "" else ""], 6 + captured[0] * 3, 15 + captured[0] * 4, {"score": captured[0]})


func cleanup() -> void:
	player.visual.stop_action()
	if is_instance_valid(opponent):
		opponent.visual.stop_action()
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
