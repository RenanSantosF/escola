class_name KartRace
extends Minigame
## Corrida de KART no Kartódromo que dá a volta na escola (KartTrack).
## 3 voltas contra 5 pilotos (ou contra a turma, online).
##
## Controles (pensados para criança):
##   • o kart ACELERA SOZINHO; joystick para os lados = virar;
##     joystick para trás ou botão azul = FREAR;
##   • VERDE (segure) = DERRAPAR: faz a curva mais fechada e carrega um
##     miniturbo (faíscas azuis → laranja); soltou = impulso!
##   • AMARELO = TURBO (pega nas caixinhas "?" da pista);
##   • setas amarelas no chão = turbo grátis; morrinhos = SALTO.
## A pista é um trilho (KartTrack): o kart anda liso em subida, descida,
## curva e viaduto; bater na mureta faz perder velocidade.

const LAPS := 3
const BOTS := 5
const MAX_V := 23.0          # m/s (~83 km/h de kart de brinquedo...)
const BOOST_V := 31.0
const ACCEL := 9.0
const BRAKE := 20.0
const DRIFT_MINI := [0.9, 1.9]  # segundos de derrapagem para miniturbo azul / laranja
const ITEM_U := [0.18, 0.62, 0.86]  # caixinhas de turbo (fração da volta)
const TIME_LIMIT := 300.0
const COLORS := [Color("e53935"), Color("2f80ed"), Color("27ae60"), Color("ffb300"), Color("8e44ad"), Color("ff6fae"), Color("16a085"), Color("f39c12")]
const NAMES_BOT := ["Bia", "Rafa", "Pedro", "Lucas", "Júlia", "Gui"]

var racers: Array = []   # [{who, kart, wheels, s, d, h, v, lap, done, time, ai, boost, ...}]
var me: Dictionary = {}
var _elapsed := 0.0
var _finished_order: Array = []
var _end_t := -1.0
var _cam_xf := Transform3D()
var _hud: Control
var _lights: Array[MeshInstance3D] = []
var _items: Array = []  # [{s, node, back_t}]
var _drift := false
var _drift_t := 0.0
var _drift_dir := 0.0
var _turbos := 1
var _sparks: GPUParticles3D
var _brake_btn := false
var _net_t := 0.0
var _remote_prog := {}  # id -> [progresso, terminou?]
var _total := 0.0


func begin() -> void:
	_total = KartTrack.length()
	player.force_stand()
	if player.riding:
		player.toggle_ride()
	player.bounds_off = true
	player.collision_mask = 0
	player.movement_locked = true
	player.input_enabled = true
	var multi := is_multi()
	var grid := 0
	if multi:
		grid = maxi(int(net.get("index", 0)), 0)
	me = _add_racer(player, COLORS[grid % COLORS.size()], grid, false, player.visual.appearance.kart)
	if not multi:
		var bots: Array[NPC] = students(BOTS, KartTrack.pos_at(0.0))
		take_npcs(bots)
		for i in bots.size():
			var r := _add_racer(bots[i], COLORS[(i + 1) % COLORS.size()], i + 1, true)
			r.name = bots[i].display_name
	if is_net():
		NetworkManager.mg_relay.connect(_on_relay)
	_build_lights()
	_build_items()
	_build_hud()
	_build_sparks()
	player.visual.play("sit_down")
	_place_all(0.0)
	_cam_xf = _chase_xf(me)
	if player.camera_rig:
		player.camera_rig.set_override(_cam_xf)
	time_left = TIME_LIMIT
	countdown(3.0)
	super.begin()
	hud.show_banner("Corrida de Kart!", "3 voltas em volta da escola. Prepare-se!")
	AudioManager.play_ui("ui_confirm", -4.0)


