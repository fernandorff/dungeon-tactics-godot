class_name ActFlow
## "Agir primeiro" (port of act-flow.ts): Act lists the targets the unit can reach this turn by walking and then acting
## (enemies first, then allies, near to far; then the actions with no unit to aim at), then the actions that hit the
## picked target, then the tiles to stand on with the best one first. Pure: the screens draw it, the battle screen runs it.
## A target is {k: "unit", unit, pos} | {k: "direct", ability} | {k: "side", side: "foe"/"ally"}.
## An action is {k: "ability"/"item", id, enabled, reason?, missing?, pool?, count?, reach?, spots: [{pos, cost, aim,
## preview?, heal?, mana?}]}. A ref is {k, id}.

const GROUPS := ["skills", "magic", "items"]

static var _memo_b: Battle = null
static var _memo_key := 0
static var _memo: Dictionary = {}


## the engine's options for the acting unit, worked out once per battle state (the screens ask several times a key)
static func _options(b: Battle) -> Dictionary:
	var key := b.state.hash()
	if not is_same(_memo_b, b) or _memo_key != key:
		_memo_b = b
		_memo_key = key
		_memo = {"abilities": Options.action_options(b.grid, b.state, b.actor().id), "items": Bag.item_options(b.grid, b.state, b.actor().id)}
	return _memo


## main or secondary: an item is always secondary
static func act_kind(a: Dictionary) -> String:
	return "bonus" if a.k == "item" else Slots.kind_of(Content.abilities[a.id])


static func same_ref(a: Dictionary, r: Dictionary) -> bool:
	return (r.k == "ability" or r.k == "item") and r.k == a.k and r.id == a.id


static func _same_target(a: Dictionary, b: Dictionary) -> bool:
	return Util.diff(a, b) == ""


static func _flip(s: String) -> String:
	return "ally" if s == "foe" else "foe"


static func _unit_side(b: Battle, unit: String) -> String:
	return "ally" if Combat.find_unit(b.state, unit).get("team") == b.actor().team else "foe"


## the side an action is aimed at: damage at foes, heals (and every item) at allies, the rest at both ("")
static func side_of(r: Dictionary) -> String:
	if r.k == "item":
		return "ally"
	var a: Dictionary = Content.abilities[r.id]
	return "ally" if a.heal[1] > 0 or a.get("ally", false) else ("foe" if a.damage[1] > 0 else "")


static func _all_targets(b: Battle) -> Array:
	var id: String = b.actor().id
	var units := {}
	var direct: Array = []
	for o in _options(b).abilities:
		for t in o.targets:
			if t.kind == "unit" and t.get("unit"):
				units[t.unit] = t.pos
			elif t.kind == "self" and Content.abilities[o.ability].range[1] > 0:
				units[id] = t.pos
			elif not direct.any(func(d: Dictionary) -> bool: return d.ability == o.ability):
				direct.append({"k": "direct", "ability": o.ability})
	for o in _options(b).items:
		for t in o.targets:
			units[t.unit] = t.pos
	var me := b.actor()
	var rank := func(u: String) -> int:
		return 2 if u == id else (1 if Combat.find_unit(b.state, u).team == me.team else 0)
	var rows: Array = []
	for u in units:
		rows.append({"k": "unit", "unit": u, "pos": units[u]})
	rows = Util.stable_sort(rows, func(x: Dictionary, y: Dictionary) -> bool:
		var rx: int = rank.call(x.unit)
		var ry: int = rank.call(y.unit)
		return rx < ry if rx != ry else Grid.dist(me.pos, x.pos) < Grid.dist(me.pos, y.pos))
	return rows + direct


