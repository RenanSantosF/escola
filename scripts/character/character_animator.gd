class_name CharacterAnimator
extends RefCounted
## Animação procedural em camadas para o esqueleto humanoide:
##  1. Idle (respiração, peso alternado, olhar, piscar)
##  2. Locomoção (caminhar/correr com fase sincronizada pela distância
##     percorrida — os pés não "deslizam"), passos no lugar ao girar,
##     inclinação em curvas e na aceleração.
##  3. Ar (pulo/queda) e amortecimento de aterrissagem.
##  4. Ações com keyframes (sentar, chutar, arremessar, comemorar...).
## O resultado passa por suavização exponencial — sem trocas bruscas.

signal action_event(action: String, event: String)
signal action_finished(action: String)
signal footstep(side: int)

const DEG := PI / 180.0
const LEG_UPPER := 0.39
const LEG_LOWER := 0.37
const LEG_REST := LEG_UPPER + LEG_LOWER

# Entradas (definidas pelo controlador a cada frame)
var speed := 0.0
var max_walk_speed := 2.0
var max_run_speed := 5.0
var grounded := true
var vertical_velocity := 0.0
var yaw_rate := 0.0
var forward_accel := 0.0
var look_target_yaw := 0.0  # graus, olhar da cabeça (para NPCs)

var skel: Skeleton3D
var bone_idx := {}
var rest_pos := {}
var bone_names: Array[String] = []

var _cur := {}  # bone -> Vector3 (graus) suavizado
var _cur_hips := Vector3.ZERO
var _cur_face := {"eyes": 1.0, "mouth": 1.0, "brow": 0.0}

var _phase := 0.0
var _smooth_speed := 0.0
var _run_blend := 0.0
var _turn_step := 0.0
var _air := 0.0
var _land_dip := 0.0
var _land_vel := 0.0
var _was_grounded := true
var _time := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _idle_look := 0.0
var _idle_look_target := 0.0
var _idle_look_timer := 3.0
var _last_step_half := 0
var _lean := 0.0

var action := ""
var _action_def := {}
var _action_t := 0.0
var _action_w := 0.0
var _action_fading := false
var _fired := {}
var action_speed := 1.0

# Canal superior (braços/tronco/rosto) sobreposto a tudo — permite, por
# exemplo, levantar a mão ou conversar enquanto está sentado.
var upper_action := ""
var _u_def := {}
var _u_t := 0.0
var _u_w := 0.0
var _u_fading := false
var _u_fired := {}

## Frequência de atualização reduzida para personagens distantes (LOD).
var update_interval := 0.0
var _accum := 0.0


func setup(skeleton: Skeleton3D) -> void:
	skel = skeleton
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		bone_idx[bn] = i
		rest_pos[bn] = skel.get_bone_rest(i).origin
		bone_names.append(bn)
		_cur[bn] = Vector3.ZERO
	_phase = randf()
	_time = randf() * 10.0


# ------------------------------------------------------------------ ações

func play(action_name: String, speed_scale := 1.0) -> bool:
	var def := ActionLibrary.get_def(action_name)
	if def.is_empty():
		push_warning("Animação inexistente: %s" % action_name)
		return false
	if def.get("mask", "full") == "upper":
		upper_action = action_name
		_u_def = def
		_u_t = 0.0
		_u_fading = false
		_u_fired.clear()
		return true
	action = action_name
	_action_def = def
	_action_t = 0.0
	_action_fading = false
	_fired.clear()
	action_speed = speed_scale
	return true


func stop_action(fade := true) -> void:
	if action == "":
		return
	if fade:
		_action_fading = true
	else:
		_end_action()


func stop_upper(fade := true) -> void:
	if upper_action == "":
		return
	if fade:
		_u_fading = true
	else:
		_end_upper()


func is_playing(action_name := "") -> bool:
	if action_name == "":
		return action != "" and not _action_fading
	if upper_action == action_name and not _u_fading:
		return true
	return action == action_name and not _action_fading


