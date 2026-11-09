class_name QuestSpot
extends Interactable
## Ponto de missão: o jogador interage, faz uma animação por alguns
## segundos (plantar, regar, colher...) e a etapa avança.

signal done(spot: Node)

var hold_time := 1.0
var anim := "interact"
var _busy := false


func _ready() -> void:
	super._ready()
	interact_radius = 1.6
	# brilho no chão para ser fácil de achar
	var md := MeshData.new()
	md.cur_color = Color(0.37, 0.78, 1.0)
	md.add_cylinder(Transform3D(), 0.55, 0.55, 0.02, 20)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.55)
	var mi := MeshInstance3D.new()
	mi.mesh = md.build_mesh(mat)
	mi.position = Vector3(0, 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func can_interact(_player: Node) -> bool:
	return not _busy


func interact(player: Node) -> void:
	if _busy:
		return
	_busy = true
	var p := player as PlayerController
	var to := global_position - p.global_position
	if Vector2(to.x, to.z).length() > 0.05:
		p.yaw = atan2(to.x, to.z)
	p.visual.play(anim)
	p.input_enabled = false
	get_tree().create_timer(hold_time).timeout.connect(func():
		p.input_enabled = true
		done.emit(self))
