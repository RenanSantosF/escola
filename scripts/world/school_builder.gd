class_name SchoolBuilder
extends RefCounted
## Gera a escola inteira proceduralmente (prédios, salas, pátios, quadra,
## parquinho, murada...). O layout fica todo neste arquivo, em metros:
## X = leste/oeste, Z = norte(-)/sul(+). A rua e o portão ficam em +Z.

const FLOOR_TOP := 0.025
const WALL_T := 0.25
const LOT := Rect2(-90, -75, 180, 150)

var chunks := {}
var zones: Array = []
var labels: Array = []
var trees: Array = []
var balls: Array = []
var pickups: Array = []
var roof_chunks := {}
var interior_chunks := {}
var map_shapes: Array = []
var surfaces: Array = []  # {rect, type} — tipo de piso para sons de passos
var classrooms := {}  # nome -> {rect, board, teacher, door_in, door_out, board_yaw}
var nav_points: Array = []  # pontos extras de navegação (portas, corredores)
var nav_links: Array = []  # pares [a, b] que devem ser ligados (passagem por portas)
var spots: Array = []  # pontos de atividade do recreio {type, pos, yaw}
var spawn := Vector3(0, 0.05, 52)
var spawn_yaw := PI
var rng := RandomNumberGenerator.new()

# Cores
const CREAM := Color("f2e6c8")
const WHITE_WALL := Color("f4f1ea")
const BLUE_BAR := Color("3d78c2")
const GREEN_BAR := Color("3f9a5a")
const ROOF_RED := Color("c2643c")
const CONCRETE := Color("cfcac0")
const RED_FLOOR := Color("b5523b")


## Alcance padrão de chunks de áreas externas com muitos detalhes.
const AREA_RANGE := {"parquinho": 95.0, "horta": 90.0, "queimada": 110.0, "bosque": 100.0, "jardim_oeste": 100.0,
	"pias": 70.0, "parking": 110.0, "front": 120.0, "outside": 170.0, "patio_coberto": 120.0, "signs": 45.0}


func chunk(name: String, vis := 0.0) -> WorldBatcher:
	if not chunks.has(name):
		var b := WorldBatcher.new(name)
		b.visibility_end = vis if vis > 0.0 else AREA_RANGE.get(name, 0.0)
		chunks[name] = b
	return chunks[name]


func add_zone(zone_name: String, r: Rect2, indoor := false, roof_id := "", priority := 0, map_col := Color(0, 0, 0, 0)) -> void:
	zones.append({"name": zone_name, "rect": r, "indoor": indoor, "roof": roof_id, "priority": priority, "color": map_col})


func add_surface(r: Rect2, type: String) -> void:
	surfaces.append({"rect": r, "type": type})


func add_label(text: String, pos: Vector3, rot_y: float, font_size := 48, color := Color.WHITE, outline := Color(0, 0, 0, 0.8), pixel := 0.006, vis := 40.0) -> void:
	labels.append({"text": text, "pos": pos, "rot": rot_y, "size": font_size, "color": color, "outline": outline, "pixel": pixel, "vis": vis})


