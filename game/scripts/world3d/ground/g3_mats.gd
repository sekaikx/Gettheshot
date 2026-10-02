class_name G3Mats
extends RefCounted
## The ground's materials (Compatibility-renderer safe: no SSAO, no screen reads). One StandardMaterial3D
## per surface kind, plus small spatial shaders for glow, light pools, steam and the river.
## apply(night, wet) retunes them: lamp heads glow, wet streets lose roughness and darken.

# mesh key -> [texture key or "", uv metres per tile, material builder]
const TILE := {
	"road": 8.0, "cobble": 2.56, "setts": 2.56, "walk": 1.83, "planks": 2.0, "planks_z": 2.0, "dirt": 4.0,
}

var mats := {}
var water: ShaderMaterial
var steam: ShaderMaterial
var _wet_rough := {}
var _nscale := {}
var _wetable: Array = []     # [material, base roughness, base colour]
var night := 0.0
var wet := 0.0


func _init() -> void:
	mats["road"] = _tex("asphalt", 0.93, 1.1)
	mats["cobble"] = _tex("cobble", 0.82, 1.4)
	mats["setts"] = _tex("setts", 0.78, 1.0)
	mats["walk"] = _tex("slab", 0.9, 0.8)
	mats["planks"] = _tex("planks", 0.88, 1.0)
	mats["planks_z"] = mats["planks"]
	mats["dirt"] = _tex("dirt", 0.97, 0.8)
	mats["stone"] = _vc(0.88, 0.0)
	mats["props"] = _vc(0.8, 0.0)
	mats["metal"] = _vc(0.5, 0.3)
	mats["leaf"] = _vc(0.9, 0.0)
	mats["wood"] = _vc(0.9, 0.0)
	var paint := _vc(0.88, 0.0)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.render_priority = 1
	mats["paint"] = paint
	_wetable.append([paint, 0.88, paint.albedo_color])
	var pud := _vc(0.04, 0.0)
	pud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pud.cull_mode = BaseMaterial3D.CULL_DISABLED
	pud.render_priority = 2
	pud.metallic_specular = 1.0
	mats["puddle"] = pud
	mats["glow"] = _glow_mat()
	mats["pools"] = _pool_mat()
	water = _water_mat()
	steam = _steam_mat()
	for k in ["road", "cobble", "setts", "walk", "planks", "dirt", "stone"]:
		var m: StandardMaterial3D = mats[k]
		_wetable.append([m, m.roughness, m.albedo_color])
		_wet_rough[m] = {"road": 0.5, "cobble": 0.42, "setts": 0.4, "walk": 0.55, "planks": 0.5, "dirt": 0.8, "stone": 0.5}[k]
		_nscale[m] = m.normal_scale
	apply(0.0, 0.0)


func material(key: String) -> Material:
	return mats[key]


