extends RefCounted
## The shared materials of the buildings: one procedural shader per kind of surface (facade with its
## windows, tar roof, trim, shop glass, awning canvas, lamps). Shared by every lot, so the whole city
## costs a handful of materials; day/night and wet are uniforms set once for all of them.
##
## Vertex data the shaders read (everything is built in scripts/world3d/buildings/*):
##   wall : UV = (metres along the face, metres above ground), UV2 = (window width, face length),
##          COLOR r = columns/16, g = brick tint, b = (style + 4 * ground mode)/16, a = lot seed
##   roof : UV = deck coords, UV2 = deck size, COLOR rgb = tone, a = surface/4
##   trim : COLOR = colour (sRGB)
##   glass: UV = 0..1 across the pane, UV2 = pane size, COLOR rgb = tint, a = mode
##   awn  : UV = (metres along, 0..1 wall to edge), UV2 = (stripe width, 1 = valance), COLOR = canvas colour
##   lamp : COLOR rgb = colour, a = glow (1 = lamp, 0.5 = neon)

const COMMON := """
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec3 lin(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
vec3 alb(vec3 c) { return lin(c) * 0.74; }
"""

const WALL := """
shader_type spatial;
render_mode cull_back;
//COMMON
uniform float night = 0.0;
uniform float wet = 0.0;
uniform float lit_ratio = 0.0;
uniform int dbg = 0;
varying vec4 vc;
varying vec2 vuv;
varying vec2 vuv2;
void vertex() {
	vc = COLOR;
	vuv = UV;
	vuv2 = UV2;
}
void fragment() {
	float u = vuv.x;
	float y = vuv.y;
	float ncols = floor(vc.r * 16.0 + 0.5);
	float tint = floor(vc.g * 255.0 + 0.5) / 255.0;
	float sg = floor(vc.b * 16.0 + 0.5);
	float gm = floor(sg / 4.0);
	float style = sg - gm * 4.0;
	float seed = floor(vc.a * 255.0 + 0.5) / 255.0;
	float ww = vuv2.x;
	float L = vuv2.y;
	float aa = length(fwidth(vec2(u, y)));
	vec3 base;
	vec3 stone = vec3(0.72, 0.68, 0.60);
	if (style < 0.5) base = vec3(0.47, 0.26, 0.20);
	else if (style < 1.5) base = vec3(0.37, 0.23, 0.18);
	else if (style < 2.5) base = vec3(0.66, 0.56, 0.43);
	else base = vec3(0.60, 0.58, 0.53);
	base *= 0.80 + 0.40 * tint;
	base = mix(base, base * vec3(1.06, 0.98, 0.9), fract(tint * 7.0));
	// ---- the wall: brick courses, plaster or ashlar
	vec3 col = base;
	vec2 bs = vec2(0.30, 0.095);
	float mort_k = 0.9;
	if (style > 1.5 && style < 2.5) { bs = vec2(0.30, 0.095); mort_k = 0.3; }
	if (style > 2.5) { bs = vec2(0.66, 0.36); mort_k = 0.55; }
	vec2 bp = vec2(u, y) / bs;
	float row = floor(bp.y);
	bp.x += 0.5 * mod(row, 2.0);
	vec2 bc = floor(bp);
	vec2 bf = fract(bp);
	float dx = min(bf.x, 1.0 - bf.x) * bs.x;
	float dy = min(bf.y, 1.0 - bf.y) * bs.y;
	float mw = style > 2.5 ? 0.014 : 0.010;
	float m = 1.0 - smoothstep(-aa, aa, min(dx - mw, dy - mw * 1.3));
	float bh = h21(bc + seed * 57.0);
	vec3 bcol = base * (0.86 + 0.26 * bh);
	if (bh > 0.94) bcol *= 0.72;
	if (bh < 0.05) bcol *= 1.18;
	float fade = smoothstep(0.035, 0.10, aa);
	vec3 mortar = vec3(0.66, 0.62, 0.56) * (0.55 + 0.45 * length(base));
	col = mix(bcol, mortar, m * mort_k);
	col = mix(col, base * 0.97, fade);
	// grime and weather
	float grime = vn(vec2(u * 0.55, y * 0.22) + seed * 40.0);
	col *= 0.86 + 0.22 * grime;
	col *= 1.0 - 0.16 * smoothstep(0.55, 1.0, vn(vec2(u * 2.6, y * 0.12 + seed * 9.0)));
	// stone water table
	float wt = 0.62;
	if (y < wt) {
		vec3 sc = stone * 0.62 * (0.9 + 0.2 * h21(floor(vec2(u / 0.8, y / 0.3))));
		col = sc * (0.85 + 0.15 * vn(vec2(u * 4.0, y * 8.0)));
	}
	col = mix(col, stone * 0.8, smoothstep(wt, wt + 0.02, y) * (1.0 - smoothstep(wt + 0.02, wt + 0.07, y)) * 0.8);
	// ---- windows
	float emis = 0.0;
	vec3 ecol = vec3(0.0);
	float shine = 0.0;
	if (ncols > 0.5 && ww > 0.01 && y > 0.6) {
		float cw = L / ncols;
		float cidx = floor(u / cw);
		float cc = (cidx + 0.5) * cw;
		float lu = u - cc;
		float hw = ww * 0.5;
		bool ok = true;
		float fi = 0.0;
		float wy0 = 0.95;
		float wy1 = 2.5;
		if (y < 3.4) {
			if (gm < 0.5) ok = false;
			if (gm > 0.5 && gm < 1.5 && abs(cc - 0.5 * L) < 1.3) ok = false;
		} else {
			fi = floor((y - 3.4) / 3.0) + 1.0;
			float fb = 3.4 + (fi - 1.0) * 3.0;
			wy0 = fb + 0.6;
			wy1 = fb + 2.35;
		}
		if (ok) {
			float arch = (style < 2.5 && fract(seed * 7.31) > 0.55) ? 1.0 : 0.0;
			float d = max(abs(lu) - hw, max(wy0 - y, y - wy1));
			float ys = wy1 - hw;
			if (arch > 0.5 && y > ys) d = length(vec2(lu, y - ys)) - hw;
			float wid = h21(vec2(cidx * 3.1 + fi * 7.7, seed * 133.0));
			// shutters beside the window
			float sh_on = (style < 2.5 && fract(seed * 3.7) > 0.62 && (cw * 0.5 - hw) > hw * 0.6) ? 1.0 : 0.0;
			if (sh_on > 0.5 && d > 0.07 && abs(lu) < hw + 0.07 + hw * 0.55 && y > wy0 && y < (arch > 0.5 ? ys : wy1)) {
				vec3 shc = (fract(seed * 11.3) > 0.5) ? vec3(0.17, 0.30, 0.22) : vec3(0.30, 0.20, 0.13);
				float lv = 0.8 + 0.2 * step(0.5, fract((y - wy0) * 17.0));
				col = shc * lv;
			}
			// the stone surround: lintel, jambs, and the sill band
			float sw = 0.10;
			if (d > 0.0 && d < sw && (y > wy0 - 0.02 || abs(lu) > hw - 0.02)) {
				float lin = (y > wy1 - 0.02 && arch < 0.5) ? 0.04 : 0.0;
				col = mix(col, stone * (0.95 + 0.2 * h21(vec2(floor(y * 4.0), cidx))), step(d, sw + lin));
				if (arch < 0.5 && y > wy1 && y < wy1 + 0.16 && abs(lu) < hw + 0.09) col = stone * 0.98;
			}
			if (y < wy0 && y > wy0 - 0.2 && abs(lu) < hw + 0.1) col = mix(col, stone * 0.9, 1.0 - smoothstep(0.12, 0.2, wy0 - y));
			// soot under the sill
			if (y < wy0 - 0.2 && y > wy0 - 1.1 && abs(lu) < hw + 0.05) col *= 0.88 + 0.12 * smoothstep(1.1, 0.2, wy0 - y);
			if (d < 0.0) {
				// reveal (the window is set into the wall)
				vec3 jamb = col * 0.3;
				float lux = lu / hw;
				float t = (y - wy0) / (wy1 - wy0);
				vec3 frame = (wid < 0.5) ? vec3(0.86, 0.82, 0.72) : ((wid < 0.8) ? vec3(0.22, 0.17, 0.12) : vec3(0.18, 0.28, 0.24));
				vec3 glass = mix(vec3(0.14, 0.18, 0.24), vec3(0.42, 0.52, 0.60), clamp(t * 0.9 + 0.1 * lux, 0.0, 1.0));
				glass *= 0.75 + 0.5 * h21(vec2(cidx + fi * 5.0, seed * 77.0));
				float streak = smoothstep(0.03, 0.0, abs(fract((lu * 0.9 + y * 0.55) * 0.8) - 0.5) - 0.42) * 0.10;
				glass += streak;
				float mid = 0.5 * (wy0 + wy1);
				float frame_w = 0.045;
				float inner = -d;
				bool is_frame = inner < 0.075 + frame_w && inner > 0.075;
				if (abs(lu) < 0.022 && ww > 0.9) is_frame = true;
				if (abs(y - mid) < 0.028) is_frame = true;
				if (abs(y - mid * 0.5 - wy0 * 0.5) < 0.014 || abs(y - (mid * 0.5 + wy1 * 0.5)) < 0.014) { if (ww > 0.0) is_frame = is_frame || (abs(lu) < hw); }
				// blinds, curtains, a dark room
				float ch = h21(vec2(cidx * 1.37 + fi * 4.3, seed * 91.0));
				vec3 inside = glass;
				float cover = 0.0;
				if (ch < 0.30) {
					float f = 0.25 + 0.55 * h21(vec2(ch * 31.0, fi + seed));
					if (y > wy1 - f * (wy1 - wy0)) { inside = vec3(0.80, 0.74, 0.60) * (0.8 + 0.2 * sin(lu * 40.0)); cover = 1.0; }
				} else if (ch < 0.42) {
					inside = vec3(0.13, 0.10, 0.09); cover = 0.6;
				} else if (ch < 0.5) {
					if (abs(lu) > hw * 0.35 && abs(lu) < hw * 0.9) { inside = vec3(0.70, 0.66, 0.52); cover = 1.0; }
				}
				float lit_h = h21(vec2(cidx * 1.7 + fi * 13.1, seed * 100.0 + 3.0));
				vec3 col_in;
				if (inner < 0.075) {
					col_in = jamb * (0.7 + 0.5 * smoothstep(0.0, 0.075, inner));
					if (y > wy1 - 0.12) col_in *= 0.6;
				} else if (is_frame) {
					col_in = frame * (0.85 + 0.15 * lux);
				} else {
					col_in = inside;
					shine = 1.0 - cover * 0.8;
					if (lit_h < lit_ratio) {
						float k = h21(vec2(cidx * 9.0, fi * 3.0 + seed));
						vec3 lc = mix(vec3(1.0, 0.70, 0.36), vec3(1.0, 0.86, 0.58), k);
						if (k > 0.9) lc = vec3(0.55, 0.72, 1.0);
						float vgl = 0.75 + 0.25 * (1.0 - abs(lux));
						ecol = lc * vgl * (cover > 0.5 ? 0.62 : 1.0) * (0.85 + 0.3 * h21(vec2(fi, cidx)));
						emis = 1.0;
						col_in = mix(col_in, lc * 0.4, 0.5);
					}
				}
				col = col_in;
			}
		}
	}
	// ghost signs on the blank party walls
	if (ncols < 0.5 && L > 3.2 && y > 4.0 && fract(seed * 13.7) > 0.5) {
		float ya = 4.6 + fract(seed * 3.3) * 3.0;
		if (u > L * 0.16 && u < L * 0.84 && y > ya && y < ya + 2.4) {
			float edge = min(min(u - L * 0.16, L * 0.84 - u), min(y - ya, ya + 2.4 - y));
			vec3 pc = (fract(seed * 5.1) > 0.5) ? vec3(0.80, 0.74, 0.60) : vec3(0.75, 0.30, 0.25);
			float band = step(0.5, fract(y * 3.0 + 0.2));
			float a = smoothstep(0.0, 0.1, edge) * (0.30 + 0.12 * band) * (0.6 + 0.4 * vn(vec2(u * 3.0, y * 3.0)));
			col = mix(col, pc, a);
		}
	}
	col *= 1.0 - 0.25 * wet;
	ALBEDO = alb(col) * 1.15;
	ROUGHNESS = mix(0.93, 0.5, wet) * (1.0 - 0.8 * shine) + 0.12 * shine;
	SPECULAR = 0.2 + 0.5 * shine;
	EMISSION = lin(ecol) * emis * night * 1.35 + (alb(col) * vec3(0.16, 0.2, 0.34) * 2.6 + vec3(0.022, 0.03, 0.06)) * night;
	if (dbg == 1) { ALBEDO = lin(bcol); EMISSION = vec3(0.0); }
	if (dbg == 2) { ALBEDO = vec3(m); EMISSION = vec3(0.0); }
	if (dbg == 3) { ALBEDO = vec3(fract(bp.y), fract(bp.x), 0.0); EMISSION = vec3(0.0); }
	if (dbg == 4) { ALBEDO = vec3(bh); EMISSION = vec3(0.0); }
	if (dbg == 5) { ALBEDO = base; EMISSION = vec3(0.0); }
	if (dbg == 6) { ALBEDO = vec3(h21(bc)); EMISSION = vec3(0.0); }
	if (dbg == 7) { ALBEDO = vec3(seed, tint, 0.0); EMISSION = vec3(0.0); }
}
"""

