extends Minigame
## SOLTAR PIPA no alto do Morro. A pipa fica presa na linha (na mão da
## criança) e voa com o vento:
##   • SEGURE o amarelo para PUXAR a linha (a pipa sobe); solte e ela desce;
##   • joystick para os lados leva a pipa para a esquerda/direita;
##   • pegue as estrelas que aparecem no céu; cuidado com as RAJADAS de vento
##     (a pipa dá um tranco para o lado) e não deixe a pipa cair no chão!
## 90 segundos, 3 vidas. Online: rodada com a turma (maior placar ganha).

const TIME := 90.0
const LINE := 22.0
const SPOT := Vector3(-45, 0, -104)  # topo do Morro

var az := 0.0      # para os lados (rad), 0 = para o norte
var el := 0.6      # altura (rad acima do horizonte)
var _el_v := 0.0
var _az_v := 0.0
var _pull := false
var lives := 3
var stars := 0
var _star_nodes: Array = []  # [{node, az, el, t}]
var _gust := 0.0
var _gust_dir := 0.0
var _gust_t := 6.0
var _kite: Node3D
var _line: MeshInstance3D
var _im: ImmediateMesh
var _base_yaw := PI  # olhando para o norte (-z)
var _spawn_t := 1.0
var _crash_t := 0.0


func begin() -> void:
	player.force_stand()
	var top := SPOT
	top.y = ParkHill.height(top.x, top.z) + 0.05
	player.global_position = top
	player.yaw = _base_yaw
	player.velocity = Vector3.ZERO
	player.movement_locked = true
	_build_kite()
	time_left = TIME
	countdown(3.0)
	super.begin()
	hud.show_banner("Soltar pipa!", "Segure o amarelo para PUXAR. Pegue as estrelas!")
	player.visual.play("raise_hand")


func _build_kite() -> void:
	_kite = Node3D.new()
	var md := MeshData.new()
	var cols := [Color("e53935"), Color("ffd23f"), Color("2f80ed"), Color("27ae60")]
	var top := Vector3(0, 0.75, 0)
	var bot := Vector3(0, -0.75, 0)
	var lf := Vector3(-0.55, 0.15, 0)
	var rt := Vector3(0.55, 0.15, 0)
	var ctr := Vector3(0, 0.15, 0)
	var tris := [[top, lf, ctr], [top, ctr, rt], [lf, bot, ctr], [ctr, bot, rt]]
	for i in tris.size():
		md.cur_color = cols[i]
		var a: Vector3 = tris[i][0]
		var b: Vector3 = tris[i][1]
		var c: Vector3 = tris[i][2]
		var nn := (b - a).cross(c - a).normalized()
		md.tri(md.add_vertex(a, nn), md.add_vertex(b, nn), md.add_vertex(c, nn))
	md.cur_color = Color("5d4037")
	md.add_box(Transform3D(Basis(), Vector3(0, 0, 0.02)), Vector3(0.04, 1.5, 0.03))
	md.add_box(Transform3D(Basis(), Vector3(0, 0.15, 0.02)), Vector3(1.1, 0.04, 0.03))
	# rabiola com lacinhos
	for k in 7:
		md.cur_color = cols[k % cols.size()]
		md.add_box(Transform3D(Basis(Vector3.FORWARD, 0.5 * (1 if k % 2 == 0 else -1)), Vector3(sin(k * 0.9) * 0.12, -0.9 - k * 0.32, 0)), Vector3(0.22, 0.06, 0.02))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	_kite.add_child(mi)
	world.add_child(_kite)
	_line = MeshInstance3D.new()
	_im = ImmediateMesh.new()
	_line.mesh = _im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.9)
	_line.material_override = lm
	world.add_child(_line)


func _hand() -> Vector3:
	return player.visual.hand_position()


func _kite_pos(a: float, e: float) -> Vector3:
	var dir := Vector3(sin(_base_yaw + a) * cos(e), sin(e), cos(_base_yaw + a) * cos(e))
	return player.global_position + Vector3(0, 1.2, 0) + dir * LINE


func play_label() -> String:
	return "Puxar!"


func on_play() -> bool:
	_pull = true
	return true


func on_play_release() -> bool:
	_pull = false
	return true


func hidden_buttons() -> Array:
	return ["run", "jump", "emote", "ride"]


