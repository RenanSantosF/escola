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
##   • AMARELO = usa o ITEM das caixinhas "?": turbo, turbo triplo, óleo
##     (solta atrás, quem passa rodopia) ou foguete. Quem está atrás ganha
##     itens melhores; quem lidera ganha mais óleo;
##   • VÁCUO: fique logo atrás de outro kart e aparece o vento: mais velocidade;
##   • setas amarelas no chão = turbo grátis; morrinhos = SALTO; poças de
##     ÓLEO na pista fazem rodopiar. O kart nunca anda de ré nem ao contrário.
## A pista é um trilho (KartTrack): o kart anda liso em subida, descida,
## curva e viaduto; bater na mureta faz perder velocidade.

const LAPS := 3
const BOTS := 5
const MAX_V := 23.0          # m/s (~83 km/h de kart de brinquedo...)
const BOOST_V := 31.0
const ACCEL := 9.0
const BRAKE := 20.0
const DRIFT_MINI := [0.9, 1.9]  # segundos de derrapagem para miniturbo azul / laranja
const ITEM_U := [0.08, 0.3, 0.55, 0.82]  # fileiras de caixinhas "?" (fração da volta)
const MAX_H := 0.75          # ângulo máximo com a pista (nunca anda ao contrário)
const SLIP_CHARGE := 0.8     # segundos atrás de alguém para o vácuo "pegar"
const SLIP_BONUS := 2.6      # m/s a mais no vácuo
const CATCH_UP := 1.6        # m/s a mais para quem está bem atrás do líder
const SPIN_TIME := 1.1       # rodopio no óleo
const OIL_TTL := 25.0
const KART_LEN := 1.75       # tamanho para as batidas (ao longo da pista / de lado)
const KART_WID := 1.15
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
var _rng := RandomNumberGenerator.new()
var _oils: Array = []  # [{id, s, d, node, ttl, owner}]
var _oil_id := 0
var _leader := 0.0
var _bump_cd := {}
var _wind: Node3D
var _wind_mat: StandardMaterial3D
var _slip_told := false
var _cam_lift := 0.0
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
	_rng.randomize()
	_build_lights()
	_build_items()
	_build_hud()
	_build_sparks()
	_build_wind()
	for o in KartTrack.OIL_SPOTS:
		_drop_oil(float(o[0]) * _total, float(o[1]), null, true)
	# todo mundo começa com um turbo na mão (largada animada)
	for r in racers:
		r.item = "turbo"
		r.item_n = 1
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
		"name": "Você" if who == player else "", "color": col, "max": randf_range(22.2, 23.6) if ai else MAX_V,
		"line": randf_range(-1.2, 1.2), "skill": randf_range(0.7, 1.0), "vd": 0.0, "spin": 0.0, "slip": 0.0,
		"item": "", "item_n": 0, "roulette": 0.0, "next_item": "", "item_t": randf_range(0.5, 2.0), "rocket": 0.0,
		"oil_safe": 0.0, "oil_seen": {}, "n_spin": 0, "n_wall": 0,
	}
	var k := make_kart_item(paint, col) if paint != "" else make_kart(col)
	if paint != "":
		r.color = item_color(paint, col)
	world.add_child(k)
	r["kart"] = k
	r["wheels"] = k.get_meta("wheels")
	if who is NPC:
		(who as NPC).visual.play("sit_down")
		(who as NPC).stop()
	racers.append(r)
	return r


## Kart de um item (kart_padrao, kart_turbo, kart_foguete...). O kart da escola
## não tem cor própria: usa a cor do lugar no grid (fallback).
static func make_kart_item(id: String, fallback := Color("e53935")) -> Node3D:
	var k: Dictionary = ShopCatalog.get_item(id).get("kart", {})
	if k.is_empty():
		return make_kart(fallback)
	var c := str(k.get("color", ""))
	return make_kart(fallback if c == "" else Color(c), Color(str(k.get("accent", "ffffff"))), str(k.get("style", "")), str(k.get("body", "")))


## Cor que o kart de um item tem na pista ("" = kart da escola = cor do grid).
static func item_color(id: String, fallback: Color) -> Color:
	var c := str(ShopCatalog.get_item(id).get("kart", {}).get("color", ""))
	return fallback if c == "" else Color(c)


