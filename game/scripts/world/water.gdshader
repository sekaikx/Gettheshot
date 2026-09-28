shader_type spatial;
// The East River at night: dark, slow swell, lamp and moon glints.
uniform float night = 0.0;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.35 + TIME * 0.9) * 0.08 + sin(w.z * 0.5 + TIME * 1.3) * 0.06;
}
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float r = sin(w.x * 1.7 + TIME * 1.1) * sin(w.z * 1.3 - TIME * 0.8);
	ALBEDO = mix(vec3(0.05, 0.09, 0.11), vec3(0.02, 0.04, 0.06), night);
	ROUGHNESS = 0.08;
	METALLIC = 0.3;
	NORMAL_MAP = normalize(vec3(0.5 + r * 0.12, 0.5 + r * 0.08, 1.0));
}
