class_name BuildingC
extends RefCounted
## Bloco C (Ciências e Tecnologia): dois andares, escada interna, varanda
## no 1º andar com escada externa. Fica no lado oeste do terreno.
##
##   x -86 .. -66,  z 22 .. 46
##   corredor central x -77..-73 (aberto ao sul)
##   térreo: Robótica, Lab. de Física | escadaria, Grêmio
##   1º andar: Lab. de Química, Idiomas | (vão da escada), Mirante

const FLOOR2 := 3.85
const BAR := Color("7b4fb0")
const WALL := Color("a9dbe8")


static func build(sb: SchoolBuilder) -> void:
	var R := SchoolBuilder.R
	# ---- térreo
	var g_rooms := [
		{"name": "Sala de Robótica", "rect": R.call(-86, 22, -77, 34), "kind": "computer",
			"doors": [["e", 31.5, 1.2]], "auto_windows": ["w"], "inner": [Color("2d98da"), Color("eaf4fb"), 1.1]},
		{"name": "Laboratório de Física", "rect": R.call(-86, 34, -77, 46), "kind": "lab",
			"doors": [["e", 43.5, 1.2]], "auto_windows": ["w"], "inner": [Color("eb8a2f"), Color("fdf1e4"), 1.1]},
		{"name": "Escadaria", "rect": R.call(-73, 22, -66, 28), "kind": "", "always_visible": true, "no_ceiling": true,
			"doors": [["w", 26.6, 1.6]], "windows": [["e", 25.0, 1.8]], "inner": [BAR, Color("f6eee4"), 1.1]},
		{"name": "Grêmio Estudantil", "rect": R.call(-73, 28, -66, 46), "kind": "teachers",
			"doors": [["w", 30.5, 1.2]], "auto_windows": ["e"], "inner": [Color("e84393"), Color("fdeef6"), 1.1]},
		{"name": "Corredor do Bloco C", "rect": R.call(-77, 22, -73, 46), "kind": "", "always_visible": true,
			"open": ["s"], "inner": [BAR, Color("f6eee4"), 1.1]},
	]
	sb.build_building_at({"id": "C1", "title": "Bloco C", "height": 3.6, "wall": WALL, "bar": BAR, "bar_h": 1.1,
		"trim": Color("ffffff"), "rooms": g_rooms}, 0.0)
	# ---- 1º andar
	var u_rooms := [
		{"name": "Laboratório de Química", "rect": R.call(-86, 22, -77, 34), "kind": "lab",
			"doors": [["e", 31.5, 1.2]], "auto_windows": ["w"], "inner": [Color("20bf6b"), Color("eafaf1"), 1.1]},
		{"name": "Sala de Idiomas", "rect": R.call(-86, 34, -77, 46), "kind": "classroom", "grade": 7,
			"doors": [["e", 43.5, 1.2]], "auto_windows": ["w"], "inner": [Color("fa8231"), Color("fff3e6"), 1.1]},
		{"name": "Vão da escada", "rect": R.call(-73, 22, -66, 28), "kind": "", "always_visible": true, "no_floor": true, "no_nav": true,
			"doors": [["w", 23.6, 2.3]], "windows": [["e", 25.0, 1.8]], "inner": [BAR, Color("f6eee4"), 1.1]},
		{"name": "Mirante", "rect": R.call(-73, 28, -66, 46), "kind": "", "always_visible": true,
			"doors": [["w", 37.0, 2.4, 2.6]], "open": ["e"], "colonnade": ["e"], "floor_col": Color("c8a27a"), "floor": "wood",
			"inner": [BAR, Color("f6eee4"), 1.1]},
		{"name": "Corredor do 1º andar", "rect": R.call(-77, 22, -73, 46), "kind": "", "always_visible": true,
			"open": ["s"], "inner": [BAR, Color("f6eee4"), 1.1]},
	]
	sb.build_building_at({"id": "C2", "title": "Bloco C 1º andar", "height": 3.5, "wall": WALL, "bar": BAR, "bar_h": 1.1,
		"trim": Color("ffffff"), "rooms": u_rooms, "floor_collider": true,
		"roof": {"rect": R.call(-86, 22, -66, 46), "axis": "z", "pitch": 18.0, "overhang": 0.9}}, FLOOR2)
	# o telhado do 1º andar também some quando se está no térreo
	sb.roof_chunks["C1"] = sb.roof_chunks.get("C2", [])
	_inner_stairs(sb)
	_balcony_and_outer_stairs(sb)
	_mirante_props(sb)
	sb.add_label("BLOCO C · CIÊNCIAS", Vector3(-75, 7.2, 46.4), 0.0, 72, Color("7b4fb0"), Color(1, 1, 1, 0.95), 0.008, 80.0)
	sb.map_shapes.append({"rect": R.call(-86, 22, -66, 46), "color": Color(0.62, 0.42, 0.75), "label": "Bloco C"})


