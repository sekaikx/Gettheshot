shader_type spatial;
// Tenement facades from one unit box: brick or plaster walls, a grid of sash windows (a few lit
// at dusk, more at night), a stone cornice, a tar roof, and a storefront on the street side of a
// shop. The street front is the box's local +Z face.

uniform sampler2D brick_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D plaster_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roof_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform vec3 focus = vec3(0.0);
uniform vec3 cam_pos = vec3(0.0, 100.0, 0.0);

// per building, baked into the mesh: COLOR = tint + style / 8, UV = (seed, height), UV2 = (width, depth);
// seed >= 1000 marks a storefront. style: 0/1 brick, 2 plaster, 3 corrugated warehouse, 4 roof only
varying vec3 size;
varying vec4 tint;
varying float seed;
varying float style;
varying float shop;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	size = vec3(UV2.x, UV.y, UV2.y);
	tint = vec4(COLOR.rgb, 1.0);
	style = floor(COLOR.a * 8.0 + 0.5);
	shop = UV.x >= 1000.0 ? 1.0 : 0.0;
	seed = UV.x - shop * 1000.0;
	lpos = VERTEX;
	lnrm = NORMAL;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// cut away walls between the camera and the player, with a dithered edge
	vec3 seg = cam_pos - focus;
	float sl = max(dot(seg, seg), 0.001);
	float t = clamp(dot(wpos - focus, seg) / sl, 0.0, 1.0);
	float dcut = length(wpos - (focus + seg * t));
	if (t > 0.02 && wpos.y > 1.2) {
		float keep = smoothstep(2.6, 4.2, dcut);
		float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548, 0.5698)) + 0.13);
		if (keep < dither) discard;
	}
	vec3 n = normalize(lnrm);
	float y = lpos.y + size.y * 0.5;
	vec3 col;
	float rough = 0.9;
	vec3 emit = vec3(0.0);
	float metal = 0.0;
	if (n.y > 0.5) {
		col = texture(roof_tex, wpos.xz * 0.12).rgb * vec3(0.42, 0.40, 0.39);
		// tar seams
		float seam = step(0.96, fract(wpos.x * 0.25)) + step(0.96, fract(wpos.z * 0.25));
		col *= 1.0 - seam * 0.25;
		rough = mix(0.95, 0.35, wet);
	} else if (n.y < -0.5) {
		col = vec3(0.1);
	} else {
		bool side_x = abs(n.x) > 0.5;
		float u = side_x ? lpos.z : lpos.x;
		float face_w = side_x ? size.z : size.x;
		float cu = u + face_w * 0.5;
		if (style > 2.5 && style < 3.5) {
			col = texture(metal_tex, vec2(cu, y) * 0.3).rgb * tint.rgb * 0.8;
			metal = 0.2;
			rough = 0.7;
			// big loading doors on the street side
			if (n.z > 0.5 && y < 5.0 && abs(u) < face_w * 0.3) {
				col = texture(metal_tex, vec2(cu * 1.2, y) * 0.5).rgb * vec3(0.35, 0.3, 0.25);
			}
		} else {
			vec3 wall = style < 1.5 ? texture(brick_tex, vec2(cu, y) * 0.28).rgb
				: texture(plaster_tex, vec2(cu, y) * 0.2).rgb * vec3(0.82, 0.78, 0.7);
			col = wall * tint.rgb;
			float ground_h = 4.2;
			float floor_h = 3.2;
			bool front = n.z > 0.5;
			if (y < ground_h) {
				col *= 0.8;
				if (shop > 0.5 && front) {
					float half_w = face_w * 0.5;
					bool frame = abs(u) < half_w - 0.5 && y > 0.25 && y < 3.6;
					bool door = abs(u) < 0.75 && y < 2.7;
					bool glass = abs(u) < half_w - 0.8 && abs(u) > 1.0 && y > 0.9 && y < 3.2;
					if (frame) col = vec3(0.16, 0.1, 0.07);
					if (door) col = vec3(0.09, 0.06, 0.045);
					if (glass) {
						col = vec3(0.07, 0.08, 0.09);
						rough = 0.12;
						emit = vec3(1.0, 0.72, 0.42) * (0.25 + 1.6 * night);
					}
				} else if (front && abs(u) < 0.7 && y < 2.6) {
					col = vec3(0.12, 0.08, 0.06);  // tenement stoop door
				}
			} else if (y < size.y - 0.9) {
				float fy = fract((y - ground_h) / floor_h);
				float fl = floor((y - ground_h) / floor_h);
				float wx = 2.5;
				float fx = fract(cu / wx);
				float cl = floor(cu / wx);
				bool inside = cu > 0.8 && cu < face_w - 0.8;
				bool win = inside && fx > 0.28 && fx < 0.72 && fy > 0.22 && fy < 0.8;
				bool sill = inside && fx > 0.25 && fx < 0.75 && fy > 0.17 && fy < 0.22;
				if (sill) col = vec3(0.55, 0.52, 0.47) * tint.rgb;
				if (win) {
					float r = h21(vec2(cl + seed * 13.0, fl + seed * 7.0 + (side_x ? 50.0 : 0.0)));
					bool lit = r < mix(0.08, 0.5, night);
					bool shade = r > 0.8;
					col = shade ? vec3(0.32, 0.27, 0.2) : vec3(0.06, 0.07, 0.08);
					rough = 0.15;
					if (lit) emit = mix(vec3(1.0, 0.7, 0.38), vec3(0.9, 0.85, 0.7), h21(vec2(cl, fl))) * (0.2 + 1.8 * night);
					// the sash bar
					if (abs(fy - 0.51) < 0.015) col = vec3(0.2, 0.16, 0.12);
				}
			} else {
				col = vec3(0.35, 0.33, 0.3) * (0.8 + 0.2 * tint.rgb);  // cornice
				if (y > size.y - 0.35) col *= 0.7;
			}
		}
		col *= 1.0 - wet * 0.25;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
