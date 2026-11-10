class_name CameraController
extends Node3D
## Câmera em terceira pessoa: segue o jogador suavemente, gira com toque/
## mouse/analógico, desvia de paredes (SpringArm3D), zoom por pinça/roda,
## realinha atrás do jogador quando ele corre e tem modo vitrine (menu).

@export var follow_height := 1.45
@export var distance := 3.9
@export var min_distance := 2.2
@export var max_distance := 5.2  # sempre perto do personagem
@export var min_pitch := -65.0
@export var max_pitch := 8.0

var target: Node3D
var yaw := PI
var pitch := -18.0
var showcase := false
var showcase_center := Vector3(0, 0, -6)
var showcase_radius := 34.0

var arm: SpringArm3D
var camera: Camera3D
var _manual_timer := 0.0
var _shake := 0.0
var _focus := Vector3.ZERO
var _cur_distance := 4.6
var follow_offset_y := 0.0
## Enquadramento fixo usado por minijogos (gude, aviãozinho).
var override_active := false
var override_xf := Transform3D()
var override_cam: Camera3D


func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.name = "Arm"
	arm.collision_mask = 1
	arm.margin = 0.15
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	arm.shape = sphere
	add_child(arm)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 260.0
	arm.add_child(camera)
	_cur_distance = distance
	override_cam = Camera3D.new()
	override_cam.name = "OverrideCamera"
	override_cam.top_level = true
	override_cam.fov = 62.0
	override_cam.near = 0.03
	override_cam.far = 260.0
	add_child(override_cam)
	if target:
		snap_to_target()


func get_yaw() -> float:
	return rotation.y


func snap_to_target() -> void:
	if target == null:
		return
	_focus = target.global_position + Vector3(0, follow_height, 0)
	global_position = _focus
	_apply_rotation()


## Entrada de rotação em pixels (arrasto de tela).
func rotate_input(rel: Vector2) -> void:
	var sens: float = Settings.get_value("camera_sensitivity")
	var inv := -1.0 if Settings.get_value("invert_y") else 1.0
	yaw -= rel.x * 0.0055 * sens
	pitch -= rel.y * 0.25 * sens * inv
	pitch = clampf(pitch, min_pitch, max_pitch)
	_manual_timer = 2.5


func zoom_input(amount: float) -> void:
	distance = clampf(distance + amount, min_distance, max_distance)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_input(-0.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_input(0.4)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_input(event.relative)


func _process(delta: float) -> void:
	if showcase:
		_process_showcase(delta)
		return
	if override_active:
		var k := 1.0 - exp(-5.0 * delta)
		override_cam.global_transform = override_cam.global_transform.interpolate_with(override_xf, k)
		return
	if target == null:
		return
	# analógico direito / teclas J-L
	var cam_axis := Input.get_axis("cam_left", "cam_right")
	if absf(cam_axis) > 0.05:
		yaw -= cam_axis * 2.4 * delta * float(Settings.get_value("camera_sensitivity"))
		_manual_timer = 2.5

	var tp := target.global_position + Vector3(0, follow_height + follow_offset_y, 0)
	# horizontal rápido, vertical mais suave (pulos não balançam a câmera)
	var kxz := 1.0 - exp(-14.0 * delta)
	var ky := 1.0 - exp(-6.0 * delta)
	_focus.x = lerpf(_focus.x, tp.x, kxz)
	_focus.z = lerpf(_focus.z, tp.z, kxz)
	_focus.y = lerpf(_focus.y, tp.y, ky)

	# realinha atrás do jogador quando ele se move e não há controle manual
	_manual_timer -= delta
	if _manual_timer <= 0.0 and target.has_method("get") and target.get("visual"):
		var v: Vector3 = target.velocity
		var hspeed := Vector2(v.x, v.z).length()
		if hspeed > 1.0:
			var behind: float = target.yaw + PI
			var rate := 0.5 * clampf(hspeed / 5.0, 0.0, 1.0)
			yaw = lerp_angle(yaw, behind, 1.0 - exp(-rate * delta))

	var indoor: bool = GameManager.world != null and GameManager.world.get("player_indoor") == true
	var want := minf(distance, 2.7) if indoor else distance
	if indoor:
		pitch = clampf(pitch, -32.0, -6.0)
	if target.get("mode") == 1:  # sentado: aproxima e sobe a câmera
		want = minf(want, 2.6)
		follow_offset_y = lerpf(follow_offset_y, 0.35, 1.0 - exp(-4.0 * delta))
	else:
		follow_offset_y = lerpf(follow_offset_y, 0.0, 1.0 - exp(-4.0 * delta))
	_cur_distance = lerpf(_cur_distance, want, 1.0 - exp(-3.0 * delta))
	arm.spring_length = _cur_distance
	global_position = _focus
	_apply_rotation()
	if _shake > 0.0:
		camera.h_offset = randf_range(-1, 1) * _shake
		camera.v_offset = randf_range(-1, 1) * _shake
		_shake = maxf(_shake - delta * 0.6, 0.0)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _apply_rotation() -> void:
	rotation = Vector3(0, yaw, 0)
	arm.rotation = Vector3(deg_to_rad(pitch), 0, 0)


func _process_showcase(delta: float) -> void:
	yaw += delta * 0.06
	var pos := showcase_center + Vector3(sin(yaw), 0, cos(yaw)) * showcase_radius + Vector3(0, 16, 0)
	arm.spring_length = 0.0
	global_position = pos
	rotation = Vector3.ZERO
	arm.rotation = Vector3.ZERO
	camera.look_at(showcase_center + Vector3(0, 2, 0), Vector3.UP)


func set_override(xf: Variant) -> void:
	if xf == null:
		if override_active:
			override_active = false
			camera.make_current()
		return
	if not override_active:
		override_cam.global_transform = camera.global_transform
		override_cam.far = camera.far
		override_cam.make_current()
	override_active = true
	override_xf = xf


func set_showcase(enabled: bool) -> void:
	showcase = enabled
	if not enabled:
		camera.rotation = Vector3.ZERO
		if target:
			yaw = target.get("yaw") + PI if target.get("yaw") != null else yaw
			pitch = -18.0
			snap_to_target()
