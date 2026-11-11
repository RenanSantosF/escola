class_name FunRides
extends RefCounted
## Atrações grandes do recreio:
## - Tobogã gigante: torre ao lado do Morro, espiral e descida passando pelo
##   Morro e pela trilha até o Parquinho.
## - Montanha-russa: dá a volta no Lago, com subida de 13 m e duas voltas.
## - Camas elásticas no Pátio dos Fundos.
## Só monta a geometria (um chunk) e registra em b.rides / b.trampolines;
## quem anda nelas é o RideTrack / Trampoline.

const TOWER := Vector2(-62, -116)
const TOWER_H := 13.0
const COASTER_C := Vector2(31, -103)
const COASTER_R := Vector2(17, 15)
const TRAMPOLINES := [Vector2(-42, -68), Vector2(-34, -68), Vector2(-26, -68)]


static func build(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_atracoes", 170.0)
	_giant_slide(b, c)
	_coaster(b, c)
	_trampolines(b)


static func _ground(x: float, z: float) -> float:
	return ParkHill.height(x, z)


## Catmull-Rom pelos pontos de controle, amostrado a cada `step` metros.
static func _smooth(ctrl: Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in ctrl.size() - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, ctrl.size() - 1)]
		var n := maxi(int(ceil(p1.distance_to(p2) / step)), 1)
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[ctrl.size() - 1])
	return out


static func _seg_basis(a: Vector3, bb: Vector3) -> Basis:
	var dir := bb - a
	var yaw := atan2(dir.x, dir.z)
	var pitch := -atan2(dir.y, Vector2(dir.x, dir.z).length())
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


# ------------------------------------------------------------- tobogã

static func slide_points() -> PackedVector3Array:
	var g := _ground(TOWER.x, TOWER.y)
	var top := g + TOWER_H
	var pts: Array = []
	# espiral em volta da torre: 1,25 volta descendo 4 m
	var r := 3.4
	var turns := 1.25
	var a0 := PI * 0.5  # começa do lado sul da torre
	var n := 26
	for k in n + 1:
		var t := float(k) / n
		var a := a0 - t * turns * TAU
		pts.append(Vector3(TOWER.x + cos(a) * r, top - 0.6 - t * 4.0, TOWER.y + sin(a) * r))
	# saindo para o leste pelo pé do Morro, curva pela trilha e desce até o Parquinho
	var route := [Vector2(-54, -121.5), Vector2(-44, -122), Vector2(-33, -118), Vector2(-27.5, -109),
		Vector2(-29, -99), Vector2(-37, -90.5), Vector2(-48, -84), Vector2(-56, -79), Vector2(-58, -74),
		Vector2(-59, -69.5), Vector2(-60.5, -66)]
	# altura: desce do fim da espiral até o chão do Parquinho, proporcional ao caminho
	var y0: float = (pts[pts.size() - 1] as Vector3).y
	var total := 0.0
	var prev := Vector2((pts[pts.size() - 1] as Vector3).x, (pts[pts.size() - 1] as Vector3).z)
	var lens: Array = []
	for q: Vector2 in route:
		total += prev.distance_to(q)
		lens.append(total)
		prev = q
	for i in route.size():
		var q: Vector2 = route[i]
		var f: float = lens[i] / total
		var y := lerpf(y0, 0.4, pow(f, 0.85))
		var gq := _ground(q.x, q.y)
		if i < route.size() - 1:
			y = maxf(y, gq + 1.4)
		else:
			y = gq + 0.4
		pts.append(Vector3(q.x, y, q.y))
	var out := _smooth(pts, 0.7)
	# nunca entra no chão
	for i in out.size() - 6:
		var p := out[i]
		out[i].y = maxf(p.y, _ground(p.x, p.z) + 1.0)
	return out


