shader_type spatial;
// The ink outline of a 3D UI icon (web ui3d/icons.ts iconMaterial with a hull): the mesh grown `hull` model units
// along its normals, back faces only, in the dark ink.
render_mode unshaded, cull_front, fog_disabled, blend_mix, depth_draw_always;

uniform float hull = 0.0;

void vertex() {
	VERTEX += NORMAL * hull;
}

void fragment() {
	ALBEDO = vec3(0.2, 0.17, 0.12);
	ALPHA = 1.0;
}
