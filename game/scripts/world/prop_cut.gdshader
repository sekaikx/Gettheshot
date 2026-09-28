shader_type spatial;
render_mode cull_disabled;
// Vertex-coloured props that stand above the street (fire escapes, water towers, roof clutter,
// signboards, the El, cranes, ships): same cut-away as the facades, optional texture and glow.
#include "res://scripts/world/cutaway.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_mix = 0.0;       // 0 = vertex colour only, 1 = vertex colour x texture
uniform float tex_scale = 1.0;
uniform float rough = 0.8;
uniform float metal = 0.0;
uniform vec3 glow = vec3(0.0);     // added emission x vertex colour (lit signs, lamps)
uniform float wet = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway(wpos, FRAGCOORD.xy)) discard;
	vec3 col = COLOR.rgb;
	if (tex_mix > 0.0) {
		col *= mix(vec3(1.0), texture(tex, UV * tex_scale).rgb * 1.6, tex_mix);
	}
	ALBEDO = col * (1.0 - wet * 0.2);
	ROUGHNESS = mix(rough, rough * 0.4, wet);
	METALLIC = metal;
	EMISSION = glow * COLOR.rgb;
}
