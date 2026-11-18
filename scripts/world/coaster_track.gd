class_name CoasterTrack
extends RefCounted
## Montanha-russa GIGANTE do parque: subida de 42 m, primeira queda quase
## na vertical, LOOPING, passa por cima do bosque (morros de "frio na
## barriga"), volta inclinada, SACA-ROLHA (gira de cabeça para baixo),
## mergulho perto da quadrinha e chegada na estação.
##
## O trilho guarda, para cada ponto, a posição e o "para cima" do trilho
## (que gira no looping e no saca-rolha e inclina nas curvas).

const STATION := Vector3(46, 1.5, -79)  # começo da reta da estação (sentido -x)
const STEP := 0.8
const LOOP_R := 9.5
const CORK_R := 2.2

static var _pts := PackedVector3Array()
static var _ups := PackedVector3Array()
static var _cum := PackedFloat32Array()
static var total := 0.0
## Trechos especiais (distância ao longo do trilho).
static var lift := Vector2.ZERO      # corrente da subida
static var brake_s := 0.0            # freios antes da estação
static var inversions: Array = []    # [s0, s1] onde fica de cabeça para baixo


static func points() -> PackedVector3Array:
	if _pts.is_empty():
		_build()
	return _pts


static func length() -> float:
	points()
	return total


# ------------------------------------------------------------------ construção

static func _ground(x: float, z: float) -> float:
	return maxf(ParkHill.height(x, z), 0.0)


## Catmull-Rom aberto por `ctrl` (o 1º e o último só dão a direção).
static func _cr(ctrl: Array, out: Array) -> void:
	for i in range(1, ctrl.size() - 2):
		var p0: Vector3 = ctrl[i - 1]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[i + 2]
		var n := maxi(int(ceil(p1.distance_to(p2) / STEP)), 1)
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append([0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3), null])


## Looping vertical: entra andando em `fwd` a partir de `p`, sai deslocado para o lado.
static func _loop(p: Vector3, fwd: Vector3, side_shift: float, out: Array) -> Vector3:
	var side := Vector3(-fwd.z, 0, fwd.x)
	var n := int(TAU * LOOP_R / STEP)
	for k in n:
		var t := float(k) / n
		var a := TAU * t
		var pos := p + fwd * (LOOP_R * sin(a)) + Vector3.UP * (LOOP_R * (1.0 - cos(a))) + side * (side_shift * smoothstep(0.0, 1.0, t))
		var center := p + Vector3.UP * LOOP_R + side * (side_shift * smoothstep(0.0, 1.0, t))
		out.append([pos, (center - pos).normalized()])
	return p + side * side_shift


## Saca-rolha: o trilho dá uma volta inteira em torno de um eixo à frente.
static func _corkscrew(p: Vector3, fwd: Vector3, length: float, out: Array) -> Vector3:
	var side := Vector3(-fwd.z, 0, fwd.x)
	var axis0 := p + Vector3.UP * CORK_R
	var n := int(length / STEP)
	for k in n:
		var t := float(k) / n
		var a := TAU * smoothstep(0.0, 1.0, t)
		var axis := axis0 + fwd * (length * t)
		var pos := axis - Vector3.UP * (CORK_R * cos(a)) - side * (CORK_R * sin(a))
		out.append([pos, (axis - pos).normalized()])
	return p + fwd * length