static func R(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return Rect2(x0, z0, x1 - x0, z1 - z0)


# =====================================================================
# Construção principal (corrotina: chama `step` entre etapas p/ loading)
# =====================================================================

func build_all(step: Callable) -> void:
	rng.seed = 2024
	Props.reset()
	_ground()
	await step.call(0.08, "Preparando o terreno...")
	_wall_perimeter()
	_outside()
	await step.call(0.16, "Levantando a murada...")
	_building_a()
	await step.call(0.32, "Construindo o Bloco A...")
	_building_b()
	_cantina()
	await step.call(0.42, "Montando a cantina...")
	_front_yard()
	_parking()
	await step.call(0.5, "Plantando o jardim...")
	_covered_patio()
	_open_patio()
	await step.call(0.58, "Pintando o pátio...")
	_sports_court()
	await step.call(0.66, "Marcando a quadra...")
	_dodgeball_area()
	_playground()
	_garden_and_woods()
	await step.call(0.74, "Espalhando as árvores...")
	_general_zones()
	_recess_spots()


# =====================================================================
# Prédios genéricos: salas retangulares com paredes compartilhadas,
# portas, janelas basculantes, pintura interna e telhado.
# =====================================================================

## def: {id, height, wall, bar, bar_h, trim, rooms:[...], roof:{...}}
## room: {name, rect, floor, floor_col, inner:[baixo, cima, altura_barra],
##        inner_mat, doors:[[lado, centro, largura, altura]],
##        windows:[[lado, centro, largura]], auto_windows:[lados],
##        open:[lados], kind, label, colonnade:[lado]}
func build_building(def: Dictionary) -> void:
	var id: String = def.id
	var H: float = def.height
	var lines := {}
	var shell := chunk("bld_" + id)
	interior_chunks[id] = []

	for room in def.rooms:
		var r: Rect2 = room.rect
		var sides := _room_sides(r)
		var open: Array = room.get("open", [])
		for s in sides.keys():
			if s in open:
				continue
			var sd: Array = sides[s]
			var line := _line(lines, sd[0], sd[1])
			line.intervals.append([sd[2], sd[3]])
		for d in room.get("doors", []):
			var sd2: Array = sides[d[0]]
			var line2 := _line(lines, sd2[0], sd2[1])
			var h: float = d[3] if d.size() > 3 else 2.25
			line2.openings[snappedf(d[1], 0.01)] = {"c": d[1], "w": d[2], "bottom": 0.0, "top": h, "type": "door", "into": sd2[4]}
			# pontos de navegação dos dois lados da porta
			var dc: Vector3 = Vector3(d[1], 0.05, sd2[1]) if sd2[0] == "h" else Vector3(sd2[1], 0.05, d[1])
			var nrm: Vector3 = (Vector3(0, 0, 1) if sd2[0] == "h" else Vector3(1, 0, 0)) * float(sd2[4])
			var p_in: Vector3 = dc + nrm * 0.9
			var p_out: Vector3 = dc - nrm * 0.9
			nav_points.append(p_in)
			nav_points.append(p_out)
			nav_links.append([p_in, p_out])
			if room.get("kind", "") == "classroom" and not classrooms.has(room.name):
				classrooms[room.name] = {"rect": room.rect, "door_in": p_in, "door_out": p_out}
		var wins: Array = room.get("windows", []).duplicate()
		for s in room.get("auto_windows", []):
			var sd3: Array = sides[s]
			var length: float = sd3[3] - sd3[2]
			var n := int((length - 1.0) / 2.6)
			for i in n:
				var c: float = sd3[2] + length * (i + 0.5) / n
				var blocked := false
				for d in room.get("doors", []):
					if d[0] == s and absf(d[1] - c) < (d[2] * 0.5 + 1.1):
						blocked = true
				if not blocked:
					wins.append([s, c, 1.9])
		for w in wins:
			var sd4: Array = sides[w[0]]
			var line3 := _line(lines, sd4[0], sd4[1])
			line3.openings[snappedf(w[1], 0.01)] = {"c": w[1], "w": w[2], "bottom": 1.0, "top": 2.45, "type": "window", "into": sd4[4]}
		for hz in room.get("hatches", []):
			var sd5: Array = sides[hz[0]]
			var line5 := _line(lines, sd5[0], sd5[1])
			line5.openings[snappedf(hz[1], 0.01)] = {"c": hz[1], "w": hz[2], "bottom": 1.0, "top": 2.3, "type": "hatch", "into": sd5[4]}

	# Paredes
	for key in lines.keys():
		var line: Dictionary = lines[key]
		var merged := _merge_intervals(line.intervals)
		var ops: Array = line.openings.values()
		ops.sort_custom(func(a, b): return a.c < b.c)
		for iv in merged:
			_wall_run(shell, line.axis, line.coord, iv[0] - WALL_T * 0.5, iv[1] + WALL_T * 0.5, ops, H, WALL_T,
				[def.bar, def.wall, def.bar_h], "paint", 0.0, true, def.get("trim", Color.WHITE))

	# Pisos, pintura interna, conteúdo
	for room in def.rooms:
		var r: Rect2 = room.rect
		var inner_chunk_name := "int_%s_%s" % [id, room.name]
		var always: bool = room.get("always_visible", false)
		var ib := chunk(inner_chunk_name, 0.0 if always else 55.0)
		if not always:
			interior_chunks[id].append(inner_chunk_name)
		var fmat: String = room.get("floor", "tile")
		shell.slab(fmat, Vector3(r.get_center().x, FLOOR_TOP - 0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y), room.get("floor_col", Color("e9e4da")))
		if room.has("inner"):
			var sides := _room_sides(r)
			var open: Array = room.get("open", [])
			for s in sides.keys():
				if s in open:
					continue
				var sd: Array = sides[s]
				var line: Dictionary = lines[_line_key(sd[0], sd[1])]
				var ops: Array = line.openings.values()
				ops.sort_custom(func(a, b): return a.c < b.c)
				var offset: float = (WALL_T * 0.5 + 0.012) * sd[4]
				_wall_run(ib, sd[0], sd[1], sd[2] + WALL_T * 0.5, sd[3] - WALL_T * 0.5, ops, H - 0.01, 0.02,
					room.inner, room.get("inner_mat", "paint"), offset, false, Color.WHITE)
		for col_side in room.get("colonnade", []):
			var sd: Array = _room_sides(r)[col_side]
			var a: float = sd[2]
			while a <= sd[3] + 0.01:
				var p := Vector3(a, H * 0.5, sd[1]) if sd[0] == "h" else Vector3(sd[1], H * 0.5, a)
				shell.box("paint", p, Vector3(0.3, H, 0.3), def.wall)
				shell.box("paint", Vector3(p.x, 0.5, p.z), Vector3(0.34, 1.0, 0.34), def.bar)
				shell.collider(p, Vector3(0.3, H, 0.3))
				a += 4.0
			var mid := Vector3((sd[2] + sd[3]) * 0.5, H - 0.2, sd[1]) if sd[0] == "h" else Vector3(sd[1], H - 0.2, (sd[2] + sd[3]) * 0.5)
			var size := Vector3(sd[3] - sd[2] + 0.3, 0.4, 0.3) if sd[0] == "h" else Vector3(0.3, 0.4, sd[3] - sd[2] + 0.3)
			shell.box("paint", mid, size, def.wall)
		var room_name: String = room.get("label", room.name)
		add_zone(room_name, r, true, id, 10, room.get("map_col", Color(0.85, 0.82, 0.75)))
		add_surface(r, "hard")
		# pontos internos de navegação (grade de 2,5 m dentro da sala)
		var gx: float = r.position.x + 1.25
		while gx < r.end.x - 0.5:
			var gz: float = r.position.y + 1.25
			while gz < r.end.y - 0.5:
				nav_points.append(Vector3(gx, 0.05, gz))
				gz += 2.5
			gx += 2.5
		var seat_start := Props.seats.size()
		InteriorDecorator.decorate(self, ib, room, def)
		for i in range(seat_start, Props.seats.size()):
			Props.seats[i]["room"] = room_name

	# Telhado
	if def.has("roof"):
		_roof(id, def.roof, H, def.wall)
	var bounds: Rect2 = def.rooms[0].rect
	for room in def.rooms:
		bounds = bounds.merge(room.rect)
	map_shapes.append({"rect": bounds, "color": Color(0.78, 0.45, 0.32), "label": def.get("title", "")})


func _room_sides(r: Rect2) -> Dictionary:
	return {
		"n": ["h", r.position.y, r.position.x, r.end.x, 1.0],
		"s": ["h", r.end.y, r.position.x, r.end.x, -1.0],
		"w": ["v", r.position.x, r.position.y, r.end.y, 1.0],
		"e": ["v", r.end.x, r.position.y, r.end.y, -1.0],
	}


func _line_key(axis: String, coord: float) -> String:
	return "%s:%.2f" % [axis, coord]


func _line(lines: Dictionary, axis: String, coord: float) -> Dictionary:
	var k := _line_key(axis, coord)
	if not lines.has(k):
		lines[k] = {"axis": axis, "coord": coord, "intervals": [], "openings": {}}
	return lines[k]


func _merge_intervals(list: Array) -> Array:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for iv in sorted:
		if out.is_empty() or iv[0] > out[-1][1] + 0.01:
			out.append([iv[0], iv[1]])
		else:
			out[-1][1] = maxf(out[-1][1], iv[1])
	return out


## Gera um trecho de parede (ou revestimento interno) ao longo de uma linha,
## recortando portas e janelas. colors = [cor_barra, cor_superior, altura_barra]
func _wall_run(b: WorldBatcher, axis: String, coord: float, a0: float, a1: float, openings: Array, H: float, T: float,
		colors: Array, mat: String, offset: float, structural: bool, trim: Color) -> void:
	var cursor := a0
	for o in openings:
		var o0: float = o.c - o.w * 0.5
		var o1: float = o.c + o.w * 0.5
		if o1 <= a0 + 0.001 or o0 >= a1 - 0.001:
			continue
		o0 = maxf(o0, a0)
		o1 = minf(o1, a1)
		if o0 > cursor:
			_wall_piece(b, axis, coord, cursor, o0, 0.0, H, T, colors, mat, offset)
			if structural:
				_wall_collider(b, axis, coord, cursor, o0, H, T)
		if o.bottom > 0.0:
			_wall_piece(b, axis, coord, o0, o1, 0.0, o.bottom, T, colors, mat, offset)
		if o.top < H:
			_wall_piece(b, axis, coord, o0, o1, o.top, H, T, colors, mat, offset)
		if structural:
			if o.type == "window":
				_wall_collider(b, axis, coord, o0, o1, H, T)
				_window(b, axis, coord, o0, o1, o.bottom, o.top, T, trim)
			elif o.type == "hatch":
				_wall_collider(b, axis, coord, o0, o1, H, T)
				b.box("wood", _p_on(axis, coord, (o0 + o1) * 0.5, o.bottom + 0.03), _sz(axis, o1 - o0 + 0.1, 0.06, T + 0.7), Color("a0663a"))
			else:
				_door(b, axis, coord, o0, o1, o.top, T, o.into, trim)
		cursor = o1
	if cursor < a1:
		_wall_piece(b, axis, coord, cursor, a1, 0.0, H, T, colors, mat, offset)
		if structural:
			_wall_collider(b, axis, coord, cursor, a1, H, T)


func _wall_piece(b: WorldBatcher, axis: String, coord: float, a0: float, a1: float, y0: float, y1: float, T: float, colors: Array, mat: String, offset: float) -> void:
	if a1 - a0 < 0.005 or y1 - y0 < 0.005:
		return
	var bar_h: float = colors[2]
	var spans := []
	if y0 < bar_h and y1 > bar_h:
		spans = [[y0, bar_h, colors[0]], [bar_h, y1, colors[1]]]
	elif y1 <= bar_h:
		spans = [[y0, y1, colors[0]]]
	else:
		spans = [[y0, y1, colors[1]]]
	for sp in spans:
		var h: float = sp[1] - sp[0]
		var yc: float = (sp[0] + sp[1]) * 0.5
		if axis == "h":
			b.box(mat, Vector3((a0 + a1) * 0.5, yc, coord + offset), Vector3(a1 - a0, h, T), sp[2])
		else:
			b.box(mat, Vector3(coord + offset, yc, (a0 + a1) * 0.5), Vector3(T, h, a1 - a0), sp[2])


func _wall_collider(b: WorldBatcher, axis: String, coord: float, a0: float, a1: float, H: float, T: float) -> void:
	if a1 - a0 < 0.01:
		return
	if axis == "h":
		b.collider(Vector3((a0 + a1) * 0.5, H * 0.5, coord), Vector3(a1 - a0, H, T + 0.04))
	else:
		b.collider(Vector3(coord, H * 0.5, (a0 + a1) * 0.5), Vector3(T + 0.04, H, a1 - a0))


func _p_on(axis: String, coord: float, a: float, y: float, n := 0.0) -> Vector3:
	return Vector3(a, y, coord + n) if axis == "h" else Vector3(coord + n, y, a)


func _sz(axis: String, along: float, h: float, across: float) -> Vector3:
	return Vector3(along, h, across) if axis == "h" else Vector3(across, h, along)


func _window(b: WorldBatcher, axis: String, coord: float, o0: float, o1: float, y0: float, y1: float, T: float, trim: Color) -> void:
	var w := o1 - o0
	var c := (o0 + o1) * 0.5
	var frame := trim
	var ft := 0.06
	b.box("metal", _p_on(axis, coord, c, y1 - ft * 0.5), _sz(axis, w, ft, T + 0.04), frame)
	b.box("metal", _p_on(axis, coord, o0 + ft * 0.5, (y0 + y1) * 0.5), _sz(axis, ft, y1 - y0, T + 0.04), frame)
	b.box("metal", _p_on(axis, coord, o1 - ft * 0.5, (y0 + y1) * 0.5), _sz(axis, ft, y1 - y0, T + 0.04), frame)
	# peitoril
	b.box("concrete", _p_on(axis, coord, c, y0 - 0.025), _sz(axis, w + 0.12, 0.05, T + 0.16), Color("d9d4c7"))
	# vidro (basculante) e grade
	b.box("glass", _p_on(axis, coord, c, (y0 + y1) * 0.5), _sz(axis, w - 0.1, y1 - y0 - 0.08, 0.03), Color("9cc3d9"))
	var panes := maxi(int(w / 0.5), 2)
	for i in range(1, panes):
		var a := o0 + w * i / panes
		b.box("metal", _p_on(axis, coord, a, (y0 + y1) * 0.5), _sz(axis, 0.025, y1 - y0, 0.06), frame)
	for k in range(1, 3):
		var y := y0 + (y1 - y0) * k / 3.0
		b.box("metal", _p_on(axis, coord, c, y), _sz(axis, w, 0.025, 0.06), frame)


func _door(b: WorldBatcher, axis: String, coord: float, o0: float, o1: float, h: float, T: float, into: float, trim: Color) -> void:
	var w := o1 - o0
	var c := (o0 + o1) * 0.5
	# batentes
	b.box("wood", _p_on(axis, coord, o0 + 0.03, h * 0.5), _sz(axis, 0.06, h, T + 0.06), Color("7a4b2a"))
	b.box("wood", _p_on(axis, coord, o1 - 0.03, h * 0.5), _sz(axis, 0.06, h, T + 0.06), Color("7a4b2a"))
	b.box("wood", _p_on(axis, coord, c, h - 0.03), _sz(axis, w, 0.06, T + 0.06), Color("7a4b2a"))
	if w > 2.4:
		return
	# folha da porta aberta para dentro do ambiente
	var leaf_w := w - 0.08
	var n := into * (T * 0.5 + leaf_w * 0.5)
	var p := _p_on(axis, coord, o0 + 0.07, h * 0.5 - 0.02, n)
	var size := Vector3(0.045, h - 0.06, leaf_w) if axis == "h" else Vector3(leaf_w, h - 0.06, 0.045)
	b.box("wood", p, size, trim.darkened(0.05))
	var knob := p + (Vector3(0.05, -0.05, into * leaf_w * 0.35) if axis == "h" else Vector3(into * leaf_w * 0.35, -0.05, 0.05))
	b.sphere("metal", knob, 0.03, Color("d4af37"), Vector3.ONE, 6, 4)
	b.collider(p, size)


## Telhado de duas águas com telha colonial. roof: {rect, axis, pitch, overhang, color}
func _roof(id: String, roof: Dictionary, H: float, wall_col: Color) -> void:
	var rb := chunk("roof_" + id)
	roof_chunks[id] = ["roof_" + id]
	var r: Rect2 = roof.rect
	var ov: float = roof.get("overhang", 0.8)
	var pitch := deg_to_rad(roof.get("pitch", 18.0))
	var col: Color = roof.get("color", ROOF_RED)
	var along_x: bool = roof.get("axis", "x") == "x"
	var length: float = (r.size.x if along_x else r.size.y) + ov * 2.0
	var span: float = (r.size.y if along_x else r.size.x)
	var half := span * 0.5 + ov
	var rise := (span * 0.5) * tan(pitch)
	var c := r.get_center()
	if roof.get("single", false):
		# uma água só
		var tot := span + ov * 2.0
		var rise1 := span * tan(pitch)
		var xf := Transform3D(Basis(Vector3.RIGHT if along_x else Vector3.FORWARD, pitch), Vector3(c.x, H + rise1 * 0.5, c.y))
		rb.box_xf("roof", xf, Vector3(length, 0.1, tot / cos(pitch)) if along_x else Vector3(tot / cos(pitch), 0.1, length), col)
		return
	for side: float in [1.0, -1.0]:
		var basis: Basis
		var center: Vector3
		var size: Vector3
		if along_x:
			basis = Basis(Vector3.RIGHT, pitch * side)
			center = Vector3(c.x, H + rise * 0.5 - (ov * 0.5) * tan(pitch), c.y + side * half * 0.5)
			size = Vector3(length, 0.1, half / cos(pitch) + 0.05)
		else:
			basis = Basis(Vector3.FORWARD, pitch * side)
			center = Vector3(c.x + side * half * 0.5, H + rise * 0.5 - (ov * 0.5) * tan(pitch), c.y)
			size = Vector3(half / cos(pitch) + 0.05, 0.1, length)
		rb.box_xf("roof", Transform3D(basis, center), size, col)
	# cumeeira
	if along_x:
		rb.box("roof", Vector3(c.x, H + rise + 0.03, c.y), Vector3(length, 0.14, 0.3), col.darkened(0.15))
	else:
		rb.box("roof", Vector3(c.x, H + rise + 0.03, c.y), Vector3(0.3, 0.14, length), col.darkened(0.15))
	# oitões
	for e: float in [-1.0, 1.0]:
		if along_x:
			var x := c.x + e * r.size.x * 0.5
			rb.triangle("paint", Vector3(x, H, r.position.y), Vector3(x, H, r.end.y), Vector3(x, H + rise, c.y), wall_col)
		else:
			var z := c.y + e * r.size.y * 0.5
			rb.triangle("paint", Vector3(r.position.x, H, z), Vector3(r.end.x, H, z), Vector3(c.x, H + rise, z), wall_col)


# =====================================================================
# Terreno, murada e entorno
# =====================================================================

func _ground() -> void:
	var g := chunk("ground")
	g.cast_shadows = false
	# gramado do terreno inteiro
	g.slab("grass", Vector3(0, -0.05, 0), Vector3(LOT.size.x, 0.1, LOT.size.y), Color("ffffff"))
	# entorno (fora da murada)
	var o := chunk("outside_ground")
	o.cast_shadows = false
	o.slab("grass", Vector3(0, -0.07, 0), Vector3(420, 0.1, 380), Color("d8e8c8"))
	# colisão única do chão
	g.collider(Vector3(0, -0.5 + 0.02, 0), Vector3(440, 1.0, 400))


func _wall_perimeter() -> void:
	var w := chunk("murada_s")
	var wn := chunk("murada_n")
	var we := chunk("murada_e")
	var ww := chunk("murada_w")
	var H := 2.6
	var T := 0.3
	var x0 := LOT.position.x
	var x1 := LOT.end.x
	var z0 := LOT.position.y
	var z1 := LOT.end.y
	# frente (com portão principal e portão de carros)
	_murada_segment(w, "h", z1, x0, -4.5, H, T)
	_murada_segment(w, "h", z1, 4.5, 40.0, H, T)
	_murada_segment(w, "h", z1, 47.0, x1, H, T)
	_murada_segment(wn, "h", z0, x0, x1, H, T)
	_murada_segment(ww, "v", x0, z0, z1, H, T)
	_murada_segment(we, "v", x1, z0, z1, H, T)
	# Portão principal com arco e letreiro
	for sx: float in [-1.0, 1.0]:
		w.box("brick", Vector3(4.7 * sx, 1.9, z1), Vector3(0.6, 3.8, 0.6), Color("c9744d"))
		w.collider(Vector3(4.7 * sx, 1.9, z1), Vector3(0.6, 3.8, 0.6))
		# folhas do portão abertas
		w.box("metal", Vector3(3.6 * sx, 1.1, z1 - 1.1), Vector3(0.05, 2.0, 2.0), Color("2f5fa8"))
		for i in 8:
			w.box("metal", Vector3(3.6 * sx, 1.1, z1 - 0.2 - i * 0.26), Vector3(0.06, 2.0, 0.04), Color("244c88"))
		w.collider(Vector3(3.6 * sx, 1.1, z1 - 1.1), Vector3(0.1, 2.0, 2.0))
	w.box("paint", Vector3(0, 4.2, z1), Vector3(10.0, 0.9, 0.35), Color("2f5fa8"))
	w.box("paint", Vector3(0, 4.2, z1 + 0.19), Vector3(9.6, 0.7, 0.02), Color("f7f3e8"))
	add_label("E. E. RECREIO", Vector3(0, 4.22, z1 + 0.21), 0.0, 96, Color("2f5fa8"), Color(1, 1, 1, 0), 0.006, 90.0)
	add_label("ESCOLA ESTADUAL RECREIO", Vector3(0, 4.22, z1 - 0.19), PI, 64, Color("2f5fa8"), Color(1, 1, 1, 0), 0.006, 60.0)
	w.box("paint", Vector3(0, 4.2, z1 - 0.19), Vector3(9.6, 0.7, 0.02), Color("f7f3e8"))
	# Portão de carros (fechado)
	for i in 14:
		w.box("metal", Vector3(40.25 + i * 0.5, 1.1, z1), Vector3(0.05, 2.1, 0.05), Color("2f5fa8"))
	w.box("metal", Vector3(43.5, 2.1, z1), Vector3(7.0, 0.08, 0.08), Color("2f5fa8"))
	w.box("metal", Vector3(43.5, 0.15, z1), Vector3(7.0, 0.08, 0.08), Color("2f5fa8"))
	w.collider(Vector3(43.5, 1.1, z1), Vector3(7.0, 2.2, 0.2))
	# Murais na murada dos fundos e lateral (pinturas dos alunos)
	_mural(wn, Vector3(-40, 0, z0 + T * 0.5 + 0.02), 0.0, 14.0, "LER É VIAJAR SEM SAIR DO LUGAR", [Color("ff7f50"), Color("f1c40f"), Color("3498db")])
	_mural(wn, Vector3(0, 0, z0 + T * 0.5 + 0.02), 0.0, 12.0, "CUIDE DA NATUREZA", [Color("27ae60"), Color("2ecc71"), Color("f39c12")])
	_mural(wn, Vector3(40, 0, z0 + T * 0.5 + 0.02), 0.0, 14.0, "JUNTOS SOMOS MAIS FORTES", [Color("9b59b6"), Color("e84393"), Color("00b894")])
	_mural(ww, Vector3(x0 + T * 0.5 + 0.02, 0, -20), PI * 0.5, 12.0, "RECREIO É ALEGRIA!", [Color("e74c3c"), Color("f1c40f"), Color("2ecc71")])
	_mural(we, Vector3(x1 - T * 0.5 - 0.02, 0, -50), -PI * 0.5, 12.0, "ESPORTE É SAÚDE", [Color("2980b9"), Color("e67e22"), Color("16a085")])
	for c in [w, wn, we, ww]:
		c.cast_shadows = true


func _murada_segment(b: WorldBatcher, axis: String, coord: float, a0: float, a1: float, H: float, T: float) -> void:
	var len := a1 - a0
	var mid := (a0 + a1) * 0.5
	var bar := Color("3d78c2")
	var top := Color("f4f1ea")
	if axis == "h":
		b.box("paint", Vector3(mid, 0.5, coord), Vector3(len, 1.0, T), bar)
		b.box("paint", Vector3(mid, 1.0 + (H - 1.0) * 0.5, coord), Vector3(len, H - 1.0, T), top)
		b.box("concrete", Vector3(mid, H + 0.04, coord), Vector3(len, 0.08, T + 0.12), Color("d6d0c4"))
		b.collider(Vector3(mid, H * 0.5 + 0.5, coord), Vector3(len, H + 1.0, T + 0.1))
		b.occluder(Vector3(mid, H * 0.5, coord), Vector3(len, H, 0.1))
	else:
		b.box("paint", Vector3(coord, 0.5, mid), Vector3(T, 1.0, len), bar)
		b.box("paint", Vector3(coord, 1.0 + (H - 1.0) * 0.5, mid), Vector3(T, H - 1.0, len), top)
		b.box("concrete", Vector3(coord, H + 0.04, mid), Vector3(T + 0.12, 0.08, len), Color("d6d0c4"))
		b.collider(Vector3(coord, H * 0.5 + 0.5, mid), Vector3(T + 0.1, H + 1.0, len))
		b.occluder(Vector3(coord, H * 0.5, mid), Vector3(0.1, H, len))
	# pilares a cada 5 m
	var a := a0
	while a <= a1 + 0.01:
		var p := Vector3(a, H * 0.5 + 0.05, coord) if axis == "h" else Vector3(coord, H * 0.5 + 0.05, a)
		b.box("paint", p, Vector3(0.45, H + 0.1, 0.45), Color("e9e2d2"))
		a += 5.0


func _mural(b: WorldBatcher, base: Vector3, rot: float, width: float, text: String, cols: Array) -> void:
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, rot)
	b.box("paint", base + Vector3(0, 1.45, 0), (Vector3(width, 1.9, 0.02) if absf(sin(rot)) < 0.5 else Vector3(0.02, 1.9, width)), Color("fdf6e3"))
	# formas coloridas (sol, ondas, flores)
	for i in 7:
		var t := (i + 0.5) / 7.0 - 0.5
		var p := base + right * (t * width * 0.95) + Vector3(0, 1.1 + 0.3 * sin(i * 1.7), 0)
		var normal := Vector3(0, 0, 1).rotated(Vector3.UP, rot)
		b.sphere("plain", p + normal * 0.01, 0.38 + 0.12 * (i % 3), cols[i % cols.size()], Vector3(1, 1, 0.05) if absf(sin(rot)) < 0.5 else Vector3(0.05, 1, 1), 12, 6, false)
	var lp := base + Vector3(0, 2.05, 0) + Vector3(0, 0, 1).rotated(Vector3.UP, rot) * 0.03
	add_label(text, lp, rot, 56, cols[0].darkened(0.3), Color(1, 1, 1, 0.9), 0.006, 60.0)