const ROOF := """
shader_type spatial;
render_mode cull_back;
//COMMON
uniform float wet = 0.0;
uniform float night = 0.0;
varying vec4 vc;
varying vec3 vwp;
varying vec2 vuv;
varying vec2 vuv2;
void vertex() {
	vc = COLOR;
	vuv = UV;
	vuv2 = UV2;
	vwp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float style = floor(vc.a * 4.0 + 0.5);
	vec2 p = vwp.xz;
	float aa = length(fwidth(p));
	vec3 tone = vc.rgb;
	float n1 = vn(p * 0.8);
	float n2 = vn(p * 4.0 + 17.0);
	vec3 col = tone * (0.80 + 0.35 * n1);
	float rough = 0.95;
	if (style < 0.5 || style > 1.5 && style < 2.5) {
		// tar paper: roll seams across the deck, newer patches, bubbles
		float seam = style > 1.5 ? 0.9 : 1.15;
		float sx = abs(fract((vuv.x + 0.37 * floor(vuv.y / 7.0)) / seam) - 0.5) * seam;
		col *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.035 + aa, sx));
		float roll = h21(vec2(floor((vuv.x) / seam), 3.0 + floor(vuv.y / 7.0)));
		col *= 0.92 + 0.14 * roll;
		col = mix(col, col * 1.15, smoothstep(0.7, 0.85, n1) * 0.5);
		col *= 0.9 + 0.2 * n2;
	} else if (style < 1.5) {
		float g = h21(floor(p * 34.0));
		float fg = smoothstep(0.03, 0.09, aa);
		col = mix(tone * (0.72 + 0.5 * g), tone, fg);
		col *= 0.85 + 0.3 * n1;
	} else {
		float s = 0.5 + 0.5 * sin(vuv.x * 14.0);
		col = tone * (0.78 + 0.28 * mix(s, 0.5, smoothstep(0.1, 0.3, aa)));
		col = mix(col, vec3(0.45, 0.22, 0.12), smoothstep(0.7, 0.85, n2) * 0.5);
	}
	float edge = min(min(vuv.x, vuv2.x - vuv.x), min(vuv.y, vuv2.y - vuv.y));
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.8, edge));
	// puddles when it rains
	float pud = smoothstep(0.52, 0.42, n1) * wet;
	col = mix(col * (1.0 - 0.3 * wet), col * 0.45, pud);
	ALBEDO = alb(col) * 1.25;
	ROUGHNESS = mix(rough, 0.12, pud) * (1.0 - 0.25 * wet);
	SPECULAR = 0.2 + 0.5 * pud;
	EMISSION = (alb(col) * vec3(0.16, 0.2, 0.34) * 2.6 + vec3(0.022, 0.03, 0.06)) * night;
}
"""

