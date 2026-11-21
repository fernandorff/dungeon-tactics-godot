class_name Bag
## Items in battle (port of bag.ts): the heroes' shared bag lives in the state, the Item command spends a slot like an
## ability, and every item reaches the user or an ally up to ITEM_RANGE whole tiles away. No die. The AI uses no items.

const BAG_MAX := 99


static func count(state: Dictionary, item: String) -> int:
	return state.get("bag", {}).get(item, 0)


## what using `item` on the unit at `target` does from `origin` (null: where the actor stands); {} when it cannot
static func item_effect(grid: Grid, state: Dictionary, id: String, item: String, target: Vector2i, origin: Variant = null) -> Dictionary:
	var actor := Combat.find_unit(state, id)
	if actor.is_empty() or not Content.consumable.has(item) or state.outcome != "ongoing" or count(state, item) < 1:
		return {}
	if state.turn.actor == id and Slots.free_slot(state.turn, "bonus") == "":
		return {}
	var u := Pathing.unit_at(state, target)
	if u.is_empty() or u.team != actor.team:
		return {}
	var moved: Dictionary = actor.duplicate()
	moved.pos = origin if origin != null else actor.pos
	var from := Pathing.footprint(moved)
	if u.id != id and Pathing.gap(from, Pathing.footprint(u)) > Reach.far_cells(grid, Content.data.item_range):
		return {}
	return _effect_on(Content.consumable[item], u)


static func _effect_on(c: Dictionary, u: Dictionary) -> Dictionary:
	var d: Dictionary = Content.units[u.def]
	var mana_max: int = d.get("vars", {}).get("mana", 0)
	return {
		"unit": u.id,
		"heal": maxi(0, mini(c.get("heal", 0), d.hp - u.hp)),
		"mana": maxi(0, mini(c.get("mana", 0), mana_max - Pools.pool_of(u, "mana"))) if mana_max else 0,
		"turns": c.get("buff", {}).get("turns", 0),
	}


static func apply_item(grid: Grid, state: Dictionary, id: String, item: String, target: Vector2i) -> Array:
	var fx := item_effect(grid, state, id, item, target)
	if fx.is_empty():
		return []
	var u := Combat.find_unit(state, fx.unit)
	var left := count(state, item) - 1
	var bag: Dictionary = state.get("bag", {}).duplicate()
	bag[item] = left
	if left <= 0:
		bag.erase(item)
	state.bag = bag
	u.hp += fx.heal
	if fx.mana:
		var v: Dictionary = u.get("vars", {}).duplicate()
		v.mana = Pools.pool_of(u, "mana") + fx.mana
		u.vars = v
	state.turn[Slots.free_slot(state.turn, "bonus")] = item
	var events: Array = [{"k": "item", "unit": id, "item": item, "target": target}]
	if fx.heal:
		events.append({"k": "heal", "unit": u.id, "amount": fx.heal})
	if fx.mana:
		events.append({"k": "mana", "unit": u.id, "amount": fx.mana})
	if fx.turns:
		Effects.add_effect(state, u.id, item)
		events.append({"k": "effect", "unit": u.id, "item": item, "turns": fx.turns})
	return events


## every item in the bag and whom it can reach this turn, walking first (the Agir list)
static func item_options(grid: Grid, state: Dictionary, id: String) -> Array:
	var actor := Combat.find_unit(state, id)
	if actor.is_empty() or state.outcome != "ongoing":
		return []
	var used: bool = state.turn.actor == id and Slots.free_slot(state.turn, "bonus") == ""
	var origins: Array = [] if used else Options.origins_of(grid, state, actor)
	var allies: Array = []
	for u in state.units:
		if u.team == actor.team and Content.units[u.def].speed > 0:
			allies.append(u)
	var out: Array = []
	for c in Content.consumables:
		var n := count(state, c.id)
		if n <= 0:
			continue
		if used:
			out.append({"item": c.id, "count": n, "enabled": false, "reason": "used", "targets": []})
			continue
		if origins.is_empty():
			out.append({"item": c.id, "count": n, "enabled": false, "reason": "water", "targets": []})
			continue
		var targets: Array = []
		for u in allies:
			var spots: Array = []
			for o in origins:
				var e := item_effect(grid, state, id, c.id, u.pos, o.pos)
				if not e.is_empty():
					spots.append({"pos": o.pos, "cost": o.cost, "effect": e})
			if spots.size():
				targets.append({"unit": u.id, "pos": u.pos, "spots": spots})
		var key := func(t: Dictionary) -> Array:
			return [0 if t.unit == id else 1, Grid.dist(actor.pos, t.pos)]
		targets = Util.stable_sort(targets, func(x: Dictionary, y: Dictionary) -> bool:
			var kx: Array = key.call(x)
			var ky: Array = key.call(y)
			return kx[0] < ky[0] or (kx[0] == ky[0] and kx[1] < ky[1]))
		if targets.size():
			out.append({"item": c.id, "count": n, "enabled": true, "targets": targets})
		else:
			out.append({"item": c.id, "count": n, "enabled": false, "reason": "no-target", "targets": []})
	return out


## trust boundary for a saved bag: known items, whole counts 0 to BAG_MAX; null on any doubt
static func parse_bag(raw: Variant) -> Variant:
	if raw == null:
		return {}
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var bag := {}
	for k in raw:
		var v: Variant = raw[k]
		if not Content.consumable.has(k) or typeof(v) != TYPE_INT or v < 0 or v > BAG_MAX:
			return null
		if v > 0:
			bag[k] = v
	return bag
