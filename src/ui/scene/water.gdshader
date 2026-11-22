// The water's surface (port of water-shaders.ts): colour in three depth bands, foam along the banks and around the
// legs of whoever wades, moving glints (threads along the current in the river) and a light sway. The web's physics
// ripples are left out: the sway alone moves the surface. UV: the place in the tile; COLOR: banks N, E, S, W;
// CUSTOM0: corners NE, SE, SW, NW; UV2: (depth, current along x).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_schlick_ggx;

const float SWELL = 0.008; // m of constant sway
const int BODIES = 8;
uniform vec3 shallow : source_color = vec3(0.227, 0.651, 0.769);
uniform vec3 mid : source_color = vec3(0.122, 0.435, 0.639);
uniform vec3 deep : source_color = vec3(0.090, 0.239, 0.447);
uniform vec3 foam_col : source_color = vec3(0.918, 0.973, 1.0);
uniform vec2 origin; // the web centres the map: the sway and the glints land on the same spots
uniform vec4 bodies[8]; // x, z, on, phase of each unit in the water

varying vec2 wxz;
varying vec2 local;
varying vec4 edge;
varying vec4 corner;
varying float depth;
varying vec2 flow;

float swell_h(vec2 p) {
	return SWELL * (sin(p.x * 2.1 + TIME * 1.3) + sin(p.y * 1.7 - TIME * 1.1) + 0.5 * sin((p.x - p.y) * 3.3 + TIME * 2.0));
}

vec2 swell_d(vec2 p) {
	float c = 0.5 * 3.3 * cos((p.x - p.y) * 3.3 + TIME * 2.0);
	return SWELL * vec2(2.1 * cos(p.x * 2.1 + TIME * 1.3) + c, 1.7 * cos(p.y * 1.7 - TIME * 1.1) - c);
}

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz + origin;
	flow = vec2(UV2.y, 0.0);
	// the sway moves with the current; still outside the river
	VERTEX.y += swell_h(wxz - flow * TIME);
	local = UV;
	edge = COLOR;
	corner = CUSTOM0;
	depth = UV2.x;
}

void fragment() {
	vec2 pf = wxz - flow * TIME; // the drawing flows with the water
	vec2 slope = swell_d(pf);
	float collar = 0.0;
	for (int i = 0; i < BODIES; i++) {
		vec4 b = bodies[i];
		if (b.z <= 0.0) continue;
		float d = length(wxz - b.xy);
		collar = max(collar, step(abs(d - 0.25 - 0.025 * sin(TIME * 5.0 + b.w)), 0.04));
	}
	// bank foam: distance to the side or corner with land, waving slowly
	float e = 1.0;
	e = min(e, mix(1.0, local.y, edge.x));
	e = min(e, mix(1.0, 1.0 - local.x, edge.y));
	e = min(e, mix(1.0, 1.0 - local.y, edge.z));
	e = min(e, mix(1.0, local.x, edge.w));
	e = min(e, mix(1.0, length(vec2(1.0 - local.x, local.y)), corner.x));
	e = min(e, mix(1.0, length(vec2(1.0 - local.x, 1.0 - local.y)), corner.y));
	e = min(e, mix(1.0, length(vec2(local.x, 1.0 - local.y)), corner.z));
	e = min(e, mix(1.0, length(local), corner.w));
	e += 0.035 * sin(TIME * 1.6 + (wxz.x + wxz.y) * 7.0);
	// steps instead of a gradient: the painted style
	float foam = max(step(e, 0.08), 0.35 * step(e, 0.15));
	float dq = depth + 0.05 * sin(pf.x * 5.0 + pf.y * 3.0);
	float mid_b = step(0.42, dq);
	float deep_b = step(0.78, dq);
	vec3 water = mix(mix(shallow, mid, mid_b), deep, deep_b);
	float alpha = mix(mix(0.42, 0.72, mid_b), 0.93, deep_b);
	// moving shine: little light dots; in the river, threads stretched along the water
	vec2 q = pf * 4.0;
	float c = sin(q.x + TIME * 0.8) + sin(q.y * 1.3 - TIME * 0.6) + sin((q.x + q.y) * 0.7 + TIME * 1.1);
	float glint = step(2.45, c) * (1.0 - 0.6 * deep_b);
	float fl = length(flow);
	if (fl > 0.0) {
		vec2 fd = flow / fl;
		vec2 side = vec2(-fd.y, fd.x);
		float lane = fract(dot(pf, fd) * 0.9 + 0.35 * sin(dot(wxz, side) * 6.0));
		glint = max(glint, step(0.93, lane) * step(0.2, fract(dot(wxz, side) * 3.0 + 0.5 * sin(dot(pf, fd) * 2.0))));
	}
	water = mix(water, foam_col, 0.4 * glint);
	float white = max(foam, collar);
	ALBEDO = mix(water, foam_col, white);
	ALPHA = max(alpha + 0.15 * glint, 0.92 * white);
	// the sun's light and shine follow the sway's slope (x2.5: a few cm barely change the light from above)
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-2.5 * slope.x, 1.0, -2.5 * slope.y)), 0.0)).xyz);
	ROUGHNESS = 0.3;
	SPECULAR = 0.12; // weak and narrow: a white shine made the whole river white facing the sun
}
