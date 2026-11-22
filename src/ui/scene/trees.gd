class_name Trees
## Painted trees built in code (port of trees.ts; Fernando, Nov 13: "matching the painted ground, many types and sizes,
## including tall pines and big trunks"): tufted broadleaf, old thick-trunked tree, skirted pine, tall bare-trunk pine,
## dead tree and bush, each a piece of height 1 (painted.gd). Each KayKit tree name the maps use becomes a set of
## variations; the board picks one by position. `lite` is the low version for the forest around the map.


## Broadleaf: trunk, branches fanning out, a big crown core and a tuft at each branch's end, a smaller one outside it
## and at the top. o: r, th, spread, pal, top, squash, limbs, roots, stubs, tall, lite, reach
static func broadleaf(seed: float, o: Dictionary) -> Dictionary:
	var rnd := Painted.rng(seed)
	var parts := []
	var lite: bool = o.get("lite", false)
	var th: float = o.th
	var spread: float = o.spread
	var p_pal := TreeParts.pal(o.pal)
	var roots_n: int = o.roots if o.has("roots") else 3 + floori(rnd.call() * 3)
	var center: Callable = TreeParts.trunk(parts, rnd, {"r": o.r, "th": th, "roots": roots_n,
		"lean": 0.03 + rnd.call() * 0.05, "bark": "bark", "lite": lite, "reach": o.get("reach", 0.17)})
	var top: Vector3 = center.call(th)
	var n: int = 3 if lite else (o.limbs if o.has("limbs") else 4 + floori(rnd.call() * 2))
	var squash: float = o.get("squash", 0.78)
	var crown: float = o.get("top", 0.5)
	# the lump's seed is drawn before the tint's jitter, in the web's argument order
	var tuft := func(c: Vector3, r: float, detail: int) -> void:
		var seed_k: float = rnd.call() * 99
		var tint := TreeParts.leaf_tint(p_pal, c, r * squash, th - 0.02, th + crown, (rnd.call() - 0.5) * 0.14)
		parts.append(Painted.lump(c, r, r * squash, r, seed_k, tint,
			{"detail": detail, "rough": 0.36 if detail > 1 else 0.28, "uv": TreeParts.LEAF_UV}))
	tuft.call(Vector3(top.x, th + crown * 0.5, top.z), spread * 0.74, 1 if lite else 2) # the core
	var a0: float = rnd.call() * TAU
	for k in n:
		var a: float = a0 + float(k) / n * TAU + (rnd.call() - 0.5) * 0.7
		var reach: float = spread * (0.55 + rnd.call() * 0.25)
		var end := Vector3(top.x + cos(a) * reach, th + crown * (0.16 + rnd.call() * 0.3), top.z + sin(a) * reach)
		var r: float = spread * (0.4 + rnd.call() * 0.14)
		tuft.call(end + Vector3(0, r * 0.2, 0), r, 1)
		if lite:
			continue
		TreeParts.limb(parts, center.call(th * 0.86), end, o.r * 0.55, o.r * 0.2, "bark", rnd)
		# a smaller tuft outside and lower: the crown does not become one ball
		var b: float = a + (rnd.call() - 0.5) * 1.2
		tuft.call(Vector3(end.x + cos(b) * r * 0.8, end.y - r * 0.25 + rnd.call() * r * 0.3, end.z + sin(b) * r * 0.8), r * (0.5 + rnd.call() * 0.2), 1)
	if not lite:
		var tip := Vector3(top.x + (rnd.call() - 0.5) * 0.08, th + crown * 0.84, top.z + (rnd.call() - 0.5) * 0.08)
		tuft.call(tip, spread * (0.44 + rnd.call() * 0.1), 1)
		tuft.call(Vector3(tip.x + (rnd.call() - 0.5) * 0.16, tip.y + spread * 0.26, tip.z + (rnd.call() - 0.5) * 0.16), spread * 0.3, 1)
		# little tufts at the crown's edge: a ragged, leafy outline
		for k in 5:
			var a: float = rnd.call() * TAU
			var d: float = spread * (0.85 + rnd.call() * 0.3)
			tuft.call(Vector3(top.x + cos(a) * d, th + crown * (0.2 + rnd.call() * 0.5), top.z + sin(a) * d), spread * (0.2 + rnd.call() * 0.08), 1)
	# broken branch stubs on the bare trunk (tall pine)
	for k in (0 if lite else o.get("stubs", 0)):
		var y: float = th * (0.35 + 0.5 * rnd.call())
		var a: float = rnd.call() * TAU
		var from: Vector3 = center.call(y)
		TreeParts.limb(parts, from, from + Vector3(cos(a) * 0.09, 0.03, sin(a) * 0.09), o.r * 0.4, o.r * 0.12, "ash", rnd)
	return TreeParts.finish(parts, o.get("tall", 0.0))


