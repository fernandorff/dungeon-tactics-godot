shader_type canvas_item;
// The parchment on a 2D window (paper_window.gd); the body is the 3D kit's (ui3d/paper.gdshaderinc, web ui3d/panel.ts).
#include "res://src/ui/ui3d/paper.gdshaderinc"

void fragment() {
	COLOR = paper_color(UV);
}
