class_name Props
extends RefCounted
## Biblioteca de objetos do cenário montados com primitivas no batcher.
## Cada função recebe origem (no chão) e rotação Y; objetos sentáveis
## registram assentos em `seats` para virarem interativos.

const FLOOR_Y := 0.02

static var seats: Array = []  # {pos, yaw, label}
static var fountains: Array = []  # {pos, yaw}

const C_WOOD := Color("c58b52")
const C_WOOD_DARK := Color("8a5a32")
const C_METAL_BLUE := Color("2f5fa8")
const C_METAL := Color("9aa3ad")
const C_CONCRETE := Color("bcc3cc")
const C_GREEN := Color("2f7d3c")


static func reset() -> void:
	seats.clear()
	fountains.clear()


static func _p(o: Vector3, r: float, local: Vector3) -> Vector3:
	return o + local.rotated(Vector3.UP, r)


static func _bx(b: WorldBatcher, mat: String, o: Vector3, r: float, local: Vector3, size: Vector3, col: Color, shadow := true) -> void:
	b.box(mat, _p(o, r, local), size, col, r, shadow)


static func add_seat(o: Vector3, r: float, local_seat: Vector3, seat_top: float, label := "Sentar") -> void:
	var facing := Vector3(0, 0, 1).rotated(Vector3.UP, r)
	var c := _p(o, r, local_seat)
	var pos := Vector3(c.x, seat_top - 0.45 + FLOOR_Y * 0.0, c.z) + facing * 0.04
	seats.append({"pos": pos, "yaw": r, "label": label, "seat_top": seat_top})


# ---------------------------------------------------------------- sala de aula

static func student_desk(b: WorldBatcher, o: Vector3, r: float, frame_col := C_METAL_BLUE) -> void:
	var y := o.y
	# Cadeira (pessoa senta olhando para +Z local)
	_bx(b, "wood", o, r, Vector3(0, 0.43, 0), Vector3(0.4, 0.035, 0.38), C_WOOD)
	_bx(b, "wood", o, r, Vector3(0, 0.74, -0.2), Vector3(0.38, 0.2, 0.03), C_WOOD)
	for lx: float in [-0.17, 0.17]:
		for lz: float in [-0.16, 0.16]:
			_bx(b, "metal", o, r, Vector3(lx, 0.21, lz), Vector3(0.025, 0.42, 0.025), frame_col)
		_bx(b, "metal", o, r, Vector3(lx, 0.6, -0.19), Vector3(0.025, 0.36, 0.025), frame_col)
	# Mesa
	_bx(b, "wood", o, r, Vector3(0, 0.72, 0.46), Vector3(0.62, 0.03, 0.46), C_WOOD)
	_bx(b, "metal", o, r, Vector3(0, 0.6, 0.5), Vector3(0.56, 0.02, 0.34), frame_col.darkened(0.1))
	for lx: float in [-0.28, 0.28]:
		for lz: float in [0.27, 0.65]:
			_bx(b, "metal", o, r, Vector3(lx, 0.355, lz), Vector3(0.025, 0.71, 0.025), frame_col)
	add_seat(Vector3(o.x, y, o.z), r, Vector3(0, 0.45, 0), y + 0.45)
	b.collider(_p(o, r, Vector3(0, 0.37, 0.46)), Vector3(0.62, 0.74, 0.46), r)


