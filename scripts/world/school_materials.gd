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


## Camadas do atlas (Texture2DArray) — mesma ordem de tools/gen_textures.py.
const LAYERS := {
	"plain": 0, "metal": 0, "glass": 0, "paint": 1, "chalk": 1, "tile": 2, "wood": 3, "grass": 4,
	"concrete": 5, "redfloor": 5, "brick": 6, "dirt": 7, "roof": 8, "asphalt": 9,
}
## Rugosidade (0..1) e metal (0..1) por material, enviados via UV2.y.
const SURFACE := {
	"plain": [0.8, 0.0], "metal": [0.38, 0.45], "glass": [0.08, 0.3], "paint": [0.92, 0.0], "chalk": [1.0, 0.0],
	"tile": [0.42, 0.0], "wood": [0.7, 0.0], "grass": [0.95, 0.0], "concrete": [0.88, 0.0], "redfloor": [0.45, 0.0],
	"brick": [0.9, 0.0], "dirt": [1.0, 0.0], "roof": [0.8, 0.0], "asphalt": [0.9, 0.0],
}


## Grupo de material real usado pelo batcher: quase tudo cai em "world".
static func group_of(key: String) -> String:
	if key == "fence" or key == "foliage":
		return key
	return "world"


## UV2 codificado: x = camada, y = rugosidade (parte inteira 0..100) + metal (fração).
static func uv2_of(key: String) -> Vector2:
	var s: Array = SURFACE.get(key, [0.8, 0.0])
	return Vector2(float(LAYERS.get(key, 0)), floorf(s[0] * 100.0) + clampf(s[1], 0.0, 0.99))


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match key:
		"world":
			m = world_material()
		"fence":
			var f := _std("fence.png", 0.6)
			f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			f.alpha_scissor_threshold = 0.5
			f.cull_mode = BaseMaterial3D.CULL_DISABLED
			f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			m = f
		"foliage":
			m = foliage_material()
		"plain":
			m = _std("", 0.8)
		_:
			m = world_material()
	_cache[key] = m
	return m


## Material único do cenário: textura de um Texture2DArray escolhida por
## vértice (UV2.x), cor por vértice, rugosidade/metal por vértice (UV2.y).
static func world_material() -> ShaderMaterial:
	if _cache.has("world"):
		return _cache["world"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2DArray atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying flat float layer;
varying float rough;
varying float metal;
void vertex() {
	layer = UV2.x;
	rough = floor(UV2.y) / 100.0;
	metal = fract(UV2.y);
}
void fragment() {
	vec3 t = texture(atlas, vec3(UV, layer)).rgb;
	ALBEDO = COLOR.rgb * t;
	ROUGHNESS = rough;
	METALLIC = metal;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("atlas", load(TEX + "world_atlas.png"))
	_cache["world"] = m
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