func _tex(key: String, rough: float, nscale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = G3Tex.albedo(key)
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	var nt := G3Tex.normal(key)
	if nt != null:
		m.normal_enabled = true
		m.normal_texture = nt
		m.normal_scale = nscale
	return m


func _vc(rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.74, 0.74, 0.74)
	m.roughness = rough
	m.metallic = metal
	return m


func _glow_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform float glow = 0.0;
uniform float day_glow = 0.12;
void fragment() {
	ALBEDO = COLOR.rgb * 0.5;
	ROUGHNESS = 0.3;
	EMISSION = COLOR.rgb * (day_glow + glow) * COLOR.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _pool_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
void fragment() {
	ALBEDO = COLOR.rgb * COLOR.a * strength;
	ALPHA = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 3
	return m


func _steam_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float vis = 0.3;
uniform float night = 0.0;
varying float life;
void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float sd = INSTANCE_CUSTOM.y;
	float t = fract(TIME * (0.16 + 0.06 * sd) + ph);
	life = t;
	vec3 c = MODEL_MATRIX[3].xyz;
	c.y += 0.15 + t * (2.4 + sd);
	c.x += sin(TIME * 0.7 + ph * 12.0) * 0.35 * t + 0.5 * t * (sd - 0.5);
	c.z += cos(TIME * 0.5 + ph * 9.0) * 0.3 * t + 0.4 * t;
	float sz = mix(0.35, 1.6, t) * (0.7 + 0.6 * sd);
	vec4 vp = VIEW_MATRIX * vec4(c, 1.0);
	vp.xy += VERTEX.xy * sz;
	POSITION = PROJECTION_MATRIX * vp;
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = smoothstep(1.0, 0.1, d);
	ALBEDO = mix(vec3(0.86, 0.87, 0.9), vec3(0.62, 0.66, 0.78), night);
	ALPHA = a * (1.0 - life) * smoothstep(0.0, 0.12, life) * 0.34 * vis;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 4
	return m


func _water_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform sampler2D nm : repeat_enable, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.09, 0.17, 0.21);
uniform vec3 deep : source_color = vec3(0.05, 0.10, 0.15);
uniform vec3 sky : source_color = vec3(0.55, 0.64, 0.72);
uniform float edge_x = 0.0;
uniform float night = 0.0;
uniform float wet = 0.0;
uniform vec3 lamps[16];
uniform int lamp_count = 0;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 q1 = wp.xz * 0.05 + vec2(TIME * 0.010, TIME * 0.022);
	vec2 q2 = wp.xz * 0.13 + vec2(-TIME * 0.021, TIME * 0.016);
	vec2 q3 = wp.xz * 0.31 + vec2(TIME * 0.03, -TIME * 0.02);
	vec3 a = texture(nm, q1).xyz * 2.0 - 1.0;
	vec3 b = texture(nm, q2).xyz * 2.0 - 1.0;
	vec3 c = texture(nm, q3).xyz * 2.0 - 1.0;
	vec2 pert = a.xy * 0.55 + b.xy * 0.35 + c.xy * 0.18;
	// rain rings
	float ring = 0.0;
	if (wet > 0.02) {
		vec2 g = wp.xz * 1.1;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float ph = h21(id);
		float t = fract(TIME * 0.8 + ph);
		float r = length(f + (vec2(h21(id + 3.1), h21(id + 7.7)) - 0.5) * 0.4);
		float w = smoothstep(0.06, 0.0, abs(r - t * 0.55));
		ring = w * (1.0 - t) * wet;
		pert += normalize(f + 0.001) * ring * 0.8;
	}
	vec3 nw = normalize(vec3(pert.x * 0.5, 1.0, pert.y * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float d = clamp((wp.x - edge_x) / 26.0, 0.0, 1.0);
	vec3 col = mix(shallow, deep, d);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky * mix(1.0, 0.12, night), fres * 0.3);
	// foam where the water slaps the quay wall, and slow glints on the swell
	float near_edge = smoothstep(1.4, 0.0, wp.x - edge_x);
	float foam = near_edge * (0.45 + 0.55 * sin(wp.z * 1.7 + TIME * 1.1 + a.x * 6.0));
	foam = clamp(foam, 0.0, 1.0) * 0.45;
	col += vec3(foam) * mix(1.0, 0.35, night);
	col += vec3(ring * 0.25);
	col = mix(col, vec3(0.03, 0.05, 0.09), night * 0.85);
	// lamp reflections: bright streaks pulled toward the viewer (south), broken by the swell
	vec3 em = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= lamp_count) break;
		vec3 L = lamps[i];
		float dx = wp.x - max(L.x, edge_x + 0.7);
		float dz = wp.z - L.z;
		float len = 1.0 + 6.0 * smoothstep(-0.5, 7.0, dz);
		float s = exp(-(dx * dx) / (0.35 + 0.15 * dz)) * smoothstep(-0.6, 0.3, dz) * smoothstep(9.0, 2.0, dz);
		float brk = 0.55 + 0.45 * sin(dz * 7.0 + TIME * 1.7 + a.x * 8.0 + dx * 3.0);
		em += vec3(1.0, 0.72, 0.4) * s * brk * 0.9 / len * 3.0;
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.32, 0.12, night);
	SPECULAR = 0.3;
	METALLIC = 0.0;
	EMISSION = em * night + sky * vec3(0.05, 0.07, 0.12) * fres * night * (0.5 + 0.5 * a.x);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("nm", G3Tex.normal("water"))
	return m


## Retune for the time of day and the weather.
func apply(n: float, w: float) -> void:
	night = clampf(n, 0.0, 1.0)
	wet = clampf(w, 0.0, 1.0)
	for e in _wetable:
		var m: StandardMaterial3D = e[0]
		var rough: float = e[1]
		var base: Color = e[2]
		m.roughness = lerpf(rough, float(_wet_rough.get(m, 0.5)), wet)
		m.metallic_specular = lerpf(0.5, 0.62, wet)
		if m.normal_enabled:
			m.normal_scale = float(_nscale[m]) * (1.0 - 0.8 * wet)
		var dark := lerpf(1.0, 0.7, wet)
		m.albedo_color = Color(base.r * dark, base.g * dark, base.b * dark * (1.0 + 0.05 * wet), base.a)
	var pud: StandardMaterial3D = mats["puddle"]
	pud.albedo_color = Color(1, 1, 1, clampf(wet * 1.6, 0.0, 1.0))
	var g: ShaderMaterial = mats["glow"]
	g.set_shader_parameter("glow", night * 2.6)
	(mats["pools"] as ShaderMaterial).set_shader_parameter("strength", night * 0.95)
	steam.set_shader_parameter("vis", 0.22 + 0.78 * maxf(night, wet))
	steam.set_shader_parameter("night", night)
	water.set_shader_parameter("night", night)
	water.set_shader_parameter("wet", wet)
