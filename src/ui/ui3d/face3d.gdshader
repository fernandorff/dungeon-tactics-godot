shader_type spatial;
// A unit's face as a quad of the 3D kit (port of the web game's ui3d/face.ts): one frame of its painted sheet (`uv`:
// offset and size in the sheet), greyed for a fallen hero. Screen colours.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform sampler2D map : filter_linear, repeat_disable;
uniform vec4 uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float grey;
uniform float alpha = 1.0;

void fragment() {
	vec4 c = texture(map, uv.xy + UV * uv.zw);
	ALBEDO = mix(c.rgb, vec3(dot(c.rgb, vec3(0.3, 0.59, 0.11))) * 0.8, grey);
	ALPHA = c.a * alpha;
}