const TRIM := """
shader_type spatial;
render_mode cull_back;
//COMMON
uniform float wet = 0.0;
uniform float night = 0.0;
varying vec4 vc;
varying vec3 vlp;
void vertex() {
	vc = COLOR;
	vlp = VERTEX;
}
void fragment() {
	vec3 col = vc.rgb;
	float n = vn(vlp.xz * 7.0 + vlp.y * 3.0) * 0.6 + vn(vlp.xy * 11.0 + vlp.z * 5.0) * 0.4;
	col *= 0.88 + 0.22 * n;
	col *= 1.0 - 0.2 * wet;
	ALBEDO = alb(col) * 1.2;
	ROUGHNESS = mix(0.82, 0.5, wet);
	EMISSION = (alb(col) * vec3(0.16, 0.2, 0.34) * 2.6 + vec3(0.022, 0.03, 0.06)) * night;
}
"""

const GLASS := """
shader_type spatial;
render_mode cull_back;
//COMMON
uniform float night = 0.0;
uniform float wet = 0.0;
varying vec4 vc;
varying vec2 vuv;
varying vec2 vuv2;
void vertex() {
	vc = COLOR;
	vuv = UV;
	vuv2 = UV2;
}
void fragment() {
	vec2 uv = vuv;
	float mode = vc.a;
	vec3 tint = vc.rgb;
	bool dark = mode > 0.8 && mode < 0.95;
	bool broken = mode > 0.95;
	float sz = vuv2.x;
	vec3 refl = mix(vec3(0.66, 0.76, 0.84), vec3(0.28, 0.38, 0.50), uv.y);
	refl += 0.08 * smoothstep(0.04, 0.0, abs(fract((uv.x * sz + uv.y * vuv2.y * 0.7) * 0.5) - 0.5) - 0.40);
	// the shop inside: warm room, faint shelves with a few goods
	float sy = uv.y * vuv2.y;
	float gx = floor(uv.x * sz * 4.0);
	float shelf_y = fract(sy * 0.8 + 0.1);
	float shelf = smoothstep(0.06, 0.0, abs(shelf_y - 0.5) - 0.44);
	float gd = h21(vec2(gx, floor(sy * 0.8 + 0.1)));
	float goods = step(0.45, gd) * step(0.5, shelf_y) * (1.0 - shelf);
	vec3 room = tint * (0.5 + 0.35 * uv.y);
	room = mix(room, tint * vec3(1.2, 0.9, 0.7), goods * 0.5);
	room *= 1.0 - 0.4 * shelf;
	vec3 col = mix(room, refl, 0.40 + 0.22 * wet);
	vec3 em = vec3(0.0);
	if (!dark) {
		vec3 lamp = mix(vec3(1.0, 0.66, 0.34), vec3(1.0, 0.84, 0.56), uv.y);
		float k = (0.78 + 0.22 * goods) * (0.75 + 0.25 * (1.0 - abs(uv.x - 0.5) * 1.5)) * (1.0 - 0.3 * shelf);
		em = lamp * k * night + room * 0.22 * (1.0 - night);
		col = mix(col, lamp * 0.35, night * 0.55);
	} else {
		col = col * 0.35;
	}
	if (broken) {
		vec2 c = uv - vec2(0.55, 0.5);
		c.x *= sz / max(vuv2.y, 0.1);
		float r = length(c);
		float ang = atan(c.y, c.x);
		float jag = 0.14 + 0.10 * h21(vec2(floor(ang * 3.0), 2.0)) + 0.06 * sin(ang * 7.0);
		if (r < jag * 1.7) discard;
		float cr = smoothstep(0.02, 0.0, abs(fract(ang * 1.2) - 0.5) - 0.47) * step(r, 0.9);
		col = mix(col, vec3(0.9, 0.95, 1.0), cr * 0.6);
		em *= 0.4;
	}
	ALBEDO = alb(col) * 1.2;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = lin(em);
}
"""

