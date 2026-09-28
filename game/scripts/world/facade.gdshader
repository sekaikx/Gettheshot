shader_type spatial;
// Tenement, loft and warehouse facades from a few boxes per building. The street front is the
// box's local +Z face. Drawn here: brick / stucco / stone walls, sash windows with frames,
// stone lintels and sills, blinds and lit rooms, rusticated bases, stoop doors and cellar
// grates, storefronts (cast-iron pilasters, bulkhead, display glass with a dim interior and
// shelves, transom lights, the signage band), sheet-metal cornices with brackets, parapets with
// coping, tar-paper roofs, painted wall advertisements ageing on blank side walls.
#include "res://scripts/world/cutaway.gdshaderinc"

uniform sampler2D brick_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D plaster_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roof_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ads_tex : source_color, filter_linear_mipmap;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;

// Per building, baked into the vertices:
//   COLOR.rgb = wall tint; COLOR.a * 255 = style + 8 * ad (0 none, 1..8 atlas cell) + 128 * corner
//   UV = (seed + 1000 * storefront + 10000 * part, height); UV2 = (width, depth)
// style: 0 / 1 brick (1 has arched lintels), 2 stucco, 3 warehouse, 4 roof only, 5 stone loft
// part: 0 walls and roof, 1 cornice, 2 parapet
varying vec3 size;
varying vec3 tint;
varying float seed;
varying float style;
varying float shop;
varying float part;
varying float ad;
varying float corner;
varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 pick4(float h, vec3 a, vec3 b, vec3 c, vec3 d) {
	return h < 0.25 ? a : (h < 0.5 ? b : (h < 0.75 ? c : d));
}

float box2(vec2 p, vec2 lo, vec2 hi) {
	return (p.x >= lo.x && p.x <= hi.x && p.y >= lo.y && p.y <= hi.y) ? 1.0 : 0.0;
}

