class_name Options
## What a unit can do this turn, worked out before it moves (port of options.ts, the "Agir primeiro" list): for each
## ability, the targets it can reach by walking and then acting, and the tiles it may act from. Pure reading of the state.


## the tiles a unit may act from this turn, its own first, then by movement cost; never deep water
static func origins_of(grid: Grid, state: Dictionary, actor: Dictionary) -> Array:
	var spent: int = state.turn.get("spent", 0) if state.turn.actor == actor.id else 0
	var left := Effects.move_of(state, actor) - spent
	var walk: Array = Pathing.reachable(grid, state, actor.id, left).values() if left > 0 else []
	walk = Util.stable_sort(walk, func(x: Dictionary, y: Dictionary) -> bool: return x.cost < y.cost)
	var all: Array = [{"pos": actor.pos, "cost": 0}]
	for s in walk:
		all.append({"pos": s.pos, "cost": s.cost})
	var out: Array = []
	for o in all:
		var moved: Dictionary = actor.duplicate()
		moved.pos = o.pos
		if not Combat.in_deep(grid, moved):
			out.append(o)
	return out


static func action_options(grid: Grid, state: Dictionary, id: String) -> Array:
	var actor := Combat.find_unit(state, id)
	if actor.is_empty() or state.outcome != "ongoing":
		return []
	var def: Dictionary = Content.units[actor.def]
	var origins := origins_of(grid, state, actor)
	var lo := Util.BIG
	var hi := -Util.BIG
	for t in grid.tiles:
		lo = mini(lo, Grid.stand_h(t))
		hi = maxi(hi, Grid.stand_h(t))
	var span := hi - lo
	var slack: int = 2 * (def.get("size", 1) - 1) + 2 * (grid.sub - 1)
	var others: Array = []
	for u in state.units:
		if not is_same(u, actor):
			others.append(u)
	var result: Array = []
	for ability_id in def.abilities:
		var a: Dictionary = Content.abilities[ability_id]
		if state.turn.actor == id and Slots.slot_for(state.turn, a) == "":
			result.append({"ability": ability_id, "enabled": false, "reason": "used", "targets": []})
			continue
		if not Pools.can_pay(actor, a):
			result.append({"ability": ability_id, "enabled": false, "reason": "spent", "pool": a.cost[0], "missing": a.cost[1] - Pools.pool_of(actor, a.cost[0]), "targets": []})
			continue
		if origins.is_empty():
			result.append({"ability": ability_id, "enabled": false, "reason": "water", "targets": []})
			continue
		# a melee reach is measured by the longer axis (Reach.is_melee): its diagonal is twice that in steps
		var far: int = (Reach.far_cells(grid, a.range[1] + (span if a.heightRange else 0)) + slack) * (2 if Reach.is_melee(a) else 1)
		var found := {}
		var blocked := false
		var unwanted := false
		var add := func(key: String, t: Dictionary, o: Dictionary, p: Dictionary) -> void:
			if not found.has(key):
				var nt := t.duplicate()
				nt.spots = []
				found[key] = nt
			found[key].spots.append({"pos": o.pos, "cost": o.cost, "preview": p})
		var centered: bool = a.range[1] == 0
		var ground := {}
		var r := Reach.far_cells(grid, a.radius)
		if not centered and a.radius > 0:
			for u in state.units:
				var end: int = r + Pathing.size_of(u.def) - 1
				for dx in range(-r, end + 1):
					for dy in range(-r, end + 1):
						var p := Vector2i(u.pos.x + dx, u.pos.y + dy)
						if not grid.in_bounds(p) or not Pathing.unit_at(state, p).is_empty():
							continue
						var tile := Pathing.aim_tile(grid, state, p)
						ground[Grid.pos_key(tile)] = tile
		for o in origins:
			if centered or a.range[0] == 0:
				var p := Combat.preview(grid, state, id, ability_id, o.pos, false, o.pos)
				if p.ok and p.targets.size():
					add.call("self", {"kind": "self", "pos": actor.pos}, o, p)
			if centered:
				continue
			for u in others:
				if Grid.dist(o.pos, u.pos) > far + 2 * (Pathing.size_of(u.def) - 1):
					continue
				var p := Combat.preview(grid, state, id, ability_id, u.pos, false, o.pos)
				if not p.ok:
					continue
				var hits := false
				for t in p.targets:
					if t.unit == u.id:
						hits = true
				if hits:
					add.call(u.id, {"kind": "unit", "unit": u.id, "pos": u.pos}, o, p)
				elif a.needsSight:
					blocked = true
				else:
					unwanted = true
			for k in ground:
				var pos: Vector2i = ground[k]
				if Grid.dist(o.pos, pos) > far:
					continue
				var p := Combat.preview(grid, state, id, ability_id, pos, false, o.pos)
				if p.ok and p.targets.size():
					add.call(k, {"kind": "tile", "pos": pos}, o, p)
		var order := {"unit": 0, "self": 1, "tile": 2}
		var rank := func(t: Dictionary) -> int:
			if t.kind != "unit":
				return 0
			return 1 if Combat.find_unit(state, t.unit).team == actor.team else 0
		var key := func(t: Dictionary) -> Array:
			return [order[t.kind], rank.call(t), Grid.dist(actor.pos, t.pos)]
		var targets := Util.stable_sort(found.values(), func(x: Dictionary, y: Dictionary) -> bool:
			var kx: Array = key.call(x)
			var ky: Array = key.call(y)
			for i in 3:
				if kx[i] != ky[i]:
					return kx[i] < ky[i]
			return false)
		if targets.size():
			result.append({"ability": ability_id, "enabled": true, "targets": targets})
			continue
		var reason := "sight" if blocked else ("no-target" if centered or unwanted or others.is_empty() else "range")
		result.append({"ability": ability_id, "enabled": false, "reason": reason, "targets": []})
	return result
