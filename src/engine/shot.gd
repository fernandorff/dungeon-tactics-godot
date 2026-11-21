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
	# the bodies in flat arrays: read for every cell the shot crosses
	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	var bs := PackedInt32Array()
	var btop := PackedFloat64Array()
	var bid: Array = []
	for u in state.units:
		if u.id != shooter.id and u.id != target:
			bx.append(u.pos.x)
			by.append(u.pos.y)
			bs.append(Pathing.size_of(u.def))
			btop.append(_sight_h(grid, Pathing.footprint(u)) + BODY_H)
			bid.append(u.id)
	var nb := bid.size()
	var fh: float = from.h
	var ks: Array = [0.0, 1.0]
	for pq in [[from.x, to.x], [from.y, to.y]]:
		var p: float = pq[0]
		var q: float = pq[1]
		var v := floori(minf(p, q)) + 1
		while v < maxf(p, q):
			ks.append((v - p) / (q - p))
			v += 1
	ks.sort()
	var fx: float = from.x
	var fy: float = from.y
	var dx: float = to.x - fx
	var dy: float = to.y - fy
	# plain loops and floats instead of closures and a point Dictionary per step: the AI traces hundreds of shots a turn
	for i in range(1, ks.size()):
		var k0: float = ks[i - 1]
		var k1: float = ks[i]
		if k0 == k1:
			continue
		var km := (k0 + k1) / 2
		var mx := fx + dx * km
		var my := fy + dy * km
		var stop_k := -1.0
		var stop: Variant = null
		for y in _sides(my):
			for x in _sides(mx):
				var c := Vector2i(x, y)
				if not grid.in_bounds(c):
					continue
				var own: bool = (x >= a.x and x < a.x + n and y >= a.y and y < a.y + n) or (x >= b.x and x < b.x + n and y >= b.y and y < b.y + n)
				var t := grid.tile(c)
				var ground: float = t.h if own else t.h + Grid.blocks_of(t)
				var kt := _under(fh, rise, fall, ground, k0, k1)
				if kt >= 0.0 and (stop == null or kt < stop_k):
					stop_k = kt
					stop = {"k": kt, "pos": Vector2i(x - x % n, y - y % n), "unit": null}
				for j in nb:
					if x >= bx[j] and x < bx[j] + bs[j] and y >= by[j] and y < by[j] + bs[j]:
						var kb := _under(fh, rise, fall, btop[j], k0, k1)
						if kb >= 0.0 and (stop == null or kb < stop_k):
							stop_k = kb
							stop = {"k": kb, "pos": c, "unit": bid[j]}
						break
		if stop != null:
			var out := shot.duplicate()
			out.stop = stop
			return out
	return shot


## where the shot first goes under `top` inside [k0, k1], or -1 when it stays above
static func _under(fh: float, rise: float, fall: float, top: float, k0: float, k1: float) -> float:
	if fh + rise * k0 - fall * k0 * k0 < top:
		return k0
	if fh + rise * k1 - fall * k1 * k1 >= top:
		return -1.0
	var k: float
	if fall != 0.0:
		k = (rise + sqrt(rise * rise - 4 * fall * (top - fh))) / (2 * fall)
	else:
		k = (top - fh) / rise
	return minf(k1, maxf(k0, k))


static func _sides(v: float) -> Array:
	if v == floorf(v):
		return [int(v) - 1, int(v)]
	return [floori(v)]
