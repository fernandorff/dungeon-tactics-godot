// The painted ground (port of terrain.ts FRAG_MIX): the ground by the tile paint (COLOR: grass, leaves, dirt, snow),
// stone on slopes by steepness and where the tile is stone (UV.y), in triplanar projection so it does not stretch on
// cliffs; UV.x darkens the ring past the map's edge. Lambert light, as the web's MeshLambertMaterial.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D t_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_leaves : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_snow : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_cliff : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 origin; // the web centres the map on its origin: the textures land on the same spots

varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wpos.xz += origin;
	wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec4 w = COLOR;
	// 0.35 = one 512 px texture every ~3 tiles
	vec2 tuv = wpos.xz * 0.35;
	vec3 tg = texture(t_grass, tuv).rgb;
	vec3 tl = texture(t_leaves, tuv * 1.3).rgb;
	vec3 td = texture(t_dirt, tuv).rgb;
	vec3 ts = texture(t_snow, tuv).rgb;
	vec3 base = (tg * w.x + tl * w.y + td * w.z + ts * w.w) / max(w.x + w.y + w.z + w.w, 1e-3);
	vec3 tn = normalize(wn);
	vec3 an = abs(tn);
	vec3 cl = (texture(t_cliff, wpos.zy * 0.45).rgb * an.x + texture(t_cliff, wpos.xy * 0.45).rgb * an.z
		+ texture(t_cliff, wpos.xz * 0.45).rgb * an.y) / (an.x + an.y + an.z);
	float rocky = max(1.0 - smoothstep(0.5, 0.82, tn.y), UV.y);
	// sun patches on the ground, as in FFT: wide noise taken from the grass itself, only on the plain
	float dap = smoothstep(0.55, 0.62, dot(texture(t_grass, wpos.xz * 0.045 + 0.3).rgb, vec3(0.333)) * 1.6);
	base = mix(base, base * vec3(1.45, 1.32, 0.72), dap * 0.55 * (1.0 - rocky) * w.x);
	ALBEDO = UV.x * mix(base, cl, rocky);
}