func tick(delta: float) -> void:
	if not running:
		return
	if counting(delta):
		_place(delta)
		return
	time_left -= delta
	tick_clock(time_left)
	if time_left <= 0.0 or lives <= 0:
		_finish()
		return
	# rajadas de vento
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = randf_range(5.0, 9.0)
		_gust = 1.0
		_gust_dir = 1.0 if randf() < 0.5 else -1.0
		GameManager.show_toast("RAJADA de vento para a %s!" % ("direita" if _gust_dir > 0.0 else "esquerda"))
		AudioManager.play_ui("whoosh", -6.0)
	_gust = maxf(_gust - delta * 0.7, 0.0)
	if _crash_t > 0.0:
		_crash_t -= delta
		if _crash_t <= 0.0:
			el = 0.55
			_el_v = 0.0
		_place(delta)
		return
	# física simples: puxar = sobe; soltar = desce; o vento balança
	var steer := player.read_move_raw().x
	var lift := 1.4 * (1.0 - el / 1.45) if _pull else -0.55 - 0.3 * el
	_el_v = lerpf(_el_v, lift, 1.0 - exp(-3.0 * delta))
	el = clampf(el + _el_v * delta + sin(Time.get_ticks_msec() * 0.002) * 0.02 * delta, -0.1, 1.35)
	_az_v = lerpf(_az_v, steer * 1.1 + _gust * _gust_dir * 1.4, 1.0 - exp(-4.0 * delta))
	az = clampf(az + _az_v * delta, -1.2, 1.2)
	if el < 0.06:
		_crash()
	_place(delta)
	_tick_stars(delta)
	hud.set_minigame_text("Pipa  ·  estrelas: %d  ·  vidas: %d  ·  %s" % [stars, lives, fmt_time(time_left)])
	if time_left <= 0.0 or lives <= 0:
		_finish()


func _crash() -> void:
	lives -= 1
	break_combo()
	AudioManager.play_ui("bonk", -4.0)
	GameManager.show_toast("A pipa caiu! %s" % ("Mais uma tentativa..." if lives > 0 else "Acabaram as vidas."))
	_crash_t = 1.2
	el = 0.05


func _place(delta: float) -> void:
	var kp := _kite_pos(az, el)
	var hand := _hand()
	_kite.global_position = kp
	var look := hand - kp
	if look.length() > 0.1:
		_kite.global_basis = Basis.looking_at(-look.normalized(), Vector3.UP) * Basis(Vector3.FORWARD, _az_v * 0.4 + sin(Time.get_ticks_msec() * 0.006) * 0.12)
	# linha com uma barriguinha
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var t := i / 12.0
		var p := hand.lerp(kp, t) - Vector3(0, sin(t * PI) * 1.4, 0)
		_im.surface_add_vertex(p)
	_im.surface_end()
	# o jogador vira para a pipa e a câmera mostra o céu
	player.yaw = lerp_angle(player.yaw, _base_yaw + az, 1.0 - exp(-5.0 * delta))
	player.visual.rotation.y = player.yaw
	if player.camera_rig:
		var back := Vector3(sin(player.yaw), 0, cos(player.yaw))
		var eye := player.global_position - back * 4.5 + Vector3(0, 2.2, 0)
		var target := (player.global_position + Vector3(0, 1.5, 0)).lerp(kp, 0.55)
		player.camera_rig.override_snap = true
		player.camera_rig.set_override(Transform3D(Basis(), eye).looking_at(target, Vector3.UP))


func _tick_stars(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _star_nodes.size() < 3:
		_spawn_t = randf_range(1.5, 3.0)
		var s := Sprite3D.new()
		s.texture = EmoteFX.icon("star", Color("ffd23f"))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.02
		s.shaded = false
		world.add_child(s)
		var e := {"node": s, "az": randf_range(-1.0, 1.0), "el": randf_range(0.35, 1.2), "t": 7.0}
		s.global_position = _kite_pos(e.az, e.el)
		_star_nodes.append(e)
	var kp := _kite.global_position
	for e in _star_nodes.duplicate():
		e.t = float(e.t) - delta
		var n: Sprite3D = e.node
		n.rotation.z += delta * 2.0
		n.global_position = _kite_pos(e.az, e.el) + Vector3(0, sin(Time.get_ticks_msec() * 0.003 + float(e.az) * 5.0) * 0.3, 0)
		if n.global_position.distance_to(kp) < 1.8:
			stars += combo_mult()
			add_combo()
			popup(n.global_position, "+%d" % combo_mult(), Color("ffd23f"))
			AudioManager.play_ui("coin", -4.0)
			n.queue_free()
			_star_nodes.erase(e)
		elif e.t <= 0.0:
			n.queue_free()
			_star_nodes.erase(e)


func _finish() -> void:
	if not running:
		return
	if is_net():
		NetworkManager.mg_score(str(net.gid), float(stars), true)
	var won := 1 if stars >= 12 else (0 if stars >= 6 else -1)
	end_game(won, "Pipa: %d estrelas" % stars, 6 + stars * 2, 10 + stars * 3, {"score": stars})


func cleanup() -> void:
	player.movement_locked = false
	if player.camera_rig:
		player.camera_rig.set_override(null)
	player.visual.stop_action()
	for e in _star_nodes:
		if is_instance_valid(e.node):
			(e.node as Node).queue_free()
	if is_instance_valid(_kite):
		_kite.queue_free()
	if is_instance_valid(_line):
		_line.queue_free()
	super.cleanup()


func hints() -> Dictionary:
	return {"start": "SEGURE o botão amarelo para a pipa subir. Solte um pouco para ela descer. Joystick = para os lados.", "idle": "Segure o amarelo, senão a pipa cai!", "miss": ""}