func _outside() -> void:
	var o := chunk("outside")
	var z1 := LOT.end.y
	# calçada e rua na frente
	o.slab("concrete", Vector3(0, 0.0, z1 + 2.2), Vector3(240, 0.04, 4.0), Color("d3cfc6"))
	o.slab("asphalt", Vector3(0, -0.01, z1 + 9.0), Vector3(240, 0.04, 9.6), Color("6a6d72"))
	for i in 24:
		o.slab("plain", Vector3(-115 + i * 10.0, 0.012, z1 + 9.0), Vector3(4.0, 0.02, 0.18), Color("f2d64b"))
	o.slab("concrete", Vector3(0, 0.0, z1 + 15.8), Vector3(240, 0.04, 4.0), Color("d3cfc6"))
	# casas do outro lado da rua
	var hcols := [Color("f6c3a0"), Color("a8d5e2"), Color("f9e79f"), Color("d7bde2"), Color("abebc6"), Color("f5b7b1"), Color("fad7a0")]
	var x := -110.0
	var i := 0
	while x < 110.0:
		var w := rng.randf_range(7.0, 10.0)
		Props.house(o, Vector3(x + w * 0.5, 0, z1 + 22.0), PI, w - 0.6, 8.0, hcols[i % hcols.size()], ROOF_RED.darkened(rng.randf() * 0.2))
		x += w
		i += 1
	# casas e árvores nas laterais e fundos (silhuetas)
	for side in [-1, 1]:
		var zz := -70.0
		while zz < 70.0:
			Props.house(o, Vector3(side * 101.0, 0, zz), PI * 0.5 * side, 9.0, 8.0, hcols[posmod(i + int(zz), hcols.size())], ROOF_RED.darkened(0.1))
			zz += 13.0
			i += 1
	var xx := -85.0
	while xx < 90.0:
		Props.house(o, Vector3(xx, 0, LOT.position.y - 11.0), 0.0, 9.0, 8.0, hcols[i % hcols.size()], ROOF_RED)
		xx += 12.0
		i += 1
	for k in 30:
		var p := Vector3(rng.randf_range(-120, 120), 0, LOT.position.y - rng.randf_range(20, 40))
		trees.append({"type": ["copa", "pinheiro", "palmeira"][k % 3], "pos": p, "scale": rng.randf_range(1.0, 1.5), "rot": rng.randf() * TAU, "color": Color.WHITE})
	# Postes na calçada
	for k in 10:
		Props.lamp_post(o, Vector3(-90 + k * 20.0, 0, z1 + 4.0))
	add_zone("Rua da Escola", R(-200, z1, 200, z1 + 30), false, "", -10)


