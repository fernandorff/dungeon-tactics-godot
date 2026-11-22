shader_type spatial;
// A flat inset band on the paper (port of the web game's ui3d/panel.ts BAND: the sheet's name and title strips, Move's
// gauge): shaded at its top edge, lit at the bottom, as if pressed into the sheet. Lengths in page px.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://src/ui/ui3d/paper.gdshaderinc"

uniform vec3 color;

void fragment() {
	vec2 p = UV * size;
	float d = sd_box(p - size * 0.5, size * 0.5, 3.0 * unit);
	vec2 u = p / unit;
	vec3 col = color * (1.0 + (fbm(u * vec2(0.22, 1.3)) - 0.5) * 0.05);
	col *= 1.0 - 0.1 * exp(-u.y / 2.2);
	col *= 1.0 + 0.06 * exp(-(size.y / unit - u.y) / 1.6);
	ALBEDO = col;
	ALPHA = (1.0 - smoothstep(-0.5, 0.5, d)) * alpha;
}
