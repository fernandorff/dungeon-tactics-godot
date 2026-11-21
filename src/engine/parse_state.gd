class_name ParseState
## Save trust boundary for the battle state (port of parse-state.ts): every field read back is rebuilt and checked; any
## doubt returns null. Input is plain JSON data (positions as {x, y}); output is an engine state (positions as Vector2i).

const MAX_UNITS := 64


static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT


static func _pos(v: Variant) -> Variant:
	if typeof(v) == TYPE_VECTOR2I:
		return v
	if typeof(v) != TYPE_DICTIONARY or not _is_int(v.get("x")) or not _is_int(v.get("y")):
		return null
	return Vector2i(v.x, v.y)


static func parse(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY or typeof(raw.get("scenario")) != TYPE_STRING or not Content.scenarios.has(raw.scenario):
		return null
	var grid: Grid = Content.scenarios[raw.scenario].grid
	if not _is_int(raw.get("rng")) or not _is_int(raw.get("turnsPlayed")) or raw.turnsPlayed < 0:
		return null
	if not ["ongoing", "victory", "defeat"].has(raw.get("outcome")):
		return null
	if typeof(raw.get("units")) != TYPE_ARRAY or raw.units.size() > MAX_UNITS:
		return null
	var units: Array = []
	var ids := {}
	var cells := {}
	for u in raw.units:
		if typeof(u) != TYPE_DICTIONARY or typeof(u.get("id")) != TYPE_STRING or typeof(u.get("def")) != TYPE_STRING or not Content.units.has(u.def):
			return null
		if String(u.def).ends_with(Content.HALF) != (grid.sub > 1):
			return null
		if u.get("team") != "hero" and u.get("team") != "enemy":
			return null
		var pos: Variant = _pos(u.get("pos"))
		if pos == null:
			return null
		var d: Dictionary = Content.units[u.def]
		var size: int = d.get("size", 1)
		var long: bool = d.get("halfLength", 0) > 0
		var facing: Variant = u.get("facing")
		if facing != null and (not _is_int(facing) or facing < 0 or facing > 3):
			return null
		if long and facing == null:
			return null
		var tiles: Array[Vector2i] = Pathing.body_of(u.def, pos, facing) if long else Pathing.cells_of(pos, size)
		for p in tiles:
			if not grid.in_bounds(p) or not Grid.can_stand(grid.tile(p)) or cells.has(Grid.pos_key(p)):
				return null
		var hp: Variant = u.get("hp")
		var ct: Variant = u.get("ct")
		if not _is_int(hp) or hp < 1 or hp > d.hp or not _is_int(ct) or absi(ct) > 10000:
			return null
		if ids.has(u.id):
			return null
		ids[u.id] = true
		for p in tiles:
			cells[Grid.pos_key(p)] = true
		var vars: Variant = null
		if d.has("vars"):
			var raw_vars: Variant = u.get("vars")
			if raw_vars != null and typeof(raw_vars) != TYPE_DICTIONARY:
				return null
			vars = {}
			for k in d.vars:
				var pool: bool = Content.RESOURCES.has(k)
				var v: Variant = raw_vars.get(k) if raw_vars != null and raw_vars.has(k) else (d.vars[k] if pool else null)
				if not _is_int(v) or absi(v) > 9999:
					return null
				if pool and (v < 0 or v > d.vars[k]):
					return null
				vars[k] = v
		elif u.get("vars") != null:
			return null
		var nu := {"id": u.id, "def": u.def, "team": u.team, "pos": pos, "hp": hp, "ct": ct}
		if facing != null:
			nu.facing = facing
		if vars != null:
			nu.vars = vars
		units.append(nu)
	for u in units:
		if Content.units[u.def].speed > 0 and not u.has("facing"):
			var foes: Array = []
			for o in units:
				if o.team != u.team:
					foes.append(o.pos)
			u.facing = Grid.face_nearest(u.pos, foes)
	var t: Variant = raw.get("turn")
	if typeof(t) != TYPE_DICTIONARY or typeof(t.get("actor")) != TYPE_STRING or typeof(t.get("moved")) != TYPE_BOOL:
		return null
	var actor: Dictionary = {}
	for u in units:
		if u.id == t.actor:
			actor = u
	if actor.is_empty():
		return null
	var bad := "<bad>"
	var slot := func(v: Variant, bonus: bool) -> Variant:
		if v == null:
			return null
		if typeof(v) != TYPE_STRING:
			return bad
		var own: bool = Content.abilities.has(v) and Content.units[actor.def].abilities.has(v)
		var ok: bool = (own and (not bonus or Slots.kind_of(Content.abilities[v]) == "bonus" or Content.abilities[v].has("bonusShare"))) or Content.consumable.has(v)
		return v if ok else bad
	var old: bool = not t.has("main") and not t.has("bonus")
	var main: Variant = slot.call(t.get("usedAbility") if old else t.get("main"), false)
	var bonus: Variant = null if old else slot.call(t.get("bonus"), true)
	if (old and not t.has("usedAbility")) or (not old and not t.has("main")) or (not old and not t.has("bonus")):
		return null
	if typeof(main) == TYPE_STRING and main == bad or typeof(bonus) == TYPE_STRING and bonus == bad:
		return null
	if typeof(raw.get("charges")) != TYPE_ARRAY or raw.charges.size() > MAX_UNITS:
		return null
	var charges: Array = []
	for c in raw.charges:
		if typeof(c) != TYPE_DICTIONARY or typeof(c.get("unit")) != TYPE_STRING or typeof(c.get("ability")) != TYPE_STRING or not _is_int(c.get("ticks")) or c.ticks < 1 or c.ticks > 99:
			return null
		var caster: Dictionary = {}
		for u in units:
			if u.id == c.unit:
				caster = u
		if caster.is_empty() or not Content.units[caster.def].abilities.has(c.ability):
			return null
		for x in charges:
			if x.unit == c.unit:
				return null
		var target: Variant = _pos(c.get("target"))
		if target == null or not grid.in_bounds(target):
			return null
		var follow: Variant = c.get("follow")
		if follow != null:
			if typeof(follow) != TYPE_STRING:
				return null
			var known := false
			for u in units:
				if u.id == follow:
					known = true
			if not known:
				return null
		charges.append({"unit": c.unit, "ability": c.ability, "target": target, "follow": follow, "ticks": c.ticks})
	var spent: Variant = t.get("spent")
	if spent != null and (not _is_int(spent) or spent < 0 or spent > 99):
		return null
	var engaged: Array = []
	var owed := func(list: Variant, this_turn: bool) -> bool:
		if list == null:
			return true
		if typeof(list) != TYPE_ARRAY or list.size() > MAX_UNITS * MAX_UNITS:
			return false
		for e in list:
			var uid: Variant = e.get("unit") if typeof(e) == TYPE_DICTIONARY else e
			var u: Dictionary = {}
			for x in units:
				if x.id == uid:
					u = x
			if u.is_empty():
				continue
			var keep := true
			if this_turn:
				keep = typeof(e) == TYPE_DICTIONARY and e.get("by") == actor.id and e.get("turns") != 1
			if keep and u.team != actor.team and not engaged.has(u.id):
				engaged.append(u.id)
		return true
	if not owed.call(t.get("engaged"), false) or not owed.call(raw.get("engaged"), true):
		return null
	var turn := {"actor": actor.id, "moved": t.moved, "main": main, "bonus": bonus}
	if spent != null:
		turn.spent = spent
	if engaged.size():
		turn.engaged = engaged
	var out := {"scenario": raw.scenario, "units": units, "rng": raw.rng, "turn": turn, "charges": charges, "outcome": raw.outcome, "turnsPlayed": raw.turnsPlayed}
	if raw.get("corpses") != null:
		if typeof(raw.corpses) != TYPE_ARRAY or raw.corpses.size() > grid.width * grid.height:
			return null
		var seen := {}
		var corpses: Array = []
		for c in raw.corpses:
			var p: Variant = _pos(c)
			if p == null or not grid.in_bounds(p) or cells.has(Grid.pos_key(p)):
				return null
			if not seen.has(Grid.pos_key(p)):
				corpses.append(p)
			seen[Grid.pos_key(p)] = true
		if corpses.size():
			out.corpses = corpses
		if typeof(raw.get("corpseDefs")) == TYPE_DICTIONARY:
			var defs := {}
			for k in raw.corpseDefs:
				var dv: Variant = raw.corpseDefs[k]
				if seen.has(k) and typeof(dv) == TYPE_STRING and Content.units.has(dv):
					defs[k] = dv
			if defs.size():
				out.corpseDefs = defs
	var bag: Variant = Bag.parse_bag(raw.get("bag"))
	var effects: Variant = Effects.parse_effects(raw.get("effects"), units)
	if bag == null or effects == null:
		return null
	if bag.size():
		out.bag = bag
	if effects.size():
		out.effects = effects
	return out