## Kart de brinquedo colorido (também usado para mostrar o kart de um colega online).
## Todos andam IGUAL; o que muda é só a aparência.
## style (pintura): "" | "listras" | "xadrez" | "chamas" | "estrelas" | "arco"
## body (design, só no passe): "" | "esportivo" | "turbo" | "neon" | "foguete" | "campeao"
static func make_kart(col: Color, accent := Color.WHITE, style := "", body := "") -> Node3D:
	var root := Node3D.new()
	root.name = "Kart"
	var md := MeshData.new()
	var dark := col.darkened(0.35)
	var chrome := Color("d7dde4")
	# chassi baixo, laterais, bico com número, banco e volante
	md.cur_color = Color("2b2d33")
	md.add_box(Transform3D(Basis(), Vector3(0, 0.16, 0)), Vector3(1.05, 0.08, 1.9))
	md.cur_color = col
	md.add_box(Transform3D(Basis(), Vector3(0, 0.3, 0.72)), Vector3(0.9, 0.22, 0.55))
	if body != "foguete" and body != "campeao":
		md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.36, 1.02)), Vector3(0.7, 0.12, 0.35))
	for sx in [-1.0, 1.0]:
		md.add_box(Transform3D(Basis(), Vector3(sx * 0.52, 0.27, 0.0)), Vector3(0.16, 0.2, 1.1))
	md.cur_color = dark
	md.add_box(Transform3D(Basis(), Vector3(0, 0.25, -0.95)), Vector3(1.1, 0.12, 0.18))
	if body == "":
		# aerofólio pequenininho do kart da escola
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
	if body != "foguete" and body != "campeao":
		md.cur_color = Color.WHITE
		md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -0.35 + PI * 0.5), Vector3(0, 0.43, 1.0)), 0.13, 0.13, 0.02, 12)
	# pintura especial
	match style:
		"listras":
			md.cur_color = accent
			for sx in [-0.14, 0.14]:
				md.add_box(Transform3D(Basis(), Vector3(sx, 0.415, 0.72)), Vector3(0.09, 0.02, 0.56))
				if body != "foguete" and body != "campeao":
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
	# DESIGN (karts do passe): aerofólios grandes, carburadores, foguete...
	var glow: Array = []  # [xf, size, cor] partes que brilham (neon / fogo)
	var rim := Color("cfd5dc")
	var rear_scale := 1.0
	match body:
		"esportivo":
			_wing(md, Vector3(0, 0.82, -0.98), 1.3, 0.34, accent, dark, 0.3)
			md.cur_color = Color("1d1d1d")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.17, 1.2)), Vector3(1.15, 0.04, 0.22))
			md.cur_color = accent
			for sx in [-1.0, 1.0]:
				md.add_box(Transform3D(Basis(), Vector3(sx * 0.61, 0.24, 0.0)), Vector3(0.02, 0.06, 1.0))
		"turbo":
			# aerofólio GIGANTE de dois andares
			_wing(md, Vector3(0, 1.02, -1.02), 1.56, 0.44, accent, col, 0.48)
			md.cur_color = col
			md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 1.14, -1.2)), Vector3(1.5, 0.04, 0.2))
			# motor com 3 carburadores cromados (cornetas) e escapamentos
			md.cur_color = Color("3a3f47")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.38, -0.66)), Vector3(0.52, 0.24, 0.36))
			md.cur_color = chrome
			md.add_box(Transform3D(Basis(), Vector3(0, 0.52, -0.66)), Vector3(0.56, 0.05, 0.4))
			for cx in [-0.17, 0.0, 0.17]:
				md.add_cylinder(Transform3D(Basis(), Vector3(cx, 0.66, -0.66)), 0.085, 0.06, 0.24, 10)
				md.cur_color = Color("1d1d1d")
				md.add_cylinder(Transform3D(Basis(), Vector3(cx, 0.785, -0.66)), 0.06, 0.06, 0.012, 10)
				md.cur_color = chrome
			for ex in [-0.32, 0.32]:
				md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.2), Vector3(ex, 0.34, -1.1)), 0.07, 0.06, 0.4, 10)
			# bico com tomada de ar e saia dianteira larga
			md.cur_color = Color("1d1d1d")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.17, 1.22)), Vector3(1.3, 0.05, 0.26))
			md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.47, 0.86)), Vector3(0.24, 0.06, 0.2))
			rear_scale = 1.22
		"neon":
			_wing(md, Vector3(0, 0.86, -0.98), 1.3, 0.34, col.lightened(0.15), dark, 0.32)
			# luz neon embaixo e na borda da asa
			for sx in [-1.0, 1.0]:
				glow.append([Transform3D(Basis(), Vector3(sx * 0.5, 0.1, 0.0)), Vector3(0.05, 0.03, 1.6), accent])
			glow.append([Transform3D(Basis(), Vector3(0, 0.1, 0.9)), Vector3(0.9, 0.03, 0.05), accent])
			glow.append([Transform3D(Basis(), Vector3(0, 0.89, -0.82)), Vector3(1.3, 0.025, 0.03), accent])
			glow.append([Transform3D(Basis(), Vector3(0, 0.27, 1.27)), Vector3(0.8, 0.03, 0.03), accent])
			rim = accent
		"foguete":
			# bico de foguete
			md.cur_color = col
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.34, 1.3)), 0.04, 0.3, 0.75, 14)
			md.cur_color = accent
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.34, 1.01)), 0.3, 0.31, 0.12, 14)
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.34, 1.62)), 0.02, 0.07, 0.14, 10)
			# cápsulas laterais com aletas
			for sx in [-1.0, 1.0]:
				md.cur_color = accent
				md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.62, 0.34, -0.2)), 0.13, 0.13, 1.1, 12)
				md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 0.62, 0.34, 0.45)), 0.02, 0.13, 0.3, 12)
				md.cur_color = col
				for i in 3:
					md.add_box(Transform3D(Basis(Vector3.FORWARD, sx * 0.6), Vector3(sx * (0.7 + i * 0.05), 0.44 + i * 0.07, -0.6 - i * 0.04)), Vector3(0.03, 0.08, 0.36 - i * 0.1))
			# turbina atrás e aleta de cauda
			md.cur_color = Color("4a5058")
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.42, -1.1)), 0.13, 0.19, 0.32, 14)
			md.cur_color = Color("2b2d33")
			md.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.42, -1.27)), 0.11, 0.11, 0.03, 14)
			# aleta de cauda em "escadinha" (parece um triângulo)
			md.cur_color = accent
			for i in 4:
				md.add_box(Transform3D(Basis(), Vector3(0, 0.6 + i * 0.1, -0.92 - i * 0.05)), Vector3(0.04, 0.1, 0.44 - i * 0.1))
			glow.append([Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.42, -1.45)), Vector3(0.12, 0.36, 0.0), Color("ff8a1f")])
			glow.append([Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.42, -1.38)), Vector3(0.07, 0.2, 0.0), Color("ffe08a")])
		"campeao":
			# bico comprido com asa dianteira
			md.cur_color = col
			md.add_box(Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, 0.3, 1.25)), Vector3(0.32, 0.14, 0.8))
			md.cur_color = accent
			md.add_box(Transform3D(Basis(), Vector3(0, 0.15, 1.58)), Vector3(1.45, 0.04, 0.26))
			for sx in [-1.0, 1.0]:
				md.add_box(Transform3D(Basis(), Vector3(sx * 0.72, 0.22, 1.58)), Vector3(0.04, 0.16, 0.32))
				# caixas laterais
				md.cur_color = col
				md.add_box(Transform3D(Basis(), Vector3(sx * 0.5, 0.32, -0.3)), Vector3(0.3, 0.24, 0.8))
				md.cur_color = accent
				md.add_box(Transform3D(Basis(), Vector3(sx * 0.5, 0.45, -0.3)), Vector3(0.31, 0.02, 0.8))
			# tomada de ar sobre o piloto e asa traseira dupla
			md.cur_color = col
			md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.66, -0.62)), Vector3(0.24, 0.34, 0.46))
			md.cur_color = Color("1d1d1d")
			md.add_box(Transform3D(Basis(), Vector3(0, 0.78, -0.42)), Vector3(0.16, 0.12, 0.04))
			_wing(md, Vector3(0, 0.95, -1.05), 1.4, 0.36, accent, accent, 0.42)
			md.cur_color = accent
			md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 1.08, -1.18)), Vector3(1.36, 0.035, 0.18))
			rim = Color("ffcf3f")
			rear_scale = 1.18
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mat.metallic = 0.1 if body == "" else 0.3
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = md.build_mesh(mat)
	root.add_child(body_mi)
	if not glow.is_empty():
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.vertex_color_use_as_albedo = true
		var gmd := MeshData.new()
		for g in glow:
			gmd.cur_color = g[2]
			var sz: Vector3 = g[1]
			if sz.z == 0.0:
				gmd.add_cylinder(g[0], 0.0, sz.x, sz.y, 10)  # chama (cone)
			else:
				gmd.add_box(g[0], sz)
		var gi := MeshInstance3D.new()
		gi.name = "Glow"
		gi.mesh = gmd.build_mesh(gm)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gi)
	# rodas (giram e as da frente esterçam)
	var wmd := MeshData.new()
	wmd.cur_color = Color("1d1d1d")
	wmd.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.2, 0.2, 0.22, 14)
	wmd.cur_color = rim
	wmd.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), 0.1, 0.1, 0.24, 8)
	var wmesh := wmd.build_mesh(mat)
	var wheels: Array = []
	for w in [[-0.6, 0.65], [0.6, 0.65], [-0.62, -0.7], [0.62, -0.7]]:
		var pivot := Node3D.new()
		var rear: bool = float(w[1]) < 0.0
		var sc := rear_scale if rear else 1.0
		pivot.position = Vector3(float(w[0]) * (1.0 + (sc - 1.0) * 0.4), 0.2 * sc, w[1])
		root.add_child(pivot)
		var wi := MeshInstance3D.new()
		wi.mesh = wmesh
		wi.scale = Vector3(sc, sc, sc)
		pivot.add_child(wi)
		wheels.append(pivot)
	root.set_meta("wheels", wheels)
	return root