## Posição na largada: 2 por fila, atrás da faixa quadriculada.
func _add_racer(who: Node3D, col: Color, grid: int, ai: bool, paint := "") -> Dictionary:
	var row := grid / 2
	var side := -1.0 if grid % 2 == 0 else 1.0
	var r := {
		"who": who, "s": -3.0 - row * 4.2, "d": side * 2.2, "h": 0.0, "v": 0.0, "lap": 0, "done": false,
		"time": 0.0, "ai": ai, "boost": 0.0, "wall_cd": 0.0, "air_y": 0.0, "air_v": 0.0, "prev_slope": 0.0,
		"name": "Você" if who == player else "", "color": col, "max": randf_range(22.0, 24.2) if ai else MAX_V,
		"line": randf_range(-1.2, 1.2), "skill": randf_range(0.75, 1.0), "turbo_t": randf_range(8.0, 20.0),
	}
	var k := make_kart_item(paint) if paint != "" else make_kart(col)
	if paint != "":
		r.color = Color(str(ShopCatalog.get_item(paint).get("kart", {}).get("color", col.to_html())))
	world.add_child(k)
	r["kart"] = k
	r["wheels"] = k.get_meta("wheels")
	if who is NPC:
		(who as NPC).visual.play("sit_down")
		(who as NPC).stop()
	racers.append(r)
	return r


## Kart com a pintura de um item da loja (kart_dourado, kart_chamas...).
static func make_kart_item(id: String) -> Node3D:
	var k: Dictionary = ShopCatalog.get_item(id).get("kart", {})
	if k.is_empty():
		return make_kart(COLORS[0])
	return make_kart(Color(str(k.get("color", "e53935"))), Color(str(k.get("accent", "ffffff"))), str(k.get("style", "")))