func _end_upper() -> void:
	var finished := upper_action
	upper_action = ""
	_u_def = {}
	_u_w = 0.0
	_u_fading = false
	if finished != "":
		action_finished.emit(finished)


func is_holding() -> bool:
	return action != "" and _action_def.get("hold", false) and _action_t >= 1.0


func _end_action() -> void:
	var finished := action
	action = ""
	_action_def = {}
	_action_w = 0.0
	_action_fading = false
	if finished != "":
		action_finished.emit(finished)


# ------------------------------------------------------------------ update

func update(delta: float) -> void:
	if skel == null:
		return
	if update_interval > 0.0:
		_accum += delta
		if _accum < update_interval:
			return
		delta = _accum
		_accum = 0.0
	delta = minf(delta, 0.1)
	_time += delta

	_update_params(delta)
	var pose := _base_pose(delta)
	_apply_air(pose)
	_apply_action(pose, delta)
	_apply_upper(pose, delta)
	_apply_to_skeleton(pose, delta)


func _update_params(delta: float) -> void:
	_smooth_speed = lerpf(_smooth_speed, speed, 1.0 - exp(-10.0 * delta))
	var rb := clampf((_smooth_speed - (max_walk_speed + 0.4)) / maxf(max_run_speed - max_walk_speed - 0.4, 0.1), 0.0, 1.0)
	_run_blend = lerpf(_run_blend, rb, 1.0 - exp(-6.0 * delta))
	var turning := absf(yaw_rate) > 1.2 and _smooth_speed < 0.5 and grounded
	_turn_step = lerpf(_turn_step, 1.0 if turning else 0.0, 1.0 - exp(-8.0 * delta))
	_air = lerpf(_air, 0.0 if grounded else 1.0, 1.0 - exp(-12.0 * delta))
	_lean = lerpf(_lean, clampf(forward_accel * 1.2, -10.0, 12.0), 1.0 - exp(-5.0 * delta))

	if grounded and not _was_grounded:
		_land_vel -= clampf(absf(vertical_velocity) * 0.06, 0.05, 0.35)
	_was_grounded = grounded
	# mola amortecida para a aterrissagem
	_land_vel += (-_land_dip * 120.0 - _land_vel * 14.0) * delta
	_land_dip += _land_vel * delta

	# Fase do ciclo de passos
	var stride := lerpf(lerpf(0.7, 1.5, clampf(_smooth_speed / 1.6, 0.0, 1.0)), 2.9, _run_blend)
	if _smooth_speed > 0.05 and grounded:
		_phase += _smooth_speed * delta / stride
	elif _turn_step > 0.05:
		_phase += absf(yaw_rate) * delta * 0.35
	_phase = fmod(_phase, 1.0)

	var half := int(_phase * 2.0)
	if half != _last_step_half:
		_last_step_half = half
		if grounded and (_smooth_speed > 0.4 or _turn_step > 0.5):
			footstep.emit(half)

	# Piscar
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.5)
	_blink = maxf(_blink - delta * 7.0, 0.0)
	# Olhar ocioso
	_idle_look_timer -= delta
	if _idle_look_timer <= 0.0:
		_idle_look_timer = randf_range(2.5, 6.0)
		_idle_look_target = randf_range(-28.0, 28.0) if randf() < 0.6 else 0.0
	_idle_look = lerpf(_idle_look, _idle_look_target, 1.0 - exp(-3.0 * delta))