## Pine: a straight trunk and skirts of boughs with drooping ragged tips, lighter at the tip and dark under.
## o: r, R, tiers, base, pal, tall, lite
static func fir(seed: float, o: Dictionary) -> Dictionary:
	var rnd := Painted.rng(seed)
	var parts := []
	var lite: bool = o.get("lite", false)
	var tiers: int = ceili(o.tiers * 0.7) if lite else o.tiers
	var center: Callable = TreeParts.trunk(parts, rnd, {"r": o.r, "th": 0.93, "roots": 3 + floori(rnd.call() * 2),
		"lean": rnd.call() * 0.04, "bark": "bark", "taper": 0.9, "lite": lite, "reach": 0.12})
	var p_pal := TreeParts.pal(o.pal)
	var gap: float = (0.9 - o.base) / tiers
	for i in tiers:
		var t := float(i) / tiers
		var y: float = o.base + gap * i
		var hh := gap * 1.9
		var r: float = o.R * pow(1 - t, 0.85) + 0.035
		var sides := 6 if lite else (10 if t < 0.6 else 8)
		var jag := []
		for j in sides:
			jag.append((1.0 if j % 2 else 0.68) * (0.88 + 0.24 * rnd.call()))
		var turn: float = rnd.call() * 6
		var jg := func(a: float) -> float: return jag[roundi(a / TAU * sides) % sides]
		var rings := [{"p": center.call(y + hh), "r": 0.012}, {"p": center.call(y + hh * 0.5), "r": r * 0.5},
			{"p": center.call(y), "r": r}, {"p": center.call(y + hh * 0.2), "r": r * 0.3}]
		var tone := [0.3, 0.45, 0.72, 0.02]
		var tint := func(_p: Vector3, k: int, a: float) -> Color:
			return Painted.ramp(p_pal, tone[k] + 0.2 * t + (0.25 * (jg.call(a) - 0.68) if k == 2 else 0.0))
		var g := Painted.tube(rings, sides, tint, {"flat": true, "v": 3.0,
			"shape": func(a: float, k: int) -> float: return jg.call(a) if k == 2 else 1.0,
			"lift": func(a: float, k: int) -> float: return -hh * 0.5 * (jg.call(a) - 0.6) if k == 2 else 0.0})
		parts.append(g.turned(turn))
	parts.append(Painted.tube([{"p": center.call(0.86), "r": 0.04}, {"p": center.call(1.0), "r": 0.003}], 6,
		func(_p: Vector3, _i: int, _a: float) -> Color: return Painted.ramp(p_pal, 0.6), {"flat": true}))
	return TreeParts.finish(parts, o.get("tall", 0.0))


## Dead tree: only trunk and forking branches
static func dead(seed: float, lite: bool) -> Dictionary:
	var rnd := Painted.rng(seed)
	var parts := []
	var th: float = 0.42 + rnd.call() * 0.1
	var r: float = 0.05 + rnd.call() * 0.02
	var center: Callable = TreeParts.trunk(parts, rnd, {"r": r, "th": th, "roots": 3 + floori(rnd.call() * 2),
		"lean": 0.05 + rnd.call() * 0.06, "bark": "ash", "taper": 0.4, "lite": lite})
	var top: Vector3 = center.call(th)
	var n: int = 3 + floori(rnd.call() * 2)
	var a0: float = rnd.call() * 6
	for k in n + 1:
		var lead := k == n
		var a: float = a0 + float(k) / n * TAU + (rnd.call() - 0.5) * 0.6
		var reach: float = 0.04 if lead else 0.16 + rnd.call() * 0.14
		var end := Vector3(top.x + cos(a) * reach, th + (0.34 if lead else 0.14 + rnd.call() * 0.2), top.z + sin(a) * reach)
		TreeParts.limb(parts, center.call(th * (0.92 if lead else 0.7 + rnd.call() * 0.2)), end, r * 0.55, r * 0.22, "ash", rnd)
		for f in (1 if lite else 2):
			var b: float = a + (0.9 if f else -0.7) + (rnd.call() - 0.5) * 0.5
			var length: float = 0.1 + rnd.call() * 0.1
			TreeParts.limb(parts, end, end + Vector3(cos(b) * length, 0.08 + rnd.call() * 0.12, sin(b) * length), r * 0.22, 0.006, "ash", rnd)
	return TreeParts.finish(parts)