static func _giant_slide(b: SchoolBuilder, c: WorldBatcher) -> void:
	var g := _ground(TOWER.x, TOWER.y)
	var base := Vector3(TOWER.x, g, TOWER.y)
	var top := g + TOWER_H
	# torre: 4 colunas, andares e telhadinho
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			c.cylinder("metal", base + Vector3(sx * 1.6, (TOWER_H + 1.0) * 0.5, sz * 1.6), 0.16, 0.18, TOWER_H + 1.0, Color("2f5fa8"), 8)
	var k := 0
	var h := 3.0
	while h < TOWER_H:
		c.box("wood", base + Vector3(0, h, 0), Vector3(3.6, 0.15, 3.6), Color("e9a23b") if k % 2 == 0 else Color("ef6c4a"))
		for s in 4:
			var rot := s * PI * 0.5
			var off := Vector3(0, 0, 1.75).rotated(Vector3.UP, rot)
			c.box("paint", base + off + Vector3(0, h + 0.55, 0), Vector3(3.5, 0.08, 0.06), Color("f4f7fa"), rot)
		h += 3.3
		k += 1
	c.box("wood", base + Vector3(0, top - 0.7, 0), Vector3(3.8, 0.18, 3.8), Color("e9a23b"))
	c.cylinder("roof", base + Vector3(0, TOWER_H + 1.6, 0), 0.2, 3.0, 1.6, Color("ff4d6d"), 12)
	c.sphere("metal", base + Vector3(0, TOWER_H + 2.5, 0), 0.25, Color("ffd23f"))
	# elevador colorido no centro
	c.box("glass", base + Vector3(0, TOWER_H * 0.5, 0), Vector3(1.4, TOWER_H, 1.4), Color(0.6, 0.85, 1.0, 1.0), 0.0, false)
	c.collider(base + Vector3(0, TOWER_H * 0.5, 0), Vector3(3.4, TOWER_H, 3.4))
	# base com degrau
	c.box("concrete", base + Vector3(0, 0.1, 2.6), Vector3(3.2, 0.2, 1.6), Color("cfd5dc"))
	b.add_label("TOBOGÃ GIGANTE", base + Vector3(0, 3.8, 1.85), 0.0, 72, Color("e04a3a"), Color(1, 1, 1, 0.92), 0.008, 90.0)
	# o tubo
	var pts := slide_points()
	var trail := [Vector2(-45, -82), Vector2(-36, -86), Vector2(-30, -92), Vector2(-38, -95), Vector2(-50, -94)]
	for i in pts.size() - 1:
		var a := pts[i]
		var bb := pts[i + 1]
		var mid := (a + bb) * 0.5
		var basis := _seg_basis(a, bb)
		var len := a.distance_to(bb) + 0.06
		var col := Color("3ec1ff") if (i / 6) % 2 == 0 else Color("2d9cdb")
		c.box_xf("plain", Transform3D(basis, mid), Vector3(1.3, 0.1, len), col)
		for sx: float in [-1.0, 1.0]:
			var wall := Basis(basis.z.normalized(), sx * 0.5) * basis
			c.box_xf("plain", Transform3D(wall, mid + basis.x * 0.7 * sx + Vector3(0, 0.25, 0)), Vector3(0.08, 0.55, len), Color("ffd23f"))
		# pilares (fora da trilha)
		if i % 6 == 3 and Vector2(mid.x - TOWER.x, mid.z - TOWER.y).length() > 4.5:
			var gy := _ground(mid.x, mid.z)
			var hh := mid.y - 0.1 - gy
			var on_trail := false
			for t: Vector2 in trail:
				if t.distance_to(Vector2(mid.x, mid.z)) < 2.5:
					on_trail = true
			if hh > 0.6 and not on_trail:
				c.cylinder("metal", Vector3(mid.x, gy + hh * 0.5, mid.z), 0.12, 0.14, hh, Color("f4f7fa"), 6)
	b.rides.append({"kind": "slide", "prompt": "Tobogã gigante!", "points": pts,
		"base": base + Vector3(0, 0.05, 2.6), "lift_top": Vector3(pts[0].x, pts[0].y, pts[0].z), "laps": 1})
	b.add_zone("Tobogã Gigante", Rect2(TOWER.x - 5, TOWER.y - 5, 10, 10), false, "", 7, Color(0.24, 0.76, 1.0))


# ------------------------------------------------------------- montanha-russa