# =====================================================================
# Bloco A — prédio principal
# =====================================================================

func _building_a() -> void:
	var cls_inner := [Color("6fae7f"), Color("f3ecd6"), 1.1]
	var cor_inner := [Color("3d78c2"), Color("f4efe1"), 1.1]
	var rooms: Array = []
	var names_back := ["Sala 1", "Sala 2", "Sala 3", "Sala 4", "Sala 5"]
	var names_back_e := ["Sala 6", "Sala 7", "Sala 8", "Sala 9", "Sala 10"]
	var cls_colors := [Color("6fae7f"), Color("e9a35b"), Color("5d9bd5"), Color("d77a8f"), Color("9f86c9"),
		Color("5fb3a3"), Color("e5c15a"), Color("7fa6d9"), Color("e08a6a"), Color("8cc06b")]
	for i in 5:
		var x0 := -60.0 + i * 10.0
		rooms.append({"name": names_back[i], "rect": R(x0, 24, x0 + 10, 34), "kind": "classroom",
			"doors": [["s", x0 + 8.4, 1.1]], "auto_windows": ["n"], "inner": [cls_colors[i], Color("f3ecd6"), 1.1], "grade": i})
		var x1 := 10.0 + i * 10.0
		rooms.append({"name": names_back_e[i], "rect": R(x1, 24, x1 + 10, 34), "kind": "classroom",
			"doors": [["s", x1 + 8.4, 1.1]], "auto_windows": ["n"], "inner": [cls_colors[i + 5], Color("f3ecd6"), 1.1], "grade": i + 5})
	rooms.append({"name": "Biblioteca", "rect": R(-60, 38, -40, 48), "kind": "library", "floor": "wood", "floor_col": Color("d9a066"),
		"doors": [["n", -42.0, 1.6]], "auto_windows": ["s"], "inner": [Color("8a5a32"), Color("f6efdc"), 1.0]})
	rooms.append({"name": "Sala dos Professores", "rect": R(-40, 38, -30, 48), "kind": "teachers",
		"doors": [["n", -32.0, 1.1]], "auto_windows": ["s"], "inner": [Color("b39b72"), Color("f4efe1"), 1.1]})
	rooms.append({"name": "Diretoria", "rect": R(-30, 38, -20, 48), "kind": "director", "floor": "wood", "floor_col": Color("b5794a"),
		"doors": [["n", -22.0, 1.1]], "auto_windows": ["s"], "inner": [Color("7c5a3c"), Color("efe6d2"), 1.1]})
	rooms.append({"name": "Secretaria", "rect": R(-20, 38, -10, 48), "kind": "office",
		"doors": [["n", -12.0, 1.1]], "windows": [["n", -16.5, 2.2]], "auto_windows": ["s"], "inner": [Color("6a8caf"), Color("f4efe1"), 1.1]})
	rooms.append({"name": "Hall de Entrada", "rect": R(-10, 24, 10, 48), "kind": "hall", "always_visible": true,
		"doors": [["s", 0.0, 6.0, 3.0], ["w", 36.0, 4.0, 3.0], ["e", 36.0, 4.0, 3.0]], "open": ["n"],
		"inner": [Color("3d78c2"), Color("f4efe1"), 1.1], "floor_col": Color("e6dfd0")})
	rooms.append({"name": "Sala de Informática", "rect": R(10, 38, 22, 48), "kind": "computer",
		"doors": [["n", 20.0, 1.1]], "auto_windows": ["s"], "inner": [Color("4a6fa5"), Color("eef1f4"), 1.1]})
	rooms.append({"name": "Sala de Artes", "rect": R(22, 38, 34, 48), "kind": "art",
		"doors": [["n", 32.0, 1.1]], "auto_windows": ["s"], "inner": [Color("e67e22"), Color("fdf2e0"), 1.1]})
	rooms.append({"name": "Banheiro Feminino", "rect": R(34, 38, 42, 48), "kind": "bathroom_f",
		"doors": [["n", 40.5, 1.2]], "windows": [["s", 38.0, 2.5]], "inner": [Color("f5b7c5"), Color("fdf0f3"), 1.8], "inner_mat": "tile"})
	rooms.append({"name": "Banheiro Masculino", "rect": R(42, 38, 50, 48), "kind": "bathroom_m",
		"doors": [["n", 48.5, 1.2]], "windows": [["s", 46.0, 2.5]], "inner": [Color("8fc1e3"), Color("eef6fb"), 1.8], "inner_mat": "tile"})
	rooms.append({"name": "Depósito de Ed. Física", "rect": R(50, 38, 60, 48), "kind": "storage",
		"doors": [["n", 52.0, 1.4]], "auto_windows": ["s"], "inner": [Color("7f8c8d"), Color("ecf0f1"), 1.1]})
	rooms.append({"name": "Corredor Oeste", "rect": R(-60, 34, -10, 38), "kind": "corridor", "always_visible": true,
		"open": ["w"], "inner": cor_inner, "label": "Corredor"})
	rooms.append({"name": "Corredor Leste", "rect": R(10, 34, 60, 38), "kind": "corridor", "always_visible": true,
		"open": ["e"], "inner": cor_inner, "label": "Corredor"})
	build_building({"id": "A", "title": "Bloco A", "height": 3.6, "wall": CREAM, "bar": BLUE_BAR, "bar_h": 1.1,
		"trim": Color("f4f4f4"), "rooms": rooms,
		"roof": {"rect": R(-60, 24, 60, 48), "axis": "x", "pitch": 16.0, "overhang": 0.9}})
	add_label("BLOCO A", Vector3(0, 3.3, 48.2), 0.0, 72, Color("2f5fa8"), Color(1, 1, 1, 0.9), 0.008, 80.0)


# =====================================================================
# Bloco B — salas extras com corredor avarandado
# =====================================================================

func _building_b() -> void:
	var rooms := [
		{"name": "Laboratório de Ciências", "rect": R(70, -28, 82, -16), "kind": "lab",
			"doors": [["w", -18.0, 1.2]], "auto_windows": ["e"], "inner": [Color("4aa3a2"), Color("eef7f6"), 1.1]},
		{"name": "Sala 11", "rect": R(70, -16, 82, -4), "kind": "classroom", "grade": 10,
			"doors": [["w", -6.0, 1.1]], "auto_windows": ["e"], "inner": [Color("e9a35b"), Color("f3ecd6"), 1.1]},
		{"name": "Sala 12", "rect": R(70, -4, 82, 8), "kind": "classroom", "grade": 11,
			"doors": [["w", 6.0, 1.1]], "auto_windows": ["e"], "inner": [Color("5d9bd5"), Color("f3ecd6"), 1.1]},
		{"name": "Sala de Música", "rect": R(70, 8, 82, 20), "kind": "music",
			"doors": [["w", 18.0, 1.2]], "auto_windows": ["e"], "inner": [Color("8e44ad"), Color("f6eefa"), 1.1]},
		{"name": "Varanda do Bloco B", "rect": R(66, -28, 70, 20), "kind": "corridor", "always_visible": true,
			"open": ["w", "n", "s"], "colonnade": ["w"], "inner": [GREEN_BAR, Color("f4efe1"), 1.1], "label": "Bloco B"},
	]
	build_building({"id": "B", "title": "Bloco B", "height": 3.5, "wall": Color("f6eccf"), "bar": GREEN_BAR, "bar_h": 1.1,
		"trim": Color("f4f4f4"), "rooms": rooms,
		"roof": {"rect": R(66, -28, 82, 20), "axis": "z", "pitch": 18.0, "overhang": 0.9}})
	add_label("BLOCO B", Vector3(65.7, 3.2, -4), -PI * 0.5, 64, GREEN_BAR.darkened(0.3), Color(1, 1, 1, 0.9), 0.008, 70.0)


