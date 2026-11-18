class_name KartTrack
extends RefCounted
## Kartódromo que DÁ A VOLTA NA ESCOLA. O terreno da escola foi aumentado:
## a pista corre numa faixa nova por fora do muro (oeste, fundos e leste) e,
## na frente, passa num VIADUTO por cima do portão de entrada. Tem descida
## forte (rampa do viaduto), chicane, morrinhos com salto no fundo e subida
## de volta para o viaduto. ~840 m por volta.
##
## A pista é um trilho (linha central + largura): o kart anda nela por
## distância (s) e deslocamento lateral (d). Nada de física de carro em
## terreno: anda liso em subida, descida, curva inclinada e viaduto.

## Terreno novo (escola + faixa do kartódromo).
const OUTER := Rect2(-116, -151, 232, 226)
const WIDTH := 10.0          # largura da pista no chão
const WIDTH_BRIDGE := 9.0    # no viaduto
const BRIDGE_Y := 6.0        # acima disto é viaduto (guard-rail, pilares)
const START_S := 0.0         # largada/chegada no início do trilho
const STEP := 1.6

## Pontos de controle (x, altura, z), no sentido da corrida, começando na largada.
const CTRL := [
	Vector3(-103, 0, -6),
	# lado oeste: zigue-zague (S) até o fundo
	Vector3(-103, 0, -16), Vector3(-98, 0, -36), Vector3(-108, 0, -58), Vector3(-98, 0, -80),
	Vector3(-107, 0, -100), Vector3(-104, 0, -118),
	# curva noroeste
	Vector3(-99, 0, -132), Vector3(-88, 0, -139),
	# fundos: curvas com morrinhos e o SALTO no meio
	Vector3(-66, 2.0, -133), Vector3(-44, 0, -143), Vector3(-24, 2.0, -134),
	Vector3(-10, 0.4, -138), Vector3(2, 3.0, -138), Vector3(11, 0.8, -138),
	Vector3(30, 0, -133), Vector3(51, 1.4, -143), Vector3(72, 0, -134),
	# curva nordeste
	Vector3(89, 0, -139), Vector3(100, 0, -131), Vector3(104, 0, -117),
	# lado leste: zigue-zague e SUBIDA para o viaduto
	Vector3(98, 0, -98), Vector3(108, 0, -78), Vector3(98, 0, -56), Vector3(108, 0, -34),
	Vector3(102, 0, -12), Vector3(103, 1.4, 10), Vector3(103, 4.4, 30), Vector3(103, 7.0, 49),
	Vector3(103, 8.0, 61),
	# curva sudeste (já no alto)
	Vector3(100, 8.0, 70), Vector3(90, 8.0, 75),
	# VIADUTO (com curvinhas) por cima do portão
	Vector3(70, 8.0, 73), Vector3(50, 8.6, 77), Vector3(30, 7.8, 73), Vector3(14, 7.4, 75), Vector3(0, 7.4, 75),
	Vector3(-14, 7.4, 75), Vector3(-30, 7.8, 77), Vector3(-50, 8.6, 73), Vector3(-70, 8.0, 77), Vector3(-90, 8.0, 75),
	# curva sudoeste e a DESCIDA
	Vector3(-100, 8.0, 70), Vector3(-103, 8.0, 61), Vector3(-103, 7.0, 50), Vector3(-103, 4.4, 32),
	Vector3(-103, 1.4, 12),
]

## Poças de ÓLEO fixas na pista (fração da volta, deslocamento lateral).
const OIL_SPOTS := [[0.2, 2.6], [0.47, -2.4], [0.71, 2.4]]

## Placas de turbo (setas amarelas): distância ao longo da volta (fração).
const BOOST_U := [0.06, 0.37, 0.5, 0.77]

static var _pts: PackedVector3Array = PackedVector3Array()
static var _cum: PackedFloat32Array = PackedFloat32Array()
static var total := 0.0


## Linha central amostrada a cada STEP metros (laço fechado).
static func points() -> PackedVector3Array:
	if _pts.is_empty():
		_build_points()
	return _pts


static func _build_points() -> void:
	var c: Array = CTRL
	var n := c.size()
	var out := PackedVector3Array()
	for i in n:
		var p0: Vector3 = c[(i - 1 + n) % n]
		var p1: Vector3 = c[i]
		var p2: Vector3 = c[(i + 1) % n]
		var p3: Vector3 = c[(i + 2) % n]
		var k := maxi(int(ceil(p1.distance_to(p2) / STEP)), 1)
		for j in k:
			var t := float(j) / k
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	_pts = out
	_cum.resize(out.size() + 1)
	var acc := 0.0
	for i in out.size():
		_cum[i] = acc
		acc += out[i].distance_to(out[(i + 1) % out.size()])
	_cum[out.size()] = acc
	total = acc


static func length() -> float:
	points()
	return total


static func _index(s: float) -> int:
	var lo := 0
	var hi := _pts.size()
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if _cum[m] <= s:
			lo = m
		else:
			hi = m
	return lo


