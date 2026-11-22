// Shared distance-field helpers of the 3D combat bar's shaders (port of the web game's bar3d/plates.ts LIB). Lengths in
// reference px; PAD is the room around a region inside its quad (BarLayout.PAD).

const float PAD = 14.0;

float box(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
float cov(float d) { return 1.0 - smoothstep(-0.6, 0.6, d); }
vec4 over(vec4 d, vec3 c, float a) {
	float o = a + d.a * (1.0 - a);
	return vec4(o > 0.0 ? (c * a + d.rgb * d.a * (1.0 - a)) / o : c, o);
}
// distance to a box given as x, y, w, h; lean > 0 slants it into the reference's parallelogram
float rect(vec2 u, vec4 b, float r, float lean) {
	vec2 c = u - b.xy - b.zw * 0.5;
	c.x -= c.y * lean;
	return box(c, b.zw * 0.5, r);
}
float along(vec2 u, vec4 b, float lean) { return (u.x - (u.y - b.y - b.w * 0.5) * lean - b.x) / b.z; }
