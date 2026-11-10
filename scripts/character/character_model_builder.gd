class_name CharacterModelBuilder
extends RefCounted
## Constrói um personagem estilizado 100% procedural:
## - Skeleton3D com nomes de ossos do perfil humanoide do Godot
##   (compatível com retarget de animações Mixamo no futuro).
## - Uma única malha skinned com cores por vértice = 1 draw call por personagem.

const BONES := [
	# nome, pai, posição local de repouso
	["Hips", "", Vector3(0, 0.86, 0)],
	["Spine", "Hips", Vector3(0, 0.10, 0)],
	["Chest", "Spine", Vector3(0, 0.17, 0)],
	["Neck", "Chest", Vector3(0, 0.25, 0)],
	["Head", "Neck", Vector3(0, 0.07, 0)],
	["LeftShoulder", "Chest", Vector3(0.07, 0.20, 0)],
	["LeftUpperArm", "LeftShoulder", Vector3(0.11, 0, 0)],
	["LeftLowerArm", "LeftUpperArm", Vector3(0, -0.25, 0)],
	["LeftHand", "LeftLowerArm", Vector3(0, -0.23, 0)],
	["RightShoulder", "Chest", Vector3(-0.07, 0.20, 0)],
	["RightUpperArm", "RightShoulder", Vector3(-0.11, 0, 0)],
	["RightLowerArm", "RightUpperArm", Vector3(0, -0.25, 0)],
	["RightHand", "RightLowerArm", Vector3(0, -0.23, 0)],
	["LeftUpperLeg", "Hips", Vector3(0.095, -0.03, 0)],
	["LeftLowerLeg", "LeftUpperLeg", Vector3(0, -0.39, 0)],
	["LeftFoot", "LeftLowerLeg", Vector3(0, -0.37, 0)],
	["RightUpperLeg", "Hips", Vector3(-0.095, -0.03, 0)],
	["RightLowerLeg", "RightUpperLeg", Vector3(0, -0.39, 0)],
	["RightFoot", "RightLowerLeg", Vector3(0, -0.37, 0)],
	["LeftEye", "Head", Vector3(0.072, 0.155, 0.172)],
	["RightEye", "Head", Vector3(-0.072, 0.155, 0.172)],
	["LeftBrow", "Head", Vector3(0.074, 0.232, 0.168)],
	["RightBrow", "Head", Vector3(-0.074, 0.232, 0.168)],
	["Mouth", "Head", Vector3(0, 0.083, 0.176)],
]

## Estilo "chibi" infantil: cabeça grande e redonda, olhos grandes.
const HEAD_C := Vector3(0, 0.17, 0)  # centro da cabeça, relativo ao osso Head
const HEAD_R := 0.2

static var _material: StandardMaterial3D

var md := MeshData.new()
var bone_index := {}
var bone_global := {}
var app: CharacterAppearance
## 1.0 = malha completa; menor = menos segmentos (bots, vistos de longe).
var detail := 1.0


func _seg(n: int) -> int:
	return maxi(int(round(n * detail)), 5 if detail >= 0.99 else 4)



static func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.72
		# luz "enrolada": sombra suave e arredondada, visual de desenho animado
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_material.rim_enabled = true
		_material.rim = 0.18
		_material.rim_tint = 0.6
	return _material


## Cria o Skeleton3D (com a malha como filha) para a aparência dada.
static func build(appearance: CharacterAppearance, detail_level := 1.0) -> Skeleton3D:
	var b := CharacterModelBuilder.new()
	b.app = appearance
	b.detail = detail_level
	var skel := b._make_skeleton()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = b._make_mesh()
	mi.extra_cull_margin = 0.6
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	return skel


## Reconstrói apenas a malha (troca de roupa) mantendo o esqueleto.
static func rebuild_mesh(skel: Skeleton3D, appearance: CharacterAppearance, detail_level := 1.0) -> void:
	var b := CharacterModelBuilder.new()
	b.app = appearance
	b.detail = detail_level
	for i in BONES.size():
		b.bone_index[BONES[i][0]] = i
	b._compute_globals()
	var mi := skel.get_node_or_null("Body") as MeshInstance3D
	if mi:
		mi.mesh = b._make_mesh()


func _compute_globals() -> void:
	for bd in BONES:
		var parent: String = bd[1]
		var base: Vector3 = bone_global[parent] if parent != "" else Vector3.ZERO
		bone_global[bd[0]] = base + bd[2]