## Ponto da linha central na distância s (dá a volta sozinho).
static func pos_at(s: float) -> Vector3:
	points()
	s = fposmod(s, total)
	var i := _index(s)
	var j := (i + 1) % _pts.size()
	var seg := maxf(_cum[i + 1] - _cum[i], 0.001)
	return _pts[i].lerp(_pts[j], clampf((s - _cum[i]) / seg, 0.0, 1.0))


## Direção da pista (com subida/descida) em s.
static func dir_at(s: float) -> Vector3:
	var a := pos_at(s - 1.2)
	var b := pos_at(s + 1.2)
	return (b - a).normalized()


## Lado direito (horizontal) em s.
static func right_at(s: float) -> Vector3:
	var d := dir_at(s)
	return Vector3(-d.z, 0, d.x).normalized()


## Curvatura com sinal (+ = curva para a direita) — usada para inclinar o kart e a IA.
static func curve_at(s: float) -> float:
	var a := dir_at(s - 4.0)
	var b := dir_at(s + 4.0)
	var ya := atan2(a.x, a.z)
	var yb := atan2(b.x, b.z)
	return -wrapf(yb - ya, -PI, PI) / 8.0


static func width_at(s: float) -> float:
	return WIDTH_BRIDGE if pos_at(s).y > BRIDGE_Y - 0.5 else WIDTH


## Ponto no mundo para (s, d): d > 0 = para a direita.
static func world_at(s: float, d: float) -> Vector3:
	return pos_at(s) + right_at(s) * d