## Kart de brinquedo colorido (também usado para mostrar o kart de um colega online).
## style: "" | "listras" | "xadrez" | "chamas" | "estrelas" | "arco"
static func make_kart(col: Color, accent := Color.WHITE, style := "") -> Node3D:
	var root := Node3D.new()
	root.name = "Kart"
	var md := MeshData.new()
	var dark := col.darkened(0.35)
	# chassi baixo, laterais, bico com número, aerofólio, banco e volante
	md.cur_color = Color("2b2d33")
	md.add_box(Transform3D(Basis(), Vector3(0, 0.16, 0)), Vector3(1.05, 0.08, 1.9))
	md.cur_color = col
	md.add_box(Transform3D(Basis(), Vector3(0, 0.3, 0.72)), Vector3(0.9, 0.22, 0.55))
	md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.36, 1.02)), Vector3(0.7, 0.12, 0.35))
	for sx in [-1.0, 1.0]:
		md.add_box(Transform3D(Basis(), Vector3(sx * 0.52, 0.27, 0.0)), Vector3(0.16, 0.2, 1.1))
	md.cur_color = dark
	md.add_box(Transform3D(Basis(), Vector3(0, 0.25, -0.95)), Vector3(1.1, 0.12, 0.18))
	md.add_box(Transform3D(Basis(), Vector3(0, 0.62, -0.92)), Vector3(1.0, 0.06, 0.28))
	for sx in [-0.4, 0.4]:
		md.add_box(Transform3D(Basis(), Vector3(sx, 0.45, -0.92)), Vector3(0.05, 0.3, 0.05))
	md.cur_color = Color("1d1d1d")
	md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.36, -0.35)), Vector3(0.5, 0.42, 0.08))
	md.add_box(Transform3D(Basis(), Vector3(0, 0.24, -0.15)), Vector3(0.5, 0.06, 0.45))
	md.add_box(Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, 0.55, 0.42)), Vector3(0.05, 0.25, 0.05))
	md.cur_color = Color("dfe6ee")
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.9), Vector3(0, 0.63, 0.48)), 0.15, 0.15, 0.04, 10)
	md.cur_color = Color("8a96a3")
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.22, 0.3, -1.02)), 0.06, 0.06, 0.12, 8)
	md.cur_color = Color.WHITE
	md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -0.35 + PI * 0.5), Vector3(0, 0.43, 1.0)), 0.13, 0.13, 0.02, 12)
	# pintura especial
	match style:
		"listras":
			md.cur_color = accent
			for sx in [-0.14, 0.14]:
				md.add_box(Transform3D(Basis(), Vector3(sx, 0.415, 0.72)), Vector3(0.09, 0.02, 0.56))
				md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(sx, 0.43, 1.02)), Vector3(0.09, 0.02, 0.36))
		"xadrez":
			for i in 4:
				for j in 2:
					md.cur_color = accent if (i + j) % 2 == 0 else col
					md.add_box(Transform3D(Basis(), Vector3(-0.3 + i * 0.2, 0.415, 0.6 + j * 0.2)), Vector3(0.2, 0.02, 0.2))
		"chamas":
			md.cur_color = accent
			for sx in [-1.0, 1.0]:
				for k in 4:
					md.add_box(Transform3D(Basis(Vector3.FORWARD, 0.6 * sx), Vector3(sx * 0.61, 0.28 + (k % 2) * 0.04, 0.4 - k * 0.22)), Vector3(0.02, 0.1, 0.26 - k * 0.04))
			md.cur_color = accent.lightened(0.3)
			md.add_box(Transform3D(Basis(), Vector3(0, 0.415, 0.75)), Vector3(0.5, 0.02, 0.3))
		"estrelas":
			md.cur_color = accent
			for p in [Vector3(-0.25, 0.415, 0.6), Vector3(0.2, 0.415, 0.8), Vector3(0.05, 0.415, 0.55), Vector3(0.6, 0.29, -0.2), Vector3(-0.6, 0.29, 0.2)]:
				md.add_box(Transform3D(Basis(Vector3.UP, 0.78), p), Vector3(0.09, 0.025, 0.09))
		"arco":
			var rb := [Color("e53935"), Color("ff8a1f"), Color("ffd23f"), Color("27ae60"), Color("2f80ed"), Color("8e44ad")]
			for i in rb.size():
				md.cur_color = rb[i]
				md.add_box(Transform3D(Basis(), Vector3(-0.375 + i * 0.15, 0.415, 0.72)), Vector3(0.15, 0.02, 0.56))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mat.metallic = 0.1
	var body := MeshInstance3D.new()
	body.mesh = md.build_mesh(mat)
	root.add_child(body)
	# rodas (giram e as da frente esterçam)
	var wmd := MeshData.new()
	wmd.cur_color = Color("1d1d1d")
	wmd.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.2, 0.2, 0.22, 14)
	wmd.cur_color = Color("cfd5dc")
	wmd.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.1, 0.1, 0.24, 8)
	var wmesh := wmd.build_mesh(mat)
	var wheels: Array = []
	for w in [[-0.6, 0.65], [0.6, 0.65], [-0.62, -0.7], [0.62, -0.7]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(w[0], 0.2, w[1])
		root.add_child(pivot)
		var wi := MeshInstance3D.new()
		wi.mesh = wmesh
		pivot.add_child(wi)
		wheels.append(pivot)
	root.set_meta("wheels", wheels)
	return root


# ---------------------------------------------------------------- cenário da corrida

func _build_lights() -> void:
	var st: Dictionary = world.builder.kart_start
	var sp: Vector3 = st.get("pos", KartTrack.pos_at(0.0))
	var sd: Vector3 = st.get("dir", Vector3.FORWARD)
	var right := Vector3(-sd.z, 0, sd.x)
	for i in 4:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.64
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("3a1010")
		m.emission_enabled = true
		m.emission = Color.BLACK
		mi.material_override = m
		world.add_child(mi)
		mi.global_position = sp + right * (-1.5 + i) + Vector3(0, 4.25, 0) - sd * 0.25
		_lights.append(mi)


func _set_lights(n_red: int, green: bool) -> void:
	for i in _lights.size():
		var m := _lights[i].material_override as StandardMaterial3D
		if green:
			m.albedo_color = Color("2ecc71")
			m.emission = Color("2ecc71") * 2.0
		elif i < n_red:
			m.albedo_color = Color("ff2d2d")
			m.emission = Color("ff2d2d") * 2.0
		else:
			m.albedo_color = Color("3a1010")
			m.emission = Color.BLACK


## Caixinhas "?" que dão TURBO (somem e voltam depois de alguns segundos).
func _build_items() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("ffb300")
	mat.emission_energy_multiplier = 0.6
	for u in ITEM_U:
		var s: float = u * _total
		for lane in [-2.8, 0.0, 2.8]:
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.75, 0.75, 0.75)
			box.mesh = bm
			box.material_override = mat
			var lb := Label3D.new()
			lb.text = "?"
			lb.font = UITheme.bold_font()
			lb.font_size = 96
			lb.pixel_size = 0.006
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.modulate = Color("2f5fa8")
			lb.outline_size = 12
			box.add_child(lb)
			world.add_child(box)
			box.global_position = KartTrack.world_at(s, lane) + Vector3(0, 0.9, 0)
			_items.append({"s": s, "d": lane, "node": box, "back": 0.0})


