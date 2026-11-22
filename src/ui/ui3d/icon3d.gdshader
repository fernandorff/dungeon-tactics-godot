shader_type spatial;
// The low-poly icons of the 3D UI kit (port of the web game's ui3d/icons.ts): flat faces (the normal from the screen
// derivatives) lit from the upper left in four tone steps, warm in the light and cool in the shade like a pixel-art
// ramp. `gray`: a greyed row; `flash`: the white of a confirmed row; `hull` grows the mesh along its normals and, drawn
// on its back faces in ink, outlines the silhouette (icon3d_hull.gdshader). COLOR holds the parts' sRGB bytes.
render_mode unshaded, cull_back, fog_disabled, blend_mix, depth_draw_always;

uniform float gray = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	// Godot's render target runs y the other way from the WebGL canvas: the derivatives' face normal comes out flipped
	if (dot(n, NORMAL) < 0.0) n = -n;
	float d = dot(n, normalize(vec3(-0.45, 0.65, 0.62)));
	float tone = d > 0.55 ? 1.12 : d > 0.1 ? 0.93 : d > -0.3 ? 0.72 : 0.54;
	vec3 c = COLOR.rgb * tone * mix(vec3(0.88, 0.91, 1.04), vec3(1.03, 1.0, 0.95), smoothstep(-0.3, 0.6, d));
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(g) * vec3(0.78, 0.76, 0.7) + 0.2, gray);
	ALBEDO = clamp(c + flash, 0.0, 1.0);
	ALPHA = 1.0; // in the transparent pass, after every panel (Layer3d.DEEP), still depth-tested among the models
}
