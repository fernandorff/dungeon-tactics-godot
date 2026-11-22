shader_type spatial;
// A unit sheet of the 3D combat bar (port of the web game's bar3d/plates.ts SHEET): back to front the band in the side's
// colour, the dark strip, the bars and the framed portrait. Everything in reference px from the region's top left (`u`);
// `unit` turns a distance into page px for the edges. Colours are the reference capture's, as screen colours.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://src/ui/ui3d/bar3d.gdshaderinc"

uniform vec2 size;
uniform float unit = 1.0;
uniform float alpha = 0.0;
uniform float time;
uniform float team;
uniform float mirror;
uniform vec4 band_box;
uniform vec4 strip;
uniform vec4 portrait;
uniform vec4 hp_bar;
uniform vec4 pool_bar;
uniform vec4 ct_bar;
uniform vec4 box2;
uniform vec4 box_bar;
uniform vec3 hp = vec3(1.0, 1.0, 0.0); // what stays, up to where it changes, 1 for a heal
uniform float sure = 1.0; // where the part it changes for certain meets the part it may change
uniform vec3 fill = vec3(-1.0); // first pool, second pool and CT, each 0 to 1 or under 0 for none
uniform float line; // 1 when the strip has a text
uniform float tag; // 1 when the portrait carries the side's tag
uniform sampler2D face : filter_linear, repeat_disable;
uniform vec4 face_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint = vec4(0.0);
uniform float has_face;

// a thin round bar: dark groove, fill up to f
vec4 groove(vec4 col, vec2 u, vec4 b, float f, vec3 tone) {
	float d = rect(u, b, b.w * 0.5, 0.0) * unit;
	col = over(col, vec3(0.039, 0.055, 0.086), 0.85 * cov(d - 1.5));
	float y = (u.y - b.y) / b.w;
	return over(col, tone * (1.15 - 0.4 * y), cov(d) * step(along(u, b, 0.0), f));
}