func _cantina() -> void:
	var rooms := [
		{"name": "Cantina", "rect": R(-36, 4, -22, 20), "kind": "cantina", "always_visible": true, "floor_col": Color("e8d9c0"),
			"doors": [["s", -33.0, 1.2]], "hatches": [["e", 12.0, 6.0]], "inner": [Color("e74c3c"), Color("fff3dc"), 1.4], "inner_mat": "tile",
			"counter": true},
	]
	build_building({"id": "C", "title": "Cantina", "height": 3.4, "wall": Color("f7d774"), "bar": Color("d6453a"), "bar_h": 1.0,
		"trim": Color("ffffff"), "rooms": rooms,
		"roof": {"rect": R(-36, 4, -22, 20), "axis": "z", "pitch": 16.0, "overhang": 0.7}})


# =====================================================================
# Áreas externas
# =====================================================================

func _paved(b: WorldBatcher, r: Rect2, mat: String, col: Color, y := 0.012) -> void:
	b.slab(mat, Vector3(r.get_center().x, y - 0.03, r.get_center().y), Vector3(r.size.x, 0.06, r.size.y), col)
	add_surface(r, "dirt" if mat == "dirt" else ("hard" if mat != "grass" else "grass"))


func _tree(type: String, pos: Vector3, scale := 1.0, col := Color.WHITE, b: WorldBatcher = null) -> void:
	trees.append({"type": type, "pos": pos, "scale": scale, "rot": rng.randf() * TAU, "color": col})
	var tr := TreeFactory.trunk_radius(type) * scale
	if tr > 0.0 and b != null:
		b.collider_cyl(pos + Vector3(0, 1.5, 0), tr, 3.0)


func _front_yard() -> void:
	var f := chunk("front")
	_paved(f, R(-4, 48, 4, 75), "concrete", Color("d8d2c4"))
	_paved(f, R(-14, 50, 14, 60), "concrete", Color("d2c7b5"))
	# pisos de pedra portuguesa (faixas) no caminho
	for i in 12:
		f.slab("plain", Vector3(0, 0.018, 61.5 + i * 1.1), Vector3(7.6, 0.02, 0.18), Color("8c8273"))
	Props.flagpole(f, Vector3(-8, 0.012, 52), Color("2e9e4f"))
	Props.flagpole(f, Vector3(-11, 0.012, 52), Color("2f5fa8"))
	Props.flagpole(f, Vector3(-5, 0.012, 52), Color("f1c40f"))
	var fr := RandomNumberGenerator.new()
	fr.seed = 99
	for sx: float in [-1.0, 1.0]:
		Props.planter(f, Vector3(sx * 9.0, 0.012, 57), Vector2(5.0, 2.4), fr)
		for k in 5:
			_tree("palmeira", Vector3(sx * 5.5, 0.0, 63 + k * 2.6), 0.8 + 0.05 * k, Color.WHITE, f)
		Props.bench(f, Vector3(sx * 12.5, 0.012, 54.5), PI * 0.5 * -sx)
		Props.lamp_post(f, Vector3(sx * 4.6, 0.012, 58))
		Props.lamp_post(f, Vector3(sx * 4.6, 0.012, 70))
	for k in 10:
		var x := -80.0 + k * 11.0
		if absf(x) < 18.0:
			continue
		_tree("ipe", Vector3(x, 0, rng.randf_range(62, 70)), rng.randf_range(0.9, 1.2), [Color("f2c230"), Color("e86aa6"), Color("f2c230")][k % 3], f)
	for k in 8:
		_tree("arbusto", Vector3(rng.randf_range(-28, -16), 0, rng.randf_range(50, 72)), rng.randf_range(0.8, 1.3), Color.WHITE)
	# placa de boas-vindas
	f.box("wood", Vector3(10, 1.0, 64), Vector3(0.12, 2.0, 0.12), Color("7a4b2a"))
	f.box("wood", Vector3(13, 1.0, 64), Vector3(0.12, 2.0, 0.12), Color("7a4b2a"))
	f.box("paint", Vector3(11.5, 1.7, 64), Vector3(3.4, 1.0, 0.08), Color("2f5fa8"))
	add_label("Bem-vindos!\nBoa aula a todos", Vector3(11.5, 1.7, 64.05), 0.0, 48, Color.WHITE, Color(0, 0, 0, 0), 0.006, 40.0)
	f.collider(Vector3(11.5, 1.0, 64), Vector3(3.4, 2.0, 0.2))
	add_zone("Entrada da Escola", R(-30, 48, 30, 75), false, "", 2, Color(0.82, 0.8, 0.74))


func _parking() -> void:
	var p := chunk("parking")
	var r := R(30, 52, 86, 73)
	_paved(p, r, "asphalt", Color("7a7d82"))
	for i in 11:
		p.slab("plain", Vector3(33 + i * 5.0, 0.016, 56), Vector3(0.12, 0.02, 5.0), Color("f2f2f2"))
	var car_cols := [Color("c0392b"), Color("ecf0f1"), Color("2c3e50"), Color("f1c40f")]
	var slots := [0, 2, 3, 6, 8]
	for i in slots.size():
		Props.parked_car(p, Vector3(35.5 + slots[i] * 5.0, 0.012, 56), PI, car_cols[i % car_cols.size()])
	for k in 6:
		_tree("copa", Vector3(34 + k * 9.5, 0, 70.5), rng.randf_range(0.8, 1.0), Color.WHITE, p)
	add_zone("Estacionamento", r, false, "", 2, Color(0.6, 0.6, 0.62))


func _covered_patio() -> void:
	var c := chunk("patio_coberto")
	var r := R(-22, 4, 22, 20)
	_paved(c, r, "redfloor", RED_FLOOR, 0.016)
	# pilares e cobertura (telhado metálico, escondido quando o jogador está embaixo)
	var x := r.position.x
	while x <= r.end.x + 0.01:
		for z: float in [r.position.y, r.end.y]:
			c.box("paint", Vector3(x, 2.3, z), Vector3(0.35, 4.6, 0.35), CREAM)
			c.box("paint", Vector3(x, 0.55, z), Vector3(0.39, 1.1, 0.39), BLUE_BAR)
			c.collider(Vector3(x, 2.3, z), Vector3(0.35, 4.6, 0.35))
		x += 5.5
	var rc := chunk("roof_P")
	roof_chunks["P"] = ["roof_P"]
	rc.box("metal", Vector3(0, 4.75, 12), Vector3(46, 0.12, 18.5), Color("b9c2c9"))
	for k in 12:
		rc.box("metal", Vector3(-22.5 + k * 4.0, 4.66, 12), Vector3(0.12, 0.2, 18.5), Color("8e9aa4"))
	rc.box("paint", Vector3(0, 4.55, 3.85), Vector3(46, 0.4, 0.2), CREAM)
	rc.box("paint", Vector3(0, 4.55, 20.15), Vector3(46, 0.4, 0.2), CREAM)
	# mesas do refeitório
	for i in 4:
		for j in 2:
			Props.cafeteria_table(c, Vector3(-17 + i * 7.0, 0.016, 8.5 + j * 6.0), 0.0, 3.6, [Color("f0e6d2"), Color("dfeaf2")][j])
	# palco com rampa
	var stage := R(14, 6, 21.5, 18)
	c.box("wood", Vector3(stage.get_center().x, 0.3, stage.get_center().y), Vector3(stage.size.x, 0.6, stage.size.y), Color("a0663a"))
	c.collider(Vector3(stage.get_center().x, 0.3, stage.get_center().y), Vector3(stage.size.x, 0.6, stage.size.y))
	var ramp_ang := atan2(0.6, 3.0)
	var ramp_xf := Transform3D(Basis(Vector3.BACK, ramp_ang), Vector3(12.5, 0.3, 12))
	c.box_xf("wood", ramp_xf, Vector3(3.06, 0.08, 3.0), Color("8a5a32"))
	c.collider_xf(ramp_xf, Vector3(3.06, 0.08, 3.0))
	c.box("plain", Vector3(21.3, 2.2, 12), Vector3(0.1, 3.2, 11.0), Color("8e2a3a"))
	c.box("paint", Vector3(21.2, 3.9, 12), Vector3(0.12, 0.6, 9.0), Color("f1c40f"))
	add_label("FESTA JUNINA DIA 24!", Vector3(21.1, 3.9, 12), -PI * 0.5, 56, Color("8e2a3a"), Color(1, 1, 1, 0), 0.006, 40.0)
	# bandeirinhas de festa junina penduradas
	var flag_cols := [Color("e74c3c"), Color("f1c40f"), Color("3498db"), Color("2ecc71"), Color("e84393"), Color("ff7f50")]
	for row in 3:
		var z := 7.0 + row * 5.0
		for k in 40:
			var fx := -21.0 + k * 1.07
			var sag := 4.2 - 0.35 * sin(PI * k / 39.0)
			var xf := Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3(fx, sag, z))
			c.box_xf("plain", xf, Vector3(0.35, 0.4, 0.01), flag_cols[(k + row) % flag_cols.size()], false)
	add_zone("Pátio Coberto", r, false, "P", 6, Color(0.75, 0.42, 0.35))
	map_shapes.append({"rect": r, "color": Color(0.72, 0.4, 0.33), "label": "Refeitório"})
	# pias coletivas e bebedouros
	var s := chunk("pias")
	var sr := R(24, 7, 32, 17)
	_paved(s, sr, "tile", Color("e5edf2"), 0.016)
	s.box("tile", Vector3(32.2, 1.0, 12), Vector3(0.3, 2.0, 10), Color("7fb3d5"))
	s.collider(Vector3(32.2, 1.0, 12), Vector3(0.3, 2.0, 10))
	for k in 5:
		var z := 8.2 + k * 1.9
		s.box("tile", Vector3(31.65, 0.85, z), Vector3(0.8, 0.12, 1.4), Color("f4f6f7"))
		s.box("tile", Vector3(31.65, 0.42, z), Vector3(0.7, 0.84, 0.15), Color("dfe6e9"))
		s.cylinder("metal", Vector3(31.85, 1.05, z), 0.02, 0.02, 0.25, Color("b0b8bf"), 6)
		s.box("glass", Vector3(32.03, 1.55, z), Vector3(0.03, 0.6, 1.0), Color("cfe3ee"))
	for k in 3:
		Props.water_fountain(s, Vector3(25.5 + k * 2.4, 0.016, 7.4), 0.0)
	add_zone("Pias e Bebedouros", sr, false, "", 7, Color(0.7, 0.82, 0.9))


