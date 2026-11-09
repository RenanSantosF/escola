class_name NavGraph
extends RefCounted
## Grafo de navegação gerado automaticamente a partir da física da escola:
## pontos numa grade (3 m) + pontos extras (portas, salas), validados com
## consultas de forma; ligações validadas com raycasts. Caminhos por A*.
## Muito mais barato que navmesh em tempo real e totalmente determinístico.

const GRID := 3.0
const LINK_RADIUS := 4.4
const EXTRA_LINK_RADIUS := 3.3

var astar := AStar3D.new()
var points: PackedVector3Array = []
var _space: PhysicsDirectSpaceState3D
var _shape_q: PhysicsShapeQueryParameters3D
var _ray_q: PhysicsRayQueryParameters3D
var _hash := {}  # célula -> [ids]


func build(world: Node3D, builder: SchoolBuilder, lot: Rect2) -> void:
	_space = world.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	_shape_q = PhysicsShapeQueryParameters3D.new()
	_shape_q.shape = sphere
	_shape_q.collision_mask = 1
	_ray_q = PhysicsRayQueryParameters3D.new()
	_ray_q.collision_mask = 1

	var candidates: Array[Vector3] = []
	var x := lot.position.x + 1.5
	while x < lot.end.x - 1.0:
		var z := lot.position.y + 1.5
		while z < lot.end.y - 1.0:
			candidates.append(Vector3(x, 0.05, z))
			z += GRID
		x += GRID
	var extra_start := candidates.size()
	for p in builder.nav_points:
		candidates.append(p)
	for i in candidates.size():
		var p: Vector3 = candidates[i]
		if _walkable(p):
			_add_point(p, i >= extra_start)
	# ligações
	for id in astar.get_point_ids():
		var p := astar.get_point_position(id)
		for other in _near(p, LINK_RADIUS):
			if other <= id or astar.are_points_connected(id, other):
				continue
			var q := astar.get_point_position(other)
			if absf(p.y - q.y) > 0.6:
				continue
			var d := p.distance_to(q)
			var lim := LINK_RADIUS
			if _is_extra(id) or _is_extra(other):
				lim = EXTRA_LINK_RADIUS
			if d > lim:
				continue
			if _clear(p, q):
				astar.connect_points(id, other)
	# passagens por portas (sempre ligadas)
	for link in builder.nav_links:
		var a := _nearest_id(link[0], 0.3)
		var b := _nearest_id(link[1], 0.3)
		if a == -1:
			a = _add_point(link[0], true)
		if b == -1:
			b = _add_point(link[1], true)
		if not astar.are_points_connected(a, b):
			astar.connect_points(a, b)
	_keep_main_component()


## Desativa "ilhas" do grafo (pontos que não se ligam ao componente
## principal), para que caminhos nunca atravessem paredes.
var main_component_size := 0


func _keep_main_component() -> void:
	var comp := {}
	var best_id := -1
	var best_size := 0
	var label := 0
	for id in astar.get_point_ids():
		if comp.has(id):
			continue
		label += 1
		var stack := [id]
		comp[id] = label
		var size := 0
		while not stack.is_empty():
			var c: int = stack.pop_back()
			size += 1
			for nb in astar.get_point_connections(c):
				if not comp.has(nb):
					comp[nb] = label
					stack.append(nb)
		if size > best_size:
			best_size = size
			best_id = label
	main_component_size = best_size
	for id in comp.keys():
		if comp[id] != best_id:
			astar.set_point_disabled(id, true)


func is_clear(a: Vector3, b: Vector3) -> bool:
	return _clear(a, b)

var _extra := {}


func _add_point(p: Vector3, extra: bool) -> int:
	var id := points.size()
	points.append(p)
	astar.add_point(id, p)
	var c := _cell(p)
	if not _hash.has(c):
		_hash[c] = []
	_hash[c].append(id)
	if extra:
		_extra[id] = true
	return id


func _is_extra(id: int) -> bool:
	return _extra.has(id)


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / 4.5), floori(p.z / 4.5))


func _near(p: Vector3, r: float) -> Array:
	var out := []
	var c := _cell(p)
	var span := ceili(r / 4.5)
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if _hash.has(k):
				out.append_array(_hash[k])
	return out


func _nearest_id(p: Vector3, max_d: float) -> int:
	var best := -1
	var bd := max_d
	for id in _near(p, max_d + 0.1):
		var d := astar.get_point_position(id).distance_to(p)
		if d <= bd:
			bd = d
			best = id
	return best


func _walkable(p: Vector3) -> bool:
	for h: float in [0.45, 1.0]:
		_shape_q.transform = Transform3D(Basis(), Vector3(p.x, p.y + h, p.z))
		if not _space.intersect_shape(_shape_q, 1).is_empty():
			return false
	return true


func _clear(a: Vector3, b: Vector3) -> bool:
	var dir := (b - a)
	dir.y = 0.0
	var side := Vector3(-dir.z, 0, dir.x).normalized() * 0.26
	for o in [[side, 0.5], [-side, 0.5], [Vector3.ZERO, 1.25]]:
		_ray_q.from = Vector3(a.x, a.y + o[1], a.z) + o[0]
		_ray_q.to = Vector3(b.x, b.y + o[1], b.z) + o[0]
		if not _space.intersect_ray(_ray_q).is_empty():
			return false
	return true


## Ponto do grafo mais próximo que é alcançável em linha reta (evita
## "atravessar a parede" até um ponto do outro lado dela).
func closest_visible(pos: Vector3) -> int:
	var ids := _near(pos, 6.0)
	ids.sort_custom(func(x, y): return astar.get_point_position(x).distance_squared_to(pos) < astar.get_point_position(y).distance_squared_to(pos))
	for id in ids:
		if astar.is_point_disabled(id):
			continue
		var q := astar.get_point_position(id)
		if absf(q.y - pos.y) > 1.5:
			continue
		if _clear(pos, q):
			return id
	return astar.get_closest_point(pos)


## Caminho entre duas posições (inclui o destino exato no final).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if points.is_empty():
		return PackedVector3Array([to])
	var a := closest_visible(from)
	var b := closest_visible(to)
	var p := astar.get_point_path(a, b)
	if p.is_empty():
		return PackedVector3Array([to])
	# remove o primeiro ponto se já estamos praticamente nele/além dele
	if p.size() > 1 and from.distance_to(p[1]) < p[0].distance_to(p[1]):
		p.remove_at(0)
	p.append(to)
	return p


func random_point(rng: RandomNumberGenerator, area: Rect2) -> Vector3:
	for i in 30:
		var id := rng.randi() % points.size()
		var q := points[id]
		if area.has_point(Vector2(q.x, q.z)) and not astar.is_point_disabled(id):
			return q
	return points[rng.randi() % points.size()]


func connected_count() -> int:
	return main_component_size