const AWN := """
shader_type spatial;
render_mode cull_disabled;
//COMMON
uniform float wet = 0.0;
uniform float night = 0.0;
varying vec4 vc;
varying vec2 vuv;
varying vec2 vuv2;
varying vec3 vwp;
void vertex() {
	vc = COLOR;
	vuv = UV;
	vuv2 = UV2;
}
void fragment() {
	float sw = vuv2.x;
	vec3 main = vc.rgb;
	bool solid = vc.a > 0.4 && vc.a < 0.7;
	vec3 cream = vec3(0.90, 0.85, 0.72);
	float par = mod(floor(vuv.x / sw), 2.0);
	vec3 col = (par < 0.5 || solid) ? main : cream;
	float aa = fwidth(vuv.x);
	float edge = abs(fract(vuv.x / sw) - 0.5);
	col *= 0.94 + 0.06 * sin(vuv.x * 90.0) * (1.0 - smoothstep(0.01, 0.04, aa));
	if (vuv2.y > 0.5) {
		// the scalloped valance
		float s = abs(fract(vuv.x / 0.24) - 0.5) * 2.0;
		float lim = 0.62 + 0.38 * (1.0 - s * s);
		if (vuv.y > lim) discard;
		if (vuv.y > lim - 0.07) col *= 0.82;
		col *= 0.88;
	} else {
		col *= 0.62 + 0.38 * vuv.y;
	}
	col *= 1.0 - 0.18 * wet;
	if (!FRONT_FACING) col *= 0.55;
	ALBEDO = alb(col) * 1.6;
	ROUGHNESS = 0.9;
	EMISSION = (alb(col) * vec3(0.4, 0.45, 0.65) * 1.8 + vec3(0.022, 0.03, 0.06)) * night;
}
"""

