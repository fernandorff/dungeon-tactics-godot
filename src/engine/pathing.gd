class_name Pathing
## Walking, bodies and ranges (port of pathing.ts): who stands where, where a unit can walk this turn (`reachable`, a
## Dictionary pos key -> step in insertion order, as the web game's Map), leaps over gaps, the square tokens of half tiles,
## and the cell measures of ranges and areas.

const MAX_JUMP := 1


static func jump_of(state: Dictionary, def: String) -> int:
	var rules: Dictionary = Content.scenarios.get(state.scenario, {}).get("rules", {})
	if rules.has("jump"):
		return rules.jump
	return Content.units[def].get("jump", MAX_JUMP) if Content.units.has(def) else MAX_JUMP


static func size_of(def: String) -> int:
	return Content.units[def].get("size", 1)


static func cells_of(p: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			out.append(Vector2i(p.x + dx, p.y + dy))
	return out


## a long body (halfLength, the snake) adds the squares behind the head, opposite its facing
static func body_of(def: String, pos: Vector2i, facing: int = 0) -> Array[Vector2i]:
	var d: Dictionary = Content.units[def]
	var size: int = d.get("size", 1)
	var f: Vector2i = Grid.FACING[facing]
	var out: Array[Vector2i] = []
	for k in d.get("halfLength", 1):
		out.append_array(cells_of(pos - f * k, size))
	return out


static func footprint(u: Dictionary) -> Array[Vector2i]:
	return body_of(u.def, u.pos, u.get("facing", 0))


static func body_fits(grid: Grid, state: Dictionary, u: Dictionary, pos: Vector2i, facing: int = 0, passing: bool = false) -> bool:
	if not Content.units[u.def].get("halfLength", 0):
		return true
	for c in body_of(u.def, pos, facing):
		if not grid.in_bounds(c) or not Grid.can_stand(grid.tile(c)):
			return false
		if absi(grid.tile(c).h - grid.tile(pos).h) > jump_of(state, u.def):
			return false
		var o := unit_at(state, c)
		if passing:
			if not (o.is_empty() or o.team == u.team):
				return false
		elif no_stop_at(grid, state, c) or not (o.is_empty() or o.id == u.id):
			return false
	return true


## where `u` looks after turning toward `dir`: a long body keeps its facing when the turn does not fit
static func turned_to(grid: Grid, state: Dictionary, u: Dictionary, pos: Vector2i, dir: int) -> Variant:
	return dir if body_fits(grid, state, u, pos, dir) else u.get("facing")


static func square_h(grid: Grid, p: Vector2i, size: int) -> int:
	var best := -Util.BIG
	for c in cells_of(p, size):
		best = maxi(best, Grid.stand_h(grid.tile(c)))
	return best


static func nearest_tile(u: Dictionary, p: Vector2i) -> Vector2i:
	var fp := footprint(u)
	var best: Vector2i = fp[0]
	for b in fp:
		if Grid.dist(b, p) < Grid.dist(best, p):
			best = b
	return best


## the closest pair [in a, in b] (a tie keeps the first pair, a's order then b's)
static func closest(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = [a[0], b[0]]
	var d := Util.BIG
	for p in a:
		for q in b:
			var dd := absi(p.x - q.x) + absi(p.y - q.y)
			if dd < d:
				d = dd
				best = [p, q]
	return best


static func gap(a: Array[Vector2i], b: Array[Vector2i]) -> int:
	var c := closest(a, b)
	return Grid.dist(c[0], c[1])


static func area_of(grid: Grid, state: Dictionary, center: Vector2i) -> Array[Vector2i]:
	if grid.sub == 1:
		return [center]
	return cells_of(aim_tile(grid, state, center) if not unit_at(state, center).is_empty() else center, grid.sub)


## the whole tile an aim at `p` stands for, as the corner cell of its square
static func aim_tile(grid: Grid, state: Dictionary, p: Vector2i) -> Vector2i:
	var k := grid.sub
	if k == 1:
		return p
	var u := unit_at(state, p)
	var o: Vector2i = u.pos if not u.is_empty() else Vector2i.ZERO
	return Vector2i(p.x - (p.x - o.x) % k, p.y - (p.y - o.y) % k)


static func aim_ends(grid: Grid, state: Dictionary, actor: Dictionary, center: Vector2i) -> Array[Vector2i]:
	if grid.sub == 1:
		return [nearest_tile(actor, center), center]
	return closest(footprint(actor), area_of(grid, state, aim_tile(grid, state, center)))


static func in_area(grid: Grid, area: Array[Vector2i], radius: int, cells: Array[Vector2i]) -> bool:
	return gap(area, cells) <= Reach.far_cells(grid, radius)


## the unit standing on `p` (any cell of its body), or an empty Dictionary
static func unit_at(state: Dictionary, p: Vector2i) -> Dictionary:
	for u in state.units:
		var d: Dictionary = Content.units[u.def]
		if d.get("halfLength", 0):
			if footprint(u).has(p):
				return u
			continue
		var dx: int = p.x - u.pos.x
		var dy: int = p.y - u.pos.y
		if dx >= 0 and dy >= 0 and maxi(dx, dy) < d.get("size", 1):
			return u
	return {}


static func no_stop_at(grid: Grid, state: Dictionary, p: Vector2i) -> bool:
	if grid.tile(p).get("noStop", false):
		return true
	return state.has("corpses") and state.corpses.has(p)


## Leap over a gap, as in FFT: straight over tiles you cannot stand on or lower than both ends; lands on the same level or
## up to `jump` below. Returns [{to, over}]
static func leaps(grid: Grid, from: Vector2i, jump: int) -> Array:
	var out: Array = []
	var h0 := Grid.stand_h(grid.tile(from))
	for d in Grid.FACING:
		var over: Array[Vector2i] = []
		for k in range(1, jump / 2 + 1):
			var mid: Vector2i = from + d * k
			var to: Vector2i = mid + d
			if not grid.in_bounds(to):
				break
			var g := grid.tile(mid)
			if not Grid.walkable(g):
				break
			over.append(mid)
			var land := grid.tile(to)
			if not Grid.can_stand(land) or Grid.is_deep(land) or Grid.stand_h(land) > h0 or h0 - Grid.stand_h(land) > jump:
				continue
			var low := mini(h0, Grid.stand_h(land))
			var clear := true
			for p in over:
				var t := grid.tile(p)
				if Grid.can_stand(t) and Grid.stand_h(t) >= low:
					clear = false
					break
			if clear:
				out.append({"to": to, "over": over.duplicate()})
	return out


## One move of a square token from the corner `cur`, in FACING order, each step before its gaps. `blocked(cell)`: a cell it
## cannot stand on or fly over. Returns [{to, cost}]
static func square_moves(grid: Grid, cur: Vector2i, size: int, jump: int, blocked: Callable) -> Array:
	var height_of := func(p: Vector2i) -> Variant:
		var lo := Util.BIG
		var hi := -Util.BIG
		for c in cells_of(p, size):
			if not grid.in_bounds(c):
				return null
			var t := grid.tile(c)
			if not Grid.can_stand(t) or blocked.call(c):
				return null
			lo = mini(lo, t.h)
			hi = maxi(hi, t.h)
		return null if hi - lo > jump else hi
	var out: Array = []
	var fly_max := (grid.sub * jump) / 2
	var h0v: Variant = height_of.call(cur)
	var h0: int = h0v if h0v != null else grid.tile(cur).h
	for d in Grid.FACING:
		var n: Vector2i = cur + d
		var h: Variant = height_of.call(n)
		if h != null and absi(h - h0) <= jump:
			var cost := -Util.BIG
			for c in cells_of(n, size):
				cost = maxi(cost, Grid.step_cost(grid.tile(c)))
			out.append({"to": n, "cost": cost})
		var edge := Vector2i(cur.x + (size - 1 if d.x > 0 else 0), cur.y + (size - 1 if d.y > 0 else 0))
		var strip: Array[Vector2i] = []
		for g in range(1, fly_max + 1):
			var line: Array[Vector2i] = []
			for k in size:
				line.append(Vector2i(edge.x + d.x * g + (0 if d.x else k), edge.y + d.y * g + (0 if d.y else k)))
			var stop := false
			for c in line:
				if not grid.in_bounds(c) or not Grid.walkable(grid.tile(c)) or blocked.call(c):
					stop = true
					break
			if stop:
				break
			strip.append_array(line)
			var land := Vector2i(cur.x + d.x * (size + g), cur.y + d.y * (size + g))
			var hl: Variant = height_of.call(land)
			if hl == null or hl > h0 or h0 - hl > jump:
				continue
			var deep := false
			for c in cells_of(land, size):
				if Grid.is_deep(grid.tile(c)):
					deep = true
			if deep:
				continue
			var low := mini(h0, hl)
			var ok := true
			for c in strip:
				if Grid.stand_h(grid.tile(c)) >= low:
					ok = false
					break
			if ok:
				for c in cells_of(land, size):
					if grid.tile(c).h != hl:
						ok = false
						break
			if ok:
				out.append({"to": land, "cost": size + g})
	return out


## Where a square may stop: all its cells the same ground; a ramp cell only under a square on its own whole tile
static func rests_on(grid: Grid, p: Vector2i, size: int) -> bool:
	var k := grid.sub
	var first: String = ""
	for c in cells_of(p, size):
		var t := grid.tile(c)
		var kind := "%d,%d,%s,%s" % [t.h, Grid.stand_h(t), t.get("spikes", false), t.terrain]
		if first == "":
			first = kind
		if kind != first:
			return false
		if t.has("ramp") and not (p.x % k == 0 and p.y % k == 0):
			return false
	return true


static func _build_paths(seen: Dictionary) -> void:
	for key in seen:
		var step: Dictionary = seen[key]
		var path: Array[Vector2i] = []
		var s: Variant = step
		while s != null and s.from != null:
			path.push_front(s.pos)
			s = seen.get(s.from)
		step.path = path


static func _reachable_big(grid: Grid, state: Dictionary, unit: Dictionary, budget: int, jump: int) -> Dictionary:
	var size: int = Content.units[unit.def].size
	var foe := func(c: Vector2i) -> bool:
		var o := unit_at(state, c)
		return not o.is_empty() and o.id != unit.id and o.team != unit.team
	var seen := {Grid.pos_key(unit.pos): {"pos": unit.pos, "cost": 0, "from": null}}
	var queue: Array[Vector2i] = [unit.pos]
	var i := 0
	while i < queue.size():
		var cur: Vector2i = queue[i]
		i += 1
		var cost: int = seen[Grid.pos_key(cur)].cost
		for m in square_moves(grid, cur, size, jump, foe):
			var k := Grid.pos_key(m.to)
			if cost + m.cost > budget or (seen.has(k) and seen[k].cost <= cost + m.cost):
				continue
			seen[k] = {"pos": m.to, "cost": cost + m.cost, "from": Grid.pos_key(cur)}
			queue.append(m.to)
	_build_paths(seen)
	seen.erase(Grid.pos_key(unit.pos))
	for k in seen.keys():
		var step: Dictionary = seen[k]
		var drop := not rests_on(grid, step.pos, size)
		if not drop:
			for c in cells_of(step.pos, size):
				var o := unit_at(state, c)
				if (not o.is_empty() and o.id != unit.id) or no_stop_at(grid, state, c):
					drop = true
					break
		if drop:
			seen.erase(k)
	return seen


## Where the unit can stop this turn: pos key -> {pos, cost, from, path}; `budget` = movement points left (-1: all of it)
static func reachable(grid: Grid, state: Dictionary, unit_id: String, budget: int = -1) -> Dictionary:
	var unit: Dictionary = {}
	for u in state.units:
		if u.id == unit_id:
			unit = u
			break
	if budget < 0:
		budget = Effects.move_of(state, unit)
	var jump := jump_of(state, unit.def)
	var d: Dictionary = Content.units[unit.def]
	var long: bool = d.get("halfLength", 0) > 0
	var has_facing := unit.has("facing")
	var faced := func(from: Vector2i, to: Vector2i) -> int:
		return Grid.facing_to(from, to) if has_facing else 0
	if d.get("size", 1) > 1 and d.move > 0:
		return _reachable_big(grid, state, unit, budget, jump)
	var seen := {Grid.pos_key(unit.pos): {"pos": unit.pos, "cost": 0, "from": null}}
	var queue: Array[Vector2i] = [unit.pos]
	var i := 0
	while i < queue.size():
		var cur: Vector2i = queue[i]
		i += 1
		var cost: int = seen[Grid.pos_key(cur)].cost
		for n in grid.neighbors(cur):
			var k := Grid.pos_key(n)
			var to := grid.tile(n)
			var nxt := cost + Grid.step_cost(to)
			if nxt > budget or (seen.has(k) and seen[k].cost <= nxt):
				continue
			if not Grid.can_stand(to) or absi(to.h - grid.tile(cur).h) > jump:
				continue
			var other := unit_at(state, n)
			if not other.is_empty() and other.team != unit.team:
				continue
			if long and not body_fits(grid, state, unit, n, faced.call(cur, n), true):
				continue
			seen[k] = {"pos": n, "cost": nxt, "from": Grid.pos_key(cur)}
			queue.append(n)
		for lp in leaps(grid, cur, jump):
			var n: Vector2i = lp.to
			var k := Grid.pos_key(n)
			var nxt: int = cost + lp.over.size() + Grid.step_cost(grid.tile(n))
			if nxt > budget or (seen.has(k) and seen[k].cost <= nxt):
				continue
			var hit_foe := false
			for p in [n] + lp.over:
				var o := unit_at(state, p)
				if not o.is_empty() and o.team != unit.team:
					hit_foe = true
					break
			if hit_foe or (long and not body_fits(grid, state, unit, n, faced.call(cur, n), true)):
				continue
			seen[k] = {"pos": n, "cost": nxt, "from": Grid.pos_key(cur)}
			queue.append(n)
	_build_paths(seen)
	if long:
		for key in seen:
			var step: Dictionary = seen[key]
			if step.from == null or body_fits(grid, state, unit, step.pos, faced.call(seen[step.from].pos, step.pos)):
				continue
			var alt: Variant = null
			for m in grid.neighbors(step.pos):
				var ms: Variant = seen.get(Grid.pos_key(m))
				if ms != null and ms.cost + Grid.step_cost(grid.tile(step.pos)) <= budget and absi(grid.tile(ms.pos).h - grid.tile(step.pos).h) <= jump and body_fits(grid, state, unit, step.pos, faced.call(ms.pos, step.pos)):
					alt = ms
					break
			if alt != null:
				step.cost = alt.cost + Grid.step_cost(grid.tile(step.pos))
				step.from = Grid.pos_key(alt.pos)
				var p: Array[Vector2i] = alt.path.duplicate()
				p.append(step.pos)
				step.path = p
	seen.erase(Grid.pos_key(unit.pos))
	for k in seen.keys():
		var step: Dictionary = seen[k]
		var o := unit_at(state, step.pos)
		if (not o.is_empty() and o.id != unit.id) or no_stop_at(grid, state, step.pos):
			seen.erase(k)
	if long:
		for k in seen.keys():
			var step: Dictionary = seen[k]
			var path: Array = step.path
			var prev: Vector2i = path[path.size() - 2] if path.size() >= 2 else unit.pos
			if not body_fits(grid, state, unit, step.pos, faced.call(prev, step.pos)):
				seen.erase(k)
	return seen


static func path_to(reach: Dictionary, target: Vector2i) -> Variant:
	var s: Variant = reach.get(Grid.pos_key(target))
	return s.path if s != null else null