## Bush: low tufts, no trunk
static func shrub(seed: float, p: String, lite: bool) -> Dictionary:
	var rnd := Painted.rng(seed)
	var parts := []
	var p_pal := TreeParts.pal(p)
	var n: int = 3 if lite else 4 + floori(rnd.call() * 3)
	for k in n:
		var a: float = float(k) / n * TAU + rnd.call()
		var d: float = 0.14 + rnd.call() * 0.2 if k else 0.0
		var r: float = 0.26 + rnd.call() * 0.14
		var c := Vector3(cos(a) * d, r * 0.5 + (0.0 if k else 0.12), sin(a) * d)
		var seed_k: float = rnd.call() * 99
		var tint := TreeParts.leaf_tint(p_pal, c, r * 0.8, 0, 0.75, (rnd.call() - 0.5) * 0.14)
		parts.append(Painted.lump(c, r, r * 0.8, r, seed_k, tint, {"uv": TreeParts.LEAF_UV}))
	return TreeParts.finish(parts)


static func _oak(p: String, o: Dictionary, s: float, lite: bool) -> Dictionary:
	var base := {"r": 0.065, "th": 0.4, "spread": 0.36, "pal": p, "lite": lite}
	base.merge(o, true)
	return broadleaf(s, base)


static func _spruce(o: Dictionary, s: float, lite: bool) -> Dictionary:
	var base := {"r": 0.05, "R": 0.2, "tiers": 7, "base": 0.2, "pal": "fir", "tall": 1.5, "lite": lite}
	base.merge(o, true)
	return fir(s, base)


## the variation `i` of a set (the order of trees.ts SETS); a set mixes species, as Ash Wood's broadleaf, old tree and pine
static func _make(set_name: String, i: int, s: float, lite: bool) -> Dictionary:
	match set_name:
		"Bush":
			return shrub(s, ["green", "olive", "teal"][i], lite)
		"Tree_Bare":
			return dead(s, lite)
		"Tree_4":
			return [_spruce.bind({}, s, lite), _spruce.bind({"R": 0.16, "tiers": 8, "base": 0.26}, s, lite), _pine.bind(s, lite)][i].call()
		"Tree_2":
			return [_oak.bind("teal", {"th": 0.48, "spread": 0.27, "squash": 0.9, "tall": 1.25}, s, lite), _spruce.bind({"R": 0.18}, s, lite), _old.bind(s, lite)][i].call()
		"Tree_3":
			return [_oak.bind("olive", {"r": 0.045, "th": 0.34, "spread": 0.3}, s, lite), _oak.bind("green", {"r": 0.075, "th": 0.3, "spread": 0.46, "squash": 0.62}, s, lite), _spruce.bind({"R": 0.22, "tiers": 6, "tall": 1.2}, s, lite)][i].call()
	return [_oak.bind("green", {}, s, lite), _oak.bind("teal", {"spread": 0.4, "th": 0.36}, s, lite), _old.bind(s, lite), _pine.bind(s, lite)][i].call()


static func _old(s: float, lite: bool) -> Dictionary:
	return broadleaf(s, {"r": 0.09, "th": 0.36, "spread": 0.42, "pal": "green", "roots": 5, "limbs": 5, "lite": lite}) # thick trunk


static func _pine(s: float, lite: bool) -> Dictionary:
	# tall, bare trunk
	return broadleaf(s, {"r": 0.045, "th": 0.62, "spread": 0.2, "top": 0.36, "squash": 0.5, "pal": "fir", "limbs": 4,
		"stubs": 3, "tall": 1.6, "reach": 0.11, "lite": lite})


## the set a KayKit tree name belongs to, and how many variations it has
static func set_of(name: String) -> Array:
	for row in [["Bush", 3], ["Tree_Bare", 3], ["Tree_4", 3], ["Tree_2", 3], ["Tree_3", 3], ["Tree_", 4]]:
		if name.contains(row[0]):
			return row
	return []


## every variation of a KayKit tree name, as swapTrees builds them: the seed is the sum of the name's character codes
static func variations(name: String, lite: bool = false) -> Array:
	var row := set_of(name)
	var seed := 0
	for c in name:
		seed += c.unicode_at(0)
	var out := []
	for i in row[1]:
		out.append(_make(row[0], i, seed + i * 131, lite))
	return out
