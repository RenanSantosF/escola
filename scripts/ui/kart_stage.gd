class_name KartStage
extends SubViewportContainer
## Vitrine 3D de uma pintura de kart: o kart gira devagar num palco com luz.

var item_id := "kart_padrao"
var _pivot: Node3D
var _vp: SubViewport


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.4, 3.4)
	cam.fov = 40.0
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 0.3, 0))
	# palco redondo
	var disk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.55
	cyl.height = 0.1
	disk.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("ffcf3f")
	disk.material_override = dm
	disk.position = Vector3(0, -0.06, 0)
	_vp.add_child(disk)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_pivot.add_child(KartRace.make_kart_item(item_id))


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate_y(delta * 0.8)
