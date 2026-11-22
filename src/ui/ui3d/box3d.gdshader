shader_type spatial;
// A rounded box by distance field (port of the web game's hints3d/hints3d.ts BOX_FRAG): fill, an outline `line` px wide,
// and with `fade` an alpha that runs out to the left (the line under Height); with `has_image` a picture instead (a key
// cap, ui3d/caps.ts' image quad). Lengths in page px; screen colours.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec2 size;
uniform float radius;
uniform vec4 color;
uniform vec4 edge;
uniform float line = 1.0;
uniform float fade;
uniform float alpha = 0.0;
uniform sampler2D image : filter_linear, repeat_disable;
uniform float has_image = 0.0;

void fragment() {
	vec2 q = abs((UV - 0.5) * size) - size * 0.5 + radius;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	vec4 col = mix(color, edge, edge.a * smoothstep(-line - 0.5, -line + 0.5, d));
	float run = mix(1.0, smoothstep(0.0, 0.8, UV.x), fade);
	vec4 im = texture(image, UV);
	ALBEDO = mix(col.rgb, im.rgb, has_image);
	ALPHA = mix(col.a * (1.0 - smoothstep(-0.5, 0.5, d)) * run, im.a, has_image) * alpha;
}
