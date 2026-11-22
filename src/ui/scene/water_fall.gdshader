// The water's sides (port of fallMaterial in water-shaders.ts): a waterfall inside the map (UV2.x 1) runs in threads of
// foam and foams at its foot; the cut at the map's edge (UV2.x 0) darkens toward the bottom in bands.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 side_col : source_color;

varying float fall;

void vertex() {
	fall = UV2.x;
}

void fragment() {
	// vertical threads, each with its own phase and strength (drawn by column)
	float col = floor(UV.x * 14.0);
	float rnd = fract(sin(col * 12.9898) * 43758.5453);
	float streak = fract(UV.y * 2.0 + TIME * (1.2 + 0.8 * rnd) + rnd);
	float fall_foam = step(0.72, streak) * (0.35 + 0.45 * rnd) + step(0.82, 1.0 - UV.y) * 0.75 + step(0.94, UV.y) * 0.5;
	vec3 base = side_col;
	// the volume's cut: light at the surface line, darkening toward the bottom
	vec3 cut = mix(vec3(0.09, 0.24, 0.45), base, step(0.5, UV.y)) * (1.0 + 0.6 * step(0.92, UV.y));
	float foam = clamp(fall_foam, 0.0, 1.0) * fall;
	ALBEDO = mix(mix(cut, base * 1.15, fall), vec3(0.92, 0.97, 1.0), foam);
	ALPHA = max(mix(0.85, 0.7, fall), foam);
}