## the rows of the target list; `only`: an action picked on the Agir list keeps the targets it can hit this turn
static func act_targets(b: Battle, only: Dictionary = {}, other: bool = false) -> Array:
	var all := _all_targets(b)
	if only.is_empty():
		return all
	var hit: Array = all.filter(func(r: Dictionary) -> bool:
		return act_actions(b, r).any(func(a: Dictionary) -> bool: return same_ref(only, a) and a.enabled))
	var side := side_of(only)
	if side == "":
		return hit
	var own := func(r: Dictionary, s: String) -> bool:
		return _unit_side(b, r.unit) == s if r.k == "unit" else (r.k == "direct" and s == side)
	if not hit.any(func(r: Dictionary) -> bool: return own.call(r, side)):
		return hit
	var want := _flip(side) if other else side
	var rows: Array = hit.filter(func(r: Dictionary) -> bool: return own.call(r, want))
	if hit.any(func(r: Dictionary) -> bool: return own.call(r, _flip(want))):
		rows.append({"k": "side", "side": _flip(want)})
	return rows


## how far a unit is from the actor where it stands now, in cells
static func distance_to(b: Battle, unit: String) -> int:
	return Pathing.gap(Pathing.footprint(b.actor()), Pathing.footprint(Combat.find_unit(b.state, unit)))