func _open_patio() -> void:
	var p := chunk("patio")
	var main := R(-62, -26, 62, 24)
	_paved(p, main, "concrete", CONCRETE, 0.01)
	var fr := RandomNumberGenerator.new()
	fr.seed = 4
	# Árvore central com banco circular
	_tree("copa", Vector3(0, 0, -10), 1.6, Color("4f9a45"), p)
	for i in 10:
		var a := i * TAU / 10.0
		var bp := Vector3(sin(a) * 3.1, 0.01, -10 + cos(a) * 3.1)
		Props.bench(p, bp, a, 1.85, false)
	p.cylinder("concrete", Vector3(0, 0.15, -10), 1.6, 1.7, 0.3, Color("c9bfa8"), 16)
	# canteiros com árvores
	for pos: Vector3 in [Vector3(-30, 0.01, -5), Vector3(30, 0.01, -5), Vector3(-30, 0.01, -18), Vector3(-48, 0.01, -20), Vector3(48, 0.01, 0)]:
		Props.planter(p, pos, Vector2(3.4, 3.4), fr)
		_tree(["ipe", "copa"][int(absf(pos.x)) % 2], pos + Vector3(0, 0.3, 0), 1.0, [Color("f2c230"), Color("3f8a3a")][int(absf(pos.z)) % 2], p)
		Props.bench(p, pos + Vector3(0, 0, 2.6), 0.0)
		Props.bench(p, pos + Vector3(0, 0, -2.6), PI)
	# Amarelinha pintada no chão
	var hop := Vector3(-14, 0.016, -2)
	var cells := [[0, 0], [0, 1], [-0.5, 2], [0.5, 2], [0, 3], [-0.5, 4], [0.5, 4], [0, 5]]
	for i in cells.size():
		var cp := hop + Vector3(cells[i][0] * 1.0, 0, -cells[i][1] * 0.95)
		p.slab("plain", cp, Vector3(0.95, 0.008, 0.9), [Color("f6e05e"), Color("63b3ed"), Color("f687b3"), Color("68d391")][i % 4])
		add_label(str(i + 1), cp + Vector3(0, 0.01, 0), 0.0, 96, Color.WHITE, Color(0, 0, 0, 0.4), 0.004, 25.0)
	p.slab("plain", hop + Vector3(0, 0, -6.2), Vector3(1.9, 0.008, 1.2), Color("fc8181"))
	add_label("CÉU", hop + Vector3(0, 0.012, -6.2), 0.0, 96, Color.WHITE, Color(0, 0, 0, 0.4), 0.004, 25.0)
	# Círculo da bolinha de gude (terrinha)
	var gude := Vector3(-46, 0.0, -9)
	p.cylinder("dirt", gude + Vector3(0, 0.005, 0), 3.4, 3.4, 0.03, Color("b08a5a"), 20, false)
	for i in 24:
		var a := i * TAU / 24.0
		p.box("plain", gude + Vector3(cos(a) * 1.2, 0.025, sin(a) * 1.2), Vector3(0.35, 0.01, 0.06), Color("f2efe6"), -a + PI * 0.5, false)
	add_surface(R(gude.x - 3.4, gude.z - 3.4, gude.x + 3.4, gude.z + 3.4), "dirt")
	add_zone("Cantinho da Bolinha de Gude", R(-50, -13, -42, -5), false, "", 8, Color(0.69, 0.54, 0.35))
	# Espaço de convivência (mesas com guarda-sol)
	var conv := R(34, -22, 58, -4)
	_paved(p, conv, "tile", Color("e9dcc5"), 0.014)
	var umb := [Color("e74c3c"), Color("f1c40f"), Color("3498db"), Color("2ecc71"), Color("e84393"), Color("ff7f50")]
	for i in 3:
		for j in 2:
			Props.umbrella_table(p, Vector3(38 + i * 7.5, 0.014, -17 + j * 8.0), umb[i * 2 + j])
	add_zone("Espaço de Convivência", conv, false, "", 7, Color(0.9, 0.85, 0.75))
	# Lixeiras de coleta seletiva, postes e bebedouros
	Props.trash_bins(p, Vector3(-24, 0.01, 22.5), PI)
	Props.trash_bins(p, Vector3(24, 0.01, -24), 0.0)
	Props.trash_bins(p, Vector3(-58, 0.01, 0), PI * 0.5)
	for x: float in [-50.0, -25.0, 25.0, 50.0]:
		for z: float in [-22.0, 2.0]:
			Props.lamp_post(p, Vector3(x, 0.01, z))
	Props.water_fountain(p, Vector3(-60.5, 0.01, -14), PI * 0.5)
	Props.water_fountain(p, Vector3(-60.5, 0.01, -12), PI * 0.5)
	# Bancos ao redor
	for x: float in [-56.0, -40.0, 12.0, 20.0]:
		Props.bench(p, Vector3(x, 0.01, -24.6), 0.0)
	# Faixa "pista" de corrida pintada no pátio
	for i in 22:
		p.slab("plain", Vector3(-40 + i * 3.6, 0.014, -24.0 + 2.0), Vector3(1.8, 0.008, 0.12), Color("ffffff"))
	add_label("LARGADA", Vector3(-42, 0.02, -22), -PI * 0.5, 80, Color("f2f2f2"), Color(0, 0, 0, 0.3), 0.005, 25.0)
	add_zone("Pátio Central", main, false, "", 1, Color(0.84, 0.82, 0.78))


func _sports_court() -> void:
	var q := chunk("quadra")
	var surf := R(15, -67, 65, -30.8)
	_paved(q, surf, "concrete", Color("8d9da6"), 0.012)
	var court := R(20, -59, 60, -39)
	q.slab("concrete", Vector3(court.get_center().x, 0.014 - 0.03, court.get_center().y), Vector3(court.size.x, 0.06, court.size.y), Color("2f8f6f"))
	var lc := Color("f7f7f2")
	var lw := 0.08
	var ly := 0.018
	# linhas
	q.slab("plain", Vector3(40, ly, court.position.y), Vector3(court.size.x, 0.01, lw), lc)
	q.slab("plain", Vector3(40, ly, court.end.y), Vector3(court.size.x, 0.01, lw), lc)
	q.slab("plain", Vector3(court.position.x, ly, -49), Vector3(lw, 0.01, court.size.y), lc)
	q.slab("plain", Vector3(court.end.x, ly, -49), Vector3(lw, 0.01, court.size.y), lc)
	q.slab("plain", Vector3(40, ly, -49), Vector3(lw, 0.01, court.size.y), lc)
	for i in 36:
		var a := i * TAU / 36.0
		q.box("plain", Vector3(40 + cos(a) * 3.0, ly, -49 + sin(a) * 3.0), Vector3(0.55, 0.01, lw), lc, -a + PI * 0.5, false)
	q.cylinder("plain", Vector3(40, ly, -49), 0.15, 0.15, 0.01, lc, 10, false)
	# áreas do gol (semicírculos)
	for side: float in [-1.0, 1.0]:
		var gx := 40 + side * 20.0
		for i in 19:
			var a := -PI * 0.5 + i * PI / 18.0
			var p := Vector3(gx - side * cos(a) * 6.0, ly, -49 + sin(a) * 6.0)
			q.box("plain", p, Vector3(0.36, 0.01, lw), lc, -a * side + PI * 0.5, false)
		_goal(q, Vector3(gx, 0.012, -49), side)
		# tabela de basquete atrás do gol
		var bx := gx + side * 1.6
		q.cylinder("metal", Vector3(bx, 1.6, -49), 0.07, 0.07, 3.2, Color("4a5560"), 8)
		q.box("paint", Vector3(bx - side * 0.35, 3.2, -49), Vector3(0.06, 1.0, 1.6), Color("f4f4f4"))
		q.box("paint", Vector3(bx - side * 0.34, 3.1, -49), Vector3(0.07, 0.4, 0.55), Color("e74c3c"))
		q.cylinder("metal", Vector3(bx - side * 0.62, 2.95, -49), 0.23, 0.23, 0.03, Color("e67e22"), 12)
		q.collider_cyl(Vector3(bx, 1.6, -49), 0.1, 3.2)
	# arquibancada (degraus de 45 cm para sentar)
	for step in 4:
		var z := -34.6 + step * 0.9
		var h := 0.45 * (step + 1)
		q.box("concrete", Vector3(40, h * 0.5, z), Vector3(36, h, 0.9), Color("c5c0b5").darkened(step * 0.04))
		q.box("paint", Vector3(40, h - 0.02, z + 0.3), Vector3(36, 0.04, 0.3), [Color("2f5fa8"), Color("f1c40f")][step % 2])
		q.collider(Vector3(40, h * 0.5, z), Vector3(36, h, 0.9))
		for k in 10:
			Props.add_seat(Vector3(24 + k * 3.6, 0, z + 0.05), PI, Vector3.ZERO, h, "Sentar na arquibancada")
	# alambrado
	var fh := 4.0
	_fence(q, "h", surf.position.y, surf.position.x, surf.end.x, fh)
	_fence(q, "v", surf.position.x, surf.position.y, -52.0, fh)
	_fence(q, "v", surf.position.x, -48.0, surf.end.y, fh)
	_fence(q, "v", surf.end.x, surf.position.y, -52.0, fh)
	_fence(q, "v", surf.end.x, -48.0, surf.end.y, fh)
	_fence(q, "h", surf.end.y, 21.5, 58.5, fh)
	# refletores
	for pos: Vector3 in [Vector3(15.5, 0, -67), Vector3(64.5, 0, -67), Vector3(15.5, 0, -31.5), Vector3(64.5, 0, -31.5)]:
		q.cylinder("metal", pos + Vector3(0, 4.5, 0), 0.08, 0.13, 9.0, Color("5d6d7e"), 8)
		q.box("metal", pos + Vector3(0, 9.0, 0), Vector3(1.2, 0.5, 0.3), Color("34495e"))
		q.box("plain", pos + Vector3(0, 9.0, 0.16 * signf(-49.0 - pos.z)), Vector3(1.0, 0.35, 0.02), Color("fffbe0"))
	add_label("QUADRA POLIESPORTIVA", Vector3(40, 3.2, -30.75), 0.0, 72, Color("2f5fa8"), Color(1, 1, 1, 0.95), 0.007, 70.0)
	balls.append({"kind": "football", "pos": Vector3(40, 0.4, -49)})
	balls.append({"kind": "basketball", "pos": Vector3(23.5, 0.4, -45)})
	add_zone("Quadra Poliesportiva", R(15, -67, 65, -30.8), false, "", 5, Color(0.25, 0.6, 0.5))
	map_shapes.append({"rect": court, "color": Color(0.2, 0.56, 0.44), "label": "Quadra"})