static func teacher_desk(b: WorldBatcher, o: Vector3, r: float) -> void:
	_bx(b, "wood", o, r, Vector3(0, 0.76, 0), Vector3(1.5, 0.05, 0.75), C_WOOD_DARK)
	_bx(b, "wood", o, r, Vector3(0, 0.4, 0.33), Vector3(1.45, 0.7, 0.04), C_WOOD_DARK.darkened(0.1))
	_bx(b, "wood", o, r, Vector3(-0.68, 0.38, 0), Vector3(0.05, 0.74, 0.7), C_WOOD_DARK)
	_bx(b, "wood", o, r, Vector3(0.68, 0.38, 0), Vector3(0.05, 0.74, 0.7), C_WOOD_DARK)
	# Itens sobre a mesa: livros, caneca, globo
	_bx(b, "plain", o, r, Vector3(-0.45, 0.82, 0.05), Vector3(0.25, 0.07, 0.18), Color("c0392b"))
	_bx(b, "plain", o, r, Vector3(-0.43, 0.88, 0.04), Vector3(0.22, 0.05, 0.16), Color("2e86de"))
	b.cylinder("plain", _p(o, r, Vector3(0.1, 0.83, -0.1)), 0.04, 0.04, 0.09, Color("f1c40f"), 8)
	b.sphere("plain", _p(o, r, Vector3(0.45, 0.98, 0.0)), 0.13, Color("3b8ed0"), Vector3.ONE, 12, 8)
	b.cylinder("metal", _p(o, r, Vector3(0.45, 0.82, 0.0)), 0.03, 0.08, 0.06, Color("444444"), 8)
	b.collider(_p(o, r, Vector3(0, 0.4, 0)), Vector3(1.5, 0.8, 0.75), r)
	# Cadeira do professor
	var co := _p(o, r, Vector3(0, 0, -0.7))
	_bx(b, "wood", co, r + PI, Vector3(0, 0.45, 0), Vector3(0.45, 0.05, 0.45), C_WOOD_DARK)
	_bx(b, "wood", co, r + PI, Vector3(0, 0.8, -0.22), Vector3(0.45, 0.5, 0.05), C_WOOD_DARK)
	for lx: float in [-0.19, 0.19]:
		for lz: float in [-0.19, 0.19]:
			_bx(b, "wood", co, r + PI, Vector3(lx, 0.22, lz), Vector3(0.04, 0.44, 0.04), C_WOOD_DARK.darkened(0.2))


## Lousa verde. Retorna a transformação central para colocar texto.
static func chalkboard(b: WorldBatcher, o: Vector3, r: float, width := 4.0) -> Transform3D:
	_bx(b, "wood", o, r, Vector3(0, 1.55, 0), Vector3(width + 0.16, 1.36, 0.06), C_WOOD_DARK)
	_bx(b, "chalk", o, r, Vector3(0, 1.55, 0.035), Vector3(width, 1.2, 0.02), Color("2f5a43"))
	_bx(b, "wood", o, r, Vector3(0, 0.88, 0.08), Vector3(width, 0.04, 0.12), C_WOOD_DARK)
	_bx(b, "plain", o, r, Vector3(-width * 0.3, 0.915, 0.09), Vector3(0.08, 0.02, 0.02), Color.WHITE)
	_bx(b, "plain", o, r, Vector3(-width * 0.3 + 0.15, 0.915, 0.08), Vector3(0.12, 0.04, 0.05), Color("ddc9a3"))
	return Transform3D(Basis(Vector3.UP, r), _p(o, r, Vector3(0, 1.6, 0.05)))


static func bookshelf(b: WorldBatcher, o: Vector3, r: float, rng: RandomNumberGenerator, width := 1.8, height := 2.0) -> void:
	_bx(b, "wood", o, r, Vector3(0, height * 0.5, -0.17), Vector3(width, height, 0.03), C_WOOD_DARK)
	_bx(b, "wood", o, r, Vector3(-width * 0.5, height * 0.5, 0), Vector3(0.04, height, 0.36), C_WOOD)
	_bx(b, "wood", o, r, Vector3(width * 0.5, height * 0.5, 0), Vector3(0.04, height, 0.36), C_WOOD)
	var shelves := 5
	var palette := [Color("c0392b"), Color("2980b9"), Color("27ae60"), Color("f39c12"), Color("8e44ad"), Color("16a085"), Color("d35400"), Color("ecf0f1")]
	for s in shelves:
		var y := 0.04 + s * (height - 0.08) / (shelves - 1)
		_bx(b, "wood", o, r, Vector3(0, y, 0), Vector3(width, 0.035, 0.36), C_WOOD)
		if s == shelves - 1:
			continue
		var x := -width * 0.5 + 0.06
		while x < width * 0.5 - 0.1:
			var w := rng.randf_range(0.04, 0.08)
			var h := rng.randf_range(0.22, 0.34)
			if rng.randf() < 0.9:
				_bx(b, "plain", o, r, Vector3(x + w * 0.5, y + 0.02 + h * 0.5, 0.02), Vector3(w, h, 0.25), palette[rng.randi() % palette.size()], false)
			x += w + 0.008
	b.collider(_p(o, r, Vector3(0, height * 0.5, 0)), Vector3(width, height, 0.38), r)


