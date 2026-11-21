class_name Chest
## The party chest and each member's equipment (port of chest.ts): gold and loose pieces, equipment per member id.
## A chest is {gold, items: [id]}; an equip is {member id: {slot: item id}}. The saved values are a trust boundary.

const CHEST_KEY := "dt:chest"
const EQUIP_KEY := "dt:equip"
## the loose pieces the chest keeps: buying, unequipping and dismissing stop here instead of losing a piece on load
const CHEST_MAX := 99


static func parse_chest(raw: Variant) -> Dictionary:
	var r: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var g: Variant = r.get("gold")
	var gold: int = g if typeof(g) == TYPE_INT and g >= 0 and g <= 999999 else 0
	var items: Array = []
	if typeof(r.get("items")) == TYPE_ARRAY:
		for i in r.items:
			if typeof(i) == TYPE_STRING and Content.items.has(i) and items.size() < CHEST_MAX:
				items.append(i)
	return {"gold": gold, "items": items}


## New game writes it: each story member holds the common weapon of their class
static func starting_equip() -> Dictionary:
	var out := {}
	for id in Content.data.starting_weapon:
		out[id] = {"main": Content.data.starting_weapon[id]}
	return out


## every known piece goes to a slot of its own kind, the saved one first, else the first free one
static func parse_equip(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for base in raw:
		var l: Variant = raw[base]
		if typeof(base) != TYPE_STRING or typeof(l) != TYPE_DICTIONARY:
			continue
		var load := {}
		for key in l:
			var id: Variant = l[key]
			if typeof(id) != TYPE_STRING or not Content.items.has(id):
				continue
			var kind: String = Content.items[id].kind
			for s in [key] + Equipment.SLOTS:
				if Equipment.SLOTS.has(s) and Equipment.kind_of(s) == kind and not load.has(s):
					load[s] = id
					break
		out[base] = load
	return out


## only commons are sold; null without the gold or the room
static func buy(chest: Dictionary, id: String) -> Variant:
	var it: Dictionary = Content.items.get(id, {})
	if it.get("rarity") != "common" or chest.gold < it.price or chest.items.size() >= CHEST_MAX:
		return null
	return {"gold": chest.gold - it.price, "items": chest.items + [id]}


## half the price, as in the FFT shops; only what is in the chest
static func sell(chest: Dictionary, id: String) -> Variant:
	var i: int = chest.items.find(id)
	if i < 0:
		return null
	var items: Array = chest.items.duplicate()
	items.remove_at(i)
	return {"gold": chest.gold + Content.items[id].price / 2, "items": items}


## equips `id` (from the chest) in `slot` on member `base`, the old piece back to the chest; "" only unequips
static func equip(chest: Dictionary, eq: Dictionary, base: String, slot: String, id: String) -> Variant:
	if id != "" and (Content.items.get(id, {}).get("kind") != Equipment.kind_of(slot) or not chest.items.has(id)):
		return null
	var items: Array = chest.items.duplicate()
	if id != "":
		items.remove_at(items.find(id))
	var load: Dictionary = eq.get(base, {}).duplicate()
	if load.get(slot):
		items.append(load[slot])
	if items.size() > CHEST_MAX:
		return null
	if id != "":
		load[slot] = id
	else:
		load.erase(slot)
	var out := eq.duplicate()
	out[base] = load
	return {"chest": {"gold": chest.gold, "items": items}, "eq": out}
