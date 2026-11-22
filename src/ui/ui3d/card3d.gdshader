shader_type spatial;
// A card of the 3D turn list (port of the web game's turn3d/card.ts FRAG): one quad draws the whole row, back to front:
// target band and gold plate, the four pools' bars beside the card, shadow, halo, frame, picture, a foe's diamond,
// charge badge and number. Shapes are rounded-rectangle distances; the small painted texture (`paint`) wears the frame,
// the plate and the picture's ground. Colours are the reference's, as screen colours. Lengths in page px.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled;
#include "res://src/ui/ui3d/bar3d.gdshaderinc"

uniform vec2 size;
uniform vec2 origin;
uniform vec2 card;
uniform vec2 clip_y = vec2(-1e5, 1e5);
uniform vec2 hp = vec2(1.0);
uniform float s = 1.0;
uniform float time;
uniform float alpha = 0.0;
uniform float team;
uniform float now;
uniform float hover;
uniform float target;
uniform float pending;
uniform float gold;
uniform float num;
uniform float shift;
uniform float lift;
uniform float has_face;
uniform float seed;
uniform float bar_h = 4.0;
uniform vec4 stat; // the bars beside the card: left, width, each row's top (px; negative for none)
uniform vec3 pools = vec3(-1.0, -1.0, 0.0); // mana, stamina and CT, 0 to 1; under 0 for a pool the unit lacks
uniform sampler2D face : filter_linear, repeat_disable;
uniform sampler2D digits : filter_linear, repeat_disable;
uniform sampler2D paint : filter_linear, repeat_enable;
uniform sampler2D icon : filter_linear, repeat_disable; // the abilities' atlas (Icons)
uniform vec2 icon_grid = vec2(1.0);
uniform vec2 icon_cell;
uniform vec4 face_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint = vec4(0.0);
uniform float icon_on; // 0 none, 1 a medal, 2 a medal with the ability's art

const float CARD_W = 44.0; // the row's width in design px; the card's parts scale by its real width

varying float top_y;