func _goal(b: WorldBatcher, c: Vector3, side: float) -> void:
	var w := 3.0
	var h := 2.0
	var d := 1.0
	var col := Color("f4f4f4")
	for sz: float in [-1.0, 1.0]:
		b.box("metal", c + Vector3(0, h * 0.5, sz * w * 0.5), Vector3(0.08, h, 0.08), col)
		b.box("metal", c + Vector3(side * d * 0.5, 0.04, sz * w * 0.5), Vector3(d, 0.06, 0.06), col)
		b.collider(c + Vector3(0, h * 0.5, sz * w * 0.5), Vector3(0.1, h, 0.1))
		b.box("fence", c + Vector3(side * d * 0.5, h * 0.5, sz * w * 0.5), Vector3(d, h, 0.02), Color.WHITE, 0.0, false)
	b.box("metal", c + Vector3(0, h, 0), Vector3(0.08, 0.08, w + 0.08), col)
	b.box("fence", c + Vector3(side * d, h * 0.5, 0), Vector3(0.02, h, w), Color.WHITE, 0.0, false)
	b.box("fence", c + Vector3(side * d * 0.5, h, 0), Vector3(d, 0.02, w), Color.WHITE, 0.0, false)
	# rede do fundo bloqueia a bola
	b.collider(c + Vector3(side * d, h * 0.5, 0), Vector3(0.05, h, w))
	b.collider(c + Vector3(side * d * 0.5, h, 0), Vector3(d, 0.05, w))
	for sz: float in [-1.0, 1.0]:
		b.collider(c + Vector3(side * d * 0.5, h * 0.5, sz * w * 0.5), Vector3(d, h, 0.05))


func _fence(b: WorldBatcher, axis: String, coord: float, a0: float, a1: float, h: float) -> void:
	var len := a1 - a0
	var mid := (a0 + a1) * 0.5
	if axis == "h":
		b.box("fence", Vector3(mid, h * 0.5, coord), Vector3(len, h, 0.02), Color("e6e6e6"), 0.0, false)
		b.collider(Vector3(mid, h * 0.5, coord), Vector3(len, h, 0.1))
	else:
		b.box("fence", Vector3(coord, h * 0.5, mid), Vector3(0.02, h, len), Color("e6e6e6"), 0.0, false)
		b.collider(Vector3(coord, h * 0.5, mid), Vector3(0.1, h, len))
	var a := a0
	while a <= a1 + 0.01:
		var p := Vector3(a, h * 0.5, coord) if axis == "h" else Vector3(coord, h * 0.5, a)
		b.cylinder("metal", p, 0.04, 0.04, h, Color("5d6d7e"), 6)
		a += 3.0
	var top := Vector3(mid, h, coord) if axis == "h" else Vector3(coord, h, mid)
	b.box("metal", top, Vector3(len, 0.05, 0.05) if axis == "h" else Vector3(0.05, 0.05, len), Color("5d6d7e"))


func _dodgeball_area() -> void:
	var d := chunk("queimada")
	var area := R(-56, -62, -24, -38)
	_paved(d, area, "dirt", Color("d9b98a"), 0.012)
	var court := R(-52, -56, -28, -44)
	var lc := Color("fbfbf5")
	var ly := 0.017
	d.slab("plain", Vector3(court.get_center().x, ly, court.position.y), Vector3(court.size.x, 0.01, 0.1), lc)
	d.slab("plain", Vector3(court.get_center().x, ly, court.end.y), Vector3(court.size.x, 0.01, 0.1), lc)
	for x: float in [court.position.x, court.position.x + 3.0, court.get_center().x, court.end.x - 3.0, court.end.x]:
		d.slab("plain", Vector3(x, ly, court.get_center().y), Vector3(0.1, 0.01, court.size.y), lc)
	add_label("CEMITÉRIO", Vector3(court.position.x + 1.5, 0.03, -50), PI * 0.5, 64, Color("ffffff"), Color(0, 0, 0, 0.3), 0.005, 25.0)
	add_label("CEMITÉRIO", Vector3(court.end.x - 1.5, 0.03, -50), -PI * 0.5, 64, Color("ffffff"), Color(0, 0, 0, 0.3), 0.005, 25.0)
	for x: float in [-50.0, -44.0, -38.0, -32.0]:
		Props.bench(d, Vector3(x, 0.012, -40.5), PI, 2.2)
		Props.bench(d, Vector3(x, 0.012, -59.5), 0.0, 2.2)
	for k in 4:
		_tree("copa", Vector3(-58.5, 0, -60 + k * 6.5), rng.randf_range(0.9, 1.15), Color.WHITE, d)
	balls.append({"kind": "dodgeball", "pos": Vector3(-40, 0.4, -50)})
	balls.append({"kind": "dodgeball", "pos": Vector3(-36, 0.4, -47)})
	add_zone("Campo de Queimada", area, false, "", 5, Color(0.85, 0.72, 0.52))


func _playground() -> void:
	var g := chunk("parquinho")
	var area := R(-88, -72, -62, -46)
	_paved(g, area, "dirt", Color("ecd9a8"), 0.012)
	add_surface(area, "dirt")
	var c := area.get_center()
	# borda de madeira
	for s: float in [-1.0, 1.0]:
		g.box("wood", Vector3(c.x, 0.12, c.y + s * area.size.y * 0.5), Vector3(area.size.x, 0.24, 0.2), Color("a0663a"))
		g.box("wood", Vector3(c.x + s * area.size.x * 0.5, 0.12, c.y), Vector3(0.2, 0.24, area.size.y), Color("a0663a"))
	# Escorregador
	var sp := Vector3(-82, 0.012, -66)
	for sx: float in [-0.45, 0.45]:
		for sz: float in [-0.45, 0.45]:
			g.box("metal", sp + Vector3(sx, 1.1, sz), Vector3(0.08, 2.2, 0.08), Color("e74c3c"))
	g.box("wood", sp + Vector3(0, 2.0, 0), Vector3(1.0, 0.08, 1.0), Color("f1c40f"))
	g.box("metal", sp + Vector3(0, 2.6, 0), Vector3(1.0, 0.06, 0.06), Color("e74c3c"))
	var sl := Transform3D(Basis(Vector3.RIGHT, 0.62), sp + Vector3(0, 1.05, 2.15))
	g.box_xf("metal", sl, Vector3(0.7, 0.06, 3.5), Color("3498db"))
	for i in 6:
		g.box("metal", sp + Vector3(0, 0.3 + i * 0.32, -0.75), Vector3(0.9, 0.05, 0.08), Color("e74c3c"))
	g.collider(sp + Vector3(0, 1.1, 0), Vector3(1.0, 2.2, 1.0))
	# Balanços
	var bp := Vector3(-72, 0.012, -66)
	for sx: float in [-2.2, 2.2]:
		var leg := Transform3D(Basis(Vector3.FORWARD, 0.25 * signf(sx)), bp + Vector3(sx, 1.25, 0))
		g.box_xf("metal", leg, Vector3(0.1, 2.6, 0.1), Color("2ecc71"))
		g.collider_xf(leg, Vector3(0.12, 2.6, 0.12))
	g.box("metal", bp + Vector3(0, 2.5, 0), Vector3(4.9, 0.1, 0.1), Color("27ae60"))
	for k in 3:
		var x := -1.4 + k * 1.4
		g.box("metal", bp + Vector3(x - 0.22, 1.5, 0), Vector3(0.02, 2.0, 0.02), Color("95a5a6"))
		g.box("metal", bp + Vector3(x + 0.22, 1.5, 0), Vector3(0.02, 2.0, 0.02), Color("95a5a6"))
		g.box("wood", bp + Vector3(x, 0.47, 0), Vector3(0.55, 0.05, 0.25), [Color("e74c3c"), Color("f1c40f"), Color("3498db")][k])
		Props.add_seat(bp + Vector3(x, 0, 0), 0.0, Vector3.ZERO, bp.y + 0.49, "Balançar")
	# Gangorra
	var gp := Vector3(-82, 0.012, -54)
	g.box("metal", gp + Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.3), Color("9b59b6"))
	var plank := Transform3D(Basis(Vector3.RIGHT, 0.18), gp + Vector3(0, 0.5, 0))
	g.box_xf("wood", plank, Vector3(0.3, 0.06, 3.6), Color("f39c12"))
	g.collider(gp + Vector3(0, 0.4, 0), Vector3(0.4, 0.8, 3.6))
	# Trepa-trepa (domo de barras)
	var tp := Vector3(-70, 0.012, -53)
	for i in 8:
		var a := i * TAU / 8.0
		for j in 4:
			var h := 0.3 + j * 0.45
			var r := 1.5 * cos(asin(clampf(h / 1.9, 0.0, 1.0)))
			g.box("metal", tp + Vector3(cos(a) * r, h, sin(a) * r), Vector3(1.2 * r / 1.5, 0.05, 0.05), Color("e67e22"), -a + PI * 0.5)
		g.box("metal", tp + Vector3(cos(a) * 1.0, 0.9, sin(a) * 1.0), Vector3(0.05, 1.8, 0.05), Color("d35400"))
	g.collider_cyl(tp + Vector3(0, 0.9, 0), 1.5, 1.8)
	# Gira-gira
	var gg := Vector3(-76, 0.012, -51)
	g.cylinder("metal", gg + Vector3(0, 0.3, 0), 1.3, 1.3, 0.08, Color("e84393"), 18)
	g.cylinder("metal", gg + Vector3(0, 0.6, 0), 0.06, 0.06, 0.9, Color("bdc3c7"), 6)
	for i in 4:
		var a := i * TAU / 4.0
		g.box("metal", gg + Vector3(cos(a) * 0.6, 0.9, sin(a) * 0.6), Vector3(1.2, 0.04, 0.04), Color("bdc3c7"), -a)
	g.collider_cyl(gg + Vector3(0, 0.3, 0), 1.3, 0.6)
	for k in 5:
		_tree("copa", Vector3(-87, 0, -72 + k * 6.0), rng.randf_range(0.9, 1.2), Color.WHITE, g)
	Props.bench(g, Vector3(-64, 0.012, -60), -PI * 0.5)
	Props.bench(g, Vector3(-64, 0.012, -52), -PI * 0.5)
	add_zone("Parquinho", area, false, "", 5, Color(0.93, 0.85, 0.6))


