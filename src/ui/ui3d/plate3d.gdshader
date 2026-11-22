shader_type spatial;
// The strike preview plate of the 3D combat bar (port of the web game's bar3d/plates.ts PLATE_FRAG): a dark arrow whose
// point reaches the target's sheet, clear on the left where it meets the acting sheet, closed by a thin light line;
// `warn` reddens the line when the strike reaches the user's own side.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://src/ui/ui3d/bar3d.gdshaderinc"

uniform vec2 size;
uniform float unit = 1.0;
uniform float alpha = 0.0;
uniform float warn;

const vec2 PLATE = vec2(340.0, 218.0);
const float TIP = 56.0;

void fragment() {
	vec2 u = UV * size - PAD;
	vec2 c = u - PLATE * 0.5;
	// the two cuts that make the point: lines from the straight edges' ends to the tip, at mid height
	vec2 n = normalize(vec2(PLATE.y * 0.5, TIP));
	float cut = dot(vec2(c.x - PLATE.x * 0.5, abs(c.y)), n);
	float d = max(box(c, PLATE * 0.5, 3.0), cut) * unit;
	float left = smoothstep(0.0, 110.0, u.x);
	vec3 ground = mix(vec3(0.133, 0.133, 0.125), vec3(0.094, 0.090, 0.082), u.y / PLATE.y);
	vec4 col = vec4(ground, 0.93 * left * cov(d));
	vec3 edge = mix(vec3(0.725, 0.702, 0.627), vec3(1.000, 0.478, 0.361), warn);
	col = over(col, edge, 0.9 * left * cov(d) * (1.0 - smoothstep(0.6, 2.4, -d)));
	ALBEDO = col.rgb;
	ALPHA = col.a * alpha;
}