## Aerofólio traseiro: placa inclinada, duas colunas e placas laterais.
static func _wing(md: MeshData, at: Vector3, w: float, depth: float, plate_col: Color, side_col: Color, h: float) -> void:
	md.cur_color = Color("2b2d33")
	for sx in [-0.3, 0.3]:
		md.add_box(Transform3D(Basis(), at + Vector3(sx * w / 1.3, -h * 0.5, 0.05)), Vector3(0.06, h, 0.08))
	md.cur_color = plate_col
	md.add_box(Transform3D(Basis(Vector3.RIGHT, -0.18), at), Vector3(w, 0.05, depth))
	# placas laterais: baixinhas, com a ponta da frente cortada (degrau)
	md.cur_color = side_col
	for sx in [-1.0, 1.0]:
		var x: float = sx * (w * 0.5 + 0.02)
		md.add_box(Transform3D(Basis(), at + Vector3(x, -0.02, -0.03)), Vector3(0.04, 0.16, depth + 0.04))
		md.add_box(Transform3D(Basis(), at + Vector3(x, 0.08, -0.08)), Vector3(0.04, 0.06, depth * 0.6))


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
	_sparks.amount = 36
	_sparks.lifetime = 0.25
	_sparks.local_coords = true  # ficam nas rodas de trás (não voam na câmera)
	_sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.6, 0.02, 0.05)
	pm.direction = Vector3(0, 1, -1)
	pm.spread = 40.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	_sparks.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("4fc3ff")
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = sm
	_sparks.draw_pass_1 = qm
	(me.kart as Node3D).add_child(_sparks)
	_sparks.position = Vector3(0, 0.05, -0.75)