## Escada interna: sobe do leste (x -67) para o oeste (x -72.6), z 22.4..24.8.
static func _inner_stairs(sb: SchoolBuilder) -> void:
	var b := sb.chunk("escada_c")
	var z0 := 22.45
	var z1 := 24.85
	var x_bottom := -67.0
	var x_top := -72.7
	var steps := 18
	var run := (x_bottom - x_top) / steps
	for i in steps:
		var hk := FLOOR2 * (i + 1) / steps
		var x := x_bottom - run * (i + 0.5)
		b.box("tile", Vector3(x, hk * 0.5, (z0 + z1) * 0.5), Vector3(run + 0.01, hk, z1 - z0), Color("d9c7b0").darkened((i % 2) * 0.05))
	var ang := atan2(FLOOR2, x_bottom - x_top)
	var mid := Vector3((x_bottom + x_top) * 0.5, FLOOR2 * 0.5, (z0 + z1) * 0.5)
	b.collider_xf(Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, 0.02, 0)), Vector3((x_bottom - x_top) / cos(ang), 0.08, z1 - z0))
	# corrimão
	b.box_xf("metal", Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, 0.9, z1 - (z0 + z1) * 0.5)), Vector3((x_bottom - x_top) / cos(ang), 0.06, 0.06), Color("7b4fb0"))
	b.collider_xf(Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, 0.6, z1 - (z0 + z1) * 0.5 + 0.03)), Vector3((x_bottom - x_top) / cos(ang), 1.2, 0.06))
	# piso do 1º andar sobre o resto do vão (fora do buraco da escada)
	b.slab("tile", Vector3(-69.5, FLOOR2 - 0.03, 26.45), Vector3(7.0, 0.06, 3.1), Color("e3d6c4"))
	b.box("paint", Vector3(-69.5, FLOOR2 - 0.15, 26.45), Vector3(7.0, 0.24, 3.1), Color("f6eee4"))
	b.collider(Vector3(-69.5, FLOOR2 - 0.12, 26.45), Vector3(7.0, 0.24, 3.1))
	b.slab("tile", Vector3(-72.85, FLOOR2 - 0.03, 23.65), Vector3(0.3, 0.06, 2.4), Color("e3d6c4"))
	# guarda-corpo em volta do buraco (lado do vão)
	b.box("metal", Vector3(-69.85, FLOOR2 + 0.5, 24.9), Vector3(5.7, 1.0, 0.05), Color("7b4fb0"))
	b.collider(Vector3(-69.85, FLOOR2 + 0.5, 24.9), Vector3(5.7, 1.0, 0.1))
	b.box("metal", Vector3(-66.95, FLOOR2 + 0.5, 23.65), Vector3(0.05, 1.0, 2.4), Color("7b4fb0"))
	b.collider(Vector3(-66.95, FLOOR2 + 0.5, 23.65), Vector3(0.1, 1.0, 2.4))
	# navegação: pé da escada, degraus e topo
	var pts := [Vector3(-68.5, 0.05, 26.3), Vector3(-66.6, 0.05, 23.6)]
	for k in 5:
		var t := float(k) / 4.0
		pts.append(Vector3(lerpf(x_bottom + 0.2, x_top - 0.1, t), lerpf(0.05, FLOOR2 + 0.05, t), 23.6))
	pts.append(Vector3(-74.0, FLOOR2 + 0.05, 23.6))
	for i in pts.size():
		sb.nav_points.append(pts[i])
		if i > 0:
			sb.nav_links.append([pts[i - 1], pts[i]])
	sb.nav_links.append([Vector3(-74.0, 0.05, 26.6), Vector3(-68.5, 0.05, 26.3)])
	sb.nav_points.append(Vector3(-74.0, 0.05, 26.6))


