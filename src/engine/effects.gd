class_name Effects
## Timed effects from items (port of effects.ts): Fire oil and Stone potion change a unit's sheet for a few of its own turns.
## The state keeps only who, which item and the turns left; what each gives is the item's `buff`.


static func _buffs_of(state: Dictionary, id: String) -> Array:
	var out: Array = []
	for e in state.get("effects", []):
		if e.unit == id and Content.buffs.has(e.item):
			out.append(Content.buffs[e.item])
	return out


static func power_bonus(state: Dictionary, id: String) -> int:
	var s := 0
	for b in _buffs_of(state, id):
		s += b.get("physPower", 0)
	return s


static func resist_bonus(state: Dictionary, id: String, k: String) -> int:
	var s := 0
	for b in _buffs_of(state, id):
		s += b.get("resist", {}).get(k, 0)
	return s


## the element a martial hit of this unit takes (the last effect applied wins); "" for none
static func hit_element(state: Dictionary, id: String) -> String:
	var el := ""
	for b in _buffs_of(state, id):
		el = b.get("element", el)
	return el


## movement points this turn: the sheet's plus its effects' (x2 on the split map), never below 0
static func move_of(state: Dictionary, u: Dictionary) -> int:
	var d: Dictionary = Content.units[u.def]
	var scale := 2 if String(d.id).ends_with(Content.HALF) else 1
	var extra := 0
	for b in _buffs_of(state, u.id):
		extra += b.get("move", 0)
	return maxi(0, d.move + scale * extra)


static func add_effect(state: Dictionary, unit: String, item: String) -> void:
	if not Content.buffs.has(item):
		return
	var buff: Dictionary = Content.buffs[item]
	var rest: Array = []
	for e in state.get("effects", []):
		if not (e.unit == unit and e.item == item):
			rest.append(e)
	rest.append({"unit": unit, "item": item, "turns": buff.turns + (1 if unit == state.turn.actor else 0)})
	state.effects = rest


static func tick_effects(state: Dictionary, actor: String) -> void:
	if not state.has("effects"):
		return
	var left: Array = []
	for e in state.effects:
		var x: Dictionary = e.duplicate() if e.unit == actor else e
		if e.unit == actor:
			x.turns -= 1
		var alive := false
		for u in state.units:
			if u.id == x.unit:
				alive = true
				break
		if x.turns > 0 and alive:
			left.append(x)
	if left.is_empty():
		state.erase("effects")
	else:
		state.effects = left


## trust boundary for saved effects; null on any doubt
static func parse_effects(raw: Variant, units: Array) -> Variant:
	if raw == null:
		return []
	if typeof(raw) != TYPE_ARRAY or raw.size() > units.size() * Content.buffs.size():
		return null
	var out: Array = []
	for e in raw:
		if typeof(e) != TYPE_DICTIONARY:
			return null
		var unit: Variant = e.get("unit")
		var item: Variant = e.get("item")
		var turns: Variant = e.get("turns")
		if typeof(unit) != TYPE_STRING or typeof(item) != TYPE_STRING or not Content.buffs.has(item):
			return null
		var known := false
		for u in units:
			if u.id == unit:
				known = true
		if not known:
			return null
		for x in out:
			if x.unit == unit and x.item == item:
				return null
		if typeof(turns) != TYPE_INT or turns < 1 or turns > Content.buffs[item].turns + 1:
			return null
		out.append({"unit": unit, "item": item, "turns": turns})
	return out
