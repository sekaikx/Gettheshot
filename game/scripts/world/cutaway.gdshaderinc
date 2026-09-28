// Shared by the facade and the rooftop / fire-escape / structure props: cut away whatever stands
// between the camera and the player (dithered edge), and fade out anything right in front of
// the lens so the top-down view stays readable. `focus` and `cam_pos` are set every frame.
uniform vec3 focus = vec3(0.0);
uniform vec3 cam_pos = vec3(0.0, 100.0, 0.0);

float cut_dither(vec2 fc) {
	return fract(dot(floor(fc), vec2(0.7548, 0.5698)) + 0.13);
}

// true when this fragment should be discarded
bool cutaway(vec3 wpos, vec2 fragcoord) {
	vec3 seg = cam_pos - focus;
	float sl = max(dot(seg, seg), 0.001);
	float t = clamp(dot(wpos - focus, seg) / sl, 0.0, 1.0);
	float dcut = length(wpos - (focus + seg * t));
	float dither = cut_dither(fragcoord);
	if (smoothstep(9.0, 15.0, distance(wpos, cam_pos)) < dither) return true;
	if (t > 0.02 && wpos.y > 1.2) {
		float keep = smoothstep(2.6, 4.2, dcut);
		if (keep < dither) return true;
	}
	return false;
}
