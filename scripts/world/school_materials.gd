class_name SchoolMaterials
extends RefCounted
## Materiais compartilhados do cenário. Todos usam cor por vértice
## multiplicada por uma textura neutra, então poucas instâncias de material
## cobrem a escola inteira (menos trocas de estado na GPU).

const TEX := "res://assets/textures/"

## Metros de mundo por repetição de textura, por material.
const UV_SCALE := {
	"paint": 3.0, "tile": 2.0, "wood": 1.4, "grass": 7.0, "concrete": 4.0, "brick": 1.6,
	"dirt": 5.0, "roof": 1.6, "asphalt": 6.0, "plain": 4.0, "metal": 4.0, "glass": 4.0,
	"foliage": 2.5, "fence": 1.2, "redfloor": 4.0, "chalk": 4.0,
}

static var _cache: Dictionary = {}


static func uv_scale(key: String) -> float:
	return UV_SCALE.get(key, 3.0)


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match key:
		"paint":
			m = _std("plaster.png", 0.92)
		"tile":
			m = _std("tiles.png", 0.42)
		"wood":
			m = _std("wood.png", 0.7)
		"grass":
			m = _std("grass.png", 0.95)
		"concrete":
			m = _std("concrete.png", 0.88)
		"redfloor":
			m = _std("concrete.png", 0.45)
		"brick":
			m = _std("brick.png", 0.9)
		"dirt":
			m = _std("dirt.png", 1.0)
		"roof":
			m = _std("roof.png", 0.8)
		"asphalt":
			m = _std("asphalt.png", 0.9)
		"plain":
			m = _std("", 0.8)
		"chalk":
			m = _std("plaster.png", 1.0)
		"metal":
			var mm := _std("", 0.38)
			mm.metallic = 0.45
			m = mm
		"glass":
			var g := _std("", 0.08)
			g.metallic = 0.3
			g.metallic_specular = 0.9
			m = g
		"fence":
			var f := _std("fence.png", 0.6)
			f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			f.alpha_scissor_threshold = 0.5
			f.cull_mode = BaseMaterial3D.CULL_DISABLED
			f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			m = f
		"foliage":
			m = foliage_material()
		_:
			m = _std("", 0.8)
	_cache[key] = m
	return m


static func _std(tex: String, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	if tex != "":
		m.albedo_texture = load(TEX + tex)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func foliage_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float sway = 0.06;
uniform float uv_scale = 2.5;
varying vec3 wpos;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = max(world.y - origin.y - 1.0, 0.0);
	float t = TIME * 1.3 + origin.x * 0.21 + origin.z * 0.17;
	VERTEX.x += sin(t) * sway * h * 0.35;
	VERTEX.z += cos(t * 0.8) * sway * h * 0.25;
	wpos = world;
}
void fragment() {
	vec3 n = abs(NORMAL);
	vec2 uv = wpos.xz;
	if (n.x > n.y && n.x > n.z) { uv = wpos.zy; } else if (n.z > n.y) { uv = wpos.xy; }
	float v = texture(tex, uv / uv_scale).r;
	ALBEDO = COLOR.rgb * (0.35 + v * 0.85);
	ROUGHNESS = 0.9;
	// leve translucidez nas folhas
	BACKLIGHT = COLOR.rgb * 0.25;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", load(TEX + "foliage.png"))
	return m