func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.35
	_sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, -1)
	pm.spread = 35.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	_sparks.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("4fc3ff")
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = sm
	_sparks.draw_pass_1 = qm
	(me.kart as Node3D).add_child(_sparks)
	_sparks.position = Vector3(0, 0.1, -0.8)


# ---------------------------------------------------------------- botões

func play_label() -> String:
	return ("TURBO x%d" % _turbos) if _turbos > 0 else ""


func interact_label() -> String:
	return "Derrapar"


func on_play() -> bool:
	if _countdown > 0.0 or me.done or _turbos <= 0:
		return true
	_turbos -= 1
	_give_boost(me, 1.6)
	popup((me.who as Node3D).global_position + Vector3(0, 2.2, 0), "TURBO!", Color("ffb300"), 80)
	player._emit_context(true)
	return true


func on_interact() -> bool:
	if _countdown > 0.0 or me.done:
		return true
	_drift = true
	_drift_t = 0.0
	_drift_dir = signf(_steer_input()) if absf(_steer_input()) > 0.2 else 0.0
	me.air_v = maxf(me.air_v, 2.2)  # pulinho para entrar na derrapagem
	return true


func on_interact_release() -> bool:
	if _drift:
		_drift = false
		_sparks.emitting = false
		if _drift_t >= DRIFT_MINI[1]:
			_give_boost(me, 1.1)
			popup((me.who as Node3D).global_position + Vector3(0, 2.2, 0), "SUPER MINITURBO!", Color("ff8a1f"), 64)
		elif _drift_t >= DRIFT_MINI[0]:
			_give_boost(me, 0.6)
			popup((me.who as Node3D).global_position + Vector3(0, 2.2, 0), "Miniturbo!", Color("4fc3ff"), 56)
	return true


func on_jump() -> bool:
	_brake_btn = true
	get_tree().create_timer(0.35).timeout.connect(func(): _brake_btn = false)
	return true


func hidden_buttons() -> Array:
	return ["run", "emote", "ride"]


func _steer_input() -> float:
	var raw := player.read_move_raw()
	return clampf(raw.x, -1.0, 1.0)


func _give_boost(r: Dictionary, secs: float) -> void:
	r.boost = maxf(r.boost, secs)
	if r == me:
		AudioManager.play_ui("whoosh", -2.0)
		if player.camera_rig:
			player.camera_rig.shake(0.05)


# ---------------------------------------------------------------- simulação

func tick(delta: float) -> void:
	if not running:
		return
	var counting_now := counting(delta)
	_update_lights()
	if counting_now:
		_place_all(delta)
		_update_camera(delta)
		_update_hud()
		return
	_elapsed += delta
	time_left -= delta
	for r in racers:
		_step(r, delta)
	_collide()
	_check_items(delta)
	_place_all(delta)
	_update_camera(delta)
	_update_hud()
	if is_multi():
		_net_send(delta)
	# fim: eu cheguei (espera 3 s mostrando o pódio) ou estourou o tempo
	if me.done and _end_t < 0.0:
		_end_t = 3.5
	if _end_t >= 0.0:
		_end_t -= delta
		if _end_t <= 0.0:
			_finish()
	elif time_left <= 0.0:
		_finish()


func _update_lights() -> void:
	if _countdown > 0.0:
		_set_lights(clampi(4 - ceili(_countdown), 1, 3), false)
	elif _elapsed < 1.5:
		_set_lights(0, true)
	else:
		_set_lights(0, false)


