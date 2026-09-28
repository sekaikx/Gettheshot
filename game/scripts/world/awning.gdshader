shader_type spatial;
render_mode cull_disabled;
// Striped canvas awning over a shop, with a scalloped valance. The stripe colour is the family
// the shop pays (grey when it pays nobody), so you can read the street's loyalties from above.
// UV.x runs across (metres / 3.2), UV.y 0..1 down the slope, 1..1.3 down the valance.
#include "res://scripts/world/cutaway.gdshaderinc"

uniform vec4 stripe : source_color = vec4(0.45, 0.45, 0.42, 1.0);
uniform float night = 0.0;
uniform float wet = 0.0;
uniform float fade = 0.0;   // how sun-bleached this one is

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway(wpos, FRAGCOORD.xy)) discard;
	float sx = fract(UV.x * 7.0);
	float s = step(0.5, sx);
	if (UV.y > 1.0) {
		// scallops along the bottom of the valance
		float sc = 1.3 - 0.11 * (1.0 - pow(abs(sin(UV.x * 7.0 * 3.14159)), 0.6));
		if (UV.y > sc) discard;
	}
	vec3 cream = vec3(0.84, 0.8, 0.69);
	vec3 st = mix(stripe.rgb, mix(stripe.rgb, cream, 0.35), fade * 0.6);
	vec3 col = mix(cream, st, s);
	// the canvas sags between the frame bars and darkens at the seams
	col *= 0.9 + 0.1 * smoothstep(0.0, 0.08, abs(sx - 0.5));
	if (UV.y > 1.0) col *= 0.88;
	if (UV.y > 1.26) col *= 0.8;
	if (!FRONT_FACING) col *= 0.45;   // the shaded underside
	ALBEDO = col * (1.0 - wet * 0.3) * 0.9;
	ROUGHNESS = mix(0.95, 0.6, wet);
	// lit from below by the shop window at night
	EMISSION = col * (FRONT_FACING ? 0.02 : 0.12) * night;
}
