shader_type spatial;
// A panel of the 3D UI layer (ui3d/paper.gdshaderinc, web ui3d/panel.ts paperMaterial): drawn over everything in the
// order its render priority gives, as the web's depthTest false and renderOrder.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://src/ui/ui3d/paper.gdshaderinc"

void fragment() {
	vec4 c = paper_color(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