static func _off(base: Dictionary, o: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.enabled = false
	out.reason = o.reason
	for k in ["missing", "pool"]:
		if o.has(k):
			out[k] = o[k]
	out.spots = []
	return out


## the actions for a target: every ability of the unit in its own order, then the items in the bag
static func act_actions(b: Battle, target: Dictionary) -> Array:
	return _cached(b, "actions " + str(target), func() -> Array: return _actions(b, target))


## a list worked out once per battle state, as the options (the Agir screens rebuild it on every key: ~100 ms)
static func _cached(b: Battle, key: String, make: Callable) -> Array:
	var m := _options(b)
	if not m.has(key):
		m[key] = make.call()
	return m[key]


static func _actions(b: Battle, target: Dictionary) -> Array:
	if target.k == "side":
		return []
	var id: String = b.actor().id
	var out: Array = []
	for o in _options(b).abilities:
		if target.k == "direct" and o.ability != target.ability:
			continue
		var base := {"k": "ability", "id": o.ability}
		if not o.enabled:
			out.append(_off(base, o))
			continue
		var area: bool = Content.abilities[o.ability].radius > 0
		var spots: Array = []
		for t in o.targets:
			var all: Array = []
			for s in t.spots:
				all.append({"pos": s.pos, "cost": s.cost, "aim": s.pos if t.kind == "self" else t.pos, "preview": s.preview})
			if target.k == "direct":
				if t.kind != "unit":
					spots.append_array(all)
			elif t.kind == "self" and target.unit == id:
				spots.append_array(all)
			elif t.kind == "unit" and t.get("unit") == target.unit:
				spots.append_array(all)
			elif area:
				# an area aimed at the ground, at another unit or at the user also hits the target
				for s in all:
					if s.preview.targets.any(func(x: Dictionary) -> bool: return x.unit == target.unit):
						spots.append(s)
		if spots.size():
			base.enabled = true
			base.spots = spots
		else:
			base.enabled = false
			base.reason = "range"
			base.spots = []
		out.append(base)
	if target.k == "direct":
		return out
	for o in _options(b).items:
		var base := {"k": "item", "id": o.item, "count": o.count}
		if not o.enabled:
			base.enabled = false
			base.reason = o.reason
			base.spots = []
			out.append(base)
			continue
		var found: Array = o.targets.filter(func(x: Dictionary) -> bool: return x.unit == target.unit)
		if found.is_empty():
			base.enabled = false
			base.reason = "no-target"
			base.spots = []
			out.append(base)
			continue
		var t: Dictionary = found[0]
		var spots: Array = []
		for s in t.spots:
			spots.append({"pos": s.pos, "cost": s.cost, "aim": t.pos, "heal": s.effect.heal, "mana": s.effect.mana})
		base.enabled = true
		base.spots = spots
		out.append(base)
	return out


## the group an action is listed under: "" for the basic attack (the unit's first ability)
static func group_of(b: Battle, r: Dictionary) -> String:
	if r.k == "item":
		return "items"
	if r.id == Counter.basic_of(b.actor().def):
		return ""
	return "magic" if Content.abilities[r.id].get("magic", false) else "skills"


## the Agir list: "Escolher alvo", the basic attack, then Técnicas, Magias and Itens (an empty one left out)
## rows: {k: "pick", enabled} | {k: "group", group, enabled, reach} | an action
static func act_list(b: Battle) -> Array:
	return _cached(b, "list", func() -> Array: return _list(b))


static func _list(b: Battle) -> Array:
	var rows := _act_rows(b)
	var out: Array = [{"k": "pick", "enabled": _all_targets(b).size() > 0}]
	for r in rows:
		if group_of(b, r) == "":
			out.append(r)
			break
	for g in GROUPS:
		var own: Array = rows.filter(func(r: Dictionary) -> bool: return group_of(b, r) == g)
		if own.is_empty():
			continue
		var seen := {}
		for r in own:
			if r.enabled:
				for t in act_targets(b, r):
					if t.k != "side":
						seen[JSON.stringify(Util.plain(t))] = true
		out.append({"k": "group", "group": g, "enabled": own.any(func(r: Dictionary) -> bool: return r.enabled), "reach": seen.size()})
	return out


## a group's column: its actions in the unit's order (the items in the bag's)
static func act_group(b: Battle, g: String) -> Array:
	return _act_rows(b).filter(func(r: Dictionary) -> bool: return group_of(b, r) == g)


static func _act_rows(b: Battle) -> Array:
	var hits: Array = []
	for t in _all_targets(b):
		hits.append({"t": t, "acts": act_actions(b, t)})
	var reach := func(r: Dictionary) -> int:
		var side := side_of(r)
		var n := 0
		for h in hits:
			if h.acts.any(func(a: Dictionary) -> bool: return same_ref(r, a) and a.enabled) and (side == "" or h.t.k != "unit" or _unit_side(b, h.t.unit) == side):
				n += 1
		return n
	var out: Array = []
	for o in _options(b).abilities:
		var base := {"k": "ability", "id": o.ability, "spots": []}
		if not o.enabled:
			out.append(_off(base, o))
		elif o.targets.size():
			base.enabled = true
			base.reach = reach.call(base)
			out.append(base)
		else:
			base.enabled = false
			base.reason = "range"
			out.append(base)
	for o in _options(b).items:
		var base := {"k": "item", "id": o.item, "count": o.count, "spots": []}
		if not o.enabled:
			base.enabled = false
			base.reason = o.reason
		elif o.targets.size():
			base.enabled = true
			base.reach = reach.call(base)
		else:
			base.enabled = false
			base.reason = "no-target"
		out.append(base)
	return out


## an ability aimed at more than one place first picks where it lands: its aims, in the engine's order
static func act_aims(a: Dictionary) -> Array:
	if a.k != "ability" or Content.abilities[a.id].range[1] == 0:
		return []
	var out: Array = []
	for s in a.spots:
		if not out.has(s.aim):
			out.append(s.aim)
	return out if out.size() > 1 else []


## an area on the free aim (Fernando, Nov 21: "snap on the chosen target first, then free on the grid"): every place it
## can land this turn, whoever it hits, not only where it hits the picked target
static func free_area(b: Battle, a: Dictionary) -> Dictionary:
	if a.k != "ability" or Content.abilities[a.id].radius == 0:
		return a
	var spots: Array = []
	for o in _options(b).abilities:
		if o.ability != a.id:
			continue
		for t in o.targets:
			for s in t.spots:
				spots.append({"pos": s.pos, "cost": s.cost, "aim": s.pos if t.kind == "self" else t.pos, "preview": s.preview})
	if spots.is_empty():
		return a
	var out := a.duplicate()
	out.spots = spots
	return out


static func with_aim(a: Dictionary, aim: Vector2i) -> Dictionary:
	var out := a.duplicate()
	out.spots = a.spots.filter(func(s: Dictionary) -> bool: return s.aim == aim)
	return out


## the spot picked first: allies out of the damage, then staying put, then the best expected result, then the shortest walk
static func best_spot(a: Dictionary, b: Battle) -> int:
	if a.spots.is_empty():
		return -1
	var team: String = b.actor().team
	var own := func(unit: String) -> bool: return Combat.find_unit(b.state, unit).get("team") == team
	var hurts := func(s: Dictionary) -> bool:
		return s.has("preview") and s.preview != null and s.preview.targets.any(func(t: Dictionary) -> bool: return own.call(t.unit) and t.dmgMax > 0)
	var score := func(s: Dictionary) -> float:
		if s.get("preview") == null:
			return float(s.get("heal", 0) + s.get("mana", 0))
		var sum := 0.0
		for t in s.preview.targets:
			var dmg: float = t.chance * (t.dmgMin + t.dmgMax) / 200.0
			var heal: float = (t.healMin + t.healMax) / 2.0
			sum += heal - dmg if own.call(t.unit) else dmg - heal
		return sum
	var best := 0
	for i in a.spots.size():
		var s: Dictionary = a.spots[i]
		var o: Dictionary = a.spots[best]
		var hs: bool = hurts.call(s)
		var ho: bool = hurts.call(o)
		var better: bool
		if hs != ho:
			better = not hs
		elif (s.cost == 0) != (o.cost == 0):
			better = s.cost == 0
		else:
			var ss: float = score.call(s)
			var so: float = score.call(o)
			better = ss > so or (ss == so and s.cost < o.cost)
		if better:
			best = i
	return best


## where the target list's cursor starts: the unit last picked when still listed, else the first row
static func target_index(rows: Array, last: Variant) -> int:
	if last == null:
		return 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		if last.k == "unit" and r.k == "unit" and r.unit == last.unit:
			return i
		if last.k == "direct" and r.k == "direct" and r.ability == last.ability:
			return i
	return 0


## the target row a tap on the map picks: the row of the unit on that tile
static func target_at(rows: Array, b: Battle, p: Vector2i) -> int:
	var on := Pathing.unit_at(b.state, p)
	if on.is_empty():
		return -1
	for i in rows.size():
		if rows[i].k == "unit" and rows[i].unit == on.id:
			return i
	return -1


## the spot a tap picks: the one whose tile (a token's square) holds the cell
static func spot_at(a: Dictionary, p: Vector2i, size: int) -> int:
	for i in a.spots.size():
		var s: Vector2i = a.spots[i].pos
		if p.x >= s.x and p.y >= s.y and p.x < s.x + size and p.y < s.y + size:
			return i
	return -1


## walk to the spot (when not already there), then act or use the item; act null when the walk was cut short
static func run_spot(b: Battle, a: Dictionary, s: Dictionary, lock: String = "", as_slot: String = "") -> Dictionary:
	var id: String = b.actor().id
	var walk: Array = [] if s.pos == b.actor().pos else b.move(s.pos)
	var me := Combat.find_unit(b.state, id)
	if b.over() or me.is_empty() or b.state.turn.actor != id or me.pos != s.pos:
		return {"walk": walk, "act": null}
	return {"walk": walk, "act": b.use_item(a.id, s.aim) if a.k == "item" else b.act(a.id, s.aim, lock, as_slot)}


## a dual action asks main or secondary on the tile choice only while both slots are free
static func needs_slot(b: Battle, a: Dictionary) -> bool:
	return a.k == "ability" and Content.abilities[a.id].has("bonusShare") and not b.state.turn.main and not b.state.turn.bonus


## what acting from `s` would do in `as_slot`: a dual action in the secondary slot at its share of the damage
static func spot_preview(b: Battle, a: Dictionary, s: Dictionary, as_slot: String = "") -> Variant:
	if a.k != "ability" or s.get("preview") == null:
		return s.get("preview")
	var ability: Dictionary = Content.abilities[a.id]
	var scale := Slots.slot_scale(ability, Slots.slot_for(b.state.turn, ability, as_slot))
	return s.preview if scale == 1.0 else Combat.preview(b.grid, b.state, b.actor().id, a.id, s.aim, false, s.pos, scale)