# ---------------------------------------------------------------- itens

## Itens das caixinhas "?" (estilo kart de videogame): quem está ATRÁS ganha
## itens melhores e quem está na FRENTE ganha mais óleo — a corrida fica
## disputada até o fim.
const ITEM_NAMES := {"turbo": "Turbo", "turbo3": "Turbo triplo", "oleo": "Óleo", "foguete": "Foguete"}
const ROULETTE := 1.1


## Sorteia o item conforme a posição (0 = primeiro ... 1 = último).
static func roll_item(pos_frac: float, rng := RandomNumberGenerator.new()) -> String:
	var r := rng.randf()
	if pos_frac < 0.2:
		return "oleo" if r < 0.65 else "turbo"
	if pos_frac < 0.6:
		return "turbo" if r < 0.45 else ("oleo" if r < 0.75 else "turbo3")
	return "turbo3" if r < 0.4 else ("foguete" if r < 0.75 else "turbo")


func _pos_frac(r: Dictionary) -> float:
	var n := _racer_count()
	return 0.0 if n <= 1 else float(_place_of(r) - 1) / float(n - 1)


func _give_item(r: Dictionary) -> void:
	if str(r.item) != "" or float(r.roulette) > 0.0:
		return
	r.roulette = ROULETTE
	r.next_item = roll_item(_pos_frac(r), _rng)
	if r == me:
		AudioManager.play_ui("coin", -4.0)


## Usa o item que está guardado (botão amarelo / IA).
func _use_item(r: Dictionary) -> void:
	var it := str(r.item)
	if it == "" or float(r.spin) > 0.0:
		return
	match it:
		"turbo":
			r.item = ""
			_give_boost(r, 1.5)
		"turbo3":
			r.item_n = int(r.item_n) - 1
			_give_boost(r, 1.3)
			if int(r.item_n) <= 0:
				r.item = ""
		"oleo":
			r.item = ""
			_drop_oil(float(r.s) - 2.6, float(r.d), r)
			if is_multi():
				NetworkManager.mg_send_relay(str(net.gid), {"oil": [snappedf(float(r.s) - 2.6, 0.1), snappedf(float(r.d), 0.1)]})
		"foguete":
			r.item = ""
			r.rocket = 3.0
			_give_boost(r, 3.0)
	if r == me:
		popup(player.global_position + Vector3(0, 2.3, 0), ITEM_NAMES.get(it, it).to_upper() + "!", Color("ffb300"), 72)
		player._emit_context(true)


# ---------------------------------------------------------------- botões

func play_label() -> String:
	if float(me.get("roulette", 0.0)) > 0.0:
		return "..."
	var it := str(me.get("item", ""))
	if it == "":
		return ""
	if it == "turbo3":
		return "TURBO x%d" % int(me.item_n)
	return str(ITEM_NAMES.get(it, it)).to_upper()


func interact_label() -> String:
	return "Derrapar"


func on_play() -> bool:
	if _countdown > 0.0 or me.done:
		return true
	_use_item(me)
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
	_leader = 0.0
	for r in racers:
		_leader = maxf(_leader, _progress_raw(r))
	for id in _remote_prog.keys():
		_leader = maxf(_leader, float(_remote_prog[id][0]))
	var place_before := _place_of(me)
	for r in racers:
		_step(r, delta)
	_collide(delta)
	_check_items(delta)
	_check_oil(delta)
	_place_all(delta)
	_update_wind(delta)
	_update_camera(delta)
	_update_hud()
	# ultrapassagem: avisa quando ganha ou perde posição
	var place_now := _place_of(me)
	if place_now < place_before and not me.done:
		popup(player.global_position + Vector3(0, 2.4, 0), "%dº!" % place_now, Color("6be36b"), 70)
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