func _garden_and_woods() -> void:
	# Horta
	var h := chunk("horta")
	var area := R(-14, -72, 8, -58)
	_paved(h, area, "dirt", Color("c9a77a"), 0.012)
	var fr := RandomNumberGenerator.new()
	fr.seed = 21
	for i in 4:
		var bed := Vector3(-10 + i * 5.2, 0.012, -66)
		h.box("wood", bed + Vector3(0, 0.2, 0), Vector3(3.6, 0.4, 8.0), Color("8a5a32"))
		h.slab("dirt", bed + Vector3(0, 0.38, 0), Vector3(3.4, 0.06, 7.8), Color("5b3a22"))
		h.collider(bed + Vector3(0, 0.2, 0), Vector3(3.6, 0.4, 8.0))
		for k in 14:
			var pp := bed + Vector3(fr.randf_range(-1.4, 1.4), 0.5, fr.randf_range(-3.5, 3.5))
			var veg_col: Color = [Color("3b8d3a"), Color("6bbf59"), Color("2e7d32")][k % 3]
			h.sphere("foliage", pp, 0.28, veg_col, Vector3(1, 0.6, 1), 7, 5, false)
			if i % 2 == 0 and k % 3 == 0:
				h.sphere("plain", pp + Vector3(0, 0.12, 0), 0.08, Color("e74c3c"), Vector3.ONE, 6, 4, false)
			elif k % 4 == 0:
				h.cylinder("plain", pp + Vector3(0, 0.05, 0), 0.0, 0.05, 0.18, Color("e67e22"), 6, false)
	# casinha de ferramentas
	var shed := Vector3(6, 0.012, -70)
	h.box("wood", shed + Vector3(0, 1.1, 0), Vector3(2.4, 2.2, 2.0), Color("b5794a"))
	h.box("roof", shed + Vector3(0, 2.3, 0), Vector3(2.8, 0.15, 2.4), Color("6d4c41"))
	h.box("wood", shed + Vector3(0, 0.95, 1.01), Vector3(0.9, 1.9, 0.04), Color("6d4c41"))
	h.collider(shed + Vector3(0, 1.1, 0), Vector3(2.4, 2.2, 2.0))
	add_label("HORTA DA ESCOLA", Vector3(-3, 1.5, -57.8), 0.0, 56, Color("2e7d32"), Color(1, 1, 1, 0.9), 0.006, 35.0)
	h.box("wood", Vector3(-3, 1.5, -57.9), Vector3(3.2, 0.6, 0.06), Color("f5e6c8"))
	h.box("wood", Vector3(-3, 0.75, -57.9), Vector3(0.1, 1.5, 0.1), Color("8a5a32"))
	add_zone("Horta", area, false, "", 5, Color(0.55, 0.42, 0.28))

	# Bosque (leste)
	var w := chunk("bosque")
	var wood := R(68, -72, 88, -32)
	for k in 26:
		var p := Vector3(rng.randf_range(69, 87), 0, rng.randf_range(-71, -33))
		var type: String = ["copa", "copa", "ipe", "pinheiro"][k % 4]
		_tree(type, p, rng.randf_range(0.85, 1.3), [Color("3f8a3a"), Color("4f9a45"), Color("f2c230"), Color("2f6e3a")][k % 4], w)
	for k in 4:
		Props.bench(w, Vector3(70.5, 0.0, -66 + k * 9.0), -PI * 0.5)
	for k in 3:
		Props.table_with_chairs(w, Vector3(80, 0.0, -62 + k * 11.0), PI * 0.5, Color("a0663a"))
	for k in 12:
		w.slab("dirt", Vector3(76 + sin(k * 0.6) * 3.0, 0.008, -70 + k * 3.2), Vector3(1.6, 0.02, 3.4), Color("c2a27a"))
	add_zone("Bosque", wood, false, "", 4, Color(0.35, 0.6, 0.35))

	# Jardim oeste
	var j := chunk("jardim_oeste")
	for k in 16:
		var p := Vector3(rng.randf_range(-88, -66), 0, rng.randf_range(-42, 46))
		_tree(["copa", "ipe", "arbusto", "palmeira"][k % 4], p, rng.randf_range(0.8, 1.2), [Color("3f8a3a"), Color("e86aa6"), Color("4a9a45"), Color.WHITE][k % 4], j)
	for k in 5:
		Props.bench(j, Vector3(-64.5, 0.0, -36 + k * 12.0), PI * 0.5)
	Props.planter(j, Vector3(-75, 0.0, 30), Vector2(6, 3), fr)
	Props.planter(j, Vector3(-75, 0.0, 10), Vector2(6, 3), fr)
	add_zone("Jardim Oeste", R(-90, -44, -62, 50), false, "", 3, Color(0.42, 0.66, 0.4))

	# árvores espalhadas pelos cantos do terreno
	for k in 14:
		var p := Vector3(rng.randf_range(-86, 86), 0, rng.randf_range(-74, -70))
		if p.x > -15 and p.x < 10:
			continue
		_tree("pinheiro", p, rng.randf_range(0.9, 1.3), Color.WHITE)
	for k in 8:
		_tree("copa", Vector3(rng.randf_range(62, 88), 0, rng.randf_range(26, 48)), rng.randf_range(0.9, 1.2), Color.WHITE, j)


func _general_zones() -> void:
	add_zone("Pátio dos Fundos", R(-90, -75, 90, -26), false, "", 0, Color(0.5, 0.72, 0.45))
	add_zone("Lateral Leste", R(60, -30, 90, 52), false, "", 0, Color(0.5, 0.72, 0.45))
	add_zone("Lateral Oeste", R(-90, 20, -60, 52), false, "", 0, Color(0.5, 0.72, 0.45))
	add_zone("Escola", LOT, false, "", -5, Color(0.5, 0.72, 0.45))
	zones.sort_custom(func(a, b): return a.priority > b.priority)


## Pontos de atividade usados pelos alunos (NPCs) no recreio.
func _recess_spots() -> void:
	var chat := [Vector3(-8, 0, -4), Vector3(8, 0, -16), Vector3(-22, 0, -12), Vector3(18, 0, 0), Vector3(-36, 0, -2),
		Vector3(-4, 0, 22), Vector3(10, 0, 22), Vector3(-12, 0, 11.5), Vector3(4, 0, 11.5), Vector3(46, 0, -12),
		Vector3(40, 0, -27.5), Vector3(-52, 0, -20), Vector3(28, 0, 12), Vector3(-30, 0, 22), Vector3(30, 0, -12)]
	for p in chat:
		spots.append({"type": "chat", "pos": p + Vector3(0, 0.05, 0)})
	for i in 6:
		spots.append({"type": "queue", "pos": Vector3(-20.6 + i * 0.85, 0.05, 12.0), "yaw": -PI * 0.5, "order": i})
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		spots.append({"type": "marbles", "pos": Vector3(-46 + cos(a) * 1.6, 0.05, -9 + sin(a) * 1.6), "yaw": atan2(-cos(a), -sin(a))})
	for i in 3:
		spots.append({"type": "hopscotch", "pos": Vector3(-14.0 + i * 0.6, 0.05, -0.6 + i * 0.3), "yaw": PI})
	for p in [Vector3(-60, 0, -60), Vector3(-80, 0, -50), Vector3(75, 0, -50), Vector3(0, 0, -45), Vector3(-30, 0, -30),
			Vector3(50, 0, 30), Vector3(-75, 0, 20), Vector3(20, 0, 60), Vector3(-20, 0, 58), Vector3(-5, 0, -64)]:
		spots.append({"type": "wander", "pos": p + Vector3(0, 0.05, 0)})


## Tipo de piso numa posição (para o som dos passos).
func surface_at(x: float, z: float) -> String:
	for i in range(surfaces.size() - 1, -1, -1):
		var s: Dictionary = surfaces[i]
		if s.rect.has_point(Vector2(x, z)):
			return s.type
	return "grass"