func _make_skeleton() -> Skeleton3D:
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	for i in BONES.size():
		var bd: Array = BONES[i]
		skel.add_bone(bd[0])
		bone_index[bd[0]] = i
		if bd[1] != "":
			skel.set_bone_parent(i, bone_index[bd[1]])
		skel.set_bone_rest(i, Transform3D(Basis(), bd[2]))
		skel.set_bone_pose_position(i, bd[2])
		skel.set_bone_pose_rotation(i, Quaternion())
		skel.set_bone_pose_scale(i, Vector3.ONE)
	_compute_globals()
	return skel


# ------------------------------------------------------------ helpers de peça

func _bone(name: String, col: Color) -> void:
	md.cur_bone = bone_index[name]
	md.cur_color = col


func _xf(bone: String, local_pos: Vector3, scale := Vector3.ONE, rot_deg := Vector3.ZERO) -> Transform3D:
	var basis := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scale)
	return Transform3D(basis, bone_global[bone] + local_pos)


func _sphere(bone: String, col: Color, pos: Vector3, r: float, scale := Vector3.ONE, rot := Vector3.ZERO, seg := 14, rings := 9) -> void:
	_bone(bone, col)
	md.add_sphere(_xf(bone, pos, scale, rot), r, _seg(seg), maxi(_seg(rings), 4))


func _capsule(bone: String, col: Color, pos: Vector3, r: float, h: float, scale := Vector3.ONE, rot := Vector3.ZERO, seg := 14) -> void:
	_bone(bone, col)
	md.add_capsule(_xf(bone, pos, scale, rot), r, h, _seg(seg), (6 if detail >= 1.0 else 4) if seg > 8 else 4)