## Velocidade de recuperação: quem está bem atrás do líder anda um pouquinho
## mais (todos, inclusive você). Quem está na frente não ganha nada.
func _catch_up(r: Dictionary) -> float:
	var behind := clampf((_leader - _progress_raw(r)) / 90.0, 0.0, 1.0)
	return behind * CATCH_UP


func _step(r: Dictionary, delta: float) -> void:
	if r.done and r != me and not r.ai:
		return
	var steer := 0.0
	var brake := false
	var maxv: float = r.max
	r.wall_cd = maxf(float(r.wall_cd) - delta, 0.0)
	r.boost = maxf(float(r.boost) - delta, 0.0)
	r.rocket = maxf(float(r.rocket) - delta, 0.0)
	r.oil_safe = maxf(float(r.oil_safe) - delta, 0.0)
	if float(r.roulette) > 0.0:
		r.roulette = float(r.roulette) - delta
		if float(r.roulette) <= 0.0:
			r.item = str(r.next_item)
			r.item_n = 3 if r.item == "turbo3" else 1
			if r == me:
				AudioManager.play_ui("ui_confirm", -6.0)
				player._emit_context(true)
	if r.done:
		# depois da chegada: volta devagarinho
		maxv = 9.0
		steer = clampf((0.0 - float(r.d)) * 0.3 - float(r.h) * 1.5, -1.0, 1.0)
	elif r.ai:
		steer = _ai_steer(r)
		maxv = _ai_max(r)
		_ai_items(r, delta)
	else:
		steer = _steer_input()
		brake = _brake_btn or player.read_move_raw().y > 0.6
		# ajudinha na curva (boa parte do volante já vem certo): divertido para criança
		var tn := lerpf(2.6, 1.35, clampf(absf(float(r.v)) / MAX_V, 0.0, 1.0))
		steer = clampf(steer + KartTrack.curve_at(r.s) * float(r.v) / tn * 0.75, -1.3, 1.3)
	if not r.done:
		maxv += _catch_up(r)
	# VÁCUO: atrás de outro kart (3 a 14 m, na mesma faixa) carrega e dá velocidade
	var behind_someone := false
	if not r.done:
		for o in racers:
			if o == r:
				continue
			var gap := wrapf(float(o.s) - float(r.s), -_total * 0.5, _total * 0.5)
			if gap > 3.0 and gap < 14.0 and absf(float(o.d) - float(r.d)) < 1.6:
				behind_someone = true
				break
	r.slip = clampf(float(r.slip) + (delta if behind_someone else -delta * 2.0), 0.0, SLIP_CHARGE + 1.2)
	var slipping: bool = float(r.slip) >= SLIP_CHARGE
	if slipping:
		maxv += SLIP_BONUS
	var v: float = r.v
	# rodopiando no óleo: sem controle por um instante
	if float(r.spin) > 0.0:
		r.spin = float(r.spin) - delta
		steer = 0.0
		v = move_toward(v, 4.0, 18.0 * delta)
		if float(r.spin) <= 0.0:
			r.h = 0.0
			r.oil_safe = 1.5
	elif brake:
		v = move_toward(v, 0.0, BRAKE * delta)  # freia até parar (nunca anda de ré)
	else:
		var top := (BOOST_V + (4.0 if float(r.rocket) > 0.0 else 0.0)) if r.boost > 0.0 else maxv
		var acc := ACCEL * (2.2 if r.boost > 0.0 else 1.0) * (1.3 if slipping else 1.0)
		acc *= lerpf(1.7, 1.0, clampf(v / MAX_V, 0.0, 1.0))  # arranca rápido depois de rodar/bater
		v = move_toward(v, top, acc * delta) if v < top else move_toward(v, top, 6.0 * delta)
	# subida segura, descida acelera
	var dir := KartTrack.dir_at(r.s)
	if r.air_y <= 0.0:
		v -= 9.8 * dir.y * delta * 0.85
	v = clampf(v, 0.0, BOOST_V + 8.0)
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
	# nunca vira de costas: no máximo ~43° para o lado (criança não anda ao contrário)
	h = clampf(h, -MAX_H, MAX_H)
	# sem mexer, o kart "endireita" um pouco (fica fácil de dirigir)
	if absf(steer) < 0.1 and not (r == me and _drift):
		h = move_toward(h, 0.0, 0.6 * delta)
	var ds := v * cos(h) * delta
	var dd := v * sin(h) * delta + float(r.vd) * delta
	r.vd = float(r.vd) * exp(-4.0 * delta)  # empurrão de lado vai perdendo força
	var d: float = r.d + dd
	var half := KartTrack.width_at(r.s) * 0.5 - 0.75
	if absf(d) > half:
		var side := signf(d)
		d = side * half
		# batida na mureta: quanto mais de frente, mais perde e mais quica
		var vn := maxf(v * sin(h) * side + float(r.vd) * side, 0.0)
		if vn > 0.6:
			var loss := clampf(0.04 + vn * 0.035, 0.04, 0.35)
			if vn > 2.0:
				r.n_wall = int(r.n_wall) + 1
			v *= 1.0 - loss
			r.vd = -side * minf(vn * 0.45 + 0.8, 4.0)
			if h * side > 0.0:
				h = -h * 0.3
			if r == me and r.wall_cd <= 0.0:
				r.wall_cd = 0.35
				AudioManager.play_ui("bonk", lerpf(-14.0, -4.0, clampf(vn / 8.0, 0.0, 1.0)))
				if player.camera_rig:
					player.camera_rig.shake(clampf(vn * 0.02, 0.03, 0.14))
				Effects.burst(KartTrack.world_at(r.s, d + side * 0.6) + Vector3(0, 0.4, 0), "sparkle")
				if vn > 3.0:
					_drift = false
					_sparks.emitting = false
		else:
			# raspando: perde um pouquinho e solta faísca
			v *= 1.0 - 0.5 * delta
			r.vd = -side * 0.4
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
	# avança e conta a volta (nunca anda para trás, então só conta para frente)
	var ns: float = r.s + ds
	if r.s < _total and ns >= _total:
		ns -= _total
		_lap_done(r)
	r.s = ns


