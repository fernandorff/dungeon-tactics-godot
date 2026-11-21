class_name Push
## Where a push ends and what it costs (port of push.ts): bump, fall, spikes and the events, without touching the state (the
## AI prices pushes with it). Returns {to, dmg, events}.


static func simulate(grid: Grid, state: Dictionary, unit: Dictionary, center: Vector2i, origin: Vector2i, steps: int) -> Dictionary:
	var result := {"to": unit.pos, "dmg": 0, "events": []}
	var size := Pathing.size_of(unit.def)
	if Pathing.size_of(Content.base_def(unit.def)) > 1:
		return result
	var facing: int = unit.get("facing", 0)
	var cells := func(p: Vector2i) -> Array[Vector2i]:
		return Pathing.body_of(unit.def, p, facing)
	var mid := func(p: Vector2i, n: int) -> Vector2i:
		return Vector2i(2 * p.x + n - 1, 2 * p.y + n - 1)
	var sub := grid.sub
	var from: Vector2i = mid.call(origin, sub) if cells.call(unit.pos).has(center) else mid.call(center, sub)
	var dx: int = mid.call(unit.pos, size).x - from.x
	var dy: int = mid.call(unit.pos, size).y - from.y
	if dx == 0 and dy == 0:
		return result
	var horizontal := absi(dx) >= absi(dy)
	dx = signi(dx) if horizontal else 0
	dy = 0 if horizontal else signi(dy)
	var height := func(p: Vector2i) -> int:
		var best := -Util.BIG
		for c in cells.call(p):
			best = maxi(best, Grid.stand_h(grid.tile(c)))
		return best
	var spiky := func(p: Vector2i) -> bool:
		for c in cells.call(p):
			if grid.tile(c).get("spikes", false):
				return true
		return false
	var move := func(cur: Vector2i) -> Variant:
		var nxt := Vector2i(cur.x + dx, cur.y + dy)
		for c in cells.call(nxt):
			if not grid.in_bounds(c):
				return null
			var t := grid.tile(c)
			var o := Pathing.unit_at(state, c)
			if not Grid.can_stand(t) or Grid.is_deep(t) or (not o.is_empty() and o.id != unit.id):
				return null
		if height.call(nxt) - height.call(cur) > Pathing.MAX_JUMP:
			return null
		var out := {"to": nxt, "dmg": 0, "events": [{"k": "push", "unit": unit.id, "to": nxt}]}
		var levels: int = height.call(cur) - height.call(nxt)
		var dmg := 0 if levels <= 0 else maxi(0, levels - Combat.FALL_FREE) * Combat.FALL_DAMAGE
		if dmg > 0:
			out.events.append({"k": "fall", "unit": unit.id, "levels": levels, "dmg": dmg})
			out.dmg += dmg
		if spiky.call(nxt) and (cells.call(nxt).size() == 1 or not spiky.call(cur)):
			out.events.append({"k": "spike", "unit": unit.id, "dmg": Combat.SPIKE_DAMAGE})
			out.dmg += Combat.SPIKE_DAMAGE
		return out
	var add := func(m: Dictionary) -> void:
		result.to = m.to
		result.dmg += m.dmg
		result.events.append_array(m.events)
	var long: bool = Content.units[unit.def].get("halfLength", 0) > 0
	var rests := func(p: Vector2i) -> bool:
		if long:
			if not Pathing.body_fits(grid, state, unit, p, facing):
				return false
			for c in cells.call(p):
				if not Pathing.rests_on(grid, c, size):
					return false
			return true
		return Pathing.rests_on(grid, p, size)
	var on_body := func(p: Vector2i) -> bool:
		for c in cells.call(p):
			if Pathing.no_stop_at(grid, state, c):
				return true
		return false
	var even := {"to": result.to, "dmg": result.dmg, "events": []}
	var bumped := false
	var i := 0
	while i < steps * sub and not bumped:
		var m: Variant = move.call(result.to)
		if m == null:
			bumped = true
		else:
			add.call(m)
			if rests.call(result.to) and not on_body.call(result.to):
				even = {"to": result.to, "dmg": result.dmg, "events": result.events.duplicate()}
		i += 1
	if on_body.call(result.to):
		_assign(result, even)
	elif not rests.call(result.to):
		var m: Variant = move.call(result.to)
		var seen := {}
		for c in cells.call(result.to):
			seen[Grid.stand_h(grid.tile(c))] = true
		var level := seen.size() == 1
		var fits: bool = m != null and rests.call(m.to) and (level or height.call(m.to) < height.call(result.to))
		if m != null and fits and not on_body.call(m.to):
			add.call(m)
		else:
			_assign(result, even)
			bumped = not fits
	if bumped:
		result.events.append({"k": "bump", "unit": unit.id, "dmg": Combat.BUMP_DAMAGE})
		result.dmg += Combat.BUMP_DAMAGE
	return result


static func _assign(result: Dictionary, from: Dictionary) -> void:
	result.to = from.to
	result.dmg = from.dmg
	result.events = from.events.duplicate()