func _base_pose(_delta: float) -> Dictionary:
	var p := {}
	var t := _time
	var move_w := clampf(_smooth_speed / 0.9, 0.0, 1.0)
	var idle_w := 1.0 - move_w
	var rb := _run_blend

	# ---------- idle
	var breath := sin(t * 1.7)
	var sway := sin(t * 0.45)
	var hips := Vector3(sway * 0.012 * idle_w, breath * 0.004 * idle_w, 0)
	_add(p, "Hips", Vector3(0, 0, sway * 2.0 * idle_w))
	_add(p, "Spine", Vector3(1.5 + breath * 0.8, 0, -sway * 1.5) * idle_w)
	_add(p, "Chest", Vector3(breath * 1.2, 0, -sway * 0.8) * idle_w)
	var look := (_idle_look * idle_w) + look_target_yaw
	_add(p, "Head", Vector3(-1.5 + sin(t * 0.7) * 2.0, look * 0.7, 0) * 1.0)
	_add(p, "Neck", Vector3(0, look * 0.3, 0))
	_add(p, "LeftUpperArm", Vector3(2 + breath * 1.0, 0, 6 + breath * 1.2) * idle_w)
	_add(p, "RightUpperArm", Vector3(2 + breath * 1.0, 0, -6 - breath * 1.2) * idle_w)
	_add(p, "LeftLowerArm", Vector3(-10, 0, 0) * idle_w)
	_add(p, "RightLowerArm", Vector3(-10, 0, 0) * idle_w)
	_add(p, "LeftUpperLeg", Vector3(0, 0, 2 - sway * 1.5) * idle_w)
	_add(p, "RightUpperLeg", Vector3(0, 0, -2 - sway * 1.5) * idle_w)
	_add(p, "LeftLowerLeg", Vector3(2 + maxf(-sway, 0) * 5.0, 0, 0) * idle_w)
	_add(p, "RightLowerLeg", Vector3(2 + maxf(sway, 0) * 5.0, 0, 0) * idle_w)

	# ---------- locomoção / passo no lugar
	var loco_w := maxf(move_w, _turn_step * (1.0 - move_w))
	if loco_w > 0.001:
		var theta := _phase * TAU
		var stride := lerpf(lerpf(0.7, 1.5, clampf(_smooth_speed / 1.6, 0.0, 1.0)), 2.9, rb)
		var amp := asin(clampf(stride / (4.0 * LEG_REST), 0.0, 0.72)) / DEG
		if move_w < 0.5 and _turn_step > 0.0:
			amp = lerpf(12.0, amp, move_w * 2.0)
		var knee_swing := lerpf(55.0, 105.0, rb)
		var knee_stance := lerpf(6.0, 28.0, rb)
		var ext := [0.0, 0.0]
		var sides := ["Left", "Right"]
		for i in 2:
			var th := theta + PI * i
			var c := cos(th)
			var s := sin(th)
			var thigh := -amp * c - rb * 8.0
			var swing_phase := fposmod(th, TAU)
			var knee := 4.0
			if swing_phase > PI:
				var u := (swing_phase - PI) / PI
				knee += knee_swing * sin(PI * pow(u, 0.75))
			else:
				knee += knee_stance * sin(swing_phase)
			var toe := 0.0
			var u2 := swing_phase / PI
			if u2 > 0.7 and u2 < 1.15:
				toe = sin((u2 - 0.7) / 0.45 * PI) * lerpf(20.0, 30.0, rb)
			var heel := maxf(c, 0.0) * 12.0 * (1.0 - rb * 0.5)
			var foot := -(thigh + knee) + toe - heel
			var side: String = sides[i]
			_add(p, side + "UpperLeg", Vector3(thigh, 0, (2.0 if i == 0 else -2.0)) * loco_w)
			_add(p, side + "LowerLeg", Vector3(knee, 0, 0) * loco_w)
			_add(p, side + "Foot", Vector3(foot, 0, 0) * loco_w)
			ext[i] = LEG_UPPER * cos(thigh * DEG) + LEG_LOWER * cos((thigh + knee) * DEG)
			# Braços em oposição às pernas
			var arm_amp := lerpf(20.0, 52.0, rb)
			var elbow := lerpf(14.0, 85.0, rb) + maxf(-c, 0.0) * lerpf(10.0, 25.0, rb)
			var arm_sign := 1.0 if i == 0 else -1.0
			_add(p, side + "UpperArm", Vector3(arm_amp * c, 0, arm_sign * lerpf(5.0, 12.0, rb)) * loco_w)
			_add(p, side + "LowerArm", Vector3(-elbow, 0, 0) * loco_w)
		var cth := cos(theta)
		var lean := lerpf(3.0, 13.0, rb) * move_w + _lean
		var turn_lean := clampf(-yaw_rate * _smooth_speed * 1.6, -14.0, 14.0)
		_add(p, "Hips", Vector3(0, -lerpf(6.0, 10.0, rb) * cth, sin(theta * 2.0) * 2.0 + turn_lean * 0.4) * loco_w)
		_add(p, "Spine", Vector3(lean, lerpf(4.0, 6.0, rb) * cth, turn_lean) * loco_w)
		_add(p, "Chest", Vector3(rb * 4.0, lerpf(5.0, 10.0, rb) * cth, 0) * loco_w)
		_add(p, "Head", Vector3(-lean * 0.6, -lerpf(4.0, 8.0, rb) * cth, -turn_lean * 0.5) * loco_w)
		# Altura do quadril: o pé de apoio sempre toca o chão (IK simplificado)
		var support := maxf(ext[0], ext[1])
		var drop := (support - LEG_REST) - 0.01
		var bounce := sin(theta * 2.0 - 0.6) * 0.035 * rb
		hips += Vector3(0, drop + bounce, 0) * loco_w

	p["hips"] = hips
	p["eyes"] = 1.0 - _blink
	p["mouth"] = 1.0
	p["brow"] = 0.0
	return p


