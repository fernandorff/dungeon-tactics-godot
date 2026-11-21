class_name Equipment
## Equipment (port of equipment.ts): 7 slots, each piece adds general stats to the battle sheet, never a rule against a
## given ability. A loadout is {slot: item id}; the items live in data/content.json.

const SLOTS := ["main", "off", "head", "body", "legs", "acc1", "acc2"]
const STATS := ["hp", "physPower", "magPower", "hit", "dodge", "move", "jump", "speed", "mana", "stamina", "manaRegen", "hpRegen"]


## an accessory fits either accessory slot
static func kind_of(slot: String) -> String:
	return "accessory" if slot == "acc1" or slot == "acc2" else slot


## the piece worn in a slot; an unknown item or one of another kind does not count (the save is a trust boundary)
static func worn(loadout: Variant, slot: String) -> Dictionary:
	if typeof(loadout) != TYPE_DICTIONARY or not loadout.get(slot):
		return {}
	var it: Dictionary = Content.items.get(loadout[slot], {})
	return it if it.get("kind") == kind_of(slot) else {}


## sum of the pieces, raw: resist_of and dodge_of clamp the sheet's total once, where the battle reads it
static func bonus_of(loadout: Variant) -> Dictionary:
	var b := {"resist": {}}
	for k in STATS:
		b[k] = 0
	for s in SLOTS:
		var it := worn(loadout, s)
		if it.is_empty():
			continue
		for k in STATS:
			b[k] += it.get(k, 0)
		for k in it.get("resist", {}):
			b.resist[k] = b.resist.get(k, 0) + it.resist[k]
	return b


## the battle sheet with the pieces on; a stat with no piece stays as the class has it
static func with_gear(d: Dictionary, loadout: Variant) -> Dictionary:
	var b := bonus_of(loadout)
	var out := d.duplicate()
	var resist: Dictionary = d.get("resist", {}).duplicate()
	for k in b.resist:
		resist[k] = resist.get(k, 0) + b.resist[k]
	var vars: Dictionary = d.get("vars", {}).duplicate()
	var regen: Dictionary = d.get("regen", {}).duplicate()
	# a mana or stamina piece raises the pool's max; a class without that pool gets one
	for k in ["mana", "stamina"]:
		if b[k]:
			vars[k] = vars.get(k, 0) + b[k]
	# a mana regen with no pool to fill gives nothing
	if b.manaRegen and vars.get("mana", 0):
		regen.mana = regen.get("mana", 0) + b.manaRegen
	out.hp = d.hp + b.hp
	if b.speed:
		out.speed = maxi(1, d.speed + b.speed) # speed 0 never plays (turn_queue.gd)
	out.move = d.move + b.move
	if b.jump:
		out.jump = d.get("jump", Pathing.MAX_JUMP) + b.jump
	if resist.size():
		out.resist = resist
	for k in ["dodge", "physPower", "magPower", "hit", "hpRegen"]:
		if b[k]:
			out[k] = d.get(k, 0) + b[k]
	if vars.size():
		out.vars = vars
	if regen.size():
		out.regen = regen
	return out