## Varanda ao sul do 1º andar e escada externa descendo para o leste.
static func _balcony_and_outer_stairs(sb: SchoolBuilder) -> void:
	var b := sb.chunk("varanda_c")
	var y := FLOOR2
	# piso da varanda (z 46..48.6, x -84..-72)
	b.box("concrete", Vector3(-78, y - 0.12, 47.3), Vector3(12.2, 0.24, 2.6), Color("d8c39a"))
	b.collider(Vector3(-78, y - 0.12, 47.3), Vector3(12.2, 0.24, 2.6))
	for x: float in [-83.8, -78.0, -72.2]:
		b.box("paint", Vector3(x, y * 0.5 - 0.12, 48.4), Vector3(0.3, y - 0.24, 0.3), WALL)
		b.collider(Vector3(x, y * 0.5 - 0.12, 48.4), Vector3(0.3, y - 0.24, 0.3))
	# guarda-corpo
	b.box("metal", Vector3(-78, y + 0.5, 48.55), Vector3(12.2, 0.06, 0.06), Color("7b4fb0"))
	b.box("glass", Vector3(-78, y + 0.25, 48.55), Vector3(12.2, 0.5, 0.03), Color("bfe3f5"))
	b.collider(Vector3(-78, y + 0.5, 48.55), Vector3(12.2, 1.0, 0.1))
	b.box("metal", Vector3(-84.05, y + 0.5, 47.3), Vector3(0.06, 1.0, 2.6), Color("7b4fb0"))
	b.collider(Vector3(-84.05, y + 0.5, 47.3), Vector3(0.1, 1.0, 2.6))
	# escada externa: topo em x -72, base em x -61.6 (z 46.2..48.4)
	var x_top := -72.0
	var x_bot := -61.6
	var steps := 20
	var run := (x_bot - x_top) / steps
	for i in steps:
		var hk := y * (steps - i) / steps
		var x := x_top + run * (i + 0.5)
		b.box("concrete", Vector3(x, hk - 0.1, 47.3), Vector3(run + 0.01, 0.2, 2.2), Color("cdb68c").darkened((i % 2) * 0.04))
	var ang := atan2(y, x_bot - x_top)
	var mid := Vector3((x_top + x_bot) * 0.5, y * 0.5, 47.3)
	b.collider_xf(Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, 0.02, 0)), Vector3((x_bot - x_top) / cos(ang), 0.08, 2.2))
	b.box_xf("concrete", Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, -0.25, 0)), Vector3((x_bot - x_top) / cos(ang), 0.3, 2.2), Color("bfa77f"))
	for zz: float in [46.15, 48.45]:
		b.box_xf("metal", Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, 0.95, zz - 47.3)), Vector3((x_bot - x_top) / cos(ang), 0.06, 0.06), Color("7b4fb0"))
		b.collider_xf(Transform3D(Basis(Vector3.BACK, -ang), mid + Vector3(0, 0.6, zz - 47.3)), Vector3((x_bot - x_top) / cos(ang), 1.2, 0.08))
	# navegação: base -> degraus -> varanda -> corredor de cima
	var pts := [Vector3(-60.4, 0.05, 47.3)]
	for k in 5:
		var t := float(k) / 4.0
		pts.append(Vector3(lerpf(x_bot + 0.2, x_top - 0.2, t), lerpf(0.05, y + 0.05, t), 47.3))
	pts.append(Vector3(-75.0, y + 0.05, 47.3))
	pts.append(Vector3(-75.0, y + 0.05, 44.8))
	for i in pts.size():
		sb.nav_points.append(pts[i])
		if i > 0:
			sb.nav_links.append([pts[i - 1], pts[i]])
	sb.add_zone("Varanda do Bloco C", SchoolBuilder.R(-84.2, 46, -72, 48.7), false, "", 9, Color(0.75, 0.6, 0.85))
	sb.zones[-1]["y0"] = 2.0
	sb.zones[-1]["y1"] = 8.0
	sb.add_zone("Escada externa", SchoolBuilder.R(-72, 46, -61.4, 48.6), false, "", 8, Color(0.75, 0.6, 0.85))


static func _mirante_props(sb: SchoolBuilder) -> void:
	var b := sb.chunk("mirante")
	var y := FLOOR2 + 0.025
	for k in 3:
		Props.bench(b, Vector3(-67.2, y, 31.0 + k * 5.0), -PI * 0.5, 1.8)
	b.cylinder("plain", Vector3(-70.5, y + 0.3, 41.5), 0.3, 0.25, 0.6, Color("c0392b"), 10)
	b.sphere("foliage", Vector3(-70.5, y + 1.0, 41.5), 0.6, Color("3f8a3a"), Vector3(1, 1.3, 1), 8, 6)
	b.collider_cyl(Vector3(-70.5, y + 0.5, 41.5), 0.32, 1.0)
	# telescópio
	b.cylinder("metal", Vector3(-67.6, y + 0.6, 29.0), 0.03, 0.05, 1.2, Color("34495e"), 8)
	b.cylinder_xf("metal", Transform3D(Basis(Vector3.FORWARD, 1.2), Vector3(-67.5, y + 1.25, 29.0)), 0.06, 0.09, 0.7, Color("2d3436"), 10)
	b.collider_cyl(Vector3(-67.6, y + 0.6, 29.0), 0.15, 1.2)
