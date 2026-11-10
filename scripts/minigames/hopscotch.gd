extends Minigame
## Amarelinha pintada no pátio. Regras:
## 1) SEGURE o botão amarelo e solte na força certa para a pedrinha cair
##    na casa da vez (1 a 8).
## 2) Pule (botão azul) no ritmo do círculo: casas simples com UM pé,
##    casas duplas com um pé em cada — nunca na casa da pedrinha!
## 3) Vá até o CÉU, vire e volte pegando a pedrinha. 3 vidas.

const ORIGIN := Vector3(-14, 0.05, -2)
## casas: número -> posição relativa (x, linha)
const CELLS := {1: Vector2(0, 0), 2: Vector2(0, 1), 3: Vector2(-0.5, 2), 4: Vector2(0.5, 2), 5: Vector2(0, 3), 6: Vector2(-0.5, 4), 7: Vector2(0.5, 4), 8: Vector2(0, 5)}
const ROWS := [[1], [2], [3, 4], [5], [6, 7], [8]]
const ROW_STEP := 0.95
const BEAT := 0.8

var target := 1
var lives := 3
var stage := "throw"  # throw, hop, done
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _stone: MeshInstance3D
var _stone_cell := 0
var _plan: Array = []  # [{pos, pose}]
var _plan_i := 0
var _beat_t := 0.0
var _hopping := false
var _beat_ring: MeshInstance3D
var _root: Node3D


static func cell_pos(n: int) -> Vector3:
	var c: Vector2 = CELLS[n]
	return ORIGIN + Vector3(c.x * 1.0, 0, -c.y * ROW_STEP)


## Sequência de pulos de ida e volta evitando a casa da pedra.
## Retorna [{pos, pose, pick}] — pose: "hop_one" ou "hop_two".
static func hop_plan(stone: int) -> Array:
	var go := []
	for row in ROWS:
		var free: Array = row.filter(func(c): return c != stone)
		if free.is_empty():
			continue  # casa simples com a pedra: pula por cima
		if free.size() == 2:
			go.append({"pos": (cell_pos(free[0]) + cell_pos(free[1])) * 0.5, "pose": "hop_two", "row": row})
		else:
			go.append({"pos": cell_pos(free[0]), "pose": "hop_one", "row": row})
	var sky := {"pos": ORIGIN + Vector3(0, 0, -6.2), "pose": "hop_two", "row": []}
	var back := go.duplicate()
	back.reverse()
	var plan := go + [sky]
	for b in back:
		var e: Dictionary = b.duplicate()
		e["pick"] = false
		plan.append(e)
	plan.append({"pos": ORIGIN + Vector3(0, 0, 1.2), "pose": "", "row": [], "end": true})
	# pega a pedra no pulo que está na linha logo antes da pedra (na volta)
	var srow := _row_of(stone)
	for i in range(go.size() + 1, plan.size()):
		var r: Array = plan[i].row
		if not r.is_empty() and ROWS.find(r) == srow + 1:
			plan[i]["pick"] = true
	if srow == ROWS.size() - 1:
		plan[go.size()]["pick"] = true
	return plan


static func _row_of(cell: int) -> int:
	for i in ROWS.size():
		if cell in ROWS[i]:
			return i
	return 0


func begin() -> void:
	for n in npcs.npcs:
		if n.active and n.activity == "hopscotch":
			npcs._leave_activity(n)
			npcs._try_activity(n, "chat")
	_root = Node3D.new()
	world.add_child(_root)
	var md := MeshData.new()
	md.cur_color = Color("7f8c8d")
	md.add_sphere(Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)), Vector3.ZERO), 0.09, 8, 5)
	_stone = MeshInstance3D.new()
	_stone.mesh = md.build_mesh(SchoolMaterials.get_mat("plain"))
	_stone.visible = false
	_root.add_child(_stone)
	var rmd := MeshData.new()
	rmd.cur_color = Color("ffcf3f")
	for k in 20:
		var a := k * TAU / 20.0
		rmd.add_box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * 0.5), Vector3(0.05, 0.02, 0.17))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beat_ring = MeshInstance3D.new()
	_beat_ring.mesh = rmd.build_mesh(mat)
	_beat_ring.visible = false
	_root.add_child(_beat_ring)
	player.force_stand()
	player.movement_locked = true
	_to_start()
	super.begin()
	hud.show_banner("Amarelinha!", "Segure e solte o botão amarelo para jogar a pedrinha")


func _to_start() -> void:
	player.global_position = ORIGIN + Vector3(0, 0, 1.2)
	player.yaw = PI
	player.visual.rotation.y = PI
	player.visual.stop_action(false)
	if player.camera_rig:
		player.camera_rig.set_override(Transform3D(Basis(), ORIGIN + Vector3(2.8, 3.6, 3.4)).looking_at(ORIGIN + Vector3(0, 0, -2.6), Vector3.UP))
	stage = "throw"
	_charging = false
	_update_hud()


func _update_hud() -> void:
	var t := "Segure e solte quando o círculo ficar VERDE" if stage == "throw" else "Toque em Pular para cada casa"
	hud.set_minigame_text("Amarelinha  ·  Casa %d de 8  ·  Vidas: %s  ·  %s" % [target, "♥".repeat(lives), t])


func play_label() -> String:
	return ("Soltar!" if _charging else "Segure: pedrinha") if stage == "throw" else "Pular!"


func interact_label() -> String:
	return "Sair"


func on_interact() -> bool:
	_finish()
	return true