static func _build() -> void:
	var nodes: Array = []  # [pos, up ou null]
	var W := Vector3(-1, 0, 0)
	var N := Vector3(0, 0, -1)
	var E := Vector3(1, 0, 0)
	var S := Vector3(0, 0, 1)
	var st := STATION
	# 1) estação (para -x), curva para o norte e SUBIDA (corrente) até 42 m
	_cr([st - W * 6.0, st, st + W * 10.0, Vector3(30, 1.6, -82), Vector3(26, 2.2, -90), Vector3(26, 9.0, -97),
		Vector3(26, 30.0, -111), Vector3(26, 41.0, -119), Vector3(29, 42.5, -123), Vector3(35, 42.0, -124.2),
		Vector3(41, 38.0, -124.2), Vector3(47, 22.0, -124.0), Vector3(52, 7.0, -123.6), Vector3(58, 2.2, -123.4),
		Vector3(63, 2.2, -123.4), Vector3(68, 2.2, -123.4)], nodes)
	# 2) LOOPING (para leste)
	var lp := Vector3(63, 2.2, -123.4) + E * 3.2
	# junta o fim do trecho anterior com a entrada do looping
	nodes.append([Vector3(64.6, 2.2, -123.4), null])
	var after_loop := _loop(lp, E, 3.0, nodes)
	var inv0 := 0
	# 3) saída, curva para o sul e os morros por cima do bosque
	var p3 := after_loop
	_cr([p3 - E * 4.0, p3, p3 + E * 6.0, Vector3(80, 3.0, -118.5), Vector3(86, 6.0, -110), Vector3(87, 14.0, -96),
		Vector3(86, 24.0, -76), Vector3(85, 13.0, -60), Vector3(86, 19.0, -44), Vector3(84, 17.0, -34),
		Vector3(76, 16.0, -27), Vector3(67, 15.0, -31), Vector3(64, 14.0, -40), Vector3(64, 14.0, -46), Vector3(64, 14.0, -50)], nodes)
	# 4) SACA-ROLHA (para o norte)
	var after_cork := _corkscrew(Vector3(64, 14.0, -46), N, 16.0, nodes)
	# 5) mergulho, morrinho de "frio na barriga" e volta para a estação
	var p5 := after_cork
	_cr([p5 - N * 4.0, p5, p5 + N * 5.0, Vector3(64, 8.0, -72), Vector3(63, 3.0, -86), Vector3(62, 10.0, -97),
		Vector3(60, 2.2, -107), Vector3(53, 2.0, -110), Vector3(47, 2.0, -104), Vector3(49, 1.8, -94),
		Vector3(55, 1.6, -86), Vector3(54, 1.5, -80), st + E * 2.0, st, st + W * 6.0], nodes)
	# amostra e "para cima" (inclinação nas curvas onde não foi definido)
	var pts := PackedVector3Array()
	var ups := PackedVector3Array()
	for nd in nodes:
		var p: Vector3 = nd[0]
		if not pts.is_empty() and p.distance_to(pts[pts.size() - 1]) < 0.05:
			continue
		pts.append(p)
		ups.append(nd[1] if nd[1] != null else Vector3.ZERO)
	var n := pts.size()
	# o trilho nunca passa dentro do morro: sobe o que for preciso, com rampa suave
	var lift_need := PackedFloat32Array()
	lift_need.resize(n)
	for i in n:
		var p := pts[i]
		var clear := 1.4 if (ups[i] != Vector3.ZERO and ups[i].y < 0.2) else 1.0
		lift_need[i] = maxf(_ground(p.x, p.z) + clear - p.y, 0.0)
	for i in n:
		var best := 0.0
		for k in range(-14, 15):
			var j := clampi(i + k, 0, n - 1)
			best = maxf(best, lift_need[j] * (0.5 + 0.5 * cos(PI * absf(k) / 15.0)))
		pts[i].y += best
	for i in n:
		if ups[i] != Vector3.ZERO:
			continue
		var t := (pts[mini(i + 2, n - 1)] - pts[maxi(i - 2, 0)]).normalized()
		var t0 := (pts[maxi(i - 6, 0)] - pts[maxi(i - 8, 0)])
		var t1 := (pts[mini(i + 8, n - 1)] - pts[mini(i + 6, n - 1)])
		var turn := 0.0
		if t0.length() > 0.01 and t1.length() > 0.01:
			turn = wrapf(atan2(t1.x, t1.z) - atan2(t0.x, t0.z), -PI, PI)
		var bank := clampf(-turn * 1.6, -0.95, 0.95)
		var side := Vector3.UP.cross(t)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := t.cross(side).normalized()
		if up.y < 0.0:
			up = -up
		ups[i] = up.rotated(t, bank)
	# suaviza as inclinações
	for pass_i in 4:
		var sm := ups.duplicate()
		for i in range(1, n - 1):
			if nodes.size() > 0:
				sm[i] = (ups[i - 1] + ups[i] * 2.0 + ups[i + 1]).normalized()
		ups = sm
	_pts = pts
	_ups = ups
	_cum.resize(n)
	var acc := 0.0
	for i in n:
		if i > 0:
			acc += pts[i - 1].distance_to(pts[i])
		_cum[i] = acc
	total = acc
	# trechos especiais
	lift = Vector2(_s_near(Vector3(26, 2.2, -90)), _s_near(Vector3(28, 42.4, -122.5)))
	brake_s = _s_near(Vector3(55, 1.6, -86))
	inversions.clear()
	var inside := false
	var s0 := 0.0
	for i in n:
		var inv := ups[i].y < -0.2
		if inv and not inside:
			s0 = _cum[i]
		elif not inv and inside:
			inversions.append([s0, _cum[i]])
		inside = inv