func _apply_air(p: Dictionary) -> void:
	if _air < 0.01:
		p["hips"] = p["hips"] + Vector3(0, _land_dip, 0)
		if _land_dip < -0.01:
			var k := clampf(-_land_dip / 0.2, 0.0, 1.0)
			for side: String in ["Left", "Right"]:
				_blend_bone(p, side + "UpperLeg", Vector3(-30, 0, 0), k)
				_blend_bone(p, side + "LowerLeg", Vector3(60, 0, 0), k)
				_blend_bone(p, side + "Foot", Vector3(-30, 0, 0), k)
		return
	var up := clampf(vertical_velocity / 4.0, -1.0, 1.0)
	var air_pose := {
		"LeftUpperLeg": Vector3(-38, 0, 4), "LeftLowerLeg": Vector3(70, 0, 0), "LeftFoot": Vector3(-10, 0, 0),
		"RightUpperLeg": Vector3(-8, 0, -4), "RightLowerLeg": Vector3(35 - up * 10.0, 0, 0), "RightFoot": Vector3(10, 0, 0),
		"LeftUpperArm": Vector3(-25, 0, 35 + (1.0 - up) * 15.0), "RightUpperArm": Vector3(15, 0, -35 - (1.0 - up) * 15.0),
		"LeftLowerArm": Vector3(-35, 0, 0), "RightLowerArm": Vector3(-25, 0, 0),
		"Spine": Vector3(6 - up * 6.0, 0, 0), "Head": Vector3(-6, 0, 0),
	}
	for bn in air_pose.keys():
		_blend_bone(p, bn, air_pose[bn], _air)
	p["hips"] = p["hips"].lerp(Vector3(0, 0.02, 0), _air)
	p["mouth"] = lerpf(p["mouth"], 1.5, _air)