## Distância aproximada de um ponto qualquer até a pista (s mais perto).
static func nearest_s(p: Vector3) -> float:
	points()
	var best := 0
	var bd := INF
	for i in range(0, _pts.size(), 2):
		var d := _pts[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return _cum[best]


# ====================================================================== geometria

static func build(b: SchoolBuilder) -> void:
	var pts := points()
	var road := b.chunk("kart_pista", 260.0)
	var deco := b.chunk("kart_deco", 160.0)
	road.cast_shadows = false
	var n := pts.size()
	var s := 0.0
	for i in n:
		var a := pts[i]
		var c := pts[(i + 1) % n]
		var seg := a.distance_to(c)
		var mid := (a + c) * 0.5
		var dir := (c - a).normalized()
		var yaw := atan2(dir.x, dir.z)
		var pitch := -atan2(dir.y, Vector2(dir.x, dir.z).length())
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var right := basis.x
		var bridge := a.y > BRIDGE_Y - 0.5
		var w := WIDTH_BRIDGE if bridge else WIDTH
		# asfalto (mais claro na largada) e faixas laterais zebradas
		var asphalt := Color("4b4f57") if (i / 3) % 2 == 0 else Color("50545c")
		road.box_xf("asphalt", Transform3D(basis, mid + Vector3(0, 0.035, 0)), Vector3(w, 0.06, seg + 0.08), asphalt)
		var zebra := Color("e53935") if (i / 2) % 2 == 0 else Color("f4f7fa")
		for sd: float in [-1.0, 1.0]:
			road.box_xf("plain", Transform3D(basis, mid + right * sd * (w * 0.5 - 0.35) + Vector3(0, 0.075, 0)), Vector3(0.7, 0.04, seg + 0.08), zebra)
		# faixa central tracejada
		if (i / 2) % 3 == 0:
			road.box_xf("plain", Transform3D(basis, mid + Vector3(0, 0.07, 0)), Vector3(0.18, 0.03, seg * 0.9), Color("f2d64b"))
		if bridge:
			# viaduto: laje grossa + guard-rail dos dois lados
			road.box_xf("concrete", Transform3D(basis, mid + Vector3(0, -0.45, 0)), Vector3(w + 0.6, 0.8, seg + 0.08), Color("b7bcc4"))
			for sd: float in [-1.0, 1.0]:
				road.box_xf("metal", Transform3D(basis, mid + right * sd * (w * 0.5 + 0.15) + Vector3(0, 0.55, 0)), Vector3(0.12, 0.22, seg + 0.08), Color("dfe6ee"))
				road.box_xf("paint", Transform3D(basis, mid + right * sd * (w * 0.5 + 0.15) + Vector3(0, 0.25, 0)), Vector3(0.25, 0.4, seg + 0.08), Color("2f5fa8") if (i / 4) % 2 == 0 else Color("ffd23f"))
		else:
			# muretas com pneus nas bordas
			for sd: float in [-1.0, 1.0]:
				road.box_xf("concrete", Transform3D(basis, mid + right * sd * (w * 0.5 + 0.35) + Vector3(0, 0.35, 0)), Vector3(0.3, 0.7, seg + 0.08), Color("ecf0f1") if (i / 3) % 2 == 0 else Color("e53935"))
			# aterro embaixo das partes altas (morrinhos e rampa)
			if a.y > 0.25:
				road.box_xf("grass", Transform3D(basis, mid + Vector3(0, -a.y * 0.5 + 0.02, 0)), Vector3(w + 1.4, a.y, seg + 0.1), Color("7cb36b"))
		# pilares do viaduto/rampa (a cada ~12 m)
		if a.y > 1.2 and int(s / 12.0) != int((s + seg) / 12.0):
			var px := Vector3(mid.x, 0.0, mid.z)
			var gate := absf(mid.x) < 7.5 and absf(mid.z - 75.0) < 6.0
			var car_gate := mid.x > 38.0 and mid.x < 49.0 and absf(mid.z - 75.0) < 6.0
			if not gate and not car_gate:
				for sd: float in [-1.0, 1.0]:
					var pp: Vector3 = px + right * sd * (w * 0.5 - 1.0)
					deco.cylinder("concrete", pp + Vector3(0, (a.y - 0.8) * 0.5, 0), 0.35, 0.4, a.y - 0.8, Color("c8cdd4"), 10)
					deco.collider(pp + Vector3(0, (a.y - 0.8) * 0.5, 0), Vector3(0.8, a.y - 0.8, 0.8))
		s += seg
	# portal do viaduto por cima do portão da escola
	for sx: float in [-1.0, 1.0]:
		deco.box("concrete", Vector3(8.6 * sx, 3.4, 75), Vector3(1.0, 6.8, 1.0), Color("c8cdd4"))
		deco.collider(Vector3(8.6 * sx, 3.4, 75), Vector3(1.0, 6.8, 1.0))
	deco.box("concrete", Vector3(0, 6.75, 75), Vector3(18.2, 0.7, 1.4), Color("b7bcc4"))
	b.add_label("KARTÓDROMO RECREIO", Vector3(0, 9.2, 79.8), 0.0, 96, Color("e53935"), Color(1, 1, 1, 0.95), 0.01, 140.0)
	# placas de turbo (setas amarelas no chão)
	for u in BOOST_U:
		var sb: float = u * total
		var p := pos_at(sb)
		var d := dir_at(sb)
		var bs := Basis(Vector3.UP, atan2(d.x, d.z)) * Basis(Vector3.RIGHT, -atan2(d.y, Vector2(d.x, d.z).length()))
		for k in 3:
			var o := p + d * (k * 1.2 - 1.2) + Vector3(0, 0.09, 0)
			road.box_xf("plain", Transform3D(bs * Basis(Vector3.UP, PI * 0.25), o), Vector3(0.9, 0.03, 0.25), Color("ffd23f"))
			road.box_xf("plain", Transform3D(bs * Basis(Vector3.UP, -PI * 0.25), o + bs.x * 0.6), Vector3(0.9, 0.03, 0.25), Color("ffd23f"))
	# largada: faixa quadriculada e pórtico com semáforo
	var sp := pos_at(START_S)
	var sdir := dir_at(START_S)
	var sb2 := Basis(Vector3.UP, atan2(sdir.x, sdir.z))
	for i in 10:
		for j in 2:
			var col := Color.WHITE if (i + j) % 2 == 0 else Color("1d1d1d")
			road.box_xf("plain", Transform3D(sb2, sp + sb2.x * (-WIDTH * 0.5 + 0.5 + i) + sb2.z * (j * 0.5 - 0.25) + Vector3(0, 0.09, 0)), Vector3(1.0, 0.03, 0.5), col)
	for sx: float in [-1.0, 1.0]:
		var post: Vector3 = sp + sb2.x * sx * (WIDTH * 0.5 + 0.9)
		deco.box("metal", post + Vector3(0, 2.6, 0), Vector3(0.35, 5.2, 0.35), Color("2c3e50"))
	deco.box_xf("paint", Transform3D(sb2, sp + Vector3(0, 5.0, 0)), Vector3(WIDTH + 2.2, 1.0, 0.4), Color("1d1d1d"))
	for i in 12:
		deco.box_xf("plain", Transform3D(sb2, sp + sb2.x * (-WIDTH * 0.5 - 0.5 + i) + Vector3(0, 5.0, -0.21)), Vector3(0.5, 0.5, 0.02), Color.WHITE if i % 2 == 0 else Color("e53935"))
	b.kart_start = {"pos": sp, "dir": sdir}
	# arquibancadinha e bandeiras ao lado da largada (do lado de dentro)
	for k in 6:
		var fp := sp + sdir * (k * 6.0 - 15.0) + sb2.x * (WIDTH * 0.5 + 2.4)
		deco.box("metal", fp + Vector3(0, 1.6, 0), Vector3(0.08, 3.2, 0.08), Color("ecf0f1"))
		deco.box("plain", fp + Vector3(0, 2.9, 0.35), Vector3(0.04, 0.6, 0.7), [Color("e53935"), Color("ffd23f"), Color("2f80ed"), Color("27ae60")][k % 4])
	b.add_zone("Kartódromo", Rect2(OUTER.position.x, OUTER.position.y, OUTER.size.x, OUTER.size.y), false, "", -6, Color(0.45, 0.47, 0.52))
	b.add_label("LARGADA", sp + Vector3(0, 6.0, 0) + sb2.z * -0.25, PI + atan2(sdir.x, sdir.z), 72, Color.WHITE, Color(0, 0, 0, 0.9), 0.008, 80.0)
