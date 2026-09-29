shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.62, 0.72, r) * (1.0 - smoothstep(0.86, 0.98, r));
	float fill = (1.0 - smoothstep(0.0, 0.7, r)) * 0.12;
	ALBEDO = color.rgb;
	ALPHA = (ring * 0.75 + fill) * color.a;
}