func _lap_done(r: Dictionary) -> void:
	r.lap = int(r.lap) + 1
	if r.lap >= LAPS and not r.done:
		r.done = true
		r.time = _elapsed
		_finished_order.append(r)
		if r == me:
			hud.show_banner("CHEGADA! %dº lugar" % _place_of(me), "Tempo: %s" % _fmt(_elapsed))
			AudioManager.play_ui("win" if _place_of(me) <= 3 else "reward", -2.0)
			Effects.burst(player.global_position + Vector3(0, 1.5, 0), "confetti")
			if is_net():
				NetworkManager.mg_score(str(net.gid), snappedf(_elapsed, 0.01), true)
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
	# pega o vácuo de quem está na frente (sem encostar) ou desvia para ultrapassar
	for o in racers:
		if o == r:
			continue
		var ds := fposmod(float(o.s) - float(r.s), _total)
		if ds > 0.5 and ds < 6.0 and absf(float(o.d) - target) < 1.6:
			target += 2.0 if float(o.d) <= float(r.d) else -2.0
		elif ds >= 6.0 and ds < 16.0 and float(r.skill) > 0.85:
			target = lerpf(target, float(o.d), 0.5)
	# desvia do óleo que viu (a maioria desvia; os mais distraídos às vezes não)
	for oil in _oils:
		var ds2 := fposmod(float(oil.s) - float(r.s), _total)
		if ds2 > 2.0 and ds2 < 26.0 and absf(float(oil.d) - target) < 1.8:
			var key := "%d-%d" % [int(oil.id), int(r.lap)]  # decide de novo a cada volta
			var seen: Dictionary = r.oil_seen
			if not seen.has(key):
				seen[key] = _rng.randf() < float(r.skill)
			if bool(seen[key]):
				target += 2.4 if float(oil.d) <= target else -2.4
	target = clampf(target, -half, half)
	var want_h := clampf((target - float(r.d)) * 0.16, -0.45, 0.45)
	var curve := KartTrack.curve_at(r.s)
	# esterço que mantém o rumo desejado mais o necessário para a curva
	var turn := lerpf(2.6, 1.35, clampf(absf(float(r.v)) / MAX_V, 0.0, 1.0))
	var need := (curve * float(r.v)) / maxf(turn, 0.1)
	return clampf(need + (want_h - float(r.h)) * 3.0 * float(r.skill), -1.0, 1.0)


func _ai_max(r: Dictionary) -> float:
	var m: float = r.max
	# só tira o pé nas curvas que não dá para fazer de pé embaixo
	# (olha a curva mais fechada dos próximos metros)
	var c := 0.0
	for k in 4:
		c = maxf(c, absf(KartTrack.curve_at(float(r.s) + 4.0 + k * 4.0)))
	if c > 0.001:
		m = minf(m, 1.25 * 1.4 / c)
	# "elástico" leve em relação a você: ninguém some na frente nem fica para trás demais
	var gap := _progress_raw(r) - _progress_raw(me)
	if gap > 45.0:
		m -= 1.6
	elif gap < -45.0:
		m += 1.0
	return m


## Bots usam os itens: turbo na reta, óleo quando alguém vem colado atrás.
func _ai_items(r: Dictionary, delta: float) -> void:
	r.item_t = float(r.item_t) - delta
	var it := str(r.item)
	if it == "" or float(r.item_t) > 0.0:
		return
	match it:
		"turbo", "turbo3":
			if absf(KartTrack.curve_at(r.s + 12.0)) < 0.03:
				_use_item(r)
				r.item_t = 1.6
		"foguete":
			_use_item(r)
		"oleo":
			var chased := false
			for o in racers:
				var gap := wrapf(float(r.s) - float(o.s), -_total * 0.5, _total * 0.5)
				if o != r and gap > 2.0 and gap < 14.0:
					chased = true
			if chased or float(r.item_t) < -8.0:
				_use_item(r)
				r.item_t = 1.0


