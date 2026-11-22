// The river past the map's edge (port of buildStream in terrain-outer.ts): stripes moving with the water and foam where
// the drop is steepest, darkening with the ring to black like the ground. UV: (tiles from the edge, steepness); COLOR:
// the ring's tone.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 water_col : source_color;
uniform float dir; // 1: the water flows toward the edge (the spring side), -1: away from it
uniform vec2 origin;

varying vec2 sxz;

void vertex() {
	sxz = VERTEX.xz + origin;
}

void fragment() {
	float flow = UV.x;
	float slope = UV.y;
	float w = sin(sxz.y * 9.0 + flow * 3.0) * 0.08;
	float lane = fract(flow * 1.6 + dir * TIME * (0.7 + 0.9 * clamp(slope, 0.0, 1.5)) + w);
	float streak = smoothstep(0.75, 1.0, lane) * (0.35 + 0.65 * fract(sin(floor(sxz.y * 6.0) * 78.233) * 43758.5));
	float foam = clamp(smoothstep(0.15, 0.7, slope) * (0.45 + 0.55 * streak) + streak * 0.3, 0.0, 1.0);
	ALBEDO = mix(water_col * COLOR.rgb, vec3(0.9, 0.96, 1.0) * COLOR.rgb, foam);
	ALPHA = mix(0.92, 1.0, foam);
}