func _box(bone: String, col: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	_bone(bone, col)
	md.add_box(_xf(bone, pos, Vector3.ONE, rot), size)


func _cyl(bone: String, col: Color, pos: Vector3, rt: float, rb: float, h: float, rot := Vector3.ZERO, seg := 10) -> void:
	_bone(bone, col)
	md.add_cylinder(_xf(bone, pos, Vector3.ONE, rot), rt, rb, h, _seg(seg))


## Calota esférica (cabelo/boné) orientada pela direção dir.
func _cap(bone: String, col: Color, pos: Vector3, r: float, dir: Vector3, angle_deg: float, scale := Vector3.ONE) -> void:
	_bone(bone, col)
	var up := Vector3.UP
	var d := dir.normalized()
	var basis := Basis()
	if not d.is_equal_approx(up):
		var axis := up.cross(d).normalized()
		basis = Basis(axis, up.angle_to(d))
	basis = Basis.from_scale(scale) * basis
	md.add_sphere(Transform3D(basis, bone_global[bone] + pos), r, _seg(16), _seg(9), deg_to_rad(angle_deg))


# ------------------------------------------------------------ corpo

func _make_mesh() -> ArrayMesh:
	md.use_bones = true
	var a := app
	var bw := a.build
	var skin := a.skin
	var shirt := a.shirt_color
	var trim := a.shirt_trim
	var pants := a.pants_color

	# Bermuda/calça: quadril arredondado com cós
	_capsule("Hips", pants, Vector3(0, -0.025, 0), 0.16, 0.29, Vector3(1.06 * bw, 1, 0.84), Vector3.ZERO, 18)
	# Camiseta: tronco em gota (barriguinha de criança)
	_capsule("Spine", shirt, Vector3(0, 0.06, 0), 0.172, 0.38, Vector3(1.07 * bw, 1, 0.86), Vector3.ZERO, 18)
	_capsule("Chest", shirt, Vector3(0, 0.1, 0), 0.172, 0.36, Vector3(1.08 * bw, 1, 0.82), Vector3.ZERO, 18)
	# barra da camiseta e gola
	_cyl("Spine", shirt.darkened(0.12), Vector3(0, -0.085, 0), 0.172 * bw, 0.176 * bw, 0.022, Vector3.ZERO, 18)
	_cyl("Chest", trim, Vector3(0, 0.262, 0.0), 0.078, 0.1, 0.04, Vector3.ZERO, 16)
	if a.shirt_logo:
		# brasão redondo no peito
		_sphere("Chest", trim, Vector3(0.085, 0.13, 0.126), 0.036, Vector3(1, 1, 0.3), Vector3(0, 28, 0), 12, 6)
		_sphere("Chest", Color("ffd23f"), Vector3(0.087, 0.13, 0.133), 0.02, Vector3(1, 1, 0.3), Vector3(0, 28, 0), 10, 5)
	# Pescoço curtinho
	_cyl("Neck", skin.darkened(0.06), Vector3(0, 0.015, 0), 0.058, 0.064, 0.1, Vector3.ZERO, 14)

	_make_head()

	# Braços: manga bufante, braço roliço e mão de luva
	for side: String in ["Left", "Right"]:
		var sx := 1.0 if side == "Left" else -1.0
		_sphere(side + "UpperArm", shirt, Vector3(0, 0.0, 0), 0.082, Vector3(bw, 0.95, 0.95), Vector3.ZERO, 14, 9)
		_capsule(side + "UpperArm", shirt, Vector3(0, -0.055, 0), 0.074, 0.2, Vector3(bw, 1, 1))
		_cyl(side + "UpperArm", trim, Vector3(0, -0.135, 0), 0.077, 0.077, 0.03, Vector3.ZERO, 14)
		_capsule(side + "UpperArm", skin, Vector3(0, -0.17, 0), 0.052, 0.2)
		_sphere(side + "LowerArm", skin, Vector3.ZERO, 0.052, Vector3.ONE, Vector3.ZERO, 10, 7)
		_capsule(side + "LowerArm", skin, Vector3(0, -0.11, 0), 0.049, 0.26)
		_sphere(side + "Hand", skin, Vector3(0, -0.05, 0.004), 0.058, Vector3(0.78, 1.05, 1.0), Vector3.ZERO, 12, 8)
		_sphere(side + "Hand", skin, Vector3(0.012 * sx, -0.035, 0.045), 0.024, Vector3(0.9, 1.2, 1.0), Vector3(-30, 0, 0), 8, 6)

	# Pernas roliças, meia e tênis grandão
	for side: String in ["Left", "Right"]:
		var up_leg: String = side + "UpperLeg"
		var low_leg: String = side + "LowerLeg"
		var foot: String = side + "Foot"
		if a.long_pants:
			_capsule(up_leg, pants, Vector3(0, -0.18, 0), 0.094 * bw, 0.44)
			_sphere(low_leg, pants, Vector3.ZERO, 0.08, Vector3.ONE, Vector3.ZERO, 10, 7)
			_capsule(low_leg, pants, Vector3(0, -0.16, 0), 0.078, 0.42)
			_cyl(low_leg, pants.darkened(0.14), Vector3(0, -0.335, 0), 0.084, 0.086, 0.035, Vector3.ZERO, 14)
		else:
			_capsule(up_leg, pants, Vector3(0, -0.12, 0), 0.1 * bw, 0.34)
			_cyl(up_leg, pants.darkened(0.14), Vector3(0, -0.275, 0), 0.104 * bw, 0.106 * bw, 0.03, Vector3.ZERO, 14)
			_capsule(up_leg, skin, Vector3(0, -0.27, 0), 0.07, 0.26)
			_sphere(low_leg, skin, Vector3.ZERO, 0.068, Vector3.ONE, Vector3.ZERO, 10, 7)
			_capsule(low_leg, skin, Vector3(0, -0.15, 0), 0.062, 0.38)
			_cyl(low_leg, a.sock_color, Vector3(0, -0.29, 0), 0.068, 0.066, 0.14, Vector3.ZERO, 14)
			_cyl(low_leg, a.sock_color.darkened(0.12), Vector3(0, -0.225, 0), 0.07, 0.07, 0.018, Vector3.ZERO, 14)
		# tênis: corpo, biqueira branca, sola e faixa lateral
		_capsule(foot, a.shoe_color, Vector3(0, -0.018, 0.05), 0.072, 0.29, Vector3(1.05, 0.82, 1), Vector3(90, 0, 0))
		_sphere(foot, Color("f7f7f4"), Vector3(0, -0.028, 0.15), 0.066, Vector3(1.05, 0.72, 0.85), Vector3.ZERO, 12, 7)
		_capsule(foot, a.shoe_sole, Vector3(0, -0.062, 0.05), 0.05, 0.3, Vector3(1.55, 0.42, 1), Vector3(90, 0, 0), 12)
		_sphere(foot, a.shoe_color.lerp(Color.WHITE, 0.55), Vector3(0, 0.03, 0.05), 0.04, Vector3(0.9, 0.5, 1.4), Vector3.ZERO, 8, 5)
		_cyl(foot, a.shoe_color.darkened(0.2), Vector3(0, 0.045, -0.03), 0.07, 0.066, 0.03, Vector3.ZERO, 12)

	if a.backpack:
		var bp := a.backpack_color
		_capsule("Chest", bp, Vector3(0, 0.07, -0.2), 0.15, 0.42, Vector3(1.05, 1, 0.56), Vector3.ZERO, 16)
		_capsule("Chest", bp.darkened(0.18), Vector3(0, -0.02, -0.275), 0.075, 0.2, Vector3(1.4, 1, 0.5), Vector3(0, 0, 90), 12)
		_sphere("Chest", Color("f4f4f0"), Vector3(0, 0.15, -0.283), 0.022, Vector3(1.6, 0.6, 0.4), Vector3.ZERO, 8, 5)
		_capsule("Chest", bp.darkened(0.28), Vector3(0, 0.3, -0.2), 0.016, 0.1, Vector3.ONE, Vector3(0, 0, 90), 6)
		# alças finas acompanhando o corpo
		var strap := bp.darkened(0.3)
		for sx: float in [1.0, -1.0]:
			_capsule("Chest", strap, Vector3(0.108 * sx, 0.1, 0.118), 0.016, 0.3, Vector3(1.0, 1, 0.4), Vector3(-6, 0, 0), 6)
			_capsule("Chest", strap, Vector3(0.108 * sx, 0.24, 0.0), 0.016, 0.26, Vector3(1.0, 1, 0.4), Vector3(96, 0, 0), 6)

	_shade_depth()
	return md.build_mesh(get_material())


## Profundidade "pintada" nas cores: um pouco mais escuro perto dos pés e
## embaixo das partes (queixo, axila), mais claro no alto. Custo zero no jogo.
func _shade_depth() -> void:
	var top := 1.85 * app.height_scale
	for i in md.v.size():
		var p := md.v[i]
		var nn := md.n[i]
		var h := clampf(p.y / top, 0.0, 1.0)
		var k := lerpf(0.84, 1.0, smoothstep(0.0, 0.75, h))
		var _unused := nn
		var col := md.c[i]
		md.c[i] = Color(col.r * k, col.g * k, col.b * k, col.a)


func _make_head() -> void:
	var a := app
	var skin := a.skin
	var c := HEAD_C
	var R := HEAD_R
	# cabeça grande e redonda, levemente achatada
	_sphere("Head", skin, c, R, Vector3(1.0, 0.94, 0.96), Vector3.ZERO, 22, 15)
	# orelhas
	for sx: float in [1.0, -1.0]:
		_sphere("Head", skin.darkened(0.05), c + Vector3(0.196 * sx, -0.025, 0.0), 0.04, Vector3(0.5, 1.0, 0.8), Vector3.ZERO, 10, 7)
		_sphere("Head", skin.darkened(0.14), c + Vector3(0.208 * sx, -0.025, 0.006), 0.02, Vector3(0.4, 1.0, 0.8), Vector3.ZERO, 8, 5)
		# bochechas coradas (discos chatos colados no rosto)
		_sphere("Head", skin.lerp(Color("ff7b8a"), 0.42), c + Vector3(0.118 * sx, -0.062, 0.145), 0.034, Vector3(1.0, 0.72, 0.22), Vector3(0, 38 * sx, 0), 10, 5)
	# narizinho
	_sphere("Head", skin.darkened(0.07), c + Vector3(0, -0.048, 0.19), 0.016, Vector3(1.1, 0.85, 0.8), Vector3.ZERO, 8, 6)
	# olhos grandes de desenho: contorno claro, íris escura e dois brilhos
	var iris := a.eye_color.lerp(Color("1a120d"), 0.35)
	for side: String in ["Left", "Right"]:
		var sx := 1.0 if side == "Left" else -1.0
		_sphere(side + "Eye", Color("fdfdfb"), Vector3(0, 0, -0.006), 0.041, Vector3(0.9, 1.16, 0.34), Vector3(0, 10 * sx, 0), 14, 9)
		_sphere(side + "Eye", iris, Vector3(-0.002 * sx, -0.002, 0.004), 0.033, Vector3(0.88, 1.16, 0.34), Vector3(0, 10 * sx, 0), 14, 9)
		_sphere(side + "Eye", Color("0d0906"), Vector3(-0.002 * sx, -0.004, 0.009), 0.02, Vector3(0.9, 1.15, 0.3), Vector3(0, 10 * sx, 0), 10, 7)
		_sphere(side + "Eye", Color.WHITE, Vector3(0.011, 0.016, 0.014), 0.0105, Vector3(1, 1, 0.5), Vector3.ZERO, 8, 5)
		_sphere(side + "Eye", Color.WHITE, Vector3(-0.011, -0.014, 0.014), 0.0055, Vector3(1, 1, 0.5), Vector3.ZERO, 6, 4)
		# sobrancelha curta e arqueada
		_capsule(side + "Brow", a.hair_color.darkened(0.12), Vector3.ZERO, 0.0075, 0.058, Vector3(1, 1, 0.7), Vector3(0, 12 * sx, 90 - 9 * sx), 6)
	# sorriso (arco de pontinhos)
	var lip := Color("8f2f3d")
	for k in 9:
		var t := (k - 4) / 4.0
		_sphere("Mouth", lip, Vector3(t * 0.04, t * t * 0.016, -absf(t) * 0.012), 0.0068, Vector3(1.3, 0.95, 0.7), Vector3.ZERO, 6, 4)

	_make_hair()

	if a.glasses:
		var fr := Color("1c1c1c")
		for sx: float in [1.0, -1.0]:
			var e := c + Vector3(0.072 * sx, -0.015, 0.2)
			for k in 12:
				var ang := k * TAU / 12.0
				_box("Head", fr, e + Vector3(cos(ang) * 0.05, sin(ang) * 0.052, -absf(cos(ang)) * 0.006), Vector3(0.028, 0.009, 0.009), Vector3(0, 0, rad_to_deg(ang) + 90))
			_box("Head", fr, c + Vector3(0.165 * sx, -0.012, 0.1), Vector3(0.009, 0.009, 0.2), Vector3(0, -12 * sx, 0))
		_box("Head", fr, c + Vector3(0, -0.012, 0.203), Vector3(0.046, 0.009, 0.009))

	if a.cap:
		var cc := a.cap_color
		_cap("Head", cc, c + Vector3(0, 0.014, -0.006), R + 0.024, Vector3(0, 1, -0.15), 80, Vector3(1.0, 0.95, 0.97))
		# aba arredondada
		_sphere("Head", cc.darkened(0.12), c + Vector3(0, 0.07, 0.235), 0.13, Vector3(1.0, 0.1, 0.85), Vector3(12, 0, 0), 14, 6)
		_sphere("Head", cc.darkened(0.22), c + Vector3(0, R * 0.95 + 0.03, -0.012), 0.02)


func _make_hair() -> void:
	var a := app
	var hc := a.hair_color
	var c := HEAD_C
	var R := HEAD_R
	var sc := Vector3(1.0, 0.95, 0.97)
	var style := a.hair_style
	if a.cap and style in ["curto", "espetado", "raspado", "franja", "cacheado", "black_power"]:
		style = "raspado"
	var base := c + Vector3(0, 0.008, -0.01)
	match style:
		"raspado":
			_cap("Head", hc.lerp(a.skin, 0.3), base, R + 0.006, Vector3(0, 1, -0.6), 90, sc)
		"curto":
			_cap("Head", hc, base, R + 0.02, Vector3(0, 1, -0.55), 93, sc)
			_tufts(hc, 5, 0.0)
			for sx: float in [1.0, -1.0]:
				_sphere("Head", hc, c + Vector3(0.182 * sx, 0.02, 0.05), 0.04, Vector3(0.55, 1.5, 0.9), Vector3.ZERO, 8, 6)
		"franja":
			_cap("Head", hc, base, R + 0.02, Vector3(0, 1, -0.55), 93, sc)
			# franja reta cobrindo a testa
			_capsule("Head", hc, c + Vector3(0, 0.1, 0.158), 0.052, 0.34, Vector3(1, 0.85, 0.5), Vector3(0, 0, 90), 14)
			for sx: float in [1.0, -1.0]:
				_sphere("Head", hc, c + Vector3(0.18 * sx, -0.01, 0.06), 0.045, Vector3(0.55, 1.9, 0.95), Vector3.ZERO, 8, 6)
		"espetado":
			_cap("Head", hc, base, R + 0.016, Vector3(0, 1, -0.55), 92, sc)
			var spikes := [Vector3(0, 1, 0.45), Vector3(0.45, 0.9, 0.2), Vector3(-0.45, 0.9, 0.2), Vector3(0.22, 1, -0.3),
				Vector3(-0.22, 1, -0.3), Vector3(0, 0.8, -0.8), Vector3(0.6, 0.6, -0.4), Vector3(-0.6, 0.6, -0.4), Vector3(0, 0.75, 0.75)]
			for d in spikes:
				var dir: Vector3 = d.normalized()
				var pos: Vector3 = c + dir * (R + 0.03)
				_bone("Head", hc.lightened(0.05))
				var axis := Vector3.UP.cross(dir)
				var basis := Basis() if axis.length() < 0.001 else Basis(axis.normalized(), Vector3.UP.angle_to(dir))
				md.add_cylinder(Transform3D(basis, bone_global["Head"] + pos), 0.0, 0.06, 0.14, 7)
		"longo":
			_cap("Head", hc, base, R + 0.022, Vector3(0, 1, -0.5), 97, sc)
			# cortina de cabelo até os ombros
			_capsule("Head", hc, c + Vector3(0, -0.13, -0.085), 0.14, 0.44, Vector3(1.36, 1, 0.62), Vector3.ZERO, 16)
			for sx: float in [1.0, -1.0]:
				_capsule("Head", hc, c + Vector3(0.172 * sx, -0.1, 0.03), 0.055, 0.36, Vector3(0.75, 1, 1.05), Vector3(0, 0, -4 * sx), 10)
			_tufts(hc, 4, 0.25)
		"rabo":
			_cap("Head", hc, base, R + 0.02, Vector3(0, 1, -0.55), 95, sc)
			_tufts(hc, 4, -0.2)
			_sphere("Head", a.backpack_color.lightened(0.1), c + Vector3(0, 0.1, -0.2), 0.034, Vector3(1.2, 0.8, 0.8))
			_sphere("Head", hc, c + Vector3(0, 0.1, -0.24), 0.06)
			_capsule("Head", hc, c + Vector3(0, -0.04, -0.3), 0.06, 0.32, Vector3(1, 1, 1), Vector3(-20, 0, 0), 10)
			_sphere("Head", hc, c + Vector3(0, -0.2, -0.345), 0.045, Vector3(0.9, 1.3, 0.9))
		"cacheado":
			_cap("Head", hc, base, R + 0.012, Vector3(0, 1, -0.55), 92, sc)
			var r := RandomNumberGenerator.new()
			r.seed = 7
			var placed := 0
			var guard := 0
			while placed < 34 and guard < 200:
				guard += 1
				var d := Vector3(r.randf_range(-1, 1), r.randf_range(0.05, 1), r.randf_range(-1, 0.75))
				var dd := d.normalized()
				if dd.z > 0.45 and dd.y < 0.62:
					continue
				_sphere("Head", hc.lightened(r.randf() * 0.1), c + dd * (R + 0.012) * sc, 0.056, Vector3.ONE, Vector3.ZERO, 8, 5)
				placed += 1
		"black_power":
			# bola de cabelo grande e fofa, com a linha da testa livre
			_cap("Head", hc, c + Vector3(0, 0.035, -0.025), R + 0.075, Vector3(0, 1, -0.35), 100, Vector3(1.06, 1.0, 1.0))
			_cap("Head", hc.lightened(0.05), c + Vector3(0, 0.03, -0.02), R + 0.045, Vector3(0, 1, 0.25), 62, Vector3(1.04, 1.0, 1.0))
		_:
			_cap("Head", hc, base, R + 0.02, Vector3(0, 1, -0.55), 93, sc)


## Mechas arredondadas na testa. `lean` < 0 penteia para a esquerda, > 0 para a direita.
func _tufts(hc: Color, n: int, lean: float) -> void:
	var c := HEAD_C
	for k in n:
		var t := (k - (n - 1) * 0.5) / maxf((n - 1) * 0.5, 1.0)
		var x := t * 0.105
		var y := 0.118 - absf(t) * 0.03
		var z := 0.158 - absf(t) * 0.035
		_sphere("Head", hc.lightened(0.05 * (k % 2)), c + Vector3(x, y, z), 0.058, Vector3(1.05, 0.62, 0.7), Vector3(-18, 0, -t * 26.0 + lean * 40.0), 10, 6)
