shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 points[64];
uniform int count = 0;

void fragment() {
	for (int i = 0; i < count; i++) {
		vec4 point = points[i];
		float d = distance(VERTEX.xy, point.xy);
		if (VERTEX.z > point.z + 0.3 && d < point.w &&
			(d < 0.7 * point.w || mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0)) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb * texture(paint, UV).rgb * 1.35;
	ROUGHNESS = 0.95;
}