static func _coaster_h(u: float) -> float:
	# altura acima do chão ao longo da volta (u de 0 a 1, começa na estação)
	var keys := [[0.0, 1.3], [0.05, 1.3], [0.3, 13.0], [0.34, 12.6], [0.45, 2.0], [0.55, 8.0], [0.63, 2.4],
		[0.72, 6.0], [0.82, 2.0], [0.92, 1.3], [1.0, 1.3]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var bb: Array = keys[i + 1]
		if u <= float(bb[0]):
			var f := (u - float(a[0])) / maxf(float(bb[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(bb[1]), smoothstep(0.0, 1.0, f))
	return 1.3


static func coaster_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := 220
	for k in n + 1:
		var u := float(k) / n
		var a := PI * 0.5 + u * TAU  # começa no lado sul (estação)
		var x := COASTER_C.x + cos(a) * COASTER_R.x
		var z := COASTER_C.y + sin(a) * COASTER_R.y
		var g := maxf(_ground(x, z), 0.0)
		out.append(Vector3(x, g + _coaster_h(u), z))
	return out


## Trecho de subida com corrente (velocidade fixa): fração da volta.
const COASTER_LIFT := Vector2(0.05, 0.31)


static func _coaster(b: SchoolBuilder, c: WorldBatcher) -> void:
	var pts := coaster_points()
	for i in pts.size() - 1:
		var a := pts[i]
		var bb := pts[i + 1]
		var mid := (a + bb) * 0.5
		var basis := _seg_basis(a, bb)
		var len := a.distance_to(bb) + 0.05
		for sx: float in [-1.0, 1.0]:
			c.box_xf("metal", Transform3D(basis, mid + basis.x * 0.42 * sx), Vector3(0.1, 0.12, len), Color("e53935"))
		if i % 2 == 0:
			c.box_xf("wood", Transform3D(basis, mid - basis.y * 0.08), Vector3(1.0, 0.07, 0.14), Color("5d4037"))
		if i % 5 == 0:
			var gy := maxf(_ground(mid.x, mid.z), 0.0)
			var hh := mid.y - 0.15 - gy
			if hh > 0.5:
				c.cylinder("metal", Vector3(mid.x, gy + hh * 0.5, mid.z), 0.12, 0.16, hh, Color("f4f7fa"), 6)
				if hh > 6.0:
					c.cylinder("metal", Vector3(mid.x, gy + hh * 0.5, mid.z) + basis.x * 0.9, 0.08, 0.12, hh, Color("f4f7fa"), 6)
	# estação
	var st := pts[0]
	var gy := maxf(_ground(st.x, st.z), 0.0)
	var plat := Vector3(st.x, gy + 0.5, st.z + 2.2)
	c.box("wood", plat, Vector3(7.0, 1.0, 2.4), Color("b5794a"))
	c.collider(plat, Vector3(7.0, 1.0, 2.4))
	c.box("wood", plat + Vector3(-4.2, -0.25, 0), Vector3(1.4, 0.5, 2.4), Color("a0663a"))
	c.collider(plat + Vector3(-4.2, -0.25, 0), Vector3(1.4, 0.5, 2.4))
	for sx: float in [-1.0, 1.0]:
		c.cylinder("metal", plat + Vector3(sx * 3.2, 1.9, 0.9), 0.1, 0.1, 2.8, Color("2f5fa8"), 8)
	c.box("roof", plat + Vector3(0, 3.4, -0.4), Vector3(8.0, 0.2, 4.2), Color("ff4d6d"))
	b.add_label("MONTANHA-RUSSA", plat + Vector3(0, 3.75, 1.75), 0.0, 72, Color("e53935"), Color(1, 1, 1, 0.92), 0.008, 90.0)
	b.rides.append({"kind": "coaster", "prompt": "Montanha-russa!", "points": pts,
		"base": plat + Vector3(0, 0.55, 0.2), "laps": 2, "lift": COASTER_LIFT})
	b.add_zone("Montanha-Russa", Rect2(st.x - 5, st.z - 1, 10, 6), false, "", 7, Color(0.9, 0.25, 0.25))


# ------------------------------------------------------------- camas elásticas

static func _trampolines(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_atracoes", 170.0)
	for q: Vector2 in TRAMPOLINES:
		var p := Vector3(q.x, 0, q.y)
		c.cylinder("plain", p + Vector3(0, 0.45, 0), 2.1, 2.1, 0.12, Color("3949ab"), 20)
		c.cylinder("plain", p + Vector3(0, 0.52, 0), 1.85, 1.85, 0.04, Color("1b1b2f"), 20, false)
		for k in 6:
			var a := k * TAU / 6.0
			c.cylinder("metal", p + Vector3(cos(a) * 2.0, 0.22, sin(a) * 2.0), 0.05, 0.05, 0.45, Color("90a4ae"), 6)
		b.trampolines.append(p + Vector3(0, 0.55, 0))
	b.add_zone("Camas Elásticas", Rect2(-46, -72, 24, 8), false, "", 6, Color(0.36, 0.42, 0.85))
