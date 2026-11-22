class_name TreeParts
## The parts every painted tree is built from (port of tree-parts.ts): the palettes, the trunk with its flare and roots,
## the branches, the crown's light and the closing of the piece at height 1. The species are put together in trees.gd.

const LEAF_UV := 2.2 # tiny paint patches on the crown: they read as leaf tufts

static var _pal := {}


## the palettes, in linear light (built once; plain colours, nothing to free)
static func pal(name: String) -> Array:
	if _pal.is_empty():
		_pal = {
			"bark": Painted.tones(["#2e2016", "#523b27", "#77593c", "#9c8059"]),
			"ash": Painted.tones(["#2a2622", "#4d4740", "#746c62", "#9a9287"]), # dry wood
			"green": Painted.tones(["#0f2616", "#1c4020", "#2c5c24", "#44792b", "#6f9c3a"]),
			"olive": Painted.tones(["#18250f", "#2e3d1b", "#4a5a22", "#6f7a2e", "#9a9a48"]),
			"teal": Painted.tones(["#0c211c", "#163a2a", "#245438", "#3c7446", "#679a5c"]),
			"fir": Painted.tones(["#091a14", "#122e20", "#1c432d", "#2f603c", "#568756"]),
			"moss": [Color("#3d4f24").srgb_to_linear()],
		}
	return _pal[name]


## An upright trunk with a wide flare at the ground and a buttress per root; each root runs along the ground and dives
## into the soil. Returns the trunk's centre at each height (branches and crown start from it).
## o: r, th, roots, lean, bark (palette name), taper, lite, reach
static func trunk(parts: Array, rnd: Callable, o: Dictionary) -> Callable:
	var dir: float = rnd.call() * TAU
	var bend: float = (rnd.call() - 0.5) * 0.05
	var seed: float = rnd.call() * 50
	var moss: float = rnd.call() * 6 if rnd.call() < 0.6 else -1.0
	var th: float = o.th
	var lean_k: float = o.lean
	var center := func(y: float) -> Vector3:
		var t := maxf(0.0, y) / th
		var lean := lean_k * pow(t, 1.6)
		var s := sin(t * PI) * bend
		return Vector3(cos(dir) * lean + s, y, sin(dir) * lean - s)
	var roots := []
	for k in o.roots:
		roots.append(float(k) / o.roots * TAU + rnd.call() * 0.9)
	var r: float = o.r
	var lite: bool = o.get("lite", false)
	var flare := maxf(0.035, r * 0.7) # where the flare fades out
	var ys := [-0.12, 0.0, flare * 1.4, th * 0.55, th] if lite \
		else [-0.12, 0.0, flare * 0.5, flare * 1.2, flare * 2.2, th * 0.45, th * 0.75, th]
	var taper: float = o.get("taper", 0.26)
	var bark_pal := pal(o.bark)
	var moss_col: Color = pal("moss")[0]
	var bark := func(p: Vector3, _i: int, a: float) -> Color:
		# tone bands along the trunk (the brushstroke), lighter going up, dark at the foot; moss on one side near the ground
		var c := Painted.ramp(bark_pal, 0.3 + 0.2 * sin(a * 3 + seed) + 0.12 * sin(a * 7 + seed * 1.7 + p.y * 14)
			+ 0.28 * minf(1.0, p.y / 0.35) - (0.12 if p.y < 0.02 else 0.0))
		if moss < 0:
			return c
		return c.lerp(moss_col, 0.75 * clampf(1.0 - p.y / (flare * 3), 0.0, 1.0) * maxf(0.0, sin(a + moss)))
	var rings := []
	for y in ys:
		var radius: float = r * (1.0 - taper * (maxf(0.0, y) / th)) * (1.0 + 0.5 * exp(-maxf(0.0, y) / flare)) * (1.12 if y < 0 else 1.0)
		rings.append({"p": center.call(y), "r": radius})
	var shape := func(a: float, i: int) -> float:
		var most := 0.0
		for rt in roots:
			most = maxf(most, pow(maxf(0.0, cos(a - rt)), 4))
		return 1.0 + (0.0 if lite else 0.45) * exp(-maxf(0.0, ys[i]) / flare) * most
	parts.append(Painted.tube(rings, 6 if lite else 12, bark, {"flat": true, "v": 0.9, "shape": shape}))
	if not lite:
		for a in roots:
			if rnd.call() < 0.2:
				continue # not every buttress becomes a visible root
			var reach := minf(o.get("reach", 0.17), r * (2.6 + rnd.call() * 1.4))
			var side: float = (rnd.call() - 0.5) * r * 1.6
			var at := func(d: float, s: float, y: float) -> Vector3:
				return Vector3(cos(a) * d - sin(a) * s, y, sin(a) * d + cos(a) * s)
			var rr := [
				{"p": at.call(r * 0.9, 0.0, flare * 1.1), "r": r * 0.62},
				{"p": at.call(r * 1.9, side * 0.2, flare * 0.6), "r": r * 0.5},
				{"p": at.call(reach * 0.72, side * 0.7, 0.014), "r": r * 0.34},
				{"p": at.call(reach, side * 1.3, -0.04), "r": r * 0.18},
				{"p": at.call(reach * 1.15, side * 1.5, -0.13), "r": 0.004},
			]
			var root_a: float = a
			parts.append(Painted.tube(rr, 5, func(p: Vector3, i: int, _a: float) -> Color: return bark.call(p, i, root_a + i * 0.4) * (1.0 - i * 0.09), {"v": 2.0}))
	return center


