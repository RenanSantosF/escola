class_name ParkHill
extends RefCounted
## Parque do Morro — a escola cresceu para os fundos (z de -75 a -125):
## - terreno com relevo de verdade (campo de alturas): morro grande com
##   coreto/mirante no topo, morrinho, ondulações e um lago;
## - trilha em ziguezague subindo o morro (os alunos-bot também sobem);
## - escorregador gigante do topo do morro;
## - lago com ponte de madeira;
## - anfiteatro em degraus com palco;
## - árvores, flores, bancos, postes e pedras.
## A MESMA função de altura gera o visual, a colisão e a navegação.

const AREA := Rect2(-90, -125, 180, 50)  # x0, z0, largura, profundidade
const HILL := Vector3(-45, 6.5, -104)  # x, altura, z
const HILL_R := 20.0
const SMALL_HILL := Vector3(62, 3.0, -110)
const SMALL_R := 13.0
const LAKE := Vector2(28, -101)
const LAKE_R := 10.0
const LAKE_DEPTH := 1.6
const WATER_Y := -0.32
const AMPHI := Vector2(-2, -110)
const MESH_STEP := 1.5


static func _bell(d: float, r: float) -> float:
	if d >= r:
		return 0.0
	return 0.5 + 0.5 * cos(PI * d / r)


## Altura do chão em (x, z). Fora do parque é 0 (escola plana).
static func height(x: float, z: float) -> float:
	if z > AREA.end.y or z < AREA.position.y - 1.0 or x < AREA.position.x - 1.0 or x > AREA.end.x + 1.0:
		return 0.0
	var h := 0.0
	h += HILL.y * _bell(Vector2(x - HILL.x, z - HILL.z).length(), HILL_R)
	h += SMALL_HILL.y * _bell(Vector2(x - SMALL_HILL.x, z - SMALL_HILL.z).length(), SMALL_R)
	h += 0.35 * sin(x * 0.13 + 1.1) * cos(z * 0.11)
	# barranquinho junto da murada dos fundos e das laterais
	var edge := minf(minf(x - AREA.position.x, AREA.end.x - x), z - AREA.position.y)
	h += 0.6 * (1.0 - smoothstep(0.0, 5.0, edge))
	# área plana do anfiteatro
	h *= 1.0 - _bell(Vector2(x - AMPHI.x, z - AMPHI.y).length(), 16.0)
	# lago
	h -= LAKE_DEPTH * _bell(Vector2(x - LAKE.x, z - LAKE.y).length(), LAKE_R)
	# emenda suave com o pátio da escola
	h *= smoothstep(AREA.end.y, AREA.end.y - 7.0, z)
	return h


static func normal(x: float, z: float) -> Vector3:
	var e := 0.5
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


static func build(b: SchoolBuilder) -> void:
	_terrain(b)
	_hill_top(b)
	_slide(b)
	_trail(b)
	_lake(b)
	_amphitheater(b)
	_dressing(b)
	_divider(b)
	b.add_zone("Parque do Morro", AREA, false, "", 2, Color(0.47, 0.73, 0.42))
	b.add_zone("Morro", Rect2(HILL.x - 15, HILL.z - 15, 30, 30), false, "", 6, Color(0.42, 0.66, 0.36))
	b.add_zone("Lago", Rect2(LAKE.x - LAKE_R, LAKE.y - LAKE_R, LAKE_R * 2, LAKE_R * 2), false, "", 6, Color(0.36, 0.62, 0.86))
	b.add_zone("Anfiteatro", Rect2(AMPHI.x - 13, AMPHI.y - 8, 26, 16), false, "", 6, Color(0.82, 0.74, 0.6))
	b.map_shapes.append({"rect": Rect2(LAKE.x - 8, LAKE.y - 8, 16, 16), "color": Color(0.33, 0.6, 0.86), "label": "Lago"})


# ------------------------------------------------------------- terreno