func _apply_action(p: Dictionary, delta: float) -> void:
	if action == "":
		return
	var def := _action_def
	var dur: float = def.get("duration", 1.0)
	var fade_in: float = def.get("fade_in", 0.12)
	var fade_out: float = def.get("fade_out", 0.18)
	_action_t += delta * action_speed / dur
	var hold: bool = def.get("hold", false)

	# Eventos (ex.: impacto do chute)
	var events: Dictionary = def.get("events", {})
	for ev in events.keys():
		if not _fired.has(ev) and _action_t >= float(events[ev]):
			_fired[ev] = true
			action_event.emit(action, ev)

	if _action_fading:
		_action_w = maxf(_action_w - delta / fade_out, 0.0)
		if _action_w <= 0.0:
			_end_action()
			return
	else:
		_action_w = minf(_action_w + delta / fade_in, 1.0)
		if _action_t >= 1.0:
			if hold:
				_action_t = 1.0
			else:
				_action_t = 1.0
				# final da ação: encerra sem pulo (a última chave já é neutra)
				var name_done := action
				_end_action()
				if name_done != "":
					return

	var t := clampf(_action_t, 0.0, 1.0)
	var pose := _sample(def["keys"], t)
	var upper_only: bool = def.get("mask", "full") == "upper"
	var w := _ease(_action_w)
	var affected := {}
	for key in pose.keys():
		affected[key] = true
	for k in def["keys"]:
		for key in k[1].keys():
			affected[key] = true
	for key in affected.keys():
		if key in ["hips", "eyes", "mouth", "brow"]:
			if upper_only and key == "hips":
				continue
			var neutral = Vector3.ZERO if key == "hips" else (0.0 if key == "brow" else 1.0)
			var target = pose.get(key, neutral)
			if key == "hips":
				p["hips"] = p["hips"].lerp(target, w)
			elif key == "eyes":
				p["eyes"] = lerpf(p["eyes"], minf(target, p["eyes"]), w)
			else:
				p[key] = lerpf(p[key], target, w)
			continue
		if upper_only and not key in ActionLibrary.UPPER_BODY:
			continue
		_blend_bone(p, key, pose.get(key, Vector3.ZERO), w)
	# Ações de corpo inteiro "congelam" a locomoção das pernas não listadas
	if not upper_only:
		for bn: String in ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Hips"]:
			if not affected.has(bn):
				_blend_bone(p, bn, Vector3.ZERO, w * 0.85)


func _apply_upper(p: Dictionary, delta: float) -> void:
	if upper_action == "":
		return
	var def := _u_def
	var dur: float = def.get("duration", 1.0)
	_u_t += delta / dur
	var loop: bool = def.get("loop", false)
	var events: Dictionary = def.get("events", {})
	for ev in events.keys():
		if not _u_fired.has(ev) and _u_t >= float(events[ev]):
			_u_fired[ev] = true
			action_event.emit(upper_action, ev)
	if _u_fading:
		_u_w = maxf(_u_w - delta / 0.2, 0.0)
		if _u_w <= 0.0:
			_end_upper()
			return
	else:
		_u_w = minf(_u_w + delta / 0.15, 1.0)
	if _u_t >= 1.0:
		if loop:
			_u_t = fmod(_u_t, 1.0)
			_u_fired.clear()
		elif def.get("hold", false):
			_u_t = 1.0
		else:
			_end_upper()
			return
	var pose := _sample(def["keys"], clampf(_u_t, 0.0, 1.0))
	var w := _ease(_u_w)
	var affected := {}
	for k in def["keys"]:
		for key in k[1].keys():
			affected[key] = true
	for key in affected.keys():
		if key == "hips":
			continue
		if key in ["eyes", "mouth", "brow"]:
			var neutral := 0.0 if key == "brow" else 1.0
			var target: float = pose.get(key, neutral)
			p[key] = lerpf(p[key], minf(target, p[key]) if key == "eyes" else target, w)
			continue
		if not key in ActionLibrary.UPPER_BODY:
			continue
		# soma sobre a pose atual (respeita estar sentado/andando)
		var base: Vector3 = p.get(key, Vector3.ZERO)
		var target_v: Vector3 = pose.get(key, Vector3.ZERO)
		var additive: bool = def.get("additive", false)
		p[key] = base.lerp(base + target_v if additive else target_v, w)


