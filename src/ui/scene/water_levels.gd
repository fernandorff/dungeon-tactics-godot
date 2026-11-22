class_name WaterLevels
## Water heights in the drawing (port of water-levels.ts), pure so the tests reach it: each water tile's surface and
## bed, and each bridge with water under it. Visuals only: the rules read `depth`. A level is
## {surface: float, bed: float, deep: bool, under: bool}, keyed by the cell.

## how much the deep surface sits below the shallow one, in levels (Nov 13: with 0.45 the deep river looked flush with the bank)
const DEEP_DROP := 0.8
## how much a unit sinks in shallow water, in levels: waist-deep (with 0.3 the legs barely showed)
const WADE := 0.45
## how much a unit sinks in deep water, below the surface: swimming, head and shoulders out
const SWIM := 0.75
## the deep bed, in levels below the surface: it vanishes into the dark water, it only must not be in view
const DEEP_BED := 1.0


static func _deep(g: Grid, p: Vector2i) -> bool:
	var t := g.tile(p)
	return t.get("look", "") == "water" and int(t.get("depth", 0)) >= 2


## River without ups and downs: each connected deep stretch that touches shallow water and is not the largest stays at
## the shallow height; the largest stays low and the ford drops to it like a waterfall (Fernando, Nov 13)
static func raised_deep(g: Grid) -> Dictionary:
	var seen := {}
	var parts: Array = []
	for i in g.tiles.size():
		var start := Vector2i(i % g.width, i / g.width)
		if not _deep(g, start) or seen.has(start):
			continue
		var part := {"tiles": [], "shallow": false}
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var p: Vector2i = queue.pop_back()
			part.tiles.append(p)
			for n in g.neighbors(p):
				var t := g.tile(n)
				if t.get("look", "") == "water" and int(t.get("depth", 0)) == 1:
					part.shallow = true
				if _deep(g, n) and not seen.has(n):
					seen[n] = true
					queue.append(n)
		parts.append(part)
	var biggest := 0
	for part in parts:
		biggest = maxi(biggest, part.tiles.size())
	var out := {}
	var big_found := false
	for part in parts:
		# the first stretch of the biggest size stays low, as the web's `find`
		if not big_found and part.tiles.size() == biggest:
			big_found = true
			continue
		if part.shallow:
			for p in part.tiles:
				out[p] = true
	return out


static func _bed(surface: float, deep: bool, step: float) -> float:
	return maxf(0.02, surface - DEEP_BED * step) if deep else surface - WADE * step


## surface and bed of each water tile and each bridge with water under it; the shallow bed sits where the feet stand
static func of_grid(g: Grid, step: float, raised: Dictionary = {}) -> Dictionary:
	if raised.is_empty():
		raised = raised_deep(g)
	var out := {}
	for i in g.tiles.size():
		var t: Dictionary = g.tiles[i]
		if t.get("look", "") != "water":
			continue
		var p := Vector2i(i % g.width, i / g.width)
		var deep := int(t.get("depth", 0)) >= 2
		var surface: float = (t.h + 1 - (DEEP_DROP if deep and not raised.has(p) else 0.0)) * step
		out[p] = {"surface": surface, "bed": _bed(surface, deep, step), "deep": deep, "under": false}
	# a bridge: water passes under it at its neighbours' height; a plank flush with the water has no gap and is left out
	for i in g.tiles.size():
		var t: Dictionary = g.tiles[i]
		if t.get("look", "") != "bridge":
			continue
		var p := Vector2i(i % g.width, i / g.width)
		var surface := INF
		var deep := false
		for q in g.neighbors(p):
			var l: Variant = out.get(q)
			if l != null and not l.under:
				surface = minf(surface, l.surface)
				deep = deep or l.deep
		if surface == INF or surface > t.h * step - 0.01:
			continue
		out[p] = {"surface": surface, "bed": _bed(surface, deep, step), "deep": deep, "under": true}
	# a wide bridge: the middle tile only touches land and bridge, and takes its neighbouring bridge's water
	var grew := true
	while grew:
		grew = false
		for i in g.tiles.size():
			var p := Vector2i(i % g.width, i / g.width)
			if g.tiles[i].get("look", "") != "bridge" or out.has(p):
				continue
			for q in g.neighbors(p):
				var l: Variant = out.get(q)
				if l != null and l.under:
					out[p] = l.duplicate()
					grew = true
					break
	return out