static func _terrain(b: SchoolBuilder) -> void:
	var t := b.chunk("parque_terreno")
	t.cast_shadows = false
	var md := t._md("grass", false)
	var nx := int(AREA.size.x / MESH_STEP) + 1
	var nz := int(AREA.size.y / MESH_STEP) + 1
	var base := md.v.size()
	for j in nz:
		for i in nx:
			var x := AREA.position.x + i * MESH_STEP
			var z := AREA.position.y + j * MESH_STEP
			var h := height(x, z)
			# cor: grama com manchas, mais clara no alto, terra/areia na beira do lago
			var noise := 0.5 + 0.5 * sin(x * 0.31 + z * 0.17) * cos(z * 0.23 - x * 0.07)
			# mesma grama da escola (textura) com manchas suaves de luz/sombra
			var col := SchoolBuilder.GRASS_TINT.lerp(Color("a9c29c"), noise * 0.6)
			col = col.lerp(Color("e3ecc8"), clampf(h / 7.0, 0.0, 0.5))
			var dl := Vector2(x - LAKE.x, z - LAKE.y).length()
			if dl < LAKE_R + 1.5:
				col = col.lerp(Color("d9c18f"), smoothstep(LAKE_R + 1.5, LAKE_R - 1.0, dl))
			md.cur_color = col
			md.add_vertex(Vector3(x, h, z), normal(x, z))
	for j in nz - 1:
		for i in nx - 1:
			var a := base + j * nx + i
			md.tri(a, a + 1, a + nx)
			md.tri(a + 1, a + nx + 1, a + nx)
	# colisão: campo de alturas (1 m) — o mesmo relevo do visual
	var w := int(AREA.size.x) + 1
	var d := int(AREA.size.y) + 1
	var data := PackedFloat32Array()
	data.resize(w * d)
	for j in d:
		for i in w:
			data[j * w + i] = height(AREA.position.x + i, AREA.position.y + j)
	b.heightfields.append({"center": Vector3(AREA.get_center().x, 0, AREA.get_center().y), "w": w, "d": d, "data": data})


# ------------------------------------------------------------- morro

