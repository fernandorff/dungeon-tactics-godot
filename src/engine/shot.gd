class_name Shot
## Shots (port of shot.ts): the path a shot flies, what stops it and the two ends it is measured between. A half tile is
## 1 m and a level 1 m; the shot leaves SHOT_H above the shooter's floor and whatever the path crosses stops it.
## A shot is {from, to, rise, fall, stop}; a point is {x, y, h}; stop is {k, pos, unit} or null.

const SHOT_H := 1.5
const BODY_H := 1.8


static func _sight_h(grid: Grid, cells: Array[Vector2i]) -> int:
	var best := -Util.BIG
	for p in cells:
		if grid.in_bounds(p):
			var t := grid.tile(p)
			best = maxi(best, t.h if Grid.is_deep(t) else Grid.stand_h(t))
	return best


static func _block_top(grid: Grid, p: Vector2i) -> int:
	var t := grid.tile(p)
	return t.h + Grid.blocks_of(t)


static func sight_ends(grid: Grid, state: Dictionary, actor: Dictionary, center: Vector2i) -> Array[Vector2i]:
	var k := grid.sub
	if k == 1:
		return [Pathing.nearest_tile(actor, center), center]
	var to := Pathing.aim_tile(grid, state, center)
	var n := Pathing.nearest_tile(actor, to)
	var pos: Vector2i = actor.pos
	var snapped := Vector2i(pos.x + Util.floor_div(n.x - pos.x, k) * k, pos.y + Util.floor_div(n.y - pos.y, k) * k)
	return [snapped, to]


static func at(s: Dictionary, k: float) -> Dictionary:
	return {
		"x": s.from.x + (s.to.x - s.from.x) * k,
		"y": s.from.y + (s.to.y - s.from.y) * k,
		"h": s.from.h + s.rise * k - s.fall * k * k,
	}


static func trace(grid: Grid, state: Dictionary, shooter: Dictionary, center: Vector2i, arc: bool) -> Dictionary:
	var n := grid.sub
	var ends := sight_ends(grid, state, shooter, center)
	var a: Vector2i = ends[0]
	var b: Vector2i = ends[1]
	var from := {"x": a.x + n / 2.0, "y": a.y + n / 2.0, "h": _sight_h(grid, Pathing.cells_of(a, n)) + SHOT_H}
	var to := {"x": b.x + n / 2.0, "y": b.y + n / 2.0, "h": _sight_h(grid, Pathing.cells_of(b, n)) + SHOT_H}
	var rise: float = to.h - from.h
	var fall := 0.0
	if arc:
		var ae := Pathing.aim_ends(grid, state, shooter, center)
		var tiles := Reach.whole_tiles(grid, Grid.dist(ae[0], ae[1]))
		var top: float = maxf(from.h, to.h) + mini(3, maxi(1, tiles / 3))
		var d: float = top - from.h
		var e: float = top - to.h
		rise = 2 * (d + sqrt(d * e))
		fall = (rise * rise) / (4 * d)
	var shot := {"from": from, "to": to, "rise": rise, "fall": fall, "stop": null}
	var tu := Pathing.unit_at(state, b)
	var target: Variant = tu.id if not tu.is_empty() else null
	var bodies: Array = []
	for u in state.units:
		if u.id != shooter.id and u.id != target:
			bodies.append({"u": u, "size": Pathing.size_of(u.def), "top": _sight_h(grid, Pathing.footprint(u)) + BODY_H})
	var fh: float = from.h
	var h := func(k: float) -> float:
		return fh + rise * k - fall * k * k
	var under := func(top: float, k0: float, k1: float) -> Variant:
		if h.call(k0) < top:
			return k0
		if h.call(k1) >= top:
			return null
		var k: float
		if fall != 0.0:
			k = (rise + sqrt(rise * rise - 4 * fall * (top - fh))) / (2 * fall)
		else:
			k = (top - fh) / rise
		return minf(k1, maxf(k0, k))
	var ks: Array = [0.0, 1.0]
	for pq in [[from.x, to.x], [from.y, to.y]]:
		var p: float = pq[0]
		var q: float = pq[1]
		var v := floori(minf(p, q)) + 1
		while v < maxf(p, q):
			ks.append((v - p) / (q - p))
			v += 1
	ks.sort()
	var own := func(x: int, y: int) -> bool:
		for p in [a, b]:
			if x >= p.x and x < p.x + n and y >= p.y and y < p.y + n:
				return true
		return false
	for i in range(1, ks.size()):
		var k0: float = ks[i - 1]
		var k1: float = ks[i]
		if k0 == k1:
			continue
		var m := at(shot, (k0 + k1) / 2)
		var stop: Variant = null
		for y in _sides(m.y):
			for x in _sides(m.x):
				var c := Vector2i(x, y)
				if not grid.in_bounds(c):
					continue
				var ground: float = grid.tile(c).h if own.call(x, y) else _block_top(grid, c)
				var kt: Variant = under.call(ground, k0, k1)
				if kt != null and (stop == null or kt < stop.k):
					stop = {"k": kt, "pos": Vector2i(x - x % n, y - y % n), "unit": null}
				var body: Variant = null
				for bd in bodies:
					var up: Vector2i = bd.u.pos
					if x >= up.x and x < up.x + bd.size and y >= up.y and y < up.y + bd.size:
						body = bd
						break
				if body != null:
					var kb: Variant = under.call(body.top, k0, k1)
					if kb != null and (stop == null or kb < stop.k):
						stop = {"k": kb, "pos": c, "unit": body.u.id}
		if stop != null:
			var out := shot.duplicate()
			out.stop = stop
			return out
	return shot


static func _sides(v: float) -> Array:
	if v == floorf(v):
		return [int(v) - 1, int(v)]
	return [floori(v)]
