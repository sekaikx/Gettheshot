shader_type spatial;
// Striped canvas awning over a shop. The stripe colour is the family the shop pays (grey when it
// pays nobody), so you can read the street's loyalties from the rooftops.
uniform vec4 stripe : source_color = vec4(0.45, 0.45, 0.42, 1.0);
uniform float night = 0.0;
void fragment() {
	float s = step(0.5, fract(UV.x * 7.0));
	vec3 cream = vec3(0.86, 0.82, 0.72);
	ALBEDO = mix(cream, stripe.rgb, s) * 0.85;
	ROUGHNESS = 0.95;
	EMISSION = mix(cream, stripe.rgb, s) * 0.05 * night;
}
