class_name Counter
## Who answers a strike with a counter, which counters a move owes, and `play`, which plays them (port of counter.ts).


static func basic_of(def: String) -> String:
	var a: Array = Content.units[def].abilities
	return a[0] if a.size() else ""


static func is_ranged(ability_id: String) -> bool:
	return Content.abilities[ability_id].range[1] > 1


static func _answers_single(def: String) -> bool:
	var b := basic_of(def)
	return b != "" and Content.abilities[b].radius == 0


static func can_counter(actor: Dictionary, ability_id: String, u: Dictionary) -> bool:
	var a: Dictionary = Content.abilities[ability_id]
	return a.charge == 0 and not (a.heal[1] > 0 or a.get("ally", false)) and u.team != actor.team and _answers_single(u.def) and Content.units[u.def].speed > 0


static func in_contact(grid: Grid, state: Dictionary, foe: Dictionary, pos: Vector2i) -> bool:
	var e := Pathing.aim_ends(grid, state, foe, pos)
	return Grid.dist(e[0], e[1]) < Pathing.near_cells(grid, Content.abilities[basic_of(foe.def)].range[0])


## the counters a move of the actor to `to` owes: [{unit, at, preview}]
static func pending(grid: Grid, state: Dictionary, actor_id: String, to: Vector2i) -> Array:
	var actor := Combat.find_unit(state, actor_id)
	if actor.is_empty() or state.turn.actor != actor_id:
		return []
	var out: Array = []
	for id in state.turn.get("engaged", []):
		var foe := Combat.find_unit(state, id)
		if foe.is_empty() or not _answers_single(foe.def):
			continue
		var at := func(pos: Vector2i) -> Dictionary:
			var moved := state.duplicate()
			var units: Array = []
			for u in state.units:
				if is_same(u, actor):
					var c: Dictionary = u.duplicate()
					c.pos = pos
					if actor.has("facing"):
						c.facing = Pathing.turned_to(grid, state, actor, pos, Grid.facing_to(pos, foe.pos))
					units.append(c)
				else:
					units.append(u)
			moved.units = units
			return Combat.preview(grid, moved, foe.id, basic_of(foe.def), pos, true)
		var here: Dictionary = at.call(actor.pos)
		var there: Dictionary = at.call(to)
		if here.ok and not there.ok:
			out.append({"unit": foe.id, "at": actor.pos, "preview": here})
		elif there.ok and in_contact(grid, state, foe, actor.pos):
			out.append({"unit": foe.id, "at": to, "preview": there})
	return out


static func play(grid: Grid, state: Dictionary, actor_id: String, owed: Array) -> Array:
	var events: Array = []
	for c in owed:
		var foe := Combat.find_unit(state, c.unit)
		var actor := Combat.find_unit(state, actor_id)
		if foe.is_empty() or actor.is_empty():
			continue
		if actor.has("facing"):
			actor.facing = Pathing.turned_to(grid, state, actor, actor.pos, Grid.facing_to(actor.pos, foe.pos))
		events.append_array(Combat.resolve(grid, state, c.unit, basic_of(foe.def), actor.pos, true, Combat.COUNTER))
		var left: Array = []
		for id in state.turn.get("engaged", []):
			if id != c.unit:
				left.append(id)
		if left.is_empty():
			state.turn.erase("engaged")
		else:
			state.turn.engaged = left
	return events
