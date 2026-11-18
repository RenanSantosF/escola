class_name Seat
extends Interactable
## Assento: a origem do nó é onde ficam os pés do personagem sentado,
## e a rotação Y indica para onde ele olha.

var occupant: Node = null
var seat_top := 0.47
var room := ""
## Distância (ao longo da frente do assento) do ponto de aproximação dos NPCs.
var approach := 0.55
var swing := false
var _swing_t := 0.0
## Balanço de verdade: corrente e tábua giram presas na trave (2,5 m acima);
## quem senta vai e volta junto, cada vez mais alto.
const SWING_PIVOT := 2.49
const SWING_MAX := 0.95  # ~55° para cada lado
var _swing_root: Node3D
var _amp := 0.0
var _phase := 0.0
var _swing_angle := 0.0


func _ready() -> void:
	super._ready()
	interact_radius = 1.1
	if swing:
		_build_swing()
		set_process(true)


func _build_swing() -> void:
	_swing_root = Node3D.new()
	_swing_root.name = "Balanco"
	_swing_root.position = Vector3(0, SWING_PIVOT, 0)
	add_child(_swing_root)
	var md := MeshData.new()
	var cols := [Color("e74c3c"), Color("f1c40f"), Color("3498db")]
	var col: Color = cols[posmod(int(round(global_position.x / 1.4)), 3)]
	var chain_len := SWING_PIVOT - seat_top + global_position.y
	md.cur_color = Color("95a5a6")
	for sx in [-0.22, 0.22]:
		md.add_box(Transform3D(Basis(), Vector3(sx, -chain_len * 0.5, 0)), Vector3(0.025, chain_len, 0.025))
	md.cur_color = col
	md.add_box(Transform3D(Basis(), Vector3(0, -chain_len - 0.02, 0)), Vector3(0.56, 0.05, 0.26))
	md.cur_color = col.darkened(0.25)
	md.add_box(Transform3D(Basis(), Vector3(0, -chain_len + 0.02, 0.12)), Vector3(0.56, 0.03, 0.03))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	_swing_root.add_child(mi)


func can_interact(_player: Node) -> bool:
	return occupant == null or _only_reserved() or (has_meta("my_desk") and occupant is NPC)


## A minha carteira: se um boneco estiver nela, ele sai para eu sentar.
func free_for_owner() -> void:
	if occupant is NPC and (has_meta("my_desk") or _only_reserved()):
		var n := occupant as NPC
		if n.sitting and n.seat == self:
			n.force_unseat()
			n.say("Opa, desculpa!", 1.6)
		else:
			n.cancel_seat()
		occupant = null


## Um bot "guardou" o lugar mas ainda não sentou: o jogador pode sentar.
func _only_reserved() -> bool:
	return occupant is NPC and not (occupant as NPC).sitting and (occupant as NPC).seat != self


## O ponto de interação fica um pouco à frente do assento.
func interact_point() -> Vector3:
	return global_position + global_basis.z * 0.35


func interact(player: Node) -> void:
	free_for_owner()
	if occupant != null:
		return
	if player.has_method("sit_on"):
		player.sit_on(self)


func occupy(who: Node) -> void:
	occupant = who
	_swing_t = 0.0


func release() -> void:
	if occupant and swing and occupant.get("visual"):
		var v: Node3D = occupant.visual
		v.position = Vector3.ZERO
		v.rotation = Vector3(0, v.rotation.y, 0)
	occupant = null


## Ângulo atual do balanço (radianos; testes e câmera).
func swing_angle() -> float:
	return _swing_angle


func _process(delta: float) -> void:
	# balanço do parquinho: vazio mexe um pouquinho com o vento; com alguém,
	# vai ganhando altura (como se a criança "tomasse impulso") até ~55°
	if not swing or _swing_root == null:
		return
	_swing_t += delta
	var target := 0.06
	if occupant != null:
		target = SWING_MAX if _swing_t > 1.0 else 0.25
	_amp = move_toward(_amp, target, delta * (0.16 if target > _amp else 0.35))
	_phase += delta * sqrt(9.8 / SWING_PIVOT)
	_swing_angle = sin(_phase) * _amp
	_swing_root.rotation.x = _swing_angle
	if occupant == null:
		return
	var v: Node3D = occupant.get("visual")
	if v == null:
		return
	# o boneco gira junto com a tábua, em volta da trave
	var right := global_basis.x.normalized()
	var r := Basis(right, _swing_angle)
	var piv := Vector3(0, SWING_PIVOT, 0)
	var yaw := float(v.rotation.y)
	v.transform = Transform3D(r * Basis(Vector3.UP, yaw), piv + r * (-piv))