static func table_with_chairs(b: WorldBatcher, o: Vector3, r: float, top_col := C_WOOD) -> void:
	_bx(b, "wood", o, r, Vector3(0, 0.74, 0), Vector3(1.6, 0.05, 0.9), top_col)
	for lx: float in [-0.72, 0.72]:
		for lz: float in [-0.38, 0.38]:
			_bx(b, "metal", o, r, Vector3(lx, 0.36, lz), Vector3(0.05, 0.72, 0.05), C_METAL)
	b.collider(_p(o, r, Vector3(0, 0.38, 0)), Vector3(1.6, 0.76, 0.9), r)
	for side: float in [1.0, -1.0]:
		for cx: float in [-0.4, 0.4]:
			var co := _p(o, r, Vector3(cx, 0, -0.75 * side))
			var cr := r if side > 0 else r + PI
			_bx(b, "wood", co, cr, Vector3(0, 0.44, 0), Vector3(0.42, 0.04, 0.4), C_WOOD)
			_bx(b, "wood", co, cr, Vector3(0, 0.72, -0.19), Vector3(0.4, 0.22, 0.03), C_WOOD)
			for lx: float in [-0.18, 0.18]:
				for lz: float in [-0.17, 0.17]:
					_bx(b, "metal", co, cr, Vector3(lx, 0.21, lz), Vector3(0.025, 0.42, 0.025), C_METAL)
			add_seat(co, cr, Vector3(0, 0.45, 0), o.y + 0.45)


# ---------------------------------------------------------------- exterior

## Banco de praça (madeira com pés de concreto), 3 lugares.
static func bench(b: WorldBatcher, o: Vector3, r: float, length := 1.8, with_back := true) -> void:
	for i in 3:
		_bx(b, "wood", o, r, Vector3(0, 0.44, -0.12 + i * 0.13), Vector3(length, 0.04, 0.11), C_WOOD)
	if with_back:
		_bx(b, "wood", o, r, Vector3(0, 0.62, -0.22), Vector3(length, 0.1, 0.035), C_WOOD)
		_bx(b, "wood", o, r, Vector3(0, 0.76, -0.24), Vector3(length, 0.1, 0.035), C_WOOD)
	for lx: float in [-length * 0.4, length * 0.4]:
		_bx(b, "concrete", o, r, Vector3(lx, 0.21, 0), Vector3(0.12, 0.42, 0.42), C_CONCRETE)
		if with_back:
			_bx(b, "metal", o, r, Vector3(lx, 0.62, -0.25), Vector3(0.04, 0.4, 0.04), Color("333333"))
	b.collider(_p(o, r, Vector3(0, 0.23, 0)), Vector3(length, 0.46, 0.45), r)
	var n := maxi(int(length / 0.65), 1)
	for i in n:
		var lx := -length * 0.5 + length * (i + 0.5) / n
		add_seat(o, r, Vector3(lx, 0.46, 0.02), o.y + 0.46)


## Mesa de refeitório com bancos corridos dos dois lados.
static func cafeteria_table(b: WorldBatcher, o: Vector3, r: float, length := 3.2, col := Color("e8e1d3")) -> void:
	_bx(b, "plain", o, r, Vector3(0, 0.74, 0), Vector3(length, 0.05, 0.85), col)
	for lx: float in [-length * 0.4, length * 0.4]:
		_bx(b, "metal", o, r, Vector3(lx, 0.37, 0), Vector3(0.06, 0.72, 0.6), Color("5a6a7a"))
	b.collider(_p(o, r, Vector3(0, 0.38, 0)), Vector3(length, 0.76, 0.85), r)
	for side: float in [1.0, -1.0]:
		_bx(b, "plain", o, r, Vector3(0, 0.44, 0.72 * side), Vector3(length, 0.05, 0.3), col.darkened(0.08))
		for lx: float in [-length * 0.4, length * 0.4]:
			_bx(b, "metal", o, r, Vector3(lx, 0.21, 0.72 * side), Vector3(0.05, 0.42, 0.22), Color("5a6a7a"))
		var n := maxi(int(length / 0.7), 1)
		for i in n:
			var lx := -length * 0.5 + length * (i + 0.5) / n
			var sr := r if side < 0 else r + PI
			add_seat(_p(o, r, Vector3(lx, 0, 0.74 * side)), sr, Vector3.ZERO, o.y + 0.47)


