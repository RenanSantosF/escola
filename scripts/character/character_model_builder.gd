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
	["LeftEye", "Head", Vector3(0.052, 0.14, 0.137)],
	["RightEye", "Head", Vector3(-0.052, 0.14, 0.137)],
	["LeftBrow", "Head", Vector3(0.055, 0.197, 0.137)],
	["RightBrow", "Head", Vector3(-0.055, 0.197, 0.137)],
	["Mouth", "Head", Vector3(0, 0.072, 0.139)],
]

const HEAD_C := Vector3(0, 0.14, 0)  # centro da cabeça, relativo ao osso Head
const HEAD_R := 0.155

static var _material: StandardMaterial3D

var md := MeshData.new()
var bone_index := {}
var bone_global := {}
var app: CharacterAppearance


static func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.72
		# luz "enrolada": sombra suave e arredondada, visual de desenho animado
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_material.rim_enabled = true
		_material.rim = 0.4
		_material.rim_tint = 0.75
	return _material


## Cria o Skeleton3D (com a malha como filha) para a aparência dada.
static func build(appearance: CharacterAppearance) -> Skeleton3D:
	var b := CharacterModelBuilder.new()
	b.app = appearance
	var skel := b._make_skeleton()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = b._make_mesh()
	mi.extra_cull_margin = 0.6
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	return skel


## Reconstrói apenas a malha (troca de roupa) mantendo o esqueleto.
static func rebuild_mesh(skel: Skeleton3D, appearance: CharacterAppearance) -> void:
	var b := CharacterModelBuilder.new()
	b.app = appearance
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
	md.add_sphere(_xf(bone, pos, scale, rot), r, seg, rings)


func _capsule(bone: String, col: Color, pos: Vector3, r: float, h: float, scale := Vector3.ONE, rot := Vector3.ZERO, seg := 14) -> void:
	_bone(bone, col)
	md.add_capsule(_xf(bone, pos, scale, rot), r, h, seg, 8 if seg > 8 else 4)