static func _s_near(p: Vector3) -> float:
	var best := 0
	var bd := INF
	for i in _pts.size():
		var d := _pts[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return _cum[best]


static func _index(s: float) -> int:
	var lo := 0
	var hi := _cum.size() - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if _cum[m] <= s:
			lo = m
		else:
			hi = m
	return lo


## Transform do trilho em s: origem no trilho, -Z/+Z? -> basis.z = para frente, basis.y = para cima.
static func frame_at(s: float) -> Transform3D:
	points()
	s = fposmod(s, total)
	var i := _index(s)
	var j := mini(i + 1, _pts.size() - 1)
	var seg := maxf(_cum[j] - _cum[i], 0.001)
	var f := clampf((s - _cum[i]) / seg, 0.0, 1.0)
	var p := _pts[i].lerp(_pts[j], f)
	var fwd := (_pts[mini(j + 1, _pts.size() - 1)] - _pts[maxi(i - 1, 0)]).normalized()
	var up := _ups[i].lerp(_ups[j], f).normalized()
	up = (up - fwd * up.dot(fwd)).normalized()
	var side := up.cross(fwd).normalized()
	return Transform3D(Basis(side, up, fwd), p)


# ------------------------------------------------------------------ física (determinística)

const G := 9.8
const LIFT_V := 4.2
const STATION_V := 2.5
static var _table := PackedFloat32Array()  # s a cada TABLE_DT segundos
const TABLE_DT := 0.05
static var ride_time := 0.0


## Simula a viagem uma vez: o mesmo trem para todo mundo (só depende do relógio).
static func ride_table() -> PackedFloat32Array:
	if not _table.is_empty():
		return _table
	points()
	var s := 0.0
	var v := STATION_V
	var out := PackedFloat32Array()
	var t := 0.0
	while s < total and t < 400.0:
		out.append(s)
		var fr := frame_at(s)
		var slope := fr.basis.z.y
		if s >= lift.x and s <= lift.y:
			v = move_toward(v, LIFT_V, 3.0 * TABLE_DT)
		elif s >= brake_s:
			v = move_toward(v, STATION_V, 7.0 * TABLE_DT)
		else:
			v += (-G * slope - 0.004 * v * v) * TABLE_DT
			if s < lift.x:
				v = maxf(v, STATION_V)
			v = maxf(v, 2.0)
		s += v * TABLE_DT
		t += TABLE_DT
	out.append(total)
	_table = out
	ride_time = out.size() * TABLE_DT
	return out


## Distância ao longo do trilho depois de `t` segundos de viagem.
static func s_at_time(t: float) -> float:
	var tb := ride_table()
	var k := t / TABLE_DT
	var i := clampi(int(k), 0, tb.size() - 1)
	var j := mini(i + 1, tb.size() - 1)
	return lerpf(tb[i], tb[j], clampf(k - i, 0.0, 1.0))


static func speed_at_time(t: float) -> float:
	return (s_at_time(t + 0.1) - s_at_time(t - 0.1)) / 0.2


# ------------------------------------------------------------------ geometria

static func build(b: SchoolBuilder) -> void:
	var c := b.chunk("montanha_russa", 220.0)
	var pts := points()
	var n := pts.size()
	var rail := Color("e53935")
	var spine := Color("ffd23f")
	var i := 0
	var last_pillar := -99.0
	while i < n - 1:
		var j := mini(i + 2, n - 1)
		var s0 := _cum[i]
		var s1 := _cum[j]
		var fa := frame_at(s0)
		var fb := frame_at(s1)
		var mid := (fa.origin + fb.origin) * 0.5
		var fwd := (fb.origin - fa.origin).normalized()
		var up := (fa.basis.y + fb.basis.y).normalized()
		up = (up - fwd * up.dot(fwd)).normalized()
		var side := up.cross(fwd).normalized()
		var bs := Basis(side, up, fwd)
		var len := fa.origin.distance_to(fb.origin) + 0.04
		for sx: float in [-1.0, 1.0]:
			c.box_xf("metal", Transform3D(bs, mid + side * 0.48 * sx), Vector3(0.11, 0.11, len), rail)
		c.box_xf("metal", Transform3D(bs, mid - up * 0.32), Vector3(0.22, 0.22, len), spine)
		c.box_xf("metal", Transform3D(bs, mid - up * 0.16), Vector3(1.05, 0.06, 0.12), Color("8a96a3"))
		# pilares (só onde o trilho está de pé e bem acima do chão)
		var gy := _ground(mid.x, mid.z)
		var hh := mid.y - 0.5 - gy
		if up.y > 0.6 and hh > 1.0 and s0 - last_pillar > 7.0:
			last_pillar = s0
			var on_court := absf(mid.x - ParkHill.COURT.x - 1.5) < 7.5 and absf(mid.z - ParkHill.COURT.y) < 6.0
			if not on_court:
				c.cylinder("metal", Vector3(mid.x, gy + hh * 0.5, mid.z), 0.14, 0.2, hh, Color("f4f7fa"), 6)
				c.collider(Vector3(mid.x, gy + hh * 0.5, mid.z), Vector3(0.4, hh, 0.4))
				if hh > 10.0:
					for sx2: float in [-1.0, 1.0]:
						var foot := Vector3(mid.x, gy, mid.z) + side * sx2 * hh * 0.18
						var top := mid - up * 0.5
						var lg := (top - foot)
						var lb := Basis.looking_at(lg.normalized(), Vector3.FORWARD if absf(lg.normalized().y) > 0.99 else Vector3.UP)
						c.box_xf("metal", Transform3D(lb, (foot + top) * 0.5), Vector3(0.14, 0.14, lg.length()), Color("dfe6ee"))
		i = j
	_station(b, c)


static func _station(b: SchoolBuilder, c: WorldBatcher) -> void:
	var st := STATION
	var gy := 0.0
	# plataforma comprida (o trem tem 4 carrinhos) ao lado do trilho (lado sul)
	var plat := Vector3(st.x - 5.0, gy + 0.5, st.z + 2.3)
	c.box("wood", plat, Vector3(13.0, 1.0, 2.4), Color("b5794a"))
	c.collider(plat, Vector3(13.0, 1.0, 2.4))
	c.box("wood", plat + Vector3(7.2, -0.25, 0), Vector3(1.6, 0.5, 2.4), Color("a0663a"))
	c.collider(plat + Vector3(7.2, -0.25, 0), Vector3(1.6, 0.5, 2.4))
	for k in 4:
		c.cylinder("metal", plat + Vector3(-5.6 + k * 3.7, 2.1, 1.0), 0.1, 0.1, 3.2, Color("2f5fa8"), 8)
	c.box("roof", plat + Vector3(0, 3.7, -0.6), Vector3(14.0, 0.2, 4.6), Color("ff4d6d"))
	# fila em zigue-zague (grades) na frente da plataforma
	var q0 := Vector3(st.x + 4.0, gy, st.z + 6.0)
	for row in 3:
		var z := q0.z + row * 1.4
		c.box("metal", Vector3(q0.x - 4.0, 0.5, z + 0.7), Vector3(9.0, 0.06, 0.06), Color("ffd23f"))
		for k in 5:
			c.box("metal", Vector3(q0.x - 8.4 + k * 2.2, 0.45, z + 0.7), Vector3(0.06, 0.9, 0.06), Color("2c3e50"))
	b.add_label("MONTANHA-RUSSA GIGANTE", plat + Vector3(0, 4.1, 1.8), 0.0, 72, Color("e53935"), Color(1, 1, 1, 0.92), 0.008, 90.0)
	b.add_label("FILA  ▸", Vector3(q0.x + 1.0, 1.6, q0.z + 4.0), 0.0, 56, Color("2f5fa8"), Color(1, 1, 1, 0.9), 0.006, 40.0)
	b.coaster = {"station": st, "platform": plat + Vector3(0, 0.55, 0), "queue": q0}
	b.add_zone("Montanha-Russa", Rect2(st.x - 13, st.z - 2, 18, 13), false, "", 7, Color(0.9, 0.25, 0.25))