static func trash_bins(b: WorldBatcher, o: Vector3, r: float) -> void:
	var cols := [Color("2e86de"), Color("e74c3c"), Color("27ae60"), Color("f1c40f")]
	for i in 4:
		var p := _p(o, r, Vector3(-0.6 + i * 0.4, 0.38, 0))
		b.cylinder("plain", p, 0.17, 0.15, 0.7, cols[i], 10)
		b.cylinder("plain", p + Vector3(0, 0.37, 0), 0.18, 0.18, 0.05, cols[i].darkened(0.2), 10)
	_bx(b, "metal", o, r, Vector3(0, 0.5, -0.2), Vector3(1.7, 0.05, 0.05), C_METAL)
	b.collider(_p(o, r, Vector3(0, 0.4, 0)), Vector3(1.6, 0.8, 0.4), r)


static func water_fountain(b: WorldBatcher, o: Vector3, r: float) -> void:
	_bx(b, "metal", o, r, Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.42), Color("cfd6dc"))
	_bx(b, "metal", o, r, Vector3(0, 0.93, 0.03), Vector3(0.52, 0.06, 0.46), Color("e8ecef"))
	b.cylinder("metal", _p(o, r, Vector3(0, 0.99, 0.1)), 0.02, 0.025, 0.08, Color("8a949e"), 6)
	_bx(b, "plain", o, r, Vector3(0, 0.6, 0.215), Vector3(0.3, 0.12, 0.01), Color("2e86de"))
	b.collider(_p(o, r, Vector3(0, 0.48, 0)), Vector3(0.52, 0.96, 0.46), r)
	fountains.append({"pos": _p(o, r, Vector3(0, 0, 0.75)), "yaw": r + PI, "spout": _p(o, r, Vector3(0, 1.02, 0.1))})


static func lamp_post(b: WorldBatcher, o: Vector3) -> void:
	b.cylinder("metal", o + Vector3(0, 2.0, 0), 0.05, 0.08, 4.0, Color("3d4752"), 8)
	b.box("metal", o + Vector3(0, 4.0, 0.25), Vector3(0.12, 0.08, 0.6), Color("3d4752"))
	b.box("plain", o + Vector3(0, 3.94, 0.45), Vector3(0.22, 0.06, 0.3), Color("fff3c4"))
	b.collider_cyl(o + Vector3(0, 1.5, 0), 0.1, 3.0)


static func planter(b: WorldBatcher, o: Vector3, size: Vector2, flower_rng: RandomNumberGenerator, edge_col := Color("d8cdb8")) -> void:
	var h := 0.45
	var t := 0.15
	b.box("concrete", o + Vector3(0, h * 0.5, size.y * 0.5 - t * 0.5), Vector3(size.x, h, t), edge_col)
	b.box("concrete", o + Vector3(0, h * 0.5, -size.y * 0.5 + t * 0.5), Vector3(size.x, h, t), edge_col)
	b.box("concrete", o + Vector3(size.x * 0.5 - t * 0.5, h * 0.5, 0), Vector3(t, h, size.y - 2 * t), edge_col)
	b.box("concrete", o + Vector3(-size.x * 0.5 + t * 0.5, h * 0.5, 0), Vector3(t, h, size.y - 2 * t), edge_col)
	b.slab("dirt", o + Vector3(0, h * 0.75, 0), Vector3(size.x - 2 * t, h * 0.5, size.y - 2 * t), Color("6b4a2f"))
	b.collider(o + Vector3(0, h * 0.5, 0), Vector3(size.x, h, size.y))
	var flower_cols := [Color("e74c3c"), Color("f1c40f"), Color("e84393"), Color("ffffff"), Color("9b59b6"), Color("ff7f50")]
	var count := int(size.x * size.y * 2.5)
	for i in count:
		var p := o + Vector3(flower_rng.randf_range(-size.x * 0.5 + 0.25, size.x * 0.5 - 0.25), h + 0.08, flower_rng.randf_range(-size.y * 0.5 + 0.25, size.y * 0.5 - 0.25))
		b.sphere("foliage", p + Vector3(0, 0.05, 0), 0.16, Color("3f8f3a").lerp(Color("5fae45"), flower_rng.randf()), Vector3(1, 0.7, 1), 6, 4, false)
		if flower_rng.randf() < 0.6:
			b.sphere("plain", p + Vector3(flower_rng.randf_range(-0.08, 0.08), 0.18, flower_rng.randf_range(-0.08, 0.08)), 0.05, flower_cols[flower_rng.randi() % flower_cols.size()], Vector3.ONE, 6, 4, false)