func _step(r: Dictionary, delta: float) -> void:
	if r.done and r != me and not r.ai:
		return
	var steer := 0.0
	var brake := false
	var maxv: float = r.max
	if r.done:
		# depois da chegada: volta devagarinho
		maxv = 9.0
		steer = clampf((0.0 - float(r.d)) * 0.3 - float(r.h) * 1.5, -1.0, 1.0)
	elif r.ai:
		steer = _ai_steer(r)
		maxv = _ai_max(r)
	else:
		steer = _steer_input()
		brake = _brake_btn or player.read_move_raw().y > 0.6
		# ajudinha na curva (metade do volante já vem certo): divertido para criança
		var tn := lerpf(2.6, 1.35, clampf(absf(float(r.v)) / MAX_V, 0.0, 1.0))
		steer = clampf(steer + KartTrack.curve_at(r.s) * float(r.v) / tn * 0.75, -1.3, 1.3)
	r.wall_cd = maxf(float(r.wall_cd) - delta, 0.0)
	r.boost = maxf(float(r.boost) - delta, 0.0)
	var v: float = r.v
	# acelera sozinho; freio; turbo
	if brake:
		v = move_toward(v, -3.0 if v < 1.0 else 0.0, BRAKE * delta)
	else:
		var top := BOOST_V if r.boost > 0.0 else maxv
		v = move_toward(v, top, (ACCEL * (2.2 if r.boost > 0.0 else 1.0)) * delta) if v < top else move_toward(v, top, 6.0 * delta)
	# subida segura, descida acelera
	var dir := KartTrack.dir_at(r.s)
	if r.air_y <= 0.0:
		v -= 9.8 * dir.y * delta * 0.85
	v = clampf(v, -4.0, BOOST_V + 6.0)
	# direção: vira mais devagar em alta velocidade; derrapando, curva fechada
	var turn := lerpf(2.6, 1.35, clampf(absf(v) / MAX_V, 0.0, 1.0))
	if r == me and _drift:
		_drift_t += delta
		if _drift_dir == 0.0 and absf(steer) > 0.2:
			_drift_dir = signf(steer)
		if _drift_dir != 0.0:
			# derrapando: curva mais fechada (o kart "de lado" é só visual)
			turn *= 1.3
			v *= 1.0 - 0.05 * delta
			_sparks.emitting = _drift_t > 0.3 and absf(v) > 6.0
			var sm := (_sparks.draw_pass_1 as QuadMesh).material as StandardMaterial3D
			sm.albedo_color = Color("ff8a1f") if _drift_t >= DRIFT_MINI[1] else Color("4fc3ff")
	# a pista faz a curva por baixo do kart: o rumo é relativo à pista
	var curve := KartTrack.curve_at(r.s)
	var h: float = r.h + (steer * turn - curve * v) * delta
	h = clampf(h, -1.2, 1.2)
	# sem mexer, o kart "endireita" um pouco (fica fácil de dirigir)
	if absf(steer) < 0.1 and not (r == me and _drift):
		h = move_toward(h, 0.0, 0.6 * delta)
	var ds := v * cos(h) * delta
	var dd := v * sin(h) * delta
	var d: float = r.d + dd
	var half := KartTrack.width_at(r.s) * 0.5 - 0.8
	if absf(d) > half:
		d = clampf(d, -half, half)
		if r.wall_cd <= 0.0 and absf(v) > 6.0:
			r.wall_cd = 0.5
			v *= 0.72
			if r == me:
				AudioManager.play_ui("bonk", -6.0)
				if player.camera_rig:
					player.camera_rig.shake(0.12)
				_drift = false
				_sparks.emitting = false
		h *= 0.4
	r.v = v
	r.h = h
	r.d = d
	# salto: crista do morrinho com velocidade = voa um pouco
	var slope := dir.y
	if r.air_y <= 0.0 and float(r.prev_slope) > 0.09 and slope < float(r.prev_slope) - 0.06 and v > 14.0:
		r.air_v = v * float(r.prev_slope) * 0.9
		if r == me:
			popup(player.global_position + Vector3(0, 2.4, 0), "SALTO!", Color("6be36b"), 70)
			AudioManager.play_ui("jump", -4.0)
	r.prev_slope = slope
	if r.air_v > 0.0 or r.air_y > 0.0:
		r.air_v = float(r.air_v) - 14.0 * delta
		r.air_y = maxf(float(r.air_y) + float(r.air_v) * delta, 0.0)
		if r.air_y <= 0.0:
			r.air_v = 0.0
			if r == me and v > 12.0:
				AudioManager.play_ui("land", -6.0)
	# placas de turbo
	for u in KartTrack.BOOST_U:
		var bs: float = u * _total
		var before: float = fposmod(r.s - bs, _total)
		if before > _total - ds - 0.01 or (before < 0.05 and ds > 0.0):
			if absf(d) < 2.2:
				_give_boost(r, 0.9)
	# avança e conta a volta
	var ns: float = r.s + ds
	if r.s < 0.0 and ns >= 0.0 and r.lap == 0:
		pass  # saiu do grid
	elif r.s < _total and ns >= _total:
		ns -= _total
		_lap_done(r)
	elif ns < 0.0 and r.lap > 0:
		ns += _total
		r.lap -= 1
	r.s = ns


