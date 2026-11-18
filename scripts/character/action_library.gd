class_name ActionLibrary
extends RefCounted
## Biblioteca de ações animadas (keyframes em graus, interpolados com spline).
##
## Convenções (personagem olhando para +Z, esquerda = +X):
## - Braços/pernas (apontam para baixo): X+ = para trás, X- = para frente.
## - LowerLeg X+ = dobrar joelho.  LowerArm X- = dobrar cotovelo.
## - Foot X+ = ponta para baixo.
## - Spine/Chest/Neck/Head: X+ = inclinar para frente, Y+ = girar para a
##   esquerda, Z+ = inclinar para a direita.
## - LeftUpperArm Z+ / RightUpperArm Z- = abrir o braço lateralmente.
## Chaves especiais: "hips" (deslocamento do quadril em metros),
## "eyes" (1 = aberto), "mouth" (escala vertical), "brow" (1 = triste).

const UPPER_BODY := ["Spine", "Chest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]

const SIT := {
	"hips": Vector3(0, -0.30, -0.04),
	"Spine": Vector3(4, 0, 0), "Chest": Vector3(2, 0, 0), "Head": Vector3(3, 0, 0),
	"LeftUpperLeg": Vector3(-78, 0, 5), "RightUpperLeg": Vector3(-78, 0, -5),
	"LeftLowerLeg": Vector3(86, 0, 0), "RightLowerLeg": Vector3(86, 0, 0),
	"LeftFoot": Vector3(-8, 0, 0), "RightFoot": Vector3(-8, 0, 0),
	"LeftUpperArm": Vector3(-30, 0, 8), "RightUpperArm": Vector3(-30, 0, -8),
	"LeftLowerArm": Vector3(-55, 0, 0), "RightLowerArm": Vector3(-55, 0, 0),
}

const SIT_HALF := {
	"hips": Vector3(0, -0.2, 0.02),
	"Spine": Vector3(26, 0, 0), "Chest": Vector3(8, 0, 0), "Head": Vector3(-12, 0, 0),
	"LeftUpperLeg": Vector3(-55, 0, 4), "RightUpperLeg": Vector3(-55, 0, -4),
	"LeftLowerLeg": Vector3(70, 0, 0), "RightLowerLeg": Vector3(70, 0, 0),
	"LeftFoot": Vector3(-15, 0, 0), "RightFoot": Vector3(-15, 0, 0),
	"LeftUpperArm": Vector3(-35, 0, 12), "RightUpperArm": Vector3(-35, 0, -12),
	"LeftLowerArm": Vector3(-30, 0, 0), "RightLowerArm": Vector3(-30, 0, 0),
}

static var _defs: Dictionary = {}


static func get_def(action: String) -> Dictionary:
	if _defs.is_empty():
		_build()
	return _defs.get(action, {})


static func has_action(action: String) -> bool:
	return not get_def(action).is_empty()


static func _build() -> void:
	_defs["sit_down"] = {
		"duration": 0.75, "hold": true, "fade_in": 0.1,
		"keys": [[0.0, {}], [0.45, SIT_HALF], [1.0, SIT]],
	}
	_defs["stand_up"] = {
		"duration": 0.7, "fade_out": 0.15,
		"keys": [[0.0, SIT], [0.45, SIT_HALF], [1.0, {}]],
	}
	_defs["kick"] = {
		"duration": 0.8, "events": {"impact": 0.44},
		"keys": [
			[0.0, {}],
			[0.32, {"hips": Vector3(0, -0.04, -0.02),
				"RightUpperLeg": Vector3(40, 0, 0), "RightLowerLeg": Vector3(78, 0, 0), "RightFoot": Vector3(20, 0, 0),
				"LeftUpperLeg": Vector3(-8, 0, 0), "LeftLowerLeg": Vector3(18, 0, 0), "LeftFoot": Vector3(-10, 0, 0),
				"Spine": Vector3(-6, 10, 0), "Chest": Vector3(0, 8, 0),
				"LeftUpperArm": Vector3(-30, 0, 32), "LeftLowerArm": Vector3(-30, 0, 0),
				"RightUpperArm": Vector3(35, 0, -18), "RightLowerArm": Vector3(-20, 0, 0)}],
			[0.46, {"hips": Vector3(0, -0.03, 0.05),
				"RightUpperLeg": Vector3(-58, 0, 0), "RightLowerLeg": Vector3(14, 0, 0), "RightFoot": Vector3(28, 0, 0),
				"LeftUpperLeg": Vector3(6, 0, 0), "LeftLowerLeg": Vector3(16, 0, 0), "LeftFoot": Vector3(-20, 0, 0),
				"Spine": Vector3(-12, -8, 0), "Chest": Vector3(-4, -6, 0),
				"LeftUpperArm": Vector3(20, 0, 48), "LeftLowerArm": Vector3(-25, 0, 0),
				"RightUpperArm": Vector3(-32, 0, -32), "RightLowerArm": Vector3(-20, 0, 0)}],
			[0.64, {"hips": Vector3(0, -0.02, 0.06),
				"RightUpperLeg": Vector3(-68, 0, 0), "RightLowerLeg": Vector3(30, 0, 0), "RightFoot": Vector3(10, 0, 0),
				"LeftUpperLeg": Vector3(4, 0, 0), "LeftLowerLeg": Vector3(12, 0, 0), "LeftFoot": Vector3(-14, 0, 0),
				"Spine": Vector3(-10, -10, 0), "LeftUpperArm": Vector3(10, 0, 35), "RightUpperArm": Vector3(-20, 0, -25)}],
			[1.0, {}],
		],
	}
	_defs["throw"] = {
		"duration": 0.85, "events": {"release": 0.5},
		"keys": [
			[0.0, {}],
			[0.36, {"hips": Vector3(0, -0.04, -0.03),
				"RightUpperArm": Vector3(10, -45, -75), "RightLowerArm": Vector3(-75, 0, 0),
				"LeftUpperArm": Vector3(-70, 0, 15), "LeftLowerArm": Vector3(-20, 0, 0),
				"Spine": Vector3(-6, -32, 0), "Chest": Vector3(0, -12, 0), "Head": Vector3(0, 30, 0),
				"LeftUpperLeg": Vector3(-20, 0, 0), "LeftLowerLeg": Vector3(14, 0, 0), "LeftFoot": Vector3(6, 0, 0),
				"RightUpperLeg": Vector3(14, 0, 0), "RightLowerLeg": Vector3(12, 0, 0), "RightFoot": Vector3(-20, 0, 0)}],
			[0.52, {"hips": Vector3(0, -0.05, 0.06),
				"RightUpperArm": Vector3(-10, 55, -70), "RightLowerArm": Vector3(-20, 0, 0),
				"LeftUpperArm": Vector3(15, 0, 22), "LeftLowerArm": Vector3(-40, 0, 0),
				"Spine": Vector3(14, 22, 0), "Chest": Vector3(4, 10, 0), "Head": Vector3(-8, -25, 0),
				"LeftUpperLeg": Vector3(-24, 0, 0), "LeftLowerLeg": Vector3(22, 0, 0), "LeftFoot": Vector3(2, 0, 0),
				"RightUpperLeg": Vector3(18, 0, 0), "RightLowerLeg": Vector3(25, 0, 0), "RightFoot": Vector3(-30, 0, 0)}],
			[0.72, {"hips": Vector3(0, -0.04, 0.07),
				"RightUpperArm": Vector3(-30, 80, -40), "RightLowerArm": Vector3(-30, 0, 0),
				"Spine": Vector3(18, 26, 0), "Head": Vector3(-10, -26, 0),
				"LeftUpperLeg": Vector3(-20, 0, 0), "LeftLowerLeg": Vector3(20, 0, 0),
				"RightUpperLeg": Vector3(14, 0, 0), "RightLowerLeg": Vector3(30, 0, 0), "RightFoot": Vector3(-25, 0, 0)}],
			[1.0, {}],
		],
	}
	_defs["interact"] = {
		"duration": 0.75, "mask": "upper", "events": {"use": 0.45},
		"keys": [
			[0.0, {}],
			[0.4, {"RightUpperArm": Vector3(-72, 0, -6), "RightLowerArm": Vector3(-18, 0, 0),
				"Spine": Vector3(8, 6, 0), "Head": Vector3(10, 0, 0)}],
			[0.6, {"RightUpperArm": Vector3(-68, 0, -6), "RightLowerArm": Vector3(-28, 0, 0),
				"Spine": Vector3(6, 4, 0), "Head": Vector3(8, 0, 0)}],
			[1.0, {}],
		],
	}
	_defs["drink"] = {
		"duration": 1.6, "events": {"use": 0.35},
		"keys": [
			[0.0, {}],
			[0.25, {"hips": Vector3(0, -0.03, -0.02), "Spine": Vector3(32, 0, 0), "Chest": Vector3(10, 0, 0),
				"Head": Vector3(-10, 0, 0), "RightUpperArm": Vector3(-60, 0, -10), "RightLowerArm": Vector3(-10, 0, 0),
				"LeftUpperArm": Vector3(10, 0, 18), "LeftUpperLeg": Vector3(-6, 0, 0), "RightUpperLeg": Vector3(-6, 0, 0),
				"LeftLowerLeg": Vector3(8, 0, 0), "RightLowerLeg": Vector3(8, 0, 0)}],
			[0.75, {"hips": Vector3(0, -0.03, -0.02), "Spine": Vector3(34, 0, 0), "Chest": Vector3(10, 0, 0),
				"Head": Vector3(-14, 0, 0), "RightUpperArm": Vector3(-62, 0, -10), "RightLowerArm": Vector3(-10, 0, 0),
				"LeftUpperArm": Vector3(10, 0, 18), "eyes": 0.3}],
			[1.0, {"mouth": 1.4}],
		],
	}
	_defs["pickup"] = {
		"duration": 1.0, "events": {"grab": 0.48},
		"keys": [
			[0.0, {}],
			[0.45, {"hips": Vector3(0, -0.25, -0.02),
				"Spine": Vector3(32, 0, 0), "Chest": Vector3(14, 0, 0), "Neck": Vector3(6, 0, 0), "Head": Vector3(-10, 0, 0),
				"LeftUpperLeg": Vector3(-55, 0, 6), "RightUpperLeg": Vector3(-50, 0, -6),
				"LeftLowerLeg": Vector3(95, 0, 0), "RightLowerLeg": Vector3(90, 0, 0),
				"LeftFoot": Vector3(-40, 0, 0), "RightFoot": Vector3(-40, 0, 0),
				"RightUpperArm": Vector3(-35, 0, -8), "RightLowerArm": Vector3(-8, 0, 0),
				"LeftUpperArm": Vector3(-10, 0, 20), "LeftLowerArm": Vector3(-30, 0, 0)}],
			[0.58, {"hips": Vector3(0, -0.24, -0.02),
				"Spine": Vector3(30, 0, 0), "Chest": Vector3(12, 0, 0), "Head": Vector3(-8, 0, 0),
				"LeftUpperLeg": Vector3(-52, 0, 6), "RightUpperLeg": Vector3(-48, 0, -6),
				"LeftLowerLeg": Vector3(90, 0, 0), "RightLowerLeg": Vector3(86, 0, 0),
				"LeftFoot": Vector3(-38, 0, 0), "RightFoot": Vector3(-38, 0, 0),
				"RightUpperArm": Vector3(-45, 0, -8), "RightLowerArm": Vector3(-35, 0, 0)}],
			[1.0, {}],
		],
	}
	var arms_up := {"LeftUpperArm": Vector3(-10, 0, 160), "RightUpperArm": Vector3(-10, 0, -160),
		"LeftLowerArm": Vector3(-15, 0, 0), "RightLowerArm": Vector3(-15, 0, 0)}
	_defs["celebrate"] = {
		"duration": 1.9,
		"keys": [
			[0.0, {}],
			[0.1, _merge(arms_up, {"hips": Vector3(0, -0.08, 0), "mouth": 2.2,
				"LeftUpperLeg": Vector3(-24, 0, 4), "RightUpperLeg": Vector3(-24, 0, -4),
				"LeftLowerLeg": Vector3(46, 0, 0), "RightLowerLeg": Vector3(46, 0, 0),
				"LeftFoot": Vector3(-22, 0, 0), "RightFoot": Vector3(-22, 0, 0), "Spine": Vector3(8, 0, 0)})],
			[0.22, _merge(arms_up, {"hips": Vector3(0, 0.11, 0), "mouth": 2.4, "Spine": Vector3(-8, 0, 0),
				"Head": Vector3(-14, 0, 0), "LeftFoot": Vector3(25, 0, 0), "RightFoot": Vector3(25, 0, 0)})],
			[0.34, {"hips": Vector3(0, -0.05, 0), "mouth": 2.0,
				"LeftUpperArm": Vector3(-20, 0, 120), "RightUpperArm": Vector3(-20, 0, -120),
				"LeftLowerArm": Vector3(-90, 0, 0), "RightLowerArm": Vector3(-90, 0, 0),
				"LeftUpperLeg": Vector3(-16, 0, 0), "RightUpperLeg": Vector3(-16, 0, 0),
				"LeftLowerLeg": Vector3(32, 0, 0), "RightLowerLeg": Vector3(32, 0, 0),
				"LeftFoot": Vector3(-16, 0, 0), "RightFoot": Vector3(-16, 0, 0)}],
			[0.48, _merge(arms_up, {"hips": Vector3(0, 0.08, 0), "mouth": 2.4, "Head": Vector3(-12, 0, 0),
				"LeftFoot": Vector3(20, 0, 0), "RightFoot": Vector3(20, 0, 0)})],
			[0.6, {"hips": Vector3(0, -0.04, 0), "mouth": 2.0,
				"LeftUpperArm": Vector3(-60, 0, 30), "RightUpperArm": Vector3(-10, 0, -150),
				"LeftLowerArm": Vector3(-100, 0, 0), "RightLowerArm": Vector3(-40, 0, 0),
				"LeftLowerLeg": Vector3(20, 0, 0), "RightLowerLeg": Vector3(20, 0, 0)}],
			[0.72, {"hips": Vector3(0, -0.02, 0), "mouth": 1.8,
				"LeftUpperArm": Vector3(-60, 0, 30), "RightUpperArm": Vector3(-10, 0, -120),
				"LeftLowerArm": Vector3(-100, 0, 0), "RightLowerArm": Vector3(-90, 0, 0), "Spine": Vector3(-5, -8, 0)}],
			[0.84, {"hips": Vector3(0, -0.02, 0), "mouth": 1.6,
				"LeftUpperArm": Vector3(-60, 0, 30), "RightUpperArm": Vector3(-10, 0, -150),
				"LeftLowerArm": Vector3(-100, 0, 0), "RightLowerArm": Vector3(-40, 0, 0), "Spine": Vector3(-5, -8, 0)}],
			[1.0, {}],
		],
	}
	_defs["hit"] = {
		"duration": 0.75,
		"keys": [
			[0.0, {}],
			[0.12, {"hips": Vector3(0, -0.03, -0.07), "Spine": Vector3(-20, 0, 4), "Chest": Vector3(-12, 0, 0),
				"Neck": Vector3(-6, 0, 0), "Head": Vector3(-22, 8, 0), "eyes": 0.15, "mouth": 1.9,
				"LeftUpperArm": Vector3(-25, 0, 50), "RightUpperArm": Vector3(-25, 0, -50),
				"LeftLowerArm": Vector3(-40, 0, 0), "RightLowerArm": Vector3(-40, 0, 0),
				"LeftUpperLeg": Vector3(-12, 0, 0), "LeftLowerLeg": Vector3(18, 0, 0), "RightUpperLeg": Vector3(6, 0, 0)}],
			[0.4, {"hips": Vector3(0, -0.05, -0.03), "Spine": Vector3(10, 0, 0), "Head": Vector3(12, -6, 0), "eyes": 0.5,
				"LeftUpperArm": Vector3(-10, 0, 20), "RightUpperArm": Vector3(-70, 0, -40), "RightLowerArm": Vector3(-110, 0, 0),
				"LeftLowerLeg": Vector3(16, 0, 0), "RightLowerLeg": Vector3(16, 0, 0)}],
			[1.0, {}],
		],
	}
	_defs["sad"] = {
		"duration": 2.6,
		"keys": [
			[0.0, {}],
			[0.2, {"Head": Vector3(26, 0, 0), "Neck": Vector3(10, 0, 0), "Spine": Vector3(12, 0, 0), "Chest": Vector3(6, 0, 0),
				"LeftShoulder": Vector3(0, 0, -6), "RightShoulder": Vector3(0, 0, 6), "brow": 1.0, "mouth": 0.6, "eyes": 0.7,
				"LeftUpperArm": Vector3(4, 0, 2), "RightUpperArm": Vector3(4, 0, -2), "hips": Vector3(0, -0.02, 0)}],
			[0.45, {"Head": Vector3(16, 0, 0), "Neck": Vector3(4, 0, 0), "Spine": Vector3(4, 0, 0), "Chest": Vector3(-4, 0, 0),
				"LeftShoulder": Vector3(0, 0, 8), "RightShoulder": Vector3(0, 0, -8), "brow": 1.0, "mouth": 0.7, "eyes": 0.5,
				"hips": Vector3(0, 0.0, 0)}],
			[0.7, {"Head": Vector3(30, 0, 0), "Neck": Vector3(12, 0, 0), "Spine": Vector3(14, 0, 0), "Chest": Vector3(8, 0, 0),
				"LeftShoulder": Vector3(0, 0, -8), "RightShoulder": Vector3(0, 0, 8), "brow": 1.0, "mouth": 0.6, "eyes": 0.6,
				"LeftUpperArm": Vector3(6, 0, 1), "RightUpperArm": Vector3(6, 0, -1), "hips": Vector3(0, -0.025, 0)}],
			[1.0, {}],
		],
	}
	_defs["wave"] = {
		"duration": 1.5, "mask": "upper",
		"keys": [
			[0.0, {}],
			[0.2, {"RightUpperArm": Vector3(-10, 0, -150), "RightLowerArm": Vector3(-20, 0, 20), "Head": Vector3(0, -6, 4), "mouth": 1.6}],
			[0.35, {"RightUpperArm": Vector3(-10, 0, -148), "RightLowerArm": Vector3(-20, 0, -25), "mouth": 1.6}],
			[0.5, {"RightUpperArm": Vector3(-10, 0, -150), "RightLowerArm": Vector3(-20, 0, 20), "mouth": 1.6}],
			[0.65, {"RightUpperArm": Vector3(-10, 0, -148), "RightLowerArm": Vector3(-20, 0, -25), "mouth": 1.6}],
			[0.8, {"RightUpperArm": Vector3(-10, 0, -150), "RightLowerArm": Vector3(-20, 0, 15), "mouth": 1.4}],
			[1.0, {}],
		],
	}
	_defs["stretch"] = {
		"duration": 2.4,
		"keys": [
			[0.0, {}],
			[0.35, {"LeftUpperArm": Vector3(-5, 0, 168), "RightUpperArm": Vector3(-5, 0, -168),
				"LeftLowerArm": Vector3(-35, 0, 0), "RightLowerArm": Vector3(-35, 0, 0),
				"Spine": Vector3(-10, 0, 0), "Chest": Vector3(-6, 0, 0), "Head": Vector3(-16, 0, 0),
				"mouth": 2.4, "eyes": 0.15, "hips": Vector3(0, 0.015, 0)}],
			[0.6, {"LeftUpperArm": Vector3(-5, 0, 165), "RightUpperArm": Vector3(-5, 0, -165),
				"LeftLowerArm": Vector3(-30, 0, 0), "RightLowerArm": Vector3(-30, 0, 0),
				"Spine": Vector3(-8, 0, 6), "Chest": Vector3(-4, 0, 4), "Head": Vector3(-12, 0, 0),
				"mouth": 2.0, "eyes": 0.2, "hips": Vector3(0, 0.015, 0)}],
			[1.0, {}],
		],
	}
	_defs["look_around"] = {
		"duration": 2.4, "mask": "upper",
		"keys": [
			[0.0, {}],
			[0.25, {"Head": Vector3(0, 55, 0), "Neck": Vector3(0, 10, 0), "Chest": Vector3(0, 8, 0)}],
			[0.45, {"Head": Vector3(0, 52, 0), "Neck": Vector3(0, 10, 0), "Chest": Vector3(0, 8, 0)}],
			[0.7, {"Head": Vector3(0, -50, 0), "Neck": Vector3(0, -10, 0), "Chest": Vector3(0, -8, 0)}],
			[0.85, {"Head": Vector3(0, -48, 0), "Neck": Vector3(0, -8, 0), "Chest": Vector3(0, -6, 0)}],
			[1.0, {}],
		],
	}
	_defs["crouch"] = {
		"duration": 0.6, "hold": true,
		"keys": [[0.0, {}], [1.0, {"hips": Vector3(0, -0.42, -0.05),
			"Spine": Vector3(30, 0, 0), "Chest": Vector3(10, 0, 0), "Head": Vector3(-10, 0, 0),
			"LeftUpperLeg": Vector3(-95, 0, 14), "RightUpperLeg": Vector3(-80, 0, -14),
			"LeftLowerLeg": Vector3(140, 0, 0), "RightLowerLeg": Vector3(130, 0, 0),
			"LeftFoot": Vector3(-45, 0, 0), "RightFoot": Vector3(-50, 0, 0),
			"LeftUpperArm": Vector3(-40, 0, 10), "RightUpperArm": Vector3(-55, 0, -10),
			"LeftLowerArm": Vector3(-50, 0, 0), "RightLowerArm": Vector3(-20, 0, 0)}]],
	}
	_defs["flick"] = {
		"duration": 0.8, "mask": "upper", "additive": true, "events": {"flick": 0.5},
		"keys": [[0.0, {}], [0.4, {"RightUpperArm": Vector3(-10, 0, 0), "RightLowerArm": Vector3(-25, 0, 0)}],
			[0.5, {"RightUpperArm": Vector3(-20, 0, 0), "RightLowerArm": Vector3(10, 0, 0)}], [1.0, {}]],
	}
	_defs["talk"] = {
		"duration": 2.4, "mask": "upper", "additive": true, "loop": true,
		"keys": [[0.0, {}],
			[0.2, {"RightUpperArm": Vector3(-25, 0, -8), "RightLowerArm": Vector3(-45, 0, 0), "Head": Vector3(-3, 6, 0), "mouth": 1.5}],
			[0.35, {"RightUpperArm": Vector3(-20, 0, -12), "RightLowerArm": Vector3(-55, 0, 0), "Head": Vector3(2, 3, 0), "mouth": 0.8}],
			[0.5, {"LeftUpperArm": Vector3(-25, 0, 10), "LeftLowerArm": Vector3(-50, 0, 0), "Head": Vector3(-2, -6, 0), "mouth": 1.6}],
			[0.7, {"LeftUpperArm": Vector3(-15, 0, 12), "LeftLowerArm": Vector3(-35, 0, 0), "Head": Vector3(3, -2, 0), "mouth": 0.9}],
			[0.85, {"Head": Vector3(-4, 2, 0), "mouth": 1.4}],
			[1.0, {}]],
	}
	_defs["write"] = {
		"duration": 1.6, "mask": "upper", "loop": true,
		"keys": [[0.0, {"RightUpperArm": Vector3(-38, 0, -10), "RightLowerArm": Vector3(-75, 0, 0),
				"LeftUpperArm": Vector3(-35, 0, 12), "LeftLowerArm": Vector3(-80, 0, 0), "Head": Vector3(22, 0, 0), "Spine": Vector3(10, 0, 0)}],
			[0.5, {"RightUpperArm": Vector3(-40, 6, -6), "RightLowerArm": Vector3(-72, 0, 0),
				"LeftUpperArm": Vector3(-35, 0, 12), "LeftLowerArm": Vector3(-80, 0, 0), "Head": Vector3(24, 4, 0), "Spine": Vector3(10, 0, 0)}],
			[1.0, {"RightUpperArm": Vector3(-38, 0, -10), "RightLowerArm": Vector3(-75, 0, 0),
				"LeftUpperArm": Vector3(-35, 0, 12), "LeftLowerArm": Vector3(-80, 0, 0), "Head": Vector3(22, 0, 0), "Spine": Vector3(10, 0, 0)}]],
	}
	_defs["raise_hand"] = {
		"duration": 2.2, "mask": "upper",
		"keys": [[0.0, {}], [0.2, {"RightUpperArm": Vector3(-10, 0, -165), "RightLowerArm": Vector3(-10, 0, 0), "Head": Vector3(-6, 0, 0), "mouth": 1.3}],
			[0.8, {"RightUpperArm": Vector3(-8, 0, -168), "RightLowerArm": Vector3(-5, 0, 0), "Head": Vector3(-6, 0, 0), "mouth": 1.2}], [1.0, {}]],
	}
	_defs["point_board"] = {
		"duration": 1.8, "mask": "upper",
		"keys": [[0.0, {}], [0.25, {"RightUpperArm": Vector3(-20, 60, -80), "RightLowerArm": Vector3(-10, 0, 0), "Head": Vector3(0, -35, 0), "Chest": Vector3(0, -12, 0), "mouth": 1.4}],
			[0.75, {"RightUpperArm": Vector3(-22, 62, -82), "RightLowerArm": Vector3(-12, 0, 0), "Head": Vector3(0, -30, 0), "Chest": Vector3(0, -10, 0), "mouth": 1.2}], [1.0, {}]],
	}
	_defs["clap"] = {
		"duration": 1.2, "mask": "upper",
		"keys": [[0.0, {}],
			[0.2, {"LeftUpperArm": Vector3(-55, -30, 10), "RightUpperArm": Vector3(-55, 30, -10), "LeftLowerArm": Vector3(-50, 0, 0), "RightLowerArm": Vector3(-50, 0, 0), "mouth": 1.8}],
			[0.35, {"LeftUpperArm": Vector3(-55, -45, 10), "RightUpperArm": Vector3(-55, 45, -10), "LeftLowerArm": Vector3(-40, 0, 0), "RightLowerArm": Vector3(-40, 0, 0), "mouth": 1.8}],
			[0.5, {"LeftUpperArm": Vector3(-55, -30, 10), "RightUpperArm": Vector3(-55, 30, -10), "LeftLowerArm": Vector3(-50, 0, 0), "RightLowerArm": Vector3(-50, 0, 0), "mouth": 1.8}],
			[0.65, {"LeftUpperArm": Vector3(-55, -45, 10), "RightUpperArm": Vector3(-55, 45, -10), "LeftLowerArm": Vector3(-40, 0, 0), "RightLowerArm": Vector3(-40, 0, 0), "mouth": 1.8}],
			[0.8, {"LeftUpperArm": Vector3(-55, -30, 10), "RightUpperArm": Vector3(-55, 30, -10), "LeftLowerArm": Vector3(-50, 0, 0), "RightLowerArm": Vector3(-50, 0, 0), "mouth": 1.6}],
			[1.0, {}]],
	}
	_defs["push"] = {
		"duration": 0.6, "events": {"push": 0.4},
		"keys": [[0.0, {}],
			[0.35, {"LeftUpperArm": Vector3(-25, 0, 12), "RightUpperArm": Vector3(-25, 0, -12), "LeftLowerArm": Vector3(-90, 0, 0), "RightLowerArm": Vector3(-90, 0, 0), "Spine": Vector3(-6, 0, 0), "hips": Vector3(0, -0.03, -0.05)}],
			[0.5, {"LeftUpperArm": Vector3(-85, 0, 10), "RightUpperArm": Vector3(-85, 0, -10), "LeftLowerArm": Vector3(-5, 0, 0), "RightLowerArm": Vector3(-5, 0, 0), "Spine": Vector3(16, 0, 0), "hips": Vector3(0, -0.04, 0.08),
				"LeftUpperLeg": Vector3(-20, 0, 0), "RightUpperLeg": Vector3(14, 0, 0), "LeftLowerLeg": Vector3(14, 0, 0)}],
			[1.0, {}]],
	}
	_defs["hop_one"] = {
		"duration": 0.2, "hold": true, "fade_in": 0.05,
		"keys": [[0.0, {}], [1.0, {"hips": Vector3(0, -0.03, 0),
			"LeftUpperLeg": Vector3(-35, 0, 6), "LeftLowerLeg": Vector3(85, 0, 0), "LeftFoot": Vector3(20, 0, 0),
			"RightLowerLeg": Vector3(8, 0, 0), "LeftUpperArm": Vector3(-10, 0, 35), "RightUpperArm": Vector3(-10, 0, -35),
			"Spine": Vector3(6, 0, 0)}]],
	}
	_defs["hop_two"] = {
		"duration": 0.2, "hold": true, "fade_in": 0.05,
		"keys": [[0.0, {}], [1.0, {"hips": Vector3(0, -0.09, 0),
			"LeftUpperLeg": Vector3(-6, 0, 24), "RightUpperLeg": Vector3(-6, 0, -24),
			"LeftLowerLeg": Vector3(14, 0, 0), "RightLowerLeg": Vector3(14, 0, 0),
			"LeftFoot": Vector3(-6, 0, -18), "RightFoot": Vector3(-6, 0, 18),
			"LeftUpperArm": Vector3(-15, 0, 40), "RightUpperArm": Vector3(-15, 0, -40)}]],
	}
	_defs["scratch_head"] = {
		"duration": 1.8, "mask": "upper",
		"keys": [
			[0.0, {}],
			[0.25, {"RightUpperArm": Vector3(-40, 0, -115), "RightLowerArm": Vector3(-120, 0, 0), "Head": Vector3(6, 0, -8), "brow": 0.5}],
			[0.4, {"RightUpperArm": Vector3(-36, 0, -118), "RightLowerArm": Vector3(-126, 0, 0), "Head": Vector3(6, 0, -10), "brow": 0.5}],
			[0.55, {"RightUpperArm": Vector3(-40, 0, -115), "RightLowerArm": Vector3(-118, 0, 0), "Head": Vector3(6, 0, -8), "brow": 0.5}],
			[0.7, {"RightUpperArm": Vector3(-36, 0, -118), "RightLowerArm": Vector3(-126, 0, 0), "Head": Vector3(6, 0, -10), "brow": 0.5}],
			[1.0, {}],
		],
	}

	_build_dances()


## Dancinhas dos emojis animados (passe e loja).
static func _build_dances() -> void:
	var la := func(z: float, lo := 0.0) -> Dictionary: return {"LeftUpperArm": Vector3(-10, 0, z), "LeftLowerArm": Vector3(lo, 0, 0)}
	var ra := func(z: float, lo := 0.0) -> Dictionary: return {"RightUpperArm": Vector3(-10, 0, -z), "RightLowerArm": Vector3(lo, 0, 0)}
	# Dancinha: balança o quadril e os braços
	var dk := [[0.0, {}]]
	for i in 6:
		var sgn := 1.0 if i % 2 == 0 else -1.0
		dk.append([0.08 + i * 0.15, _merge(_merge(la.call(110 if sgn > 0 else 60, -60), ra.call(60 if sgn > 0 else 110, -60)),
			{"hips": Vector3(0.06 * sgn, -0.04, 0), "Spine": Vector3(0, 0, 8 * sgn), "Head": Vector3(0, 0, -10 * sgn), "mouth": 2.0,
			"LeftUpperLeg": Vector3(-10 if sgn > 0 else 0, 0, 0), "RightUpperLeg": Vector3(0 if sgn > 0 else -10, 0, 0)})])
	dk.append([1.0, {}])
	_defs["dance"] = {"duration": 2.4, "keys": dk}
	# Robô: movimentos travados
	var rk := [[0.0, {}]]
	var poses := [[90, 0, -90, 0], [90, -90, 90, 0], [0, -90, 90, -90], [90, -90, 0, -90]]
	for i in 8:
		var pz: Array = poses[i % poses.size()]
		rk.append([0.06 + i * 0.115, {"LeftUpperArm": Vector3(-10, 0, pz[0]), "LeftLowerArm": Vector3(pz[1], 0, 0),
			"RightUpperArm": Vector3(-10, 0, -float(pz[0]) if i % 2 == 0 else pz[2]), "RightLowerArm": Vector3(pz[3], 0, 0),
			"Head": Vector3(0, 25 if i % 2 == 0 else -25, 0), "hips": Vector3(0, -0.03 * (i % 2), 0)}])
	rk.append([1.0, {}])
	_defs["robot"] = {"duration": 2.6, "keys": rk}
	# Fio dental: braços para os lados e quadril para o outro
	var fk := [[0.0, {}]]
	for i in 8:
		var s2 := 1.0 if i % 2 == 0 else -1.0
		fk.append([0.06 + i * 0.11, {"LeftUpperArm": Vector3(20 * s2, 0, 25), "RightUpperArm": Vector3(20 * s2, 0, -25),
			"LeftLowerArm": Vector3(-10, 0, 0), "RightLowerArm": Vector3(-10, 0, 0), "hips": Vector3(0.08 * -s2, 0, 0),
			"Spine": Vector3(0, 0, 6 * s2), "mouth": 1.8}])
	fk.append([1.0, {}])
	_defs["floss"] = {"duration": 2.2, "keys": fk}
	# Pirueta com pulo
	_defs["spin_jump"] = {"duration": 1.4, "keys": [
		[0.0, {}],
		[0.2, {"hips": Vector3(0, -0.12, 0), "LeftUpperLeg": Vector3(-40, 0, 0), "RightUpperLeg": Vector3(-40, 0, 0), "LeftLowerLeg": Vector3(70, 0, 0), "RightLowerLeg": Vector3(70, 0, 0)}],
		[0.45, _merge(_merge(la.call(170), ra.call(170)), {"hips": Vector3(0, 0.45, 0), "Hips": Vector3(0, 180, 0), "mouth": 2.4})],
		[0.7, _merge(_merge(la.call(170), ra.call(170)), {"hips": Vector3(0, 0.2, 0), "Hips": Vector3(0, 359, 0), "mouth": 2.4})],
		[0.85, {"hips": Vector3(0, -0.08, 0), "Hips": Vector3(0, 360, 0), "LeftLowerLeg": Vector3(40, 0, 0), "RightLowerLeg": Vector3(40, 0, 0)}],
		[1.0, {"Hips": Vector3(0, 360, 0)}]]}
	# Gargalhada: barriga, cabeça para trás
	var lk := [[0.0, {}]]
	for i in 6:
		lk.append([0.1 + i * 0.13, {"Spine": Vector3(-10 if i % 2 == 0 else 4, 0, 0), "Head": Vector3(-24 if i % 2 == 0 else -8, 0, 0), "mouth": 2.6,
			"LeftUpperArm": Vector3(40, 0, 30), "RightUpperArm": Vector3(40, 0, -30), "LeftLowerArm": Vector3(-80, 0, 0), "RightLowerArm": Vector3(-80, 0, 0)}])
	lk.append([1.0, {}])
	_defs["laugh"] = {"duration": 1.8, "keys": lk}
	# Coração com as mãos
	_defs["heart_hands"] = {"duration": 1.8, "mask": "upper", "keys": [
		[0.0, {}],
		[0.25, {"LeftUpperArm": Vector3(-60, 0, 40), "RightUpperArm": Vector3(-60, 0, -40), "LeftLowerArm": Vector3(-100, 0, 0), "RightLowerArm": Vector3(-100, 0, 0), "Head": Vector3(0, 0, 8), "mouth": 1.8}],
		[0.75, {"LeftUpperArm": Vector3(-62, 0, 38), "RightUpperArm": Vector3(-62, 0, -38), "LeftLowerArm": Vector3(-104, 0, 0), "RightLowerArm": Vector3(-104, 0, 0), "Head": Vector3(0, 0, -8), "mouth": 1.8}],
		[1.0, {}]]}
	# Mortal para trás
	_defs["backflip"] = {"duration": 1.3, "keys": [
		[0.0, {}],
		[0.18, {"hips": Vector3(0, -0.16, 0), "LeftUpperLeg": Vector3(-50, 0, 0), "RightUpperLeg": Vector3(-50, 0, 0), "LeftLowerLeg": Vector3(90, 0, 0), "RightLowerLeg": Vector3(90, 0, 0)}],
		[0.4, _merge(_merge(la.call(160), ra.call(160)), {"hips": Vector3(0, 0.55, 0), "Hips": Vector3(-150, 0, 0), "LeftUpperLeg": Vector3(-90, 0, 0), "RightUpperLeg": Vector3(-90, 0, 0), "LeftLowerLeg": Vector3(110, 0, 0), "RightLowerLeg": Vector3(110, 0, 0)})],
		[0.62, {"hips": Vector3(0, 0.45, 0), "Hips": Vector3(-300, 0, 0), "LeftUpperLeg": Vector3(-60, 0, 0), "RightUpperLeg": Vector3(-60, 0, 0)}],
		[0.8, _merge(_merge(la.call(150), ra.call(150)), {"hips": Vector3(0, -0.1, 0), "Hips": Vector3(-359, 0, 0), "LeftLowerLeg": Vector3(40, 0, 0), "RightLowerLeg": Vector3(40, 0, 0), "mouth": 2.4})],
		[1.0, {"Hips": Vector3(-360, 0, 0)}]]}  # termina na volta completa (sem "desgirar")
	# Guitarra imaginária
	var gk := [[0.0, {}]]
	for i in 7:
		gk.append([0.08 + i * 0.12, {"LeftUpperArm": Vector3(-40, 30, 40), "LeftLowerArm": Vector3(-60, 0, 0),
			"RightUpperArm": Vector3(-20, 0, -30), "RightLowerArm": Vector3(-70 if i % 2 == 0 else -40, 0, 0),
			"Head": Vector3(15 if i % 2 == 0 else -5, 0, 0), "Spine": Vector3(8, 0, 0), "hips": Vector3(0, -0.06, 0), "mouth": 2.2}])
	gk.append([1.0, {}])
	_defs["air_guitar"] = {"duration": 2.2, "keys": gk}
	# Pose de campeão (flexiona os braços)
	_defs["flex"] = {"duration": 1.8, "keys": [
		[0.0, {}],
		[0.25, _merge(_merge(la.call(90, -110), ra.call(90, -110)), {"Spine": Vector3(-6, 0, 0), "Head": Vector3(-10, 0, 0), "mouth": 1.6, "hips": Vector3(0, -0.05, 0)})],
		[0.6, _merge(_merge(la.call(95, -125), ra.call(95, -125)), {"Spine": Vector3(-8, 0, 0), "Head": Vector3(-12, 0, 0), "mouth": 2.2, "hips": Vector3(0, -0.05, 0)})],
		[1.0, {}]]}


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	r.merge(b, true)
	return r
