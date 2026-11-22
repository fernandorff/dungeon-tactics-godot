// The parchment of the 3D UI kit (port of the web game's ui3d/panel.ts PAPER): a rounded sheet by distance field with a
// four-corner gradient, darker head, foot and icon column, scored lines between rows, the lit focused row with its
// sheen, fibre grain, the painted detail (assets/ui/menu-paint.png, drawn by the web's own canvas code), a bevel and a
// soft shadow. One quad per panel, `pad` px larger on every side for the shadow. Lengths in page px, y down; `unit` is
// the page's scale, so the grain and lines are the reference's at every size. Colours are screen colours, as measured.

uniform vec2 size;
uniform float pad;
uniform float unit = 1.0;
uniform float head;
uniform float foot;
uniform float icon_w;
uniform vec3 rows = vec3(0.0, 1.0, 0.0); // top of the first row, row height, row count (reference px)
uniform vec4 focus = vec4(0.0, 1.0, 0.0, 0.0); // the lit row: centre y, height (reference px), strength, flash
uniform float alpha = 1.0;
uniform float lift; // how far the panel stands off the screen: the shadow grows and falls further
uniform float time;
uniform float seed;
uniform sampler2D paint : repeat_enable, filter_linear;
uniform vec3 paper;
uniform vec3 shade;
uniform vec3 lit;
uniform vec3 edge;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + 17.0; a *= 0.5; }
	return s;
}
float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// `uv`: 0,0 at the quad's top left
vec4 paper_color(vec2 uv) {
	vec2 p = uv * (size + 2.0 * pad) - pad;
	vec2 c = p - size * 0.5;
	float r = 4.0 * unit;
	float d = sd_box(c, size * 0.5, r);
	float cover = 1.0 - smoothstep(-0.5, 0.5, d);
	float fall = (3.0 + 10.0 * lift) * unit;
	float ds = sd_box(c - vec2(fall * 0.4, fall), size * 0.5, r);
	float shadow = (0.4 + 0.22 * lift) * (1.0 - smoothstep(-2.0 * unit, (9.0 + 22.0 * lift) * unit, ds));

	vec2 g = clamp(p / size, 0.0, 1.0);
	vec2 u = p / unit;
	vec2 sz = size / unit;
	// measured #e9e4d1 (top left) to #e1decb (bottom right); the grain and stains take the token down to it
	vec3 col = paper * mix(mix(1.0, 0.987, g.x), mix(0.982, 0.97, g.x), g.y);
	float column = (1.0 - smoothstep(icon_w - 1.0, icon_w + 4.0, u.x)) * step(0.5, icon_w);
	col = mix(col, shade, column);
	if (rows.z > 0.5 && u.y > rows.x + 2.0) {
		float k = (u.y - rows.x) / rows.y;
		float at = (k - floor(k + 0.5)) * rows.y;
		float inside = step(0.5, floor(k + 0.5)) * step(floor(k + 0.5), rows.z - 0.5);
		col *= 1.0 - 0.045 * inside * (1.0 - smoothstep(0.0, 1.0, abs(at + 0.5)));
		col *= 1.0 + 0.02 * inside * (1.0 - smoothstep(0.0, 1.0, abs(at - 0.8)));
	}
	float half_h = focus.y * 0.5;
	float dy = u.y - focus.x;
	float band = (1.0 - smoothstep(half_h - 1.5, half_h, abs(dy))) * smoothstep(icon_w - 1.0, icon_w + 4.0, u.x);
	float lit_k = focus.z * band * (1.0 - 0.85 * smoothstep(sz.x - 90.0, sz.x - 4.0, u.x));
	col = mix(col, lit, lit_k);
	col += 0.03 * focus.z * band * (1.0 - smoothstep(0.0, 2.5, dy + half_h));
	// max(): far above the band the bare exp() overflowed and painted a tall panel's top rows black (web, same fix)
	col *= 1.0 - 0.1 * focus.z * step(icon_w, u.x) * step(half_h, dy) * exp(-max(dy - half_h, 0.0) / 2.5);
	float sweep = mod(time * 0.42, 1.9) * sz.x - 0.25 * sz.x;
	col += 0.07 * lit_k * exp(-pow((u.x + dy * 0.6 - sweep) / 26.0, 2.0));
	col = mix(col, vec3(1.0, 0.99, 0.94), focus.w * band * (0.9 - 0.5 * abs(dy) / max(half_h, 1.0)));
	if (head > 0.5 && u.y < head) {
		col = shade * mix(0.98, 1.005, u.y / head);
		col = mix(col, shade * 1.08, 1.0 - smoothstep(0.0, 1.2, abs(u.y - head + 3.2)));
		col = mix(col, shade * 0.943, 1.0 - smoothstep(0.0, 1.2, abs(u.y - head + 1.2)));
	}
	if (foot > 0.5 && u.y > sz.y - foot) {
		col = shade * 0.995;
		col *= 1.0 - 0.07 * (1.0 - smoothstep(0.0, 1.4, u.y - sz.y + foot));
	}
	float fibre = fbm(u * vec2(0.22, 1.3) + seed);
	float relief = fibre - fbm((u - 1.2) * vec2(0.22, 1.3) + seed);
	col *= 1.0 + (fibre - 0.42) * 0.022 + (fbm(u * 0.013 + seed * 3.1) - 0.4) * 0.026;
	col += relief * 0.07;
	// painted detail: a flourish mirrored into the four corners (red), stains (green) and specks (blue)
	vec2 corner = min(u, sz - u) / 44.0;
	float ink = corner.x < 1.0 && corner.y < 1.0 ? texture(paint, corner * 0.5).r : 0.0;
	vec3 marks = texture(paint, u / 230.0 + seed).rgb;
	col = mix(col, col * vec3(0.74, 0.7, 0.6), ink * 0.5);
	col *= 1.0 - vec3(0.022, 0.027, 0.04) * marks.g - 0.05 * marks.b;
	vec2 q = abs(c) - size * 0.5;
	vec2 n = q.x > q.y ? vec2(sign(c.x), 0.0) : vec2(0.0, sign(c.y));
	float light = dot(n, vec2(-0.5, -0.86));
	float rim = 1.0 - smoothstep(1.2, 3.4, -d / unit);
	col += rim * max(light, 0.0) * 0.07;
	col *= 1.0 - rim * max(-light, 0.0) * 0.2;
	col = mix(col, edge, (1.0 - smoothstep(0.3, 1.5, -d / unit)) * 0.8);
	return vec4(mix(edge * 0.33, col, cover), mix(shadow, 1.0, cover) * alpha);
}