func _lap_done(r: Dictionary) -> void:
	r.lap = int(r.lap) + 1
	if r.lap >= LAPS and not r.done:
		r.done = true
		r.time = _elapsed
		_finished_order.append(r)
		if r == me:
			var pos := _finished_order.size()
			hud.show_banner("CHEGADA! %dº lugar" % _place_of(me), "Tempo: %s" % _fmt(_elapsed))
			AudioManager.play_ui("win" if _place_of(me) <= 3 else "reward", -2.0)
			Effects.burst(player.global_position + Vector3(0, 1.5, 0), "confetti")
			if is_net():
				NetworkManager.mg_score(str(net.gid), snappedf(_elapsed, 0.01), true)
			pos = pos
	elif r == me:
		if r.lap == LAPS - 1:
			hud.show_banner("ÚLTIMA VOLTA!", "")
			AudioManager.play_ui("whistle", -4.0)
		else:
			hud.show_banner("Volta %d de %d" % [r.lap + 1, LAPS], _fmt(_elapsed))
			AudioManager.play_ui("ui_confirm", -6.0)


# ---------------------------------------------------------------- pilotos-bot

func _ai_steer(r: Dictionary) -> float:
	# traçado: lado de dentro das curvas que vêm aí + "estilo" de cada um
	var ahead := KartTrack.curve_at(r.s + 14.0)
	var half := KartTrack.width_at(r.s) * 0.5 - 1.4
	var target := clampf(ahead * 260.0 + float(r.line), -half, half)
	# desvia de quem está logo à frente
	for o in racers:
		if o == r:
			continue
		var ds := fposmod(float(o.s) - float(r.s), _total)
		if ds > 0.5 and ds < 6.0 and absf(float(o.d) - target) < 1.6:
			target += 2.0 if float(o.d) <= float(r.d) else -2.0
	target = clampf(target, -half, half)
	var want_h := clampf((target - float(r.d)) * 0.16, -0.45, 0.45)
	var curve := KartTrack.curve_at(r.s)
	# esterço que mantém o rumo desejado mais o necessário para a curva
	var turn := lerpf(2.6, 1.35, clampf(absf(float(r.v)) / MAX_V, 0.0, 1.0))
	var need := (curve * float(r.v)) / maxf(turn, 0.1)
	return clampf(need + (want_h - float(r.h)) * 3.0 * float(r.skill), -1.0, 1.0)


func _ai_max(r: Dictionary) -> float:
	var m: float = r.max
	# freia um pouco nas curvas fortes
	var c := absf(KartTrack.curve_at(r.s + 10.0))
	m -= clampf(c * 260.0, 0.0, 5.0)
	# "elástico": se o jogador ficou muito para trás, pega leve (e vice-versa)
	var gap := _progress(r) - _progress(me)
	if gap > 60.0:
		m -= 2.5
	elif gap < -60.0:
		m += 2.0
	r.turbo_t = float(r.turbo_t) - get_process_delta_time()
	if r.turbo_t <= 0.0:
		r.turbo_t = randf_range(14.0, 26.0)
		_give_boost(r, 1.2)
	return m


# ---------------------------------------------------------------- colisões e caixinhas

func _collide() -> void:
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a: Dictionary = racers[i]
			var b: Dictionary = racers[j]
			var ds := wrapf(float(a.s) - float(b.s), -_total * 0.5, _total * 0.5)
			var dd := float(a.d) - float(b.d)
			if absf(ds) < 1.7 and absf(dd) < 1.25:
				var push := (1.25 - absf(dd)) * 0.5 * (1.0 if dd >= 0.0 else -1.0)
				a.d = float(a.d) + push
				b.d = float(b.d) - push
				# quem vem atrás perde um pouco
				var back: Dictionary = b if ds > 0.0 else a
				back.v = float(back.v) * 0.97
				if (a == me or b == me) and float(me.wall_cd) <= 0.0:
					me.wall_cd = 0.3
					AudioManager.play_ui("bonk", -12.0)