# ---------------------------------------------------------------- colisões, caixinhas e óleo

## Batidas entre karts (estilo videogame): de lado, um empurra o outro;
## por trás, quem bate perde velocidade e o da frente ganha um tiquinho.
## Com FOGUETE você é "pesado": quem você acerta rodopia.
func _collide(delta: float) -> void:
	for k in _bump_cd.keys():
		_bump_cd[k] = float(_bump_cd[k]) - delta
		if float(_bump_cd[k]) <= 0.0:
			_bump_cd.erase(k)
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a: Dictionary = racers[i]
			var b: Dictionary = racers[j]
			if (a.done and a != me) or (b.done and b != me):
				continue
			var ds := wrapf(float(a.s) - float(b.s), -_total * 0.5, _total * 0.5)
			var dd := float(a.d) - float(b.d)
			var nx := ds / KART_LEN
			var ny := dd / KART_WID
			var dist := sqrt(nx * nx + ny * ny)
			if dist >= 1.0:
				continue
			var ma := 1.0 + (2.5 if float(a.rocket) > 0.0 else 0.0) + (0.4 if float(a.boost) > 0.0 else 0.0)
			var mb := 1.0 + (2.5 if float(b.rocket) > 0.0 else 0.0) + (0.4 if float(b.boost) > 0.0 else 0.0)
			var wa := mb / (ma + mb)
			var wb := ma / (ma + mb)
			var side := ny / maxf(dist, 0.001)
			var overlap := 1.0 - dist
			# separa de lado (nunca "atravessa" o outro)
			var push := overlap * KART_WID * (1.0 if dd >= 0.0 else -1.0) * maxf(absf(side), 0.35)
			a.d = float(a.d) + push * wa
			b.d = float(b.d) - push * wb
			var key := "%d-%d" % [i, j]
			var fresh := not _bump_cd.has(key)
			if absf(nx) > absf(ny):
				# por trás: quem bate perde velocidade, o da frente ganha um pouco
				var back: Dictionary = b if ds > 0.0 else a
				var front: Dictionary = a if ds > 0.0 else b
				if float(back.v) > float(front.v):
					var dv := float(back.v) - float(front.v)
					back.v = float(front.v) - 0.3
					front.v = float(front.v) + dv * 0.25
			else:
				# de lado: os dois são jogados para os lados
				var kick := 2.2 if fresh else 0.4
				a.vd = clampf(float(a.vd) + kick * wa * (1.0 if dd >= 0.0 else -1.0) * 2.0, -3.5, 3.5)
				b.vd = clampf(float(b.vd) - kick * wb * (1.0 if dd >= 0.0 else -1.0) * 2.0, -3.5, 3.5)
			if fresh:
				_bump_cd[key] = 0.4
				# foguete acerta = o outro rodopia
				if float(a.rocket) > 0.0 and float(b.rocket) <= 0.0:
					_spin_out(b, "Foguete!")
				elif float(b.rocket) > 0.0 and float(a.rocket) <= 0.0:
					_spin_out(a, "Foguete!")
				if a == me or b == me:
					AudioManager.play_ui("bonk", -8.0)
					if player.camera_rig:
						player.camera_rig.shake(0.06)


func _spin_out(r: Dictionary, why: String) -> void:
	if float(r.spin) > 0.0 or float(r.oil_safe) > 0.0 or float(r.rocket) > 0.0 or float(r.air_y) > 0.5:
		return
	r.spin = SPIN_TIME
	r.n_spin = int(r.n_spin) + 1
	r.boost = 0.0
	r.v = float(r.v) * 0.5
	if r == me:
		_drift = false
		_sparks.emitting = false
		popup(player.global_position + Vector3(0, 2.4, 0), why, Color("ff4d6d"), 70)
		AudioManager.play_ui("trip", -2.0)
		if player.camera_rig:
			player.camera_rig.shake(0.1)


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
				it.back = 3.0
				node.visible = false
				_give_item(r)
				break


func _drop_oil(s: float, d: float, owner: Variant = null, permanent := false) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.95
	cm.bottom_radius = 0.95
	cm.height = 0.02
	cm.radial_segments = 16
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.06, 0.12, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	m.roughness = 0.08
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# brilho de arco-íris (óleo) por cima
	var shine := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.5
	sc.bottom_radius = 0.5
	sc.height = 0.005
	shine.mesh = sc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.6, 0.4, 1.0, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.material_override = sm
	shine.position = Vector3(0.25, 0.015, 0.1)
	mi.add_child(shine)
	world.add_child(mi)
	s = fposmod(s, _total)
	mi.global_position = KartTrack.world_at(s, d) + Vector3(0, 0.08, 0)
	_oil_id += 1
	_oils.append({"id": _oil_id, "s": s, "d": d, "node": mi, "ttl": 9999.0 if permanent else OIL_TTL, "owner": owner})