void vertex() {
	size = vec3(UV2.x, UV.y, UV2.y);
	tint = COLOR.rgb;
	float code = floor(COLOR.a * 255.0 + 0.5);
	style = mod(code, 8.0);
	ad = mod(floor(code / 8.0), 16.0);
	corner = floor(code / 128.0);
	part = floor(UV.x / 10000.0 + 0.0001);
	float r = UV.x - part * 10000.0;
	shop = r >= 999.5 ? 1.0 : 0.0;
	seed = r - shop * 1000.0;
	lpos = VERTEX;
	lnrm = NORMAL;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 wall_base(float cu, float y, float st, vec3 tn) {
	if (st > 1.5 && st < 2.5) {
		vec3 pl = texture(plaster_tex, vec2(cu, y) * 0.2).rgb;
		pl = mix(vec3(dot(pl, vec3(0.33))), pl, 1.4);
		return pl * vec3(0.8, 0.74, 0.65) * tn;
	}
	if (st > 4.5) {
		// dressed stone in courses
		vec3 s = texture(plaster_tex, vec2(cu, y) * 0.11).rgb * vec3(0.9, 0.86, 0.78) * tn;
		float course = step(0.94, fract(y / 0.62)) + step(0.97, fract(cu / 1.3 + floor(y / 0.62) * 0.5)) * 0.6;
		return s * (1.0 - course * 0.28);
	}
	vec3 b = texture(brick_tex, vec2(cu, y) * 0.28).rgb;
	return b * tn * (st > 0.5 ? vec3(0.86, 0.8, 0.8) : vec3(1.0));
}

// One window seen from outside: frame, sash, glass, blind, a lit room. p = metres from the
// window centre (x) and from its sill (y); hw / hh = half width / full height.
void window_px(vec2 p, float hw, float hh, float cell, float lit_bias, float panes, inout vec3 col,
		inout vec3 emit, inout float rough, vec3 frame_col, float sd, float nt) {
	float ax = abs(p.x);
	if (ax > hw + 0.07 || p.y < -0.02 || p.y > hh + 0.07) return;
	col = frame_col;
	rough = 0.6;
	if (ax > hw - 0.02 || p.y < 0.06 || p.y > hh - 0.02) return;
	float r = h21(vec2(cell, sd * 3.7));
	float lit = r < mix(0.05, 0.42, nt) + lit_bias ? 1.0 : 0.0;
	float t = p.y / hh;
	// reflections of the sky and the street, darker at the bottom
	vec3 glass = mix(vec3(0.05, 0.055, 0.06), vec3(0.2, 0.23, 0.26), smoothstep(0.1, 1.0, t));
	glass += vec3(0.07) * step(0.8, fract((p.x + p.y) * 0.7 + r * 3.0));
	vec3 room = mix(vec3(1.0, 0.68, 0.36), vec3(0.95, 0.85, 0.66), h21(vec2(cell, 9.1)));
	// the blind, pulled down part way
	float blind = h21(vec2(cell, 4.3));
	float blind_to = 1.0 - blind * 0.75;
	vec3 blind_col = pick4(h21(vec2(cell, 7.7)), vec3(0.78, 0.72, 0.58), vec3(0.62, 0.55, 0.38), vec3(0.34, 0.42, 0.33), vec3(0.72, 0.66, 0.5));
	if (blind > 0.25 && t > blind_to) {
		glass = blind_col * (0.58 + 0.04 * step(0.5, fract(t * 6.0))) * (0.8 + 0.2 * smoothstep(blind_to, 1.0, t));
		if (lit > 0.5) emit = room * blind_col * (0.25 + 0.9 * nt);
	} else {
		// lace curtains at the sides on some
		if (h21(vec2(cell, 2.2)) > 0.6 && ax > hw * 0.6) glass = mix(glass, vec3(0.8, 0.78, 0.72), 0.55);
		if (lit > 0.5) {
			glass = mix(glass, room * 0.4, 0.8);
			emit = room * (0.08 + 1.1 * nt) * (0.7 + 0.3 * t);
		}
	}
	col = glass;
	rough = 0.08;
	// reveal shadow along the top and one side
	if (p.y > hh - 0.1 || p.x < -hw + 0.07) col *= 0.55;
	// meeting rail and muntins
	float bar = step(abs(t - 0.52), 0.012);
	if (panes > 1.5) bar = max(bar, step(abs(fract((p.x / (2.0 * hw)) * panes + 0.5 * mod(panes, 2.0)) - 0.5), 0.5 / (hw * 30.0)) * step(0.06, ax));
	else bar = max(bar, step(ax, 0.012));
	if (bar > 0.5) {
		col = frame_col * 0.9;
		emit *= 0.2;
		rough = 0.6;
	}
}

void fragment() {
	if (cutaway(wpos, FRAGCOORD.xy)) discard;
	vec3 n = normalize(lnrm);
	float y = lpos.y + size.y * 0.5;
	vec3 col = vec3(0.5);
	float rough = 0.9;
	vec3 emit = vec3(0.0);
	float metal = 0.0;
	float bh = h21(vec2(seed, 3.1));
	float bh2 = h21(vec2(seed, 8.3));
	vec3 trim_col = pick4(bh2, vec3(0.2, 0.28, 0.22), vec3(0.3, 0.15, 0.12), vec3(0.14, 0.13, 0.12), vec3(0.62, 0.58, 0.5));
	vec3 frame_col = pick4(h21(vec2(seed, 5.5)), vec3(0.8, 0.76, 0.66), vec3(0.18, 0.26, 0.2), vec3(0.34, 0.14, 0.11), vec3(0.12, 0.11, 0.1));
	vec3 stone = vec3(0.7, 0.65, 0.56) * mix(vec3(1.0), tint, 0.25);
	bool side_x = abs(n.x) > 0.5;
	float u = side_x ? lpos.z : lpos.x;
	float face_w = side_x ? size.z : size.x;
	float cu = u + face_w * 0.5;

	if (part > 1.5) {
		// parapet: wall material, stone coping on top
		col = wall_base(cu + wpos.x + wpos.z, y, style, tint) * 0.92;
		if (n.y > 0.5 || y > size.y + 0.62) col = stone * 0.48;
	} else if (part > 0.5) {
		// pressed-metal cornice: fascia with mouldings, modillion brackets underneath
		vec3 cc = trim_col;
		float top = size.y;
		float dy = top - y;
		col = cc;
		metal = 0.1;
		rough = 0.55;
		float along = side_x ? wpos.z : wpos.x;
		if (n.y > 0.5) {
			col = cc * 0.6;
		} else if (n.y < -0.5) {
			float br = step(0.72, fract(along / 0.6));
			col = mix(cc * 0.35, cc * 0.9, br);
		} else {
			if (dy < 0.1) col = cc * 1.15;
			else if (dy < 0.16) col = cc * 0.6;
			else if (dy < 0.36) {
				// dentils
				col = step(0.5, fract(along / 0.18)) > 0.5 ? cc * 1.05 : cc * 0.55;
			} else if (dy < 0.42) col = cc * 0.7;
			else {
				// brackets on the frieze
				float br = step(0.72, fract(along / 0.6));
				col = mix(cc * 0.85, cc * 1.1, br);
			}
		}
	} else if (n.y > 0.5) {
		// roofs: tar paper in lapped strips, silver-painted, or tar and gravel; dirt at the edges
		vec2 rp = wpos.xz;
		bool along_x = h21(vec2(seed, 1.7)) > 0.5;
		float sv = along_x ? rp.y : rp.x;
		float strip = fract(sv / 0.91);
		float sid = floor(sv / 0.91);
		vec3 tex = texture(roof_tex, rp * 0.12).rgb;
		float kind = h21(vec2(seed, 6.1));
		if (kind < 0.55) {
			col = tex * vec3(0.2, 0.195, 0.2) * (0.9 + 0.2 * h21(vec2(sid, seed)));
			col *= 1.0 - smoothstep(0.93, 0.97, strip) * 0.4;
			col += vec3(0.03) * smoothstep(0.97, 1.0, strip);
			rough = 0.85;
		} else if (kind < 0.82) {
			col = mix(tex * vec3(0.4, 0.41, 0.42), vec3(0.42, 0.43, 0.44), 0.5) * (0.9 + 0.14 * h21(vec2(sid, seed)));
			col *= 1.0 - smoothstep(0.94, 0.98, strip) * 0.3;
			metal = 0.35;
			rough = 0.5;
		} else {
			float grit = h21(floor(rp * 22.0));
			col = tex * vec3(0.34, 0.31, 0.28) * (0.8 + 0.4 * grit);
			rough = 0.95;
		}
		// patches of fresh tar and the odd repair
		vec2 cell = floor(rp / vec2(2.3, 1.7));
		float ph = h21(cell + seed * 1.3);
		vec2 cf = fract(rp / vec2(2.3, 1.7));
		if (ph > 0.86 && cf.x > 0.15 && cf.x < 0.85 && cf.y > 0.2 && cf.y < 0.8) {
			col = vec3(0.07, 0.07, 0.075);
			rough = 0.5;
			metal = 0.0;
		}
		// soot and grime collect along the parapet
		float ex = size.x * 0.5 - abs(lpos.x);
		float ez = size.z * 0.5 - abs(lpos.z);
		float edge = min(ex, ez);
		col *= mix(0.7, 1.0, smoothstep(0.25, 1.2, edge));
		if (style > 3.5 && style < 4.5) col *= 0.85;
		rough = mix(rough, 0.25, wet);
	} else if (n.y < -0.5) {
		col = vec3(0.1);
	} else if (style > 2.5 && style < 3.5) {
		// pier warehouse: painted corrugated iron, a band of high windows, big loading doors
		col = texture(metal_tex, vec2(cu, y) * 0.3).rgb * tint * 1.25;
		col *= 0.88 + 0.12 * step(0.5, fract(cu * 3.3));
		if (fract(y / 2.4) < 0.03) col *= 0.7;
		metal = 0.25;
		rough = 0.65;
		bool front = n.z > 0.5;
		float au = abs(u);
		if (front) {
			if (y < 4.6 && au < 1.4) {
				col = vec3(0.1, 0.08, 0.06);   // the open door
				if (y < 4.4 && au < 1.25) col = vec3(0.05, 0.04, 0.035);
				emit = vec3(1.0, 0.7, 0.4) * 0.25 * night;
			} else if (y < 4.8 && au > 2.0 && au < face_w * 0.5 - 1.0) {
				// sliding doors with cross braces
				float lx = fract((au - 2.0) / 2.6);
				float ly = y / 4.8;
				col = texture(metal_tex, vec2(cu * 1.3, y) * 0.5).rgb * vec3(0.42, 0.33, 0.26);
				float brace = step(abs(lx - ly), 0.02) + step(abs(lx - (1.0 - ly)), 0.02) + step(0.97, lx) + step(0.97, ly);
				if (brace > 0.5) col = vec3(0.22, 0.17, 0.13);
			}
			if (y > 5.4 && y < 6.8) {
				float fx = fract(cu / 1.6);
				if (fx > 0.12 && fx < 0.88) {
					col = vec3(0.1, 0.12, 0.13);
					rough = 0.1;
					if (step(0.5, fract(fx * 4.0)) > 0.5 && abs(fract(fx * 4.0) - 0.5) < 0.04) col = vec3(0.25);
					emit = vec3(1.0, 0.75, 0.45) * 0.3 * night;
				}
			}
			if (y > 7.0 && y < 8.3 && au < face_w * 0.5 - 1.0) col = trim_col * 0.8;   // name board
		} else if (y > 5.4 && y < 6.8 && fract(cu / 2.2) > 0.3 && fract(cu / 2.2) < 0.7) {
			col = vec3(0.1, 0.12, 0.13);
			rough = 0.1;
		}
	} else {
		col = wall_base(cu, y, style, tint);
		bool front = n.z > 0.5;
		bool back = n.z < -0.5;
		float gh = 4.2;
		float fh = 3.2;
		float au = abs(u);
		float top_band = size.y - 0.5;
		bool windows_here = front || back || corner > 0.5;
		// a painted advertisement on a blank side wall, weathered into the brick
		if (side_x && ad > 0.5 && corner < 0.5) {
			float sw = face_w - 1.4;
			float sh = sw * 0.5;
			float top = size.y - 1.5;
			vec2 q = vec2((u + sw * 0.5) / sw, (top - y) / sh);
			if (n.x > 0.0) q.x = 1.0 - q.x;
			if (q.x > 0.0 && q.x < 1.0 && q.y > 0.0 && q.y < 1.0) {
				float idx = ad - 1.0;
				vec2 cellv = vec2(mod(idx, 2.0), floor(idx / 2.0));
				vec3 paint = texture(ads_tex, (cellv + q) / vec2(2.0, 4.0)).rgb;
				float brick_l = dot(texture(brick_tex, vec2(cu, y) * 0.28).rgb, vec3(0.33));
				float flake = h21(floor(vec2(cu, y) * vec2(4.0, 6.0)));
				float wear = smoothstep(0.1, 0.32, brick_l) * (0.45 + 0.4 * flake) * (0.75 + 0.25 * sin(y * 0.9 + cu * 0.4));
				float age = 0.35 + 0.35 * bh;
				paint = mix(paint, vec3(dot(paint, vec3(0.33))), 0.3);
				col = mix(col, paint * mix(vec3(1.0), tint, 0.3), wear * age);
			}
			windows_here = false;
		}
		if (y < gh && front) {
			if (shop > 0.5) {
				// ---------------- storefront
				float half_w = face_w * 0.5;
				vec3 pil = trim_col;
				if (au > half_w - 0.42) {
					// cast-iron pilasters with fluting, a capital and a stone base
					col = pil * (0.85 + 0.25 * step(0.5, fract(u * 9.0)));
					metal = 0.3;
					rough = 0.5;
					if (y > 3.15 && y < 3.35) col = pil * 1.3;
					if (y < 0.3) col = stone * 0.8;
				} else if (y > 3.3) {
					col = pil * 0.75;   // signage band behind the board
					if (y > 4.05) col = pil * 1.2;
				} else if (y > 2.95) {
					// transom lights (prism glass)
					col = vec3(0.3, 0.3, 0.26);
					rough = 0.2;
					emit = vec3(1.0, 0.8, 0.55) * (0.04 + 0.35 * night);
					if (fract(u / 0.36) < 0.08 || y > 3.25 || y < 3.0) {
						col = pil;
						emit = vec3(0.0);
					}
				} else if (au < 0.62) {
					// the recessed door, glazed above the lock rail
					col = pil * 0.55;
					if (y > 1.2 && y < 2.6 && au < 0.45) {
						col = vec3(0.16, 0.12, 0.08);
						rough = 0.1;
						emit = vec3(1.0, 0.72, 0.42) * (0.06 + 0.6 * night);
					}
					if (y > 1.05 && y < 1.12) col = vec3(0.6, 0.5, 0.3);
					col *= 0.8;
				} else if (y < 0.62) {
					// bulkhead panels
					col = pil * 0.8;
					float pu = fract((au - 0.62) / 1.1);
					if (pu > 0.1 && pu < 0.9 && y > 0.12 && y < 0.5) col = pil * 0.95;
				} else {
					float gx = au;
					if (gx < 0.72 || gx > half_w - 0.48 || y < 0.7 || y > 2.88) {
						col = pil * 0.9;   // window frame
					} else {
						// display glass, a dim interior with shelves of goods, a street reflection
						float cellx = floor(u / 0.45);
						float ty = (y - 0.7) / 2.2;
						vec3 inside = mix(vec3(0.11, 0.08, 0.055), vec3(0.05, 0.04, 0.03), ty);
						float shelf = step(abs(y - 1.25), 0.03) + step(abs(y - 1.95), 0.03);
						float goods = (fract(y / 0.7) > 0.25 && fract(y / 0.7) < 0.9) ? 1.0 : 0.0;
						vec3 gcol = pick4(h21(vec2(cellx, floor(y / 0.7) + seed)), vec3(0.5, 0.3, 0.18), vec3(0.6, 0.55, 0.4), vec3(0.3, 0.35, 0.28), vec3(0.55, 0.2, 0.15));
						if (goods > 0.5 && h21(vec2(cellx * 3.1, floor(y / 0.7))) > 0.35 && y < 2.4) inside = mix(inside, gcol * 0.35, 0.8);
						if (shelf > 0.5) inside = vec3(0.2, 0.14, 0.08);
						col = inside;
						rough = 0.06;
						metal = 0.2;
						col += vec3(0.1, 0.11, 0.12) * smoothstep(0.55, 1.0, ty);
						col += vec3(0.06) * step(0.86, fract((u * 0.8 + y * 0.6) * 0.5));
						emit = (inside * 2.2 + vec3(0.08, 0.05, 0.02)) * (0.35 + 2.4 * night);
						// the shop's name in gold leaf on the glass
						if (y > 2.2 && y < 2.45 && gx > 1.0 && gx < half_w - 1.0 && fract(u * 3.0) > 0.35) {
							col = vec3(0.75, 0.58, 0.28);
							metal = 0.7;
							rough = 0.3;
						}
					}
				}
			} else {
				// ---------------- a tenement ground floor: rusticated base, stoop door, raised windows
				col *= 0.82;
				if (fract(y / 0.55) < 0.07) col *= 0.7;
				if (au < 0.95 && y < 3.35 && y > 0.8) {
					col = stone * 0.85;   // door surround
					if (au < 0.72 && y < 3.15) {
						col = vec3(0.16, 0.1, 0.07);
						if (y > 2.75) {
							col = vec3(0.2, 0.18, 0.14);
							emit = vec3(1.0, 0.75, 0.45) * (0.05 + 0.5 * night);   // transom
						} else if (au < 0.3 && y > 1.6 && y < 2.55) {
							col = vec3(0.1, 0.1, 0.1);
							rough = 0.1;
						} else if (abs(au - 0.36) < 0.02) col *= 0.6;
					}
				} else if (au > 1.3) {
					float wx = 2.4;
					float bu = (au - 1.3) / wx;
					float bx = (fract(bu) - 0.5) * wx;
					if (floor(bu) < floor((face_w * 0.5 - 1.4) / wx) + 0.0 || bu < 1.0) {
						if (abs(bx) < 0.64 && y > 1.28 && y < 1.4) col = stone;   // sill
						if (abs(bx) < 0.68 && y > 3.3 && y < 3.55) col = stone;   // lintel
						window_px(vec2(bx, y - 1.4), 0.5, 1.9, floor(bu) + sign(u) * 7.0 + 90.0, 0.0, 1.0, col, emit, rough, frame_col, seed, night);
						if (abs(bx) < 0.45 && y > 0.12 && y < 0.62) {
							col = vec3(0.08, 0.07, 0.06);   // cellar grate
							if (fract(bx * 12.0) < 0.3) col = vec3(0.22, 0.2, 0.18);
						}
					}
				}
			}
		} else if (y < gh) {
			col *= 0.8;
			if (back && abs(u) < 0.6 && y < 2.4) col = vec3(0.14, 0.1, 0.07);
		} else if (y < top_band && windows_here) {
			// ---------------- upper floors
			float fl = floor((y - gh) / fh);
			float fy = (y - gh) - fl * fh;
			float loft = style > 4.5 ? 1.0 : 0.0;
			float pitch = loft > 0.5 ? 3.2 : mix(2.2, 2.7, bh);
			float margin = 0.75;
			float usable = face_w - 2.0 * margin;
			float nb = max(1.0, floor(usable / pitch));
			float bw = usable / nb;
			float bu = (cu - margin) / bw;
			float bi = floor(bu);
			float bx = (fract(bu) - 0.5) * bw;
			float hw = loft > 0.5 ? bw * 0.36 : 0.52 + 0.06 * bh2;
			float wy0 = 0.78;
			float wh = loft > 0.5 ? 2.0 : 1.72;
			if (bu >= 0.0 && bu < nb && fy < 3.15) {
				float ax = abs(bx);
				// sill with its shadow, lintel (flat stone, arched brick, or a loft's iron header)
				if (ax < hw + 0.13 && fy > wy0 - 0.12 && fy < wy0) col = stone;
				if (ax < hw + 0.13 && fy > wy0 - 0.22 && fy <= wy0 - 0.12) col *= 0.7;
				float lt = wy0 + wh + 0.07;
				if (style > 0.5 && style < 1.5) {
					float arch = lt + 0.08 * (1.0 - (bx * bx) / ((hw + 0.2) * (hw + 0.2)));
					if (ax < hw + 0.2 && fy > lt - 0.02 && fy < arch + 0.24) {
						col = wall_base(cu * 3.0, y, style, tint) * 0.75;
						if (fract(atan(bx, fy - lt + 1.2) * 18.0) < 0.12) col *= 0.7;
					}
					if (ax < 0.1 && fy > arch && fy < arch + 0.26) col = stone;   // keystone
				} else if (ax < hw + 0.18 && fy > lt && fy < lt + 0.26) {
					col = loft > 0.5 ? trim_col * 0.8 : stone * 0.95;
					if (fy > lt + 0.2) col *= 1.12;
				}
				window_px(vec2(bx, fy - wy0), hw, wh, bi * 17.0 + fl * 5.0 + (side_x ? 50.0 : 0.0) + (back ? 30.0 : 0.0),
					back ? -0.03 : 0.0, loft > 0.5 ? 3.0 : 1.0, col, emit, rough, loft > 0.5 ? trim_col : frame_col, seed, night);
			}
			// a string course between some floors
			if (fy < 0.12 && fy > 0.0 && h21(vec2(seed, fl)) > 0.55 && !back) col = stone * 0.9;
		} else if (y >= top_band) {
			col *= 0.9;
		} else if (side_x && y > gh) {
			// a blank party wall: soot streaks, patched brick, and on some a column of small
			// light-well windows
			float streak = h21(vec2(floor(cu * 1.7), seed));
			col *= 0.86 + 0.14 * streak * smoothstep(size.y, size.y - 6.0, y);
			if (h21(floor(vec2(cu * 0.8, y * 0.6)) + seed) > 0.93) col *= 0.82;
			if (ad < 0.5 && h21(vec2(seed, 11.0 + (n.x > 0.0 ? 1.0 : 0.0))) > 0.4) {
				float wx = face_w * (0.25 + 0.5 * h21(vec2(seed, 12.0 + (n.x > 0.0 ? 1.0 : 0.0))));
				float fl = floor((y - gh) / fh);
				float fy = (y - gh) - fl * fh;
				vec2 p = vec2(cu - wx, fy - 0.95);
				if (abs(p.x) < 0.5 && p.y > -0.1 && p.y < 0.0) col = stone;
				window_px(p, 0.36, 1.35, fl * 3.0 + 77.0 + (n.x > 0.0 ? 5.0 : 0.0), -0.02, 1.0, col, emit, rough, frame_col, seed, night);
			}
		}
		col *= 1.0 - wet * 0.25;
		if (wet > 0.0 && rough > 0.5) rough = mix(rough, 0.35, wet);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