func _check_items(delta: float) -> void:
	for it in _items:
		var node: MeshInstance3D = it.node
		if it.back > 0.0:
			it.back = float(it.back) - delta
			node.visible = it.back <= 0.0
			continue
		node.rotate_y(delta * 2.0)
		for r in racers:
			var ds := absf(wrapf(float(r.s) - float(it.s), -_total * 0.5, _total * 0.5))
			if ds < 1.0 and absf(float(r.d) - float(it.d)) < 1.2 and r.air_y < 0.6:
				it.back = 4.0
				node.visible = false
				if r == me:
					_turbos = mini(_turbos + 1, 3)
					AudioManager.play_ui("coin", -4.0)
					GameManager.show_toast("Pegou um TURBO! Toque no botão amarelo.")
					player._emit_context(true)
				elif r.ai:
					r.turbo_t = minf(float(r.turbo_t), randf_range(1.0, 4.0))
				break


# ---------------------------------------------------------------- desenho

func _kart_xf(r: Dictionary) -> Transform3D:
	var s: float = r.s
	var p := KartTrack.world_at(s, r.d)
	var dir := KartTrack.dir_at(s)
	# rumo do kart = rumo da pista - h (h > 0 = apontando para a direita)
	var yaw := atan2(dir.x, dir.z) - float(r.h)
	if r == me and _drift:
		yaw -= _drift_dir * 0.38  # de ladinho na derrapagem
	var pitch := -atan2(dir.y, Vector2(dir.x, dir.z).length())
	var roll := clampf(-KartTrack.curve_at(s) * float(r.v) * 0.9, -0.18, 0.18)
	if r == me and _drift:
		roll *= 1.6
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	return Transform3D(b, p + Vector3(0, 0.07 + float(r.air_y), 0))


func _place_all(delta: float) -> void:
	for r in racers:
		var xf := _kart_xf(r)
		var k: Node3D = r.kart
		k.global_transform = xf
		# rodas giram com a velocidade e as da frente esterçam
		var wheels: Array = r.wheels
		var spin: float = float(r.v) * delta / 0.2
		for i in wheels.size():
			var w: Node3D = wheels[i]
			(w.get_child(0) as Node3D).rotate_x(spin)
			if i < 2:
				w.rotation.y = clampf(-float(r.h) * 1.5, -0.5, 0.5)
		# piloto sentado no banco
		var who: Node3D = r.who
		var seat := xf * Vector3(0, 0.12, -0.28)
		who.global_position = seat
		var yaw := atan2(xf.basis.z.x, xf.basis.z.z)
		if who == player:
			player.velocity = Vector3.ZERO
			player.yaw = yaw
			player.visual.rotation.y = yaw
		elif who is NPC:
			var n := who as NPC
			n.yaw = yaw
			n.visual.rotation.y = yaw
			n.moving = false


func _chase_xf(r: Dictionary) -> Transform3D:
	var xf := _kart_xf(r)
	var fwd := xf.basis.z
	fwd.y *= 0.4
	fwd = fwd.normalized()
	var eye := xf.origin - fwd * 4.6 + Vector3(0, 2.0, 0)
	var look := xf.origin + fwd * 5.0 + Vector3(0, 0.6, 0)
	return Transform3D(Basis(), eye).looking_at(look, Vector3.UP)


func _update_camera(delta: float) -> void:
	if not player.camera_rig:
		return
	var want := _chase_xf(me)
	var k := 1.0 - exp(-10.0 * delta)
	var o := _cam_xf.origin.lerp(want.origin, k)
	# nunca fica longe demais do kart (o kart sempre aparece na frente)
	if o.distance_to(want.origin) > 2.0:
		o = want.origin + (o - want.origin).normalized() * 2.0
	_cam_xf = Transform3D(_cam_xf.basis.slerp(want.basis, k).orthonormalized(), o)
	_cam_xf = _cam_xf.looking_at(KartTrack.world_at(me.s, me.d) + Vector3(0, 0.9 + float(me.air_y), 0) + (me.kart as Node3D).global_basis.z * 4.0, Vector3.UP)
	player.camera_rig.override_snap = true
	player.camera_rig.set_override(_cam_xf)
	player.camera_rig.override_cam.global_transform = _cam_xf
	var cam: Camera3D = player.camera_rig.override_cam
	cam.fov = lerpf(cam.fov, 70.0 + clampf(float(me.v) - 10.0, 0.0, 20.0) * 0.6 + (6.0 if me.boost > 0.0 else 0.0), k)
	cam.far = maxf(cam.far, 400.0)


# ---------------------------------------------------------------- posições e HUD