func _check_oil(delta: float) -> void:
	for oil in _oils.duplicate():
		oil.ttl = float(oil.ttl) - delta
		var hit := false
		for r in racers:
			if r == oil.owner and float(oil.ttl) > OIL_TTL - 1.0:
				continue  # quem soltou não escorrega no próprio óleo logo de cara
			var ds := absf(wrapf(float(r.s) - float(oil.s), -_total * 0.5, _total * 0.5))
			if ds < 1.0 and absf(float(r.d) - float(oil.d)) < 1.0 and float(r.air_y) < 0.3:
				if float(r.spin) <= 0.0 and float(r.oil_safe) <= 0.0 and float(r.rocket) <= 0.0:
					_spin_out(r, "ESCORREGOU!")
					hit = true
		if (hit and float(oil.ttl) < 9000.0) or float(oil.ttl) <= 0.0:
			(oil.node as Node3D).queue_free()
			_oils.erase(oil)


# ---------------------------------------------------------------- vento do vácuo

## Riscos de vento passando em volta do kart quando você pega o vácuo.
func _build_wind() -> void:
	_wind = Node3D.new()
	(me.kart as Node3D).add_child(_wind)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wind_mat = mat
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.025, randf_range(0.9, 1.8))
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 14.0
		mi.position = Vector3(cos(a) * randf_range(0.9, 1.4), 0.6 + sin(a) * randf_range(0.5, 0.9), randf_range(-3.0, 3.0))
		mi.set_meta("speed", randf_range(18.0, 28.0))
		_wind.add_child(mi)


func _update_wind(delta: float) -> void:
	if _wind == null:
		return
	var charge := clampf(float(me.slip) / SLIP_CHARGE, 0.0, 1.0)
	var on := float(me.slip) >= SLIP_CHARGE
	var target_a := 0.75 if on else charge * 0.25
	_wind_mat.albedo_color.a = lerpf(_wind_mat.albedo_color.a, target_a, 1.0 - exp(-8.0 * delta))
	_wind.visible = _wind_mat.albedo_color.a > 0.02
	if not _wind.visible:
		return
	for c in _wind.get_children():
		var mi := c as MeshInstance3D
		mi.position.z -= float(mi.get_meta("speed")) * delta
		if mi.position.z < -3.5:
			mi.position.z = 3.5
	if on and not _slip_told:
		_slip_told = true
		popup(player.global_position + Vector3(0, 2.4, 0), "VÁCUO!", Color("bfe9ff"), 66)
		AudioManager.play_ui("whoosh", -8.0)
	elif not on:
		_slip_told = false


# ---------------------------------------------------------------- desenho

func _kart_xf(r: Dictionary) -> Transform3D:
	var s: float = r.s
	var p := KartTrack.world_at(s, r.d)
	var dir := KartTrack.dir_at(s)
	# rumo do kart = rumo da pista - h (h > 0 = apontando para a direita)
	var yaw := atan2(dir.x, dir.z) - float(r.h)
	if r == me and _drift:
		yaw -= _drift_dir * 0.38  # de ladinho na derrapagem
	if float(r.spin) > 0.0:
		yaw += TAU * (1.0 - float(r.spin) / SPIN_TIME)  # rodopio no óleo
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
	# câmera sobe um pouco quando tem kart colado atrás (não tampa o seu kart)
	var eye := xf.origin - fwd * (4.6 - _cam_lift * 0.6) + Vector3(0, 2.0 + _cam_lift * 1.1, 0)
	var look := xf.origin + fwd * 5.0 + Vector3(0, 0.6, 0)
	return Transform3D(Basis(), eye).looking_at(look, Vector3.UP)


func _update_camera(delta: float) -> void:
	if not player.camera_rig:
		return
	var tail := false
	for o in racers:
		if o == me:
			continue
		var gap := wrapf(float(o.s) - float(me.s), -_total * 0.5, _total * 0.5)
		if gap < -0.2 and gap > -5.4 and absf(float(o.d) - float(me.d)) < 1.9:
			tail = true
	_cam_lift = move_toward(_cam_lift, 1.0 if tail else 0.0, delta * 2.5)
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
	return _progress_raw(r)


## Distância percorrida na corrida (sem o bônus de quem terminou).
func _progress_raw(r: Dictionary) -> float:
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
	hud.minimap.visible = false  # a corrida tem o mapinha da pista (e a caixa do item fica ali)
	hud._zone_panel.visible = false


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
		if d.has("oil"):
			var o: Array = d.oil
			_drop_oil(float(o[0]), float(o[1]), null)
			return
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
	for oil in _oils:
		if is_instance_valid(oil.node):
			(oil.node as Node3D).queue_free()
	_oils.clear()
	if is_instance_valid(_hud):
		_hud.queue_free()
	hud._objective.visible = hud._objective.text != ""
	hud.minimap.visible = GameManager.is_playing()
	hud._zone_panel.visible = GameManager.is_playing()
	super.cleanup()


func hints() -> Dictionary:
	# sem cartão de dica no meio da tela (tampava o kart na largada): o tutorial já explica
	return {"start": "", "idle": "", "miss": ""}