func _box(bone: String, col: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	_bone(bone, col)
	md.add_box(_xf(bone, pos, Vector3.ONE, rot), size)


func _cyl(bone: String, col: Color, pos: Vector3, rt: float, rb: float, h: float, rot := Vector3.ZERO, seg := 10) -> void:
	_bone(bone, col)
	md.add_cylinder(_xf(bone, pos, Vector3.ONE, rot), rt, rb, h, seg)


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
	md.add_sphere(Transform3D(basis, bone_global[bone] + pos), r, 14, 8, deg_to_rad(angle_deg))


# ------------------------------------------------------------ corpo

func _make_mesh() -> ArrayMesh:
	md.use_bones = true
	var a := app
	var bw := a.build
	var skin := a.skin
	var shirt := a.shirt_color
	var trim := a.shirt_trim
	var pants := a.pants_color

	# Pelve / bermuda
	_capsule("Hips", pants, Vector3(0, 0.03, 0), 0.145, 0.30, Vector3(1.06 * bw, 1, 0.72))
	_cyl("Hips", Color("3b2a1e"), Vector3(0, 0.13, 0), 0.153 * bw, 0.153 * bw, 0.035, Vector3.ZERO, 14)
	_box("Hips", Color("d4af37"), Vector3(0, 0.13, 0.108), Vector3(0.04, 0.03, 0.012))
	# Barriga e peito (camiseta)
	_capsule("Spine", shirt, Vector3(0, 0.08, 0), 0.148, 0.36, Vector3(1.0 * bw, 1, 0.7))
	_capsule("Chest", shirt, Vector3(0, 0.11, 0), 0.165, 0.34, Vector3(1.05 * bw, 1, 0.72))
	# Gola polo
	_cyl("Chest", trim, Vector3(0, 0.255, 0.0), 0.072, 0.085, 0.035, Vector3.ZERO, 12)
	for sx: float in [1.0, -1.0]:
		_box("Chest", trim, Vector3(0.045 * sx, 0.235, 0.085), Vector3(0.06, 0.012, 0.05), Vector3(-35, 0, 18 * sx))
	_box("Chest", shirt.darkened(0.08), Vector3(0, 0.17, 0.118), Vector3(0.012, 0.09, 0.008))
	if a.shirt_logo:
		_box("Chest", trim, Vector3(0.075, 0.13, 0.118), Vector3(0.055, 0.055, 0.012))
		_box("Chest", Color("f2c230"), Vector3(0.075, 0.13, 0.124), Vector3(0.03, 0.03, 0.006))
	# cintura arredondada (une bermuda e camiseta sem "degrau")
	_sphere("Spine", shirt, Vector3(0, -0.02, 0), 0.15, Vector3(1.0 * bw, 0.6, 0.72))
	# Pescoço
	_cyl("Neck", skin.darkened(0.04), Vector3(0, 0.02, 0), 0.052, 0.058, 0.12, Vector3.ZERO, 14)

	_make_head()

	# Braços
	for side: String in ["Left", "Right"]:
		var sx := 1.0 if side == "Left" else -1.0
		# ombro arredondado e manga
		_sphere(side + "UpperArm", shirt, Vector3(0.0, 0.0, 0), 0.07, Vector3(bw, 0.95, 0.95))
		_capsule(side + "UpperArm", shirt, Vector3(0.0, -0.06, 0), 0.064, 0.2, Vector3(bw, 1, 1))
		# cotovelo (esconde a emenda do braço ao dobrar)
		_sphere(side + "LowerArm", skin, Vector3.ZERO, 0.045, Vector3.ONE, Vector3.ZERO, 10, 7)
		_cyl(side + "UpperArm", trim, Vector3(0, -0.15, 0), 0.064, 0.064, 0.028)
		_capsule(side + "UpperArm", skin, Vector3(0, -0.15, 0), 0.046, 0.21)
		_capsule(side + "LowerArm", skin, Vector3(0, -0.11, 0), 0.043, 0.25)
		# palma + 4 dedos + polegar
		_sphere(side + "Hand", skin, Vector3(0, -0.045, 0.005), 0.042, Vector3(0.7, 1.0, 1.0))
		for f in 4:
			var fz := -0.018 + f * 0.013
			_capsule(side + "Hand", skin.darkened(0.02 * (f % 2)), Vector3(0.0, -0.09, fz + 0.005), 0.0085, 0.05 - absf(f - 1.5) * 0.006, Vector3.ONE, Vector3(8, 0, 0), 6)
		_capsule(side + "Hand", skin.darkened(0.03), Vector3(0.012 * sx, -0.04, 0.035), 0.009, 0.045, Vector3.ONE, Vector3(-35, 0, 25 * sx), 6)

	# Pernas
	for side: String in ["Left", "Right"]:
		var up_leg: String = side + "UpperLeg"
		var low_leg: String = side + "LowerLeg"
		var foot: String = side + "Foot"
		_capsule(up_leg, pants, Vector3(0, -0.17, 0), 0.08 * bw, 0.40)
		# joelho
		_sphere(low_leg, pants if a.long_pants else skin, Vector3.ZERO, 0.058 if a.long_pants else 0.055, Vector3.ONE, Vector3.ZERO, 10, 7)
		if a.long_pants:
			_capsule(low_leg, pants, Vector3(0, -0.16, 0), 0.066, 0.42)
			_cyl(low_leg, pants.darkened(0.1), Vector3(0, -0.34, 0), 0.07, 0.072, 0.04)
		else:
			_cyl(up_leg, pants.darkened(0.08), Vector3(0, -0.33, 0), 0.08 * bw, 0.08 * bw, 0.03)
			_capsule(low_leg, skin, Vector3(0, -0.15, 0), 0.054, 0.38)
			_cyl(low_leg, a.sock_color, Vector3(0, -0.3, 0), 0.058, 0.056, 0.12)
		# Tênis
		_capsule(foot, a.shoe_color, Vector3(0, -0.025, 0.045), 0.058, 0.25, Vector3(1, 0.85, 1), Vector3(90, 0, 0))
		_box(foot, a.shoe_sole, Vector3(0, -0.062, 0.045), Vector3(0.11, 0.026, 0.25))
		_box(foot, a.shoe_color.darkened(0.25), Vector3(0, 0.012, 0.085), Vector3(0.05, 0.012, 0.08), Vector3(-20, 0, 0))
		for l in 3:
			_box(foot, Color("fdfdfd") if a.shoe_color.get_luminance() < 0.7 else Color("2d3436"), Vector3(0, 0.016 + l * 0.008, 0.06 + l * 0.022), Vector3(0.056, 0.007, 0.008), Vector3(-20, 0, 0))
		_box(foot, a.shoe_color.lerp(Color.WHITE, 0.4), Vector3(0.056, -0.03, 0.03), Vector3(0.006, 0.03, 0.12))

	if a.backpack:
		var bp := a.backpack_color
		_capsule("Chest", bp, Vector3(0, 0.08, -0.19), 0.14, 0.4, Vector3(1.05, 1, 0.5))
		_capsule("Chest", bp.darkened(0.2), Vector3(0, -0.01, -0.255), 0.07, 0.17, Vector3(1.4, 1, 0.45), Vector3(0, 0, 90))
		_box("Chest", Color("eeeeee"), Vector3(0, 0.07, -0.287), Vector3(0.12, 0.012, 0.006))
		for sx: float in [1.0, -1.0]:
			_box("Chest", bp.darkened(0.35), Vector3(0.1 * sx, 0.2, -0.02), Vector3(0.035, 0.05, 0.27), Vector3(25, 0, 0))
			_box("Chest", bp.darkened(0.35), Vector3(0.11 * sx, 0.07, 0.12), Vector3(0.035, 0.3, 0.012), Vector3(-6, 0, 0))

	return md.build_mesh(get_material())


func _make_head() -> void:
	var a := app
	var skin := a.skin
	var c := HEAD_C
	# Crânio levemente oval
	_sphere("Head", skin, c, HEAD_R, Vector3(0.98, 1.03, 1.0), Vector3.ZERO, 16, 12)
	# Bochecha/queixo suave
	_sphere("Head", skin, c + Vector3(0, -0.06, 0.035), 0.11, Vector3(1.0, 0.8, 1.0), Vector3.ZERO, 12, 8)
	# Orelhas
	for sx: float in [1.0, -1.0]:
		_sphere("Head", skin.darkened(0.06), c + Vector3(0.148 * sx, -0.005, 0.0), 0.036, Vector3(0.45, 1.0, 0.75))
		# Bochechas rosadas
		_sphere("Head", skin.lerp(Color("ff8f8f"), 0.35), c + Vector3(0.082 * sx, -0.045, 0.118), 0.024, Vector3(1.0, 0.7, 0.35), Vector3.ZERO, 8, 5)
	# Nariz
	_sphere("Head", skin.darkened(0.08), c + Vector3(0, -0.025, 0.152), 0.022, Vector3(1.0, 0.9, 0.8), Vector3.ZERO, 8, 6)
	# Olhos (osso próprio para piscar)
	for side: String in ["Left", "Right"]:
		# esclera branca, íris colorida, pupila e brilho
		_sphere(side + "Eye", Color("fbfbf8"), Vector3(0, 0, -0.004), 0.031, Vector3(1.0, 1.2, 0.42), Vector3.ZERO, 12, 8)
		_sphere(side + "Eye", a.eye_color.lightened(0.15), Vector3(0, -0.002, 0.007), 0.019, Vector3(1.0, 1.2, 0.4), Vector3.ZERO, 10, 7)
		_sphere(side + "Eye", Color("15100c"), Vector3(0, -0.002, 0.010), 0.0105, Vector3(1.0, 1.15, 0.4), Vector3.ZERO, 8, 5)
		_sphere(side + "Eye", Color.WHITE, Vector3(0.007, 0.009, 0.013), 0.0055, Vector3.ONE, Vector3.ZERO, 6, 4)
		var sx := 1.0 if side == "Left" else -1.0
		_box(side + "Brow", a.hair_color.darkened(0.1), Vector3.ZERO, Vector3(0.05, 0.012, 0.014), Vector3(0, 0, 8 * sx))
	# Boca (sorriso simples)
	_box("Mouth", Color("7a2a2a"), Vector3(0, 0, 0), Vector3(0.036, 0.011, 0.012))
	_box("Mouth", Color("7a2a2a"), Vector3(0.022, 0.004, -0.002), Vector3(0.014, 0.01, 0.012), Vector3(0, 0, 30))
	_box("Mouth", Color("7a2a2a"), Vector3(-0.022, 0.004, -0.002), Vector3(0.014, 0.01, 0.012), Vector3(0, 0, -30))

	_make_hair()

	if a.glasses:
		var fr := Color("1c1c1c")
		for sx: float in [1.0, -1.0]:
			var e := c + Vector3(0.052 * sx, 0.0, 0.158)
			_box("Head", fr, e + Vector3(0, 0.03, 0), Vector3(0.07, 0.01, 0.01))
			_box("Head", fr, e + Vector3(0, -0.03, 0), Vector3(0.07, 0.01, 0.01))
			_box("Head", fr, e + Vector3(0.035, 0, 0), Vector3(0.01, 0.07, 0.01))
			_box("Head", fr, e + Vector3(-0.035, 0, 0), Vector3(0.01, 0.07, 0.01))
			_box("Head", fr, c + Vector3(0.14 * sx, 0.0, 0.07), Vector3(0.01, 0.01, 0.16))
		_box("Head", fr, c + Vector3(0, 0.01, 0.16), Vector3(0.035, 0.008, 0.01))

	if a.cap:
		var cc := a.cap_color
		_cap("Head", cc, c + Vector3(0, 0.012, -0.005), HEAD_R + 0.02, Vector3(0, 1, -0.15), 82)
		_box("Head", cc.darkened(0.1), c + Vector3(0, 0.07, 0.18), Vector3(0.2, 0.014, 0.13), Vector3(12, 0, 0))
		_sphere("Head", cc.darkened(0.2), c + Vector3(0, HEAD_R + 0.03, -0.01), 0.016)


func _make_hair() -> void:
	var a := app
	var hc := a.hair_color
	var c := HEAD_C
	var style := a.hair_style
	if a.cap and style in ["curto", "espetado", "raspado", "franja", "cacheado"]:
		style = "raspado"
	match style:
		"raspado":
			_cap("Head", hc.lerp(a.skin, 0.25), c + Vector3(0, 0.004, -0.004), HEAD_R + 0.006, Vector3(0, 1, -0.6), 90)
		"curto":
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.014, Vector3(0, 1, -0.6), 92)
			for sx: float in [1.0, -1.0]:
				_box("Head", hc, c + Vector3(0.143 * sx, -0.01, 0.045), Vector3(0.02, 0.06, 0.03))
			_sphere("Head", hc, c + Vector3(0.03, 0.105, 0.1), 0.06, Vector3(1.6, 0.55, 0.8), Vector3(0, 0, -12))
		"franja":
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.014, Vector3(0, 1, -0.6), 92)
			_capsule("Head", hc, c + Vector3(0, 0.085, 0.118), 0.045, 0.27, Vector3(1, 1, 0.55), Vector3(0, 0, 90))
			for sx: float in [1.0, -1.0]:
				_box("Head", hc, c + Vector3(0.143 * sx, -0.02, 0.04), Vector3(0.022, 0.08, 0.04))
		"espetado":
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.012, Vector3(0, 1, -0.6), 90)
			var spikes := [Vector3(0, 1, 0.35), Vector3(0.45, 0.9, 0.1), Vector3(-0.45, 0.9, 0.1), Vector3(0.2, 1, -0.4),
				Vector3(-0.2, 1, -0.4), Vector3(0, 0.8, -0.8), Vector3(0.55, 0.6, -0.5), Vector3(-0.55, 0.6, -0.5)]
			for d in spikes:
				var dir: Vector3 = d.normalized()
				var pos: Vector3 = c + dir * (HEAD_R + 0.03)
				_bone("Head", hc)
				var axis := Vector3.UP.cross(dir)
				var basis := Basis() if axis.length() < 0.001 else Basis(axis.normalized(), Vector3.UP.angle_to(dir))
				md.add_cylinder(Transform3D(basis, bone_global["Head"] + pos), 0.0, 0.045, 0.1, 6)
		"longo":
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.016, Vector3(0, 1, -0.55), 96)
			_capsule("Head", hc, c + Vector3(0, -0.1, -0.075), 0.11, 0.34, Vector3(1.35, 1, 0.6))
			for sx: float in [1.0, -1.0]:
				_capsule("Head", hc, c + Vector3(0.13 * sx, -0.08, 0.02), 0.045, 0.28, Vector3(0.8, 1, 1))
			_sphere("Head", hc, c + Vector3(-0.03, 0.105, 0.1), 0.065, Vector3(1.6, 0.55, 0.8), Vector3(0, 0, 14))
		"rabo":
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.014, Vector3(0, 1, -0.6), 94)
			_sphere("Head", hc, c + Vector3(0, 0.07, -0.165), 0.05)
			_capsule("Head", hc, c + Vector3(0, -0.06, -0.21), 0.05, 0.26, Vector3(1, 1, 1), Vector3(-18, 0, 0))
			_sphere("Head", a.backpack_color, c + Vector3(0, 0.06, -0.19), 0.025)
		"cacheado":
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.012, Vector3(0, 1, -0.6), 92)
			var r := RandomNumberGenerator.new()
			r.seed = 7
			for i in 22:
				var d := Vector3(r.randf_range(-1, 1), r.randf_range(0.1, 1), r.randf_range(-1, 0.5))
				var dd := d.normalized()
				if dd.z > 0.35 and dd.y < 0.55:
					continue
				_sphere("Head", hc.lightened(r.randf() * 0.08), c + dd * (HEAD_R + 0.01), 0.045, Vector3.ONE, Vector3.ZERO, 7, 5)
		"black_power":
			_cap("Head", hc, c + Vector3(0, 0.045, -0.035), HEAD_R + 0.065, Vector3(0, 1, -0.7), 100)
		_:
			_cap("Head", hc, c + Vector3(0, 0.006, -0.006), HEAD_R + 0.014, Vector3(0, 1, -0.6), 92)