func _progress(r: Dictionary) -> float:
	if r.done:
		return 1e6 - float(r.time)
	return float(r.lap) * _total + float(r.s)


func _place_of(r: Dictionary) -> int:
	if r.done:
		return _finished_order.find(r) + 1 + _remote_done_before(r)
	var n := 1
	for o in racers:
		if o != r and _progress(o) > _progress(r):
			n += 1
	for id in _remote_prog.keys():
		var rp: Array = _remote_prog[id]
		if float(rp[0]) > _progress(r):
			n += 1
	return n


func _remote_done_before(r: Dictionary) -> int:
	var n := 0
	for id in _remote_prog.keys():
		var rp: Array = _remote_prog[id]
		if bool(rp[1]) and float(rp[2]) < float(r.time):
			n += 1
	return n


func _racer_count() -> int:
	return racers.size() + _remote_prog.size()


static func _fmt(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _build_hud() -> void:
	_hud = KartHUD.new()
	_hud.race = self
	hud.add_child(_hud)


func _update_hud() -> void:
	if _hud:
		_hud.queue_redraw()
	hud.set_minigame_text("")
	hud._objective.visible = false  # a faixa de objetivo some durante a corrida


# ---------------------------------------------------------------- online

func _net_send(delta: float) -> void:
	_net_t -= delta
	if _net_t > 0.0:
		return
	_net_t = 0.25
	NetworkManager.mg_send_relay(str(net.gid), {"p": snappedf(_progress(me), 0.1), "f": me.done, "t": snappedf(float(me.time), 0.01)})


func _on_relay(gid: String, from: String, d: Variant) -> void:
	if gid == str(net.get("gid", "")):
		on_net_relay(from, d)


func on_net_relay(from: String, d: Variant) -> void:
	if d is Dictionary and from != str(net.get("me", "")):
		_remote_prog[from] = [float(d.get("p", 0.0)), bool(d.get("f", false)), float(d.get("t", 0.0))]


func on_net_event(_ev: Dictionary) -> void:
	pass


# ---------------------------------------------------------------- fim

func _finish() -> void:
	if not running:
		return
	var place := _place_of(me)
	var n := _racer_count()
	if not me.done and is_net():
		NetworkManager.mg_score(str(net.gid), 999.0, true)
	var won := 1 if place == 1 else (0 if place <= 3 else -1)
	var coins: int = [30, 22, 16, 10, 8, 6, 5, 4][clampi(place - 1, 0, 7)]
	var xp: int = [50, 38, 28, 20, 16, 12, 10, 8][clampi(place - 1, 0, 7)]
	if place == 1:
		GameManager.unlock_achievement("piloto_kart")
	var txt := "Kart: %dº de %d" % [place, n] + ("  ·  %s" % _fmt(float(me.time)) if me.done else "")
	end_game(won, txt, coins, xp, {"score": float(me.time) if me.done else 999.0, "place": place})


func cleanup() -> void:
	if NetworkManager.mg_relay.is_connected(_on_relay):
		NetworkManager.mg_relay.disconnect(_on_relay)
	player.bounds_off = false
	player.collision_mask = 1 | 4 | 8
	player.visual.stop_action()
	if player.camera_rig:
		player.camera_rig.set_override(null)
		player.camera_rig.override_cam.fov = 70.0
	# volta para a estação, dentro da escola
	var st: Vector3 = mgr.GAMES.kart.pos if mgr else Vector3(-86, 0.05, -6)
	player.global_position = st + Vector3(1.5, 0.1, 0)
	player.velocity = Vector3.ZERO
	for r in racers:
		if is_instance_valid(r.kart):
			(r.kart as Node3D).queue_free()
		if r.who is NPC and is_instance_valid(r.who):
			(r.who as NPC).visual.stop_action()
			(r.who as NPC).teleport(st + Vector3(randf_range(2, 5), 0.05, randf_range(-3, 3)), 0.0)
	for l in _lights:
		l.queue_free()
	for it in _items:
		(it.node as Node3D).queue_free()
	if is_instance_valid(_hud):
		_hud.queue_free()
	hud._objective.visible = hud._objective.text != ""
	super.cleanup()


func hints() -> Dictionary:
	return {"start": "O kart acelera sozinho! Vire com o joystick, SEGURE o verde nas curvas para derrapar e ganhar miniturbo.", "idle": "", "miss": ""}