func _sample(keys: Array, t: float) -> Dictionary:
	var n := keys.size()
	if n == 0:
		return {}
	if t <= keys[0][0]:
		return keys[0][1]
	if t >= keys[n - 1][0]:
		return keys[n - 1][1]
	var i := 0
	while i < n - 1 and t > keys[i + 1][0]:
		i += 1
	var k1: Array = keys[i]
	var k2: Array = keys[i + 1]
	var k0: Array = keys[maxi(i - 1, 0)]
	var k3: Array = keys[mini(i + 2, n - 1)]
	var t1: float = k1[0]
	var t2: float = k2[0]
	var u := (t - t1) / maxf(t2 - t1, 0.0001)
	var out := {}
	var names := {}
	for k in [k0, k1, k2, k3]:
		for key in k[1].keys():
			names[key] = true
	for key in names.keys():
		var neutral = Vector3.ZERO
		if key in ["eyes", "mouth"]:
			neutral = 1.0
		elif key == "brow":
			neutral = 0.0
		var a = k1[1].get(key, neutral)
		var b = k2[1].get(key, neutral)
		var pre = k0[1].get(key, neutral) if k0 != k1 else a
		var post = k3[1].get(key, neutral) if k3 != k2 else b
		if a is Vector3:
			out[key] = a.cubic_interpolate_in_time(b, pre, post, u, t2 - t1, minf(float(k0[0]) - t1, -0.0001), maxf(float(k3[0]) - t1, t2 - t1 + 0.0001))
		else:
			out[key] = cubic_interpolate(float(a), float(b), float(pre), float(post), u)
	return out


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _add(p: Dictionary, bone: String, v: Vector3) -> void:
	p[bone] = p.get(bone, Vector3.ZERO) + v


func _blend_bone(p: Dictionary, bone: String, target: Vector3, w: float) -> void:
	p[bone] = p.get(bone, Vector3.ZERO).lerp(target, w)


func _apply_to_skeleton(p: Dictionary, delta: float) -> void:
	var k := 1.0 - exp(-20.0 * delta)
	for bn in bone_names:
		if bn.ends_with("Eye") or bn.ends_with("Brow") or bn == "Mouth":
			continue
		var target: Vector3 = p.get(bn, Vector3.ZERO)
		var cur: Vector3 = _cur[bn].lerp(target, k)
		_cur[bn] = cur
		skel.set_bone_pose_rotation(bone_idx[bn], Quaternion.from_euler(cur * DEG))
	_cur_hips = _cur_hips.lerp(p.get("hips", Vector3.ZERO), k)
	skel.set_bone_pose_position(bone_idx["Hips"], rest_pos["Hips"] + _cur_hips)

	var kf := 1.0 - exp(-25.0 * delta)
	for key: String in ["eyes", "mouth", "brow"]:
		_cur_face[key] = lerpf(_cur_face[key], float(p.get(key, 1.0 if key != "brow" else 0.0)), kf)
	var eyes: float = clampf(minf(_cur_face.eyes, 1.0 - _blink), 0.08, 1.0)
	for e: String in ["LeftEye", "RightEye"]:
		if bone_idx.has(e):
			skel.set_bone_pose_scale(bone_idx[e], Vector3(1, eyes, 1))
	if bone_idx.has("Mouth"):
		var m: float = _cur_face.mouth
		skel.set_bone_pose_scale(bone_idx["Mouth"], Vector3(1.0 - (m - 1.0) * 0.15, m, 1))
	var brow: float = _cur_face.brow
	if bone_idx.has("LeftBrow"):
		skel.set_bone_pose_rotation(bone_idx["LeftBrow"], Quaternion.from_euler(Vector3(0, 0, -20.0 * brow) * DEG))
		skel.set_bone_pose_rotation(bone_idx["RightBrow"], Quaternion.from_euler(Vector3(0, 0, 20.0 * brow) * DEG))
		var lift := Vector3(0, 0.006 * brow, 0)
		skel.set_bone_pose_position(bone_idx["LeftBrow"], rest_pos["LeftBrow"] + lift)
		skel.set_bone_pose_position(bone_idx["RightBrow"], rest_pos["RightBrow"] + lift)