void vertex() {
	// page px from the top: the layer's world is (x, -y)
	top_y = -(MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

// one bar of a card's lines, w px wide from x, its top at top: a dark groove, what is left (up to sure) in its tone,
// the part an aimed strike changes (to up_to) blinking, and the empty rest
vec4 meter(vec4 col, vec2 sp, float x, float w, float top, float sure, float up_to, vec3 tone) {
	vec2 bc = sp - vec2(x + w * 0.5, top + bar_h * 0.5);
	float d = box(bc, vec2(w, bar_h) * 0.5, bar_h * 0.5);
	col = over(col, vec3(0.020, 0.031, 0.059), 0.9 * cov(d - 1.0));
	float fx = bc.x / w + 0.5;
	float shade = 1.12 - 0.3 * (bc.y / bar_h + 0.5);
	vec3 c = vec3(0.165, 0.141, 0.125);
	if (fx <= sure) c = tone * shade;
	else if (fx <= up_to) c = mix(tone, vec3(1.0), 0.45 + 0.35 * sin(time * 9.0));
	return over(col, c, cov(d));
}
vec3 digit(vec2 uv, float n) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec3(0.0);
	return texture(digits, vec2((n + uv.x) / 10.0, uv.y)).rgb;
}

void fragment() {
	vec2 p = UV * size - origin; // px from the row's top left corner
	float k = card.x / CARD_W; // the card's own scale
	float body_h = card.y - 6.0 * k;
	float mid = card.y * 0.5;
	vec2 c0 = vec2(shift, 3.0 * k - lift); // a target's card steps right, a hovered one rises
	vec3 pnt = texture(paint, p / (64.0 * s) + seed).rgb;
	vec4 col = vec4(0.0);

	if (target > 0.01) {
		// the band that runs from the plate over the map, with a lit line on each edge
		float in_y = cov(abs(p.y - mid) - mid - s);
		float run = step(-5.0 * s, p.x) * smoothstep(170.0 * s, 24.0 * s, p.x);
		float line = smoothstep(1.4 * s, 0.0, abs(abs(p.y - mid) - mid - 0.3 * s));
		col = over(col, vec3(0.875, 0.902, 0.627), target * in_y * run * (0.2 + 0.3 * line));
		// the gold plate behind the number
		float d = box(p - vec2(-21.0 * s, mid), vec2(16.0 * s, mid + s), 2.0 * s);
		col = over(col, vec3(1.000, 0.898, 0.431), target * 0.7 * exp(-max(d, 0.0) / (3.0 * s)));
		vec3 g = mix(vec3(0.784, 0.647, 0.306), vec3(0.671, 0.541, 0.231), smoothstep(0.0, card.y, p.y)) * (0.9 + 0.2 * pnt.r);
		g = mix(g, vec3(0.941, 0.843, 0.424), smoothstep(-2.4 * s, -0.5 * s, d));
		col = over(col, g, target * 0.94 * cov(d));
	}

	// the lines beside the card: a dark ground under them and, on a unit's first card, a bar under each number
	if (stat.y > 0.5) {
		vec2 sp = p - vec2(shift, -lift);
		float gx = card.x * 0.5, gw = stat.x + stat.y + 6.0 * s - gx;
		float d_g = box(sp - vec2(gx + gw * 0.5, mid), vec2(gw * 0.5, mid), 4.0 * s);
		col = over(col, vec3(0.051, 0.078, 0.153), 0.8 * cov(d_g));
		if (stat.z >= 0.0) {
			float gap = 4.0 * s, hw = (stat.y - gap) * 0.5;
			float mp_on = step(0.0, pools.x), st_on = step(0.0, pools.y);
			vec3 mana = mix(vec3(0.702, 0.302, 0.294), vec3(0.788, 0.604, 0.384), 0.5);
			col = meter(col, sp, stat.x, mix(stat.y, hw, mp_on), stat.z, hp.x, hp.y, vec3(0.612, 0.788, 0.227));
			if (mp_on > 0.5) col = meter(col, sp, stat.x + hw + gap, hw, stat.z, pools.x, pools.x, mana);
			if (stat.w >= 0.0) {
				if (st_on > 0.5) col = meter(col, sp, stat.x, hw, stat.w, pools.y, pools.y, vec3(0.761, 0.471, 0.353));
				float cx = stat.x + st_on * (hw + gap);
				col = meter(col, sp, cx, mix(stat.y, hw, st_on), stat.w, pools.z, pools.z, vec3(0.722, 0.576, 0.094));
			}
		}
	}

	vec2 hb = vec2(card.x, body_h) * 0.5;
	vec2 ap = p - c0 - hb; // from the middle of the card
	vec2 bp = ap; // from the middle of the framed body
	float raised = hover + 0.5 * now;
	float d_s = box(ap - vec2(1.5, 2.5) * s * (1.0 + raised), hb, 3.0 * k);
	col = over(col, vec3(0.020, 0.047, 0.094), 0.5 * (1.0 - smoothstep(-2.0 * s, (4.0 + 4.0 * raised) * s, d_s)));

	// the one acting now breathes in gold; the row where an aimed charge would fire blinks faster
	float d_a = box(ap, hb, 3.0 * k);
	float halo = max(now * (0.72 + 0.28 * sin(time * 3.4)), pending * (0.6 + 0.4 * sin(time * 7.0)));
	col = over(col, vec3(1.000, 0.843, 0.369), halo * 0.85 * exp(-max(d_a, 0.0) / (5.0 * s)));
	col = over(col, vec3(1.000, 0.949, 0.690), halo * cov(d_a - 1.6 * k));

	float d_b = box(bp, hb, 3.0 * k);
	col = over(col, mix(vec3(0.176, 0.333, 0.431), vec3(0.212, 0.298, 0.388), team), 0.85 * cov(d_b - k));
	// frame: worn stone, lit from the top left
	vec3 frame = mix(vec3(0.714, 0.667, 0.573), vec3(0.482, 0.443, 0.376), clamp(bp.y / body_h + 0.5, 0.0, 1.0));
	frame = frame * (0.84 + 0.32 * pnt.r) - 0.1 * pnt.g;
	float rim = smoothstep(-1.4 * k, 0.0, d_b);
	frame += rim * (bp.x + bp.y < 0.0 ? 0.16 : -0.14);
	col = over(col, frame, cov(d_b));

	// the picture, sunk into the frame: thicker on the left and on top, as in the reference
	vec2 ih = hb - vec2(1.9, 1.5) * k;
	vec2 ic = bp - vec2(0.7, 0.3) * k;
	float d_i = box(ic, ih, 1.6 * k);
	vec2 uv = clamp(ic / (2.0 * ih) + 0.5, 0.0, 1.0);
	vec3 hero = mix(mix(vec3(0.667, 0.714, 0.714), vec3(0.651, 0.725, 0.776), uv.x), mix(vec3(0.561, 0.647, 0.643), vec3(0.592, 0.686, 0.706), uv.x), uv.y);
	vec3 foe = mix(mix(vec3(0.804, 0.690, 0.643), vec3(0.784, 0.639, 0.604), uv.x), mix(vec3(0.741, 0.506, 0.463), vec3(0.769, 0.584, 0.553), uv.x), uv.y);
	vec3 pic = mix(hero, foe, team) * (0.92 + 0.16 * pnt.b);
	if (has_face > 0.5) {
		vec4 f = texture(face, face_uv.xy + uv * face_uv.zw);
		f.rgb = mix(f.rgb, dot(f.rgb, vec3(0.299, 0.587, 0.114)) * tint.rgb * 1.7, tint.a);
		pic = mix(pic, f.rgb, f.a);
	}
	pic *= 1.0 - 0.3 * smoothstep(-5.0 * k, 0.5 * k, d_i);
	pic += 0.1 * smoothstep(-1.2 * k, 0.0, d_i) * step(0.0, ic.x + ic.y);
	// a light sweeps the acting card
	float sweep = fract(time * 0.28) * 3.0 - 1.0;
	pic += now * 0.16 * exp(-pow((uv.x + uv.y) * 0.5 - sweep, 2.0) / 0.012);
	pic += 0.07 * hover;
	col = over(col, pic, cov(d_i));

	// a foe's card also wears a mark, not only its colour (Nov 18 accessibility review): a pink diamond on a dark rim
	vec2 dq = p - c0 - vec2(3.5 * k, 3.5 * k);
	float dd = (abs(dq.x) + abs(dq.y)) * 0.7071 - 4.6 * k;
	col = over(col, vec3(0.020, 0.047, 0.094), team * cov(dd - 1.4 * k));
	col = over(col, vec3(0.941, 0.376, 0.557), team * cov(dd));

	// a charge going off: the ability's icon on a dark medal over the caster's face
	if (icon_on > 0.5) {
		vec2 q = p - c0 - vec2(card.x - 6.0 * k, body_h - 7.0 * k);
		float dc = length(q) - 9.5 * k;
		col = over(col, vec3(0.914, 0.784, 0.412), cov(dc - 1.3 * k));
		col = over(col, mix(vec3(0.133, 0.212, 0.361), vec3(0.059, 0.102, 0.188), q.y / (19.0 * k) + 0.5), cov(dc));
		vec2 iu = q / (15.0 * k) + 0.5;
		if (icon_on > 1.5 && iu.x > 0.0 && iu.x < 1.0 && iu.y > 0.0 && iu.y < 1.0) {
			vec4 art = texture(icon, (icon_cell + iu) / icon_grid);
			col = over(col, art.rgb, art.a);
		}
	}

	// the number: white core, its side's glow (gold for a charge's ticks); two digits shrink to fit
	vec2 np = (p - vec2(-16.0 * s, 13.5 * k)) / vec2(23.2 * s, 30.0 * s);
	float tens = floor(num / 10.0);
	float ones = num - tens * 10.0;
	vec3 dg = tens < 0.5
		? digit(np + 0.5, ones)
		: max(digit(np / 0.82 + vec2(0.76, 0.5), tens), digit(np / 0.82 + vec2(0.24, 0.5), ones));
	vec3 tone = mix(mix(vec3(0.227, 0.706, 0.949), vec3(0.941, 0.376, 0.557), team), vec3(1.000, 0.812, 0.290), gold);
	col = over(col, tone, 0.95 * dg.r);
	col = over(col, tone * 0.3, 0.55 * dg.b);
	col = over(col, mix(vec3(1.0), tone, 0.2), dg.g);

	// rows scrolled past the column's ends fade out
	float fade = smoothstep(clip_y.x, clip_y.x + 16.0 * s, top_y) * (1.0 - smoothstep(clip_y.y - 16.0 * s, clip_y.y, top_y));
	ALBEDO = col.rgb;
	ALPHA = col.a * alpha * fade;
}