static func flagpole(b: WorldBatcher, o: Vector3, flag_col: Color) -> void:
	b.cylinder("concrete", o + Vector3(0, 0.2, 0), 0.5, 0.6, 0.4, C_CONCRETE, 12)
	b.cylinder("metal", o + Vector3(0, 4.2, 0), 0.04, 0.06, 8.0, Color("d9dee3"), 8)
	b.sphere("metal", o + Vector3(0, 8.25, 0), 0.08, Color("f1c40f"))
	b.box("plain", o + Vector3(0.6, 7.4, 0), Vector3(1.2, 0.8, 0.02), flag_col)
	b.collider_cyl(o + Vector3(0, 1.5, 0), 0.5, 3.0)


static func umbrella_table(b: WorldBatcher, o: Vector3, col: Color) -> void:
	b.cylinder("plain", o + Vector3(0, 0.74, 0), 0.6, 0.6, 0.05, Color("f2efe8"), 14)
	b.cylinder("metal", o + Vector3(0, 0.37, 0), 0.04, 0.04, 0.72, Color("666666"), 6)
	b.cylinder("plain", o + Vector3(0, 0.02, 0), 0.3, 0.3, 0.04, Color("666666"), 10)
	b.cylinder("metal", o + Vector3(0, 1.4, 0), 0.025, 0.025, 1.3, Color("dddddd"), 6)
	b.cylinder("plain", o + Vector3(0, 2.15, 0), 0.0, 1.3, 0.45, col, 8)
	b.collider_cyl(o + Vector3(0, 0.38, 0), 0.6, 0.76)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var so := o + Vector3(sin(a), 0, cos(a)) * 1.0
		b.cylinder("plain", so + Vector3(0, 0.44, 0), 0.2, 0.2, 0.05, col.darkened(0.15), 10)
		b.cylinder("metal", so + Vector3(0, 0.21, 0), 0.03, 0.03, 0.42, Color("666666"), 6)
		add_seat(so, a + PI, Vector3.ZERO, o.y + 0.46)