func on_play() -> bool:
	if stage == "throw" and not _charging:
		_charging = true
		_power = 0.0
		_power_dir = 1.0
	elif stage == "hop":
		on_jump()
	return true


func on_play_release() -> bool:
	if stage == "throw" and _charging:
		_charging = false
		hud.set_meter(-1.0)
		_throw_stone()
	return true


func on_jump() -> bool:
	if stage != "hop" or _hopping:
		return true
	# sem castigo por ritmo: o círculo só ajuda a criança a achar o próximo pulo
	_do_hop()
	return true


func _throw_stone() -> void:
	player.visual.play("throw")
	# força 0..1 -> distância ao longo das casas (até o fim do céu)
	var dist := lerpf(0.3, 5.6, _power)
	var land := ORIGIN + Vector3(randf_range(-0.12, 0.12) + (CELLS[target].x if target in CELLS else 0.0), 0.04, -dist)
	_stone.visible = true
	var tw := create_tween()
	tw.tween_property(_stone, "global_position", land, 0.5).from(player.global_position + Vector3(0, 1.2, -0.3))
	await tw.finished
	if not running:
		return
	_stone_cell = _cell_at(land)
	# perto o bastante da casa certa? a pedrinha "escorrega" para ela
	var want := cell_pos(target)
	if _stone_cell != target and absf(land.z - want.z) < 0.8:
		var snap := create_tween()
		snap.tween_property(_stone, "global_position", want + Vector3(0, 0.04, 0), 0.18)
		_stone_cell = target
		GameManager.show_toast("Quase! A pedrinha rolou para a casa %d." % target)
	if _stone_cell != target:
		_fail("A pedrinha caiu fora da casa %d!" % target)
		return
	AudioManager.play_ui("ui_confirm", -6.0)
	stage = "hop"
	_plan = hop_plan(target)
	_plan_i = 0
	_beat_t = 0.0
	_update_hud()


func _cell_at(p: Vector3) -> int:
	for n in CELLS.keys():
		var c := cell_pos(n)
		if absf(p.x - c.x) < 0.48 and absf(p.z - c.z) < 0.46:
			return n
	return 0


func _do_hop() -> void:
	var step: Dictionary = _plan[_plan_i]
	_hopping = true
	_beat_t = 0.0
	var from := player.global_position
	var to: Vector3 = step.pos
	if to.distance_to(from) > 0.01:
		player.yaw = atan2(to.x - from.x, to.z - from.z) if absf(to.z - from.z) > 0.3 else player.yaw
	var tw := create_tween()
	tw.tween_method(func(k: float):
		player.global_position = from.lerp(to, k)
		player.visual.position.y = sin(PI * k) * 0.32, 0.0, 1.0, 0.33)
	tw.tween_callback(func():
		player.visual.position.y = 0.0
		_hopping = false
		if step.get("end", false):
			_round_done()
			return
		if step.pose != "":
			player.visual.play(step.pose)
		if step.get("pick", false):
			_stone.visible = false
			AudioManager.play_ui("pickup", -6.0)
		_plan_i += 1)
	AudioManager.play_3d("step_hard", to, -8.0)


func _round_done() -> void:
	player.visual.stop_action()
	GameManager.show_toast("Casa %d completa!" % target)
	target += 1
	if target > 8:
		_finish()
		return
	_to_start()


func _fail(msg: String) -> void:
	lives -= 1
	player.visual.play("sad")
	AudioManager.play_ui("bonk", -8.0)
	GameManager.show_toast(msg)
	_stone.visible = false
	if lives <= 0:
		_finish()
		return
	get_tree().create_timer(1.2).timeout.connect(_to_start)
	stage = "wait"


func tick(delta: float) -> void:
	if not running:
		return
	if stage == "throw" and _charging:
		_power += _power_dir * delta * 0.42
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
		hud.set_meter(_power)
		# prévia: casa que a pedra vai atingir
		var dist := lerpf(0.3, 5.6, _power)
		_beat_ring.visible = true
		_beat_ring.global_position = ORIGIN + Vector3(CELLS[target].x, 0.05, -dist)
		# verde = vai cair na casa certa
		var on_target := absf(-dist - (cell_pos(target).z - ORIGIN.z)) < 0.8
		_beat_ring.scale = Vector3.ONE * (0.8 if on_target else 0.55)
		(_beat_ring.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color("6be36b") if on_target else Color.WHITE
	elif stage == "hop":
		_beat_t += delta
		# anel de ritmo: encolhe até o tamanho certo = hora de pular
		var nxt: Dictionary = _plan[_plan_i]
		_beat_ring.visible = true
		_beat_ring.global_position = nxt.pos + Vector3(0, 0.05, 0)
		_beat_ring.scale = Vector3.ONE * lerpf(2.2, 0.8, clampf(_beat_t / BEAT, 0.0, 1.0))
		# demorou? pula sozinho (só ganha menos pontos de estilo)
		if _beat_t > BEAT * 3.0 and not _hopping:
			_do_hop()
	else:
		_beat_ring.visible = false
	player.visual.rotation.y = player.yaw
	player._emit_context()


func _finish() -> void:
	if not running:
		return
	var done := target - 1
	var won := 1 if done >= 8 else (0 if done >= 4 else -1)
	end_game(won, "Amarelinha: %d casas" % done, 4 + done * 3, 8 + done * 4, {"score": done})


func cleanup() -> void:
	player.visual.position.y = 0.0
	player.visual.stop_action(false)
	player.movement_locked = false
	if is_instance_valid(_root):
		_root.queue_free()
	super.cleanup()