## a curved branch from `from` to `to`, tapering
static func limb(parts: Array, from: Vector3, to: Vector3, r0: float, r1: float, bark: String, rnd: Callable) -> void:
	var mid := from.lerp(to, 0.5) + Vector3((rnd.call() - 0.5) * 0.05, 0.035, (rnd.call() - 0.5) * 0.05)
	var s: float = rnd.call() * 9
	var rings := []
	for t in [0.0, 0.4, 0.75, 1.0]:
		# the quadratic Bézier through mid, as Three's QuadraticBezierCurve3
		var p: Vector3 = from * (1 - t) * (1 - t) + mid * 2 * (1 - t) * t + to * t * t
		rings.append({"p": p, "r": r0 + (r1 - r0) * t})
	var p_bark := pal(bark)
	parts.append(Painted.tube(rings, 5, func(_p: Vector3, i: int, a: float) -> Color: return Painted.ramp(p_bark, 0.42 + 0.2 * sin(a * 2 + s) + i * 0.05), {"v": 2.0}))


## the painted crown light: each tuft light on top and dark below, the whole crown brighter toward its top
static func leaf_tint(p_pal: Array, c: Vector3, ry: float, lo: float, hi: float, jit: float) -> Callable:
	return func(p: Vector3, d: Vector3) -> Color:
		return Painted.ramp(p_pal, 0.12 + 0.52 * pow(clampf((p.y - c.y) / ry * 0.5 + 0.5, 0.0, 1.0), 1.6)
			+ 0.28 * clampf((p.y - lo) / (hi - lo), 0.0, 1.0) + jit + 0.05 * sin(d.x * 9 + d.z * 7 + jit * 40))


## closes the piece at height 1; the width is the crown's (flare and roots left out). `foot`: the radius of the flare and
## roots down to where they dive, which the board keeps inside the tile's flat core
static func finish(parts: Array, tall: float = 0.0) -> Dictionary:
	var top := 0.0
	for p in parts:
		for v in p.pos:
			top = maxf(top, v.y)
	var w := 0.0
	var foot := 0.0
	for p in parts:
		for i in p.pos.size():
			var v: Vector3 = p.pos[i] / top
			p.pos[i] = v
			if v.y > 0.2:
				w = maxf(w, maxf(absf(v.x), absf(v.z)))
			elif v.y > -0.06:
				foot = maxf(foot, Vector2(v.x, v.z).length())
	var extra := {"foot": foot}
	if tall:
		extra.tall = tall
	return Painted.piece(parts, w * 2, 1.0, extra)