void fragment() {
	vec2 u = UV * size - PAD;
	vec4 col = vec4(0.0);

	// band: the side's colour beside the portrait, thinning away from it and darker toward its foot
	float t = (u.x - band_box.x) / band_box.z;
	t = mix(t, 1.0 - t, mirror);
	float v = (u.y - band_box.y) / band_box.w;
	vec3 side = mix(vec3(0.090, 0.161, 0.345), vec3(0.353, 0.200, 0.188), team);
	side = mix(side * 1.12, mix(vec3(0.063, 0.102, 0.200), vec3(0.196, 0.157, 0.153), team), smoothstep(0.35, 1.0, v));
	float d_band = rect(u, band_box, 6.0, 0.0) * unit;
	float thin = mix(0.95, 0.42, smoothstep(0.3, 0.72, t)) * (1.0 - smoothstep(0.9, 1.0, t));
	col = over(col, side, thin * cov(d_band));
	// bevel: a lit line inside the top edge, a shade inside the bottom
	float rim = (1.0 - smoothstep(0.0, 2.2, -d_band)) * cov(d_band) * thin;
	col.rgb += rim * (v < 0.5 ? 0.16 : -0.1);

	// the strip under the bars, where the class or a charge's line goes
	float st = (u.x - strip.x) / strip.z;
	st = mix(st, 1.0 - st, mirror);
	col = over(col, vec3(0.051, 0.078, 0.153), line * 0.78 * cov(rect(u, strip, 5.0, 0.0) * unit) * (1.0 - smoothstep(0.82, 1.0, st)));

	// life: what stays, the part an aimed strike takes (red) or a heal adds (pale), blinking, and the empty rest
	float d_h = rect(u, hp_bar, 3.0, 0.5) * unit;
	float changing = step(hp.x + 0.001, hp.y);
	col = over(col, mix(vec3(0.039, 0.055, 0.086), vec3(0.561, 0.816, 0.173), 0.75 * changing), 0.9 * cov(d_h - 2.0));
	col = over(col, vec3(0.078, 0.102, 0.071), cov(d_h));
	float fx = along(u, hp_bar, 0.5);
	float fy = (u.y - hp_bar.y) / hp_bar.w;
	vec3 green = mix(vec3(0.612, 0.788, 0.227), vec3(0.361, 0.510, 0.075), fy);
	// the part it changes for certain (the least damage or heal) is solid; only the part it may change blinks (Nov 19)
	float maybe = hp.z > 0.5 ? step(sure, fx) : step(fx, sure);
	vec3 part = mix(vec3(0.988, 0.337, 0.243), vec3(0.851, 0.949, 0.604), hp.z) * (1.0 - maybe * (0.18 - 0.18 * sin(time * 6.0)));
	if (fx <= hp.x) col = over(col, green, cov(d_h));
	else if (fx <= hp.y) col = over(col, part, cov(d_h));

	// the first pool beside it (fill.x < 0: the sheet has none)
	if (fill.x >= 0.0) {
		float d_p = rect(u, pool_bar, 3.0, 0.5) * unit;
		col = over(col, vec3(0.039, 0.055, 0.086), 0.9 * cov(d_p - 2.0));
		col = over(col, vec3(0.102, 0.078, 0.078), cov(d_p));
		float px = along(u, pool_bar, 0.5);
		vec3 pool = mix(vec3(0.702, 0.302, 0.294), vec3(0.788, 0.604, 0.384), px) * (1.12 - 0.3 * (u.y - pool_bar.y) / pool_bar.w);
		col = over(col, pool, cov(d_p) * step(px, fill.x));
	}
	// the second pool in its dark box
	if (fill.y >= 0.0) {
		float d_x = rect(u, box2, 4.0, 0.0) * unit;
		col = over(col, vec3(0.227, 0.267, 0.376), 0.6 * cov(d_x));
		col = over(col, vec3(0.051, 0.078, 0.153), 0.9 * cov(d_x + 1.2));
		col = groove(col, u, box_bar, fill.y, vec3(0.761, 0.471, 0.353));
	}
	if (fill.z >= 0.0) col = groove(col, u, ct_bar, fill.z, vec3(0.722, 0.576, 0.094));

	// portrait: shadow, dark outer line, light frame, then the picture on its side's ground
	vec2 pc = u - portrait.xy - portrait.zw * 0.5;
	vec2 ph = portrait.zw * 0.5;
	float d_s = box(pc - vec2(2.0, 4.0), ph, 10.0);
	col = over(col, vec3(0.020, 0.031, 0.059), 0.55 * (1.0 - smoothstep(-3.0, 9.0, d_s)));
	float d_f = box(pc, ph, 10.0) * unit;
	col = over(col, vec3(0.408, 0.275, 0.188), cov(d_f));
	col = over(col, mix(vec3(0.937, 0.898, 0.784), vec3(0.725, 0.663, 0.514), pc.y / portrait.w + 0.5), cov(d_f + 1.5));
	vec2 ih = ph - 4.5;
	float d_i = box(pc, ih, 7.0) * unit;
	vec2 uv = clamp(pc / (2.0 * ih) + 0.5, 0.0, 1.0);
	vec3 hero = mix(mix(vec3(0.667, 0.714, 0.714), vec3(0.651, 0.725, 0.776), uv.x), mix(vec3(0.561, 0.647, 0.643), vec3(0.592, 0.686, 0.706), uv.x), uv.y);
	vec3 foe = mix(mix(vec3(0.804, 0.690, 0.643), vec3(0.784, 0.639, 0.604), uv.x), mix(vec3(0.741, 0.506, 0.463), vec3(0.769, 0.584, 0.553), uv.x), uv.y);
	vec3 pic = mix(hero, foe, team);
	if (has_face > 0.5) {
		vec4 f = texture(face, face_uv.xy + uv * face_uv.zw);
		f.rgb = mix(f.rgb, dot(f.rgb, vec3(0.299, 0.587, 0.114)) * tint.rgb * 1.7, tint.a);
		pic = mix(pic, f.rgb, f.a);
	}
	pic *= 1.0 - 0.25 * smoothstep(-8.0, 0.5, d_i / unit);
	// a shade at the foot, under the side's tag
	pic = mix(pic, vec3(0.227, 0.071, 0.086), tag * 0.72 * smoothstep(0.72, 0.9, uv.y));
	col = over(col, pic, cov(d_i));

	ALBEDO = col.rgb;
	ALPHA = col.a * alpha;
}
