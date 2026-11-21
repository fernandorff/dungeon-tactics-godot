class_name EquipmentTests
## The pieces on the battle sheet (port of the first cases of tests/equipment.test.ts).


func _units() -> Dictionary:
	return Content.units


func test_seven_slots() -> String:
	var b := Equipment.bonus_of({"main": "iron_blade", "off": "buckler", "head": "iron_helm", "body": "chain_mail", "legs": "swift_boots", "acc1": "ember_ring", "acc2": "quick_charm"})
	var want := {"hp": 75, "physPower": 20, "magPower": 10, "hit": 5, "dodge": 15, "move": 1, "jump": 0, "speed": 1}
	for k in want:
		if b[k] != want[k]:
			return "%s %d, want %d" % [k, b[k], want[k]]
	return Util.diff(b.resist, {"phys": 40, "fire": 20}, "resist")


func test_wrong_pieces_do_not_count() -> String:
	var two := Equipment.bonus_of({"acc1": "ember_ring", "acc2": "ember_ring"})
	if two.magPower != 20 or two.resist.fire != 40:
		return "two rings"
	var none := Equipment.bonus_of({"main": "chain_mail", "off": "nada", "acc2": "buckler", "legs": "quick_charm"})
	for k in Equipment.STATS:
		if none[k] != 0:
			return "counted %s" % k
	return "" if none.resist.is_empty() else "counted a resist"


func test_with_gear() -> String:
	var u := _units()
	var d := Util.diff(Equipment.with_gear(u.warrior, {}), u.warrior, "bare")
	if d != "":
		return d
	var r := Equipment.with_gear(u.rogue, {"off": "buckler", "legs": "swift_boots", "acc1": "quick_charm", "acc2": "quick_charm"})
	if r.dodge != 40 or r.speed != u.rogue.speed + 2 or r.move != u.rogue.move + 1:
		return "rogue dodge %d speed %d move %d" % [r.dodge, r.speed, r.move]
	d = Util.diff(r.resist, {"phys": 10}, "rogue resist")
	if d != "":
		return d
	return "" if Equipment.with_gear(u.mage, {"body": "colossus_plate"}).move == u.mage.move - 1 else "negative move"


func test_pools_and_regen() -> String:
	var u := _units()
	var mage := Equipment.with_gear(u.mage, {"off": "worn_grimoire", "body": "warded_robe", "acc1": "sleepstone"})
	var d := Util.diff([mage.vars, mage.regen, mage.hpRegen], [{"mana": 70, "stamina": 30}, {"mana": 11, "stamina": 3}, 10], "mage")
	if d != "":
		return d
	if Equipment.with_gear(u.warrior, {"body": "colossus_plate", "acc1": "sleepstone", "acc2": "sleepstone"}).hpRegen != 30:
		return "hp regen"
	var archer := Equipment.with_gear(u.mage, {"off": "leather_quiver"})
	d = Util.diff([archer.vars, archer.regen], [{"mana": 30, "stamina": 50}, {"mana": 8, "stamina": 3}], "quiver")
	if d != "":
		return d
	var w := Equipment.with_gear(u.warrior, {"off": "worn_grimoire"})
	d = Util.diff([w.vars, w.regen], [{"stamina": 50, "mana": 50}, {"stamina": 5, "mana": 6}], "warrior grimoire")
	if d != "":
		return d
	var bare: Dictionary = u.warrior.duplicate()
	bare.vars = {"stamina": 50}
	bare.regen = {"stamina": 5}
	var helm := Equipment.with_gear(bare, {"head": "dawn_circlet"})
	d = Util.diff([helm.vars, helm.regen], [{"stamina": 50}, {"stamina": 5}], "no pool")
	if d != "":
		return d
	return Util.diff([u.mage.vars, u.mage.regen, u.mage.has("hpRegen")], [{"mana": 30, "stamina": 30}, {"mana": 8, "stamina": 3}, false], "class untouched")