static func _hill_top(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_morro")
	var top := Vector3(HILL.x, height(HILL.x, HILL.z), HILL.z)
	# coreto (mirante) no topo
	c.cylinder("concrete", top + Vector3(0, 0.15, 0), 3.4, 3.6, 0.3, Color("e9e4da"), 16)
	c.collider_cyl(top + Vector3(0, 0.15, 0), 3.5, 0.3)
	for k in 8:
		var a := k * TAU / 8.0
		var p := top + Vector3(cos(a) * 3.0, 1.55, sin(a) * 3.0)
		c.cylinder("paint", p, 0.11, 0.11, 2.5, Color("f4f7fa"), 8)
	c.cylinder("roof", top + Vector3(0, 3.25, 0), 0.4, 4.1, 1.2, Color("d9534f"), 16)
	# colisão do telhado: a câmera não entra nele
	c.collider_cyl(top + Vector3(0, 3.25, 0), 3.6, 1.2)
	c.sphere("metal", top + Vector3(0, 3.95, 0), 0.22, Color("ffcf3f"))
	for k in 4:
		var a := k * TAU / 4.0 + PI * 0.25
		Props.bench(c, top + Vector3(cos(a) * 2.1, 0.3, sin(a) * 2.1), -a + PI * 0.5, 1.6, false)
	b.add_label("MIRANTE DO MORRO", top + Vector3(0, 2.95, 3.2), 0.0, 56, Color("2e7d32"), Color(1, 1, 1, 0.9), 0.006, 40.0)
	b.spots.append({"type": "wander", "pos": top + Vector3(1.0, 0.35, 1.0)})
	b.spots.append({"type": "chat", "pos": top + Vector3(-1.2, 0.35, 0.6)})
	# bandeirinha de cata-vento colorida
	for k in 6:
		var a := k * TAU / 6.0
		c.box("plain", top + Vector3(cos(a) * 3.0, 3.0, sin(a) * 3.0), Vector3(0.5, 0.5, 0.04), [Color("ff4d6d"), Color("ffd23f"), Color("3ec1ff")][k % 3], -a)


## Escorregador gigante do topo do morro até o gramado.
static func _slide(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_escorregador")
	var top := Vector3(HILL.x + 4.2, 0, HILL.z)
	top.y = height(top.x, top.z) + 0.9
	var bottom := Vector3(HILL.x + 20.0, 0, HILL.z + 2.0)
	bottom.y = height(bottom.x, bottom.z) + 0.35
	var pts := PackedVector3Array()
	for k in 13:
		var t := k / 12.0
		var p := top.lerp(bottom, t)
		# leve curva e barriga
		p.z += sin(t * PI) * 2.2
		p.y = lerpf(top.y, bottom.y, t) + sin(t * PI) * 0.4 - 0.25 * t * (1.0 - t)
		pts.append(p)
	for k in pts.size() - 1:
		var a := pts[k]
		var bb := pts[k + 1]
		var mid := (a + bb) * 0.5
		var dir := bb - a
		var yaw := atan2(dir.x, dir.z)
		var pitch := -atan2(dir.y, Vector2(dir.x, dir.z).length())
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var len := dir.length() + 0.05
		c.box_xf("plain", Transform3D(basis, mid), Vector3(1.0, 0.08, len), Color("ffcf3f"))
		for sx: float in [-1.0, 1.0]:
			c.box_xf("plain", Transform3D(basis, mid + basis.x * 0.52 * sx + Vector3(0, 0.14, 0)), Vector3(0.08, 0.3, len), Color("ff8a3d"))
		# pilares até o chão
		if k % 3 == 1:
			var gy := height(mid.x, mid.z)
			var hh := mid.y - gy
			if hh > 0.3:
				c.cylinder("metal", Vector3(mid.x, gy + hh * 0.5, mid.z), 0.07, 0.07, hh, Color("2f5fa8"), 6)
	# plataforma do topo
	c.box("wood", top + Vector3(-0.6, -0.5, 0), Vector3(1.6, 0.12, 1.6), Color("b5794a"))
	c.collider(top + Vector3(-0.6, -0.5, 0), Vector3(1.6, 0.12, 1.6))
	b.add_label("ESCORREGADOR", top + Vector3(-0.6, 1.0, 0), -PI * 0.5, 48, Color("e04a3a"), Color(1, 1, 1, 0.9), 0.006, 30.0)
	b.slides.append({"start": top + Vector3(-1.0, -0.45, 0), "points": pts})


## Trilha em ziguezague até o topo (passeio e caminho dos bots).
static func _trail(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_trilha")
	var raw := [Vector2(-45, -82), Vector2(-36, -86), Vector2(-30, -92), Vector2(-38, -95), Vector2(-50, -94),
		Vector2(-58, -99), Vector2(-56, -106), Vector2(-48, -110), Vector2(-40, -108), Vector2(-42, -104)]
	var pts: Array[Vector3] = []
	for k in raw.size() - 1:
		var a: Vector2 = raw[k]
		var bb: Vector2 = raw[k + 1]
		var steps := int(ceil(a.distance_to(bb) / 1.6))
		for s in steps:
			var p := a.lerp(bb, float(s) / steps)
			pts.append(Vector3(p.x, height(p.x, p.y), p.y))
	var last: Vector2 = raw[raw.size() - 1]
	pts.append(Vector3(last.x, height(last.x, last.y), last.y))
	# faixa de terra batida acompanhando o relevo
	var md := c._md("dirt", false)
	md.cur_color = Color("c9a77a")
	for k in pts.size() - 1:
		var a := pts[k]
		var bb := pts[k + 1]
		var side := Vector3(bb.z - a.z, 0, -(bb.x - a.x)).normalized() * 0.9
		var i0 := md.add_vertex(a - side + Vector3(0, 0.05, 0), Vector3.UP)
		var i1 := md.add_vertex(a + side + Vector3(0, 0.05, 0), Vector3.UP)
		var i2 := md.add_vertex(bb - side + Vector3(0, 0.05, 0), Vector3.UP)
		var i3 := md.add_vertex(bb + side + Vector3(0, 0.05, 0), Vector3.UP)
		md.tri(i0, i1, i2)
		md.tri(i1, i3, i2)
	# pontos de navegação ligados um a um (os bots sobem pela trilha)
	var prev := Vector3.INF
	for k in range(0, pts.size(), 2):
		var p := pts[k] + Vector3(0, 0.05, 0)
		b.nav_points.append(p)
		if prev != Vector3.INF:
			b.nav_links.append([prev, p])
		prev = p
	# estacas com corda no trecho mais íngreme
	for k in range(2, pts.size() - 2, 4):
		var p := pts[k]
		c.cylinder("wood", p + Vector3(1.1, 0.45, 0), 0.06, 0.06, 0.9, Color("8a5a32"), 6)
	b.spots.append({"type": "wander", "pos": pts[pts.size() / 2] + Vector3(0, 0.05, 0)})


# ------------------------------------------------------------- lago

static func _lake(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_lago")
	# pedras na margem (com colisão, menos onde a ponte passa)
	for k in 30:
		var a := k * TAU / 30.0
		if absf(sin(a)) < 0.2:
			continue
		var r := LAKE_R - 0.6 + 0.3 * sin(k * 2.1)
		var p := Vector3(LAKE.x + cos(a) * r, 0, LAKE.y + sin(a) * r)
		p.y = maxf(height(p.x, p.z), WATER_Y) + 0.1
		c.sphere("concrete", p, 0.5 + 0.2 * sin(k * 1.7), Color("a9a59b").lerp(Color("7d8a7a"), fposmod(k * 0.37, 1.0)), Vector3(1.3, 0.7, 1.0), 7, 5)
		c.collider_cyl(p + Vector3(0, 0.4, 0), 0.75, 1.6)
	# ponte de madeira atravessando o lago (eixo x)
	var x0 := LAKE.x - LAKE_R - 1.0
	var x1 := LAKE.x + LAKE_R + 1.0
	var deck_y := 0.32
	var n := int((x1 - x0) / 0.5)
	for i in n:
		var x := x0 + i * 0.5 + 0.25
		var arch := 0.45 * sin(PI * float(i) / n)
		c.box("wood", Vector3(x, deck_y + arch, LAKE.y), Vector3(0.46, 0.1, 2.2), Color("a0663a") if i % 2 == 0 else Color("b5794a"))
	for i in n / 2:
		var x := x0 + i * 1.0 + 0.5
		var arch := 0.45 * sin(PI * (i * 2.0) / n)
		for sz: float in [-1.0, 1.0]:
			c.box("wood", Vector3(x, deck_y + arch + 0.5, LAKE.y + 1.05 * sz), Vector3(1.0, 0.08, 0.08), Color("8a5a32"))
			c.cylinder("wood", Vector3(x, deck_y + arch + 0.25, LAKE.y + 1.05 * sz), 0.05, 0.05, 0.5, Color("8a5a32"), 6)
	# colisão da ponte: rampas nas pontas + tábua no meio
	var mid_y := deck_y + 0.45
	var half := (x1 - x0) * 0.5
	var ramp_len := half
	for s: float in [-1.0, 1.0]:
		var cx := LAKE.x + s * half * 0.5
		var ang := atan2(mid_y - deck_y, ramp_len) * -s
		var xf := Transform3D(Basis(Vector3.FORWARD, ang), Vector3(cx, (deck_y + mid_y) * 0.5, LAKE.y))
		c.collider_xf(xf, Vector3(ramp_len + 0.4, 0.12, 2.2))
	for sz: float in [-1.0, 1.0]:
		c.collider(Vector3(LAKE.x, mid_y + 0.5, LAKE.y + 1.1 * sz), Vector3(x1 - x0, 1.0, 0.1))
	b.nav_points.append(Vector3(x0 - 1.0, 0.05, LAKE.y))
	b.nav_points.append(Vector3(LAKE.x, mid_y + 0.05, LAKE.y))
	b.nav_points.append(Vector3(x1 + 1.0, 0.05, LAKE.y))
	b.nav_links.append([Vector3(x0 - 1.0, 0.05, LAKE.y), Vector3(LAKE.x, mid_y + 0.05, LAKE.y)])
	b.nav_links.append([Vector3(LAKE.x, mid_y + 0.05, LAKE.y), Vector3(x1 + 1.0, 0.05, LAKE.y)])
	b.lakes.append({"center": Vector3(LAKE.x, WATER_Y, LAKE.y), "radius": LAKE_R - 0.3})
	# vitórias-régias
	for k in 7:
		var a := k * 1.9
		var r := 3.0 + fposmod(k * 1.3, 4.5)
		var p := Vector3(LAKE.x + cos(a) * r, WATER_Y + 0.03, LAKE.y + sin(a) * r)
		if absf(p.z - LAKE.y) < 1.6:
			continue
		c.cylinder("plain", p, 0.55, 0.55, 0.03, Color("3f9a4a"), 10, false)
		if k % 3 == 0:
			c.sphere("plain", p + Vector3(0.15, 0.08, 0), 0.12, Color("ff8fc7"), Vector3(1, 0.7, 1), 6, 4, false)
	b.add_label("LAGO DOS PATOS", Vector3(x0 - 1.4, 1.4, LAKE.y - 1.6), -PI * 0.5, 48, Color("1f5fa8"), Color(1, 1, 1, 0.9), 0.006, 30.0)
	c.box("wood", Vector3(x0 - 1.42, 1.4, LAKE.y - 1.6), Vector3(0.06, 0.5, 2.4), Color("f5e6c8"))
	c.box("wood", Vector3(x0 - 1.42, 0.7, LAKE.y - 1.6), Vector3(0.1, 1.4, 0.1), Color("8a5a32"))
	for k in 3:
		b.spots.append({"type": "chat", "pos": Vector3(LAKE.x - 6 + k * 6, 0.05, LAKE.y + LAKE_R + 2.5)})


# ------------------------------------------------------------- anfiteatro

static func _amphitheater(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_anfiteatro")
	var ctr := Vector3(AMPHI.x, 0, AMPHI.y)
	# palco elevado (lado do fundo)
	var stage := ctr + Vector3(0, 0.3, -5.5)
	c.box("wood", stage, Vector3(9.0, 0.6, 4.0), Color("b5794a"))
	c.collider(stage, Vector3(9.0, 0.6, 4.0))
	c.box("paint", stage + Vector3(0, 2.2, -1.9), Vector3(9.0, 3.8, 0.2), Color("2f6fd0"))
	c.box("paint", stage + Vector3(0, 4.15, -1.9), Vector3(9.6, 0.3, 0.5), Color("ffcf3f"))
	b.add_label("ANFITEATRO", stage + Vector3(0, 3.3, -1.78), 0.0, 72, Color.WHITE, Color(0, 0, 0, 0), 0.007, 45.0)
	# escadinha do palco
	for k in 2:
		c.box("concrete", stage + Vector3(-3.5, -0.45 + k * 0.2 + 0.1, 2.25 + (1 - k) * 0.35), Vector3(1.4, 0.2, 0.35), Color("cfd5dc"))
	c.collider_xf(Transform3D(Basis(Vector3.RIGHT, -0.4), stage + Vector3(-3.5, -0.25, 2.55)), Vector3(1.4, 0.1, 1.2))
	# arquibancada em meia-lua (degraus de 0,35 m) virada para o palco
	var rows := 4
	for r in rows:
		var rad := 5.5 + r * 1.6
		var hgt := 0.35 * (r + 1)
		var seg := 11
		for k in seg:
			var a := lerpf(0.15 * PI, 0.85 * PI, (k + 0.5) / seg)
			if absf(a - PI * 0.5) < 0.09:
				continue  # corredor central (rampa invisível)
			var p := ctr + Vector3(cos(a) * rad, hgt * 0.5, -5.5 + sin(a) * rad)
			var w := rad * (0.7 * PI / seg) + 0.08
			c.box("concrete", p, Vector3(w, hgt, 1.6), Color("d8dde3") if r % 2 == 0 else Color("c9cfd6"), -a + PI * 0.5)
			c.collider(p, Vector3(w, hgt, 1.6), -a + PI * 0.5)
			# assento de madeira no degrau
			c.box("wood", p + Vector3(0, hgt * 0.5 + 0.03, 0), Vector3(w * 0.96, 0.06, 0.5), Color("c58b52"), -a + PI * 0.5)
			if k % 3 == 1:
				Props.add_seat(p + Vector3(0, hgt * 0.5, 0), -a - PI * 0.5, Vector3.ZERO, 0.06, "Sentar")
	# corredor central: rampa suave até a última fileira
	var top_r := 5.5 + (rows - 1) * 1.6 + 0.8
	var top_h := 0.35 * rows
	var ramp_c := ctr + Vector3(0, top_h * 0.5, -5.5 + (5.5 - 0.8 + top_r) * 0.5)
	var ramp_len := top_r - 4.7
	c.collider_xf(Transform3D(Basis(Vector3.RIGHT, atan2(top_h, ramp_len)), ramp_c), Vector3(1.2, 0.1, ramp_len + 0.6))
	for k in rows:
		c.box("concrete", ctr + Vector3(0, 0.35 * (k + 1) * 0.5, -5.5 + 5.5 + k * 1.6), Vector3(1.1, 0.35 * (k + 1), 1.6), Color("bfc6ce"))
	for k in 4:
		b.spots.append({"type": "chat", "pos": ctr + Vector3(-4 + k * 2.6, 0.05, 1.5)})
	b.nav_points.append(ctr + Vector3(0, 0.05, 1.0))


# ------------------------------------------------------------- vida

static func _dressing(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_detalhes", 90.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var kinds := ["copa", "ipe", "pinheiro", "copa", "arbusto", "palmeira"]
	var cols := [Color("3f8a3a"), Color("e86aa6"), Color("2f6e3a"), Color("4f9a45"), Color("4a9a45"), Color.WHITE]
	var placed := 0
	var guard := 0
	while placed < 46 and guard < 400:
		guard += 1
		var x := rng.randf_range(AREA.position.x + 3, AREA.end.x - 3)
		var z := rng.randf_range(AREA.position.y + 3, AREA.end.y - 8)
		# longe do lago, do anfiteatro, do topo do morro e da trilha central
		if Vector2(x - LAKE.x, z - LAKE.y).length() < LAKE_R + 3.0:
			continue
		if Vector2(x - AMPHI.x, z - AMPHI.y).length() < 15.0:
			continue
		if Vector2(x - HILL.x, z - HILL.z).length() < 6.0:
			continue
		if absf(x - (HILL.x + 12.0)) < 9.0 and absf(z - HILL.z) < 5.0:
			continue  # caminho do escorregador
		if x > -32.0 and x < 52.0 and z > -97.0:
			continue  # gramadão central livre (correr, pique-pega)
		var k := rng.randi() % kinds.size()
		b._tree(kinds[k], Vector3(x, height(x, z), z), rng.randf_range(0.85, 1.35), cols[k], c)
		placed += 1
	# canteiros de flores silvestres
	for k in 70:
		var x := rng.randf_range(AREA.position.x + 4, AREA.end.x - 4)
		var z := rng.randf_range(AREA.position.y + 4, AREA.end.y - 6)
		if Vector2(x - LAKE.x, z - LAKE.y).length() < LAKE_R + 1.0:
			continue
		var p := Vector3(x, height(x, z), z)
		c.sphere("foliage", p + Vector3(0, 0.12, 0), 0.25, Color("4f9a45"), Vector3(1, 0.6, 1), 6, 4, false)
		c.sphere("plain", p + Vector3(0.08, 0.3, 0.05), 0.07, [Color("ff4d6d"), Color("ffd23f"), Color("ffffff"), Color("b46bff")][k % 4], Vector3.ONE, 5, 3, false)
	# pedras decorativas
	for k in 18:
		var x := rng.randf_range(AREA.position.x + 4, AREA.end.x - 4)
		var z := rng.randf_range(AREA.position.y + 4, AREA.end.y - 8)
		var p := Vector3(x, height(x, z), z)
		var s := rng.randf_range(0.3, 0.8)
		c.sphere("concrete", p + Vector3(0, s * 0.3, 0), s, Color("a9a59b").lerp(Color("8c8478"), rng.randf()), Vector3(1.3, 0.75, 1.0), 7, 5)
		if s > 0.55:
			c.collider_cyl(p + Vector3(0, s * 0.4, 0), s * 0.9, s)
	# bancos e postes ao longo do caminho principal (portal -> lago -> anfiteatro)
	for k in 5:
		var x := -20.0 + k * 10.0
		var z := -83.0
		Props.bench(c, Vector3(x, height(x, z), z), PI, 1.8)
		Props.lamp_post(c, Vector3(x + 5.0, height(x + 5.0, z - 1.5), z - 1.5))
	for k in 4:
		Props.trash_bins(c, Vector3(-14 + k * 14, height(-14 + k * 14, -86.5), -86.5), PI)
	# caminho principal de lajotas
	for k in 40:
		var x := -40.0 + k * 2.0
		var z := -80.5 + sin(k * 0.25) * 0.8
		var h := height(x, z)
		c.slab("concrete", Vector3(x, h + 0.03, z), Vector3(1.8, 0.04, 2.2), Color("cfd5dc") if k % 2 == 0 else Color("bfc6ce"))
	for p in [Vector3(-60, 0, -90), Vector3(60, 0, -88), Vector3(0, 0, -95), Vector3(-20, 0, -118), Vector3(45, 0, -120), Vector3(75, 0, -100)]:
		b.spots.append({"type": "wander", "pos": Vector3(p.x, height(p.x, p.z) + 0.05, p.z)})


## Divisa entre o pátio dos fundos e o parque: cerca viva com 3 passagens
## e um portal colorido no meio.
static func _divider(b: SchoolBuilder) -> void:
	var c := b.chunk("parque_divisa")
	var z := -75.0
	var gaps := [Vector2(-62, -54), Vector2(-9, 9), Vector2(50, 58)]
	var x := -89.5
	while x < 89.5:
		var blocked := true
		for g in gaps:
			if x > g.x and x < g.y:
				blocked = false
		if blocked:
			c.sphere("foliage", Vector3(x, 0.55, z), 0.75, Color("3f8a3a").lerp(Color("4f9a45"), fposmod(x * 0.13, 1.0)), Vector3(1.1, 0.85, 0.8), 7, 5)
			c.collider(Vector3(x, 0.6, z), Vector3(1.0, 1.2, 1.0))
		x += 1.0
	# portal
	for sx: float in [-1.0, 1.0]:
		c.box("brick", Vector3(9.3 * sx, 1.7, z), Vector3(0.7, 3.4, 0.7), Color("c9744d"))
		c.collider(Vector3(9.3 * sx, 1.7, z), Vector3(0.7, 3.4, 0.7))
	c.box("paint", Vector3(0, 3.6, z), Vector3(19.4, 0.8, 0.4), Color("2fae6a"))
	b.add_label("PARQUE DO MORRO", Vector3(0, 3.62, z + 0.22), 0.0, 84, Color.WHITE, Color(0, 0, 0, 0), 0.007, 60.0)
	b.add_label("PARQUE DO MORRO", Vector3(0, 3.62, z - 0.22), PI, 84, Color.WHITE, Color(0, 0, 0, 0), 0.007, 60.0)
	for g in gaps:
		var mid: float = (g.x + g.y) * 0.5
		b.nav_points.append(Vector3(mid, 0.05, z + 2.0))
		b.nav_points.append(Vector3(mid, 0.05, z - 2.0))
		b.nav_links.append([Vector3(mid, 0.05, z + 2.0), Vector3(mid, 0.05, z - 2.0)])
