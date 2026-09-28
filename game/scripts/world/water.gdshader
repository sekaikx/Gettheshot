shader_type spatial;
// The Hudson at the West Street piers: dark, slow swell, chop, foam round the pilings, the
// quay wall and the hulls, glints of lamps and moon.
uniform float night = 0.0;
uniform float wet = 0.0;
uniform float quay_x = 316.0;
uniform vec4 foam_rects[6];   // x0, z0, x1, z1 of piers and hulls

varying vec3 wpos;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float rect_dist(vec2 p, vec4 r) {
	vec2 c = (r.xy + r.zw) * 0.5;
	vec2 h = (r.zw - r.xy) * 0.5;
	vec2 d = abs(p - c) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.3 + TIME * 0.8) * 0.07 + sin(w.z * 0.45 + w.x * 0.1 + TIME * 1.2) * 0.05;
	wpos = w;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	// two layers of chop drive the normal
	float n1 = noise(p * 0.9 + vec2(t * 0.35, t * 0.12));
	float n2 = noise(p * 2.3 - vec2(t * 0.2, t * 0.45));
	float n3 = noise(p * 5.0 + vec2(t * 0.6, -t * 0.3));
	vec2 slope = vec2(n1 - 0.5, n2 - 0.5) * 0.1 + vec2(n3 - 0.5) * 0.04 * (1.0 + wet);
	NORMAL_MAP = normalize(vec3(0.5 + slope.x, 0.5 + slope.y, 1.0));
	NORMAL_MAP_DEPTH = 1.0;
	// deep river green-grey, darker far out
	vec3 day = mix(vec3(0.09, 0.13, 0.13), vec3(0.06, 0.09, 0.1), smoothstep(0.0, 60.0, wpos.x - quay_x));
	vec3 col = mix(day, vec3(0.012, 0.02, 0.03), night);
	// foam and flotsam where the water slaps against things
	float d = wpos.x - quay_x;
	for (int i = 0; i < 6; i++) {
		d = min(d, rect_dist(p, foam_rects[i]));
	}
	float edge = 1.0 - smoothstep(0.0, 0.7, d);
	float froth = smoothstep(0.5, 0.8, noise(p * 7.0 + vec2(t * 0.7, t * 0.4)) * noise(p * 2.0 - vec2(t * 0.2)) * 1.6 * (0.4 + edge));
	float foam = edge * froth;
	col = mix(col, vec3(0.5, 0.51, 0.48) * (1.0 - night * 0.75), foam * 0.55);
	// an oily sheen in the slips
	col += vec3(0.03, 0.02, 0.04) * edge * (1.0 - night) * step(0.6, noise(p * 0.6));
	ALBEDO = col;
	ROUGHNESS = mix(0.35, 0.85, foam);
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