static func parked_car(b: WorldBatcher, o: Vector3, r: float, col: Color) -> void:
	var dark := Color("2d3436")
	# carroceria em duas partes com cantos chanfrados
	_bx(b, "metal", o, r, Vector3(0, 0.62, 0), Vector3(1.78, 0.5, 3.9), col)
	_bx(b, "metal", o, r, Vector3(0, 0.5, 1.98), Vector3(1.7, 0.36, 0.12), col.darkened(0.08))
	_bx(b, "metal", o, r, Vector3(0, 0.5, -1.98), Vector3(1.7, 0.36, 0.12), col.darkened(0.08))
	var cabin := Transform3D(Basis(Vector3.UP, r), _p(o, r, Vector3(0, 1.1, -0.25)))
	b.box_xf("metal", cabin, Vector3(1.58, 0.5, 2.0), col)
	# vidros (para-brisa inclinado, laterais e traseiro)
	b.box_xf("glass", Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, -0.55), _p(o, r, Vector3(0, 1.08, 0.82))), Vector3(1.5, 0.52, 0.04), Color("2c3e50"))
	b.box_xf("glass", Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, 0.5), _p(o, r, Vector3(0, 1.08, -1.3))), Vector3(1.5, 0.48, 0.04), Color("2c3e50"))
	for sx: float in [-1.0, 1.0]:
		_bx(b, "glass", o, r, Vector3(0.8 * sx, 1.12, -0.25), Vector3(0.02, 0.36, 1.7), Color("34495e"))
		_bx(b, "metal", o, r, Vector3(0.8 * sx, 1.12, -0.25), Vector3(0.03, 0.36, 0.06), col.darkened(0.2))
		_bx(b, "metal", o, r, Vector3(0.9 * sx, 0.95, 0.75), Vector3(0.14, 0.08, 0.1), col.darkened(0.15))
		_bx(b, "metal", o, r, Vector3(0.895 * sx, 0.72, 0.1), Vector3(0.02, 0.03, 0.14), Color("bdc3c7"))
		_bx(b, "metal", o, r, Vector3(0.895 * sx, 0.72, -0.85), Vector3(0.02, 0.03, 0.14), Color("bdc3c7"))
		_bx(b, "metal", o, r, Vector3(0.892 * sx, 0.68, -0.38), Vector3(0.01, 0.42, 0.02), col.darkened(0.3))
	# para-choques, faróis, lanternas e placa
	_bx(b, "plain", o, r, Vector3(0, 0.36, 2.06), Vector3(1.82, 0.16, 0.14), dark)
	_bx(b, "plain", o, r, Vector3(0, 0.36, -2.06), Vector3(1.82, 0.16, 0.14), dark)
	_bx(b, "plain", o, r, Vector3(0, 0.58, 2.05), Vector3(0.7, 0.14, 0.03), Color("1e272e"))
	_bx(b, "plain", o, r, Vector3(0, 0.36, 2.14), Vector3(0.5, 0.12, 0.02), Color("f5f6fa"))
	_bx(b, "plain", o, r, Vector3(0, 0.36, -2.14), Vector3(0.5, 0.12, 0.02), Color("f5f6fa"))
	for sx: float in [-1.0, 1.0]:
		_bx(b, "plain", o, r, Vector3(0.62 * sx, 0.64, 2.05), Vector3(0.34, 0.13, 0.04), Color("fff6c8"))
		_bx(b, "plain", o, r, Vector3(0.66 * sx, 0.66, -2.05), Vector3(0.3, 0.14, 0.04), Color("e74c3c"))
	# rodas com pneu, calota e caixa de roda escura
	for wx: float in [-0.82, 0.82]:
		for wz: float in [-1.3, 1.3]:
			var xf := Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.FORWARD, PI / 2), _p(o, r, Vector3(wx, 0.33, wz)))
			b.cylinder_xf("plain", xf, 0.33, 0.33, 0.24, Color("1e1e1e"), 12)
			var xf2 := Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.FORWARD, PI / 2), _p(o, r, Vector3(wx * 1.08, 0.33, wz)))
			b.cylinder_xf("metal", xf2, 0.19, 0.19, 0.04, Color("c8d6e5"), 10)
			_bx(b, "plain", o, r, Vector3(wx * 1.01, 0.62, wz), Vector3(0.06, 0.12, 0.8), dark)
	b.collider(_p(o, r, Vector3(0, 0.7, 0)), Vector3(1.8, 1.4, 4.2), r)


## Casa simples vista de fora do muro (cenário de fundo).
static func house(b: WorldBatcher, o: Vector3, r: float, w: float, d: float, wall_col: Color, roof_col: Color) -> void:
	var h := 3.0
	_bx(b, "paint", o, r, Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall_col)
	_bx(b, "glass", o, r, Vector3(-w * 0.25, 1.6, d * 0.5 + 0.01), Vector3(1.2, 1.0, 0.04), Color("8fb3c9"))
	_bx(b, "wood", o, r, Vector3(w * 0.2, 1.05, d * 0.5 + 0.01), Vector3(0.9, 2.1, 0.04), C_WOOD_DARK)
	var slope := deg_to_rad(22.0)
	var half := d * 0.5 + 0.4
	var rise := half * tan(slope)
	for side: float in [1.0, -1.0]:
		var xf := Transform3D(Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, slope * side), _p(o, r, Vector3(0, h + rise * 0.5, half * 0.5 * side)))
		b.box_xf("roof", xf, Vector3(w + 0.6, 0.08, half / cos(slope)), roof_col)
	for sx: float in [1.0, -1.0]:
		b.triangle("paint", _p(o, r, Vector3(w * 0.5 * sx, h, d * 0.5)), _p(o, r, Vector3(w * 0.5 * sx, h, -d * 0.5)), _p(o, r, Vector3(w * 0.5 * sx, h + (d * 0.5) * tan(slope), 0)), wall_col)