const LAMP := """
shader_type spatial;
render_mode cull_back;
//COMMON
uniform float night = 0.0;
varying vec4 vc;
void vertex() { vc = COLOR; }
void fragment() {
	vec3 c = vc.rgb;
	float k = vc.a;
	float on = smoothstep(0.35, 0.6, night);
	if (k < 0.35) {
		// skylights and clerestory glass: pale glass by day, a warm glow at night
		ALBEDO = alb(vec3(0.42, 0.52, 0.58));
		ROUGHNESS = 0.2;
		EMISSION = lin(c) * 1.3 * on;
	} else {
		float glow = k > 0.75 ? (0.10 + 1.6 * night) : (0.05 + 1.7 * on);
		ALBEDO = alb(mix(c, vec3(0.6, 0.64, 0.66), 0.5 * (1.0 - clamp(night * 1.4, 0.0, 1.0)) * (k < 0.75 ? 1.0 : 0.8)));
		EMISSION = lin(c) * glow;
	}
}
"""

static var _mats := {}


static func get_mats() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats["wall"] = _shader(WALL)
	_mats["roof"] = _shader(ROOF)
	_mats["trim"] = _shader(TRIM)
	_mats["glass"] = _shader(GLASS)
	_mats["awn"] = _shader(AWN)
	_mats["lamp"] = _shader(LAMP)
	return _mats


static func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code.replace("//COMMON", COMMON)
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## night 0..1, wet 0..1
static func set_light(night: float, wet: float) -> void:
	var mats := get_mats()
	var on := clampf((night - 0.15) / 0.5, 0.0, 1.0)
	for k in ["wall", "glass", "lamp", "trim", "awn", "roof"]:
		(mats[k] as ShaderMaterial).set_shader_parameter("night", on)
	for k in ["wall", "roof", "trim", "glass", "awn"]:
		(mats[k] as ShaderMaterial).set_shader_parameter("wet", wet)
	(mats["wall"] as ShaderMaterial).set_shader_parameter("lit_ratio", 0.62 * on)
