class_name CrawlFlow
## The expedition around the battles (port of game/crawl.ts, boot.ts newBattle and room-end.ts settleRoom): depart from
## town, cast a room with the party's life and mana, settle it after the battle, bank the gold when the descent ends.
## A room in play is {node, heroes: {spawn id: {id, hp, mana?}}, bag?}.


static func group() -> Dictionary:
	return Party.parse_group(Store.json(Party.GROUP_KEY))


static func _crawlers(ids: Array) -> Array:
	var g := group()
	g.deployed = ids
	return Party.heroes_for(g, Chest.parse_equip(Store.json(Chest.EQUIP_KEY)))


## the mana pool of a crawler's battle sheet (its class's with its pieces); 0 without one
static func _mana_of(u: Dictionary) -> int:
	return Equipment.with_gear(Content.units[u.base], u.get("items")).get("vars", {}).get("mana", 0)


static func _in_group(exp: Dictionary) -> Dictionary:
	var g := group()
	var ids: Array = []
	for h in exp.party:
		if not Party.member(g, h.id).is_empty():
			ids.append(h.id)
	return {"ids": ids, "units": _crawlers(ids)}


## read with each hero's mana pool as its class and pieces have it now
static func saved_expedition() -> Variant:
	var exp: Variant = Expedition.parse(Store.json(Saves.CRAWL_KEY))
	if exp == null:
		return null
	var ig := _in_group(exp)
	var by := {}
	for i in ig.ids.size():
		by[ig.ids[i]] = _mana_of(ig.units[i])
	return Expedition.class_mana(exp, by)


## the expedition in progress: saved and its boss not yet down
static func live_expedition() -> Variant:
	var exp: Variant = saved_expedition()
	if exp == null or Expedition.cleared(Expedition.map_of(exp.seed), exp.path):
		return null
	return exp


## the descent ends: its gold goes to the town's and the save is cleared in the same step
static func end_expedition(exp: Dictionary, fell: bool) -> int:
	var chest := Chest.parse_chest(Store.json(Chest.CHEST_KEY))
	var gold := Expedition.gold_home(exp, fell)
	chest.gold = mini(999999, chest.gold + gold)
	Store.set_key(Chest.CHEST_KEY, JSON.stringify(chest))
	Store.set_key(Saves.CRAWL_KEY, "")
	return gold


## back to town alive: the gold goes home whole, once
static func retreat(exp: Dictionary) -> int:
	var live: Variant = live_expedition()
	return end_expedition(live, false) if live != null and live.seed == exp.seed else 0


static func take_chest(node: int) -> Variant:
	var now: Variant = live_expedition()
	if now == null:
		return null
	var next := Expedition.open_chest(now, node)
	if is_same(next, now):
		return null
	Store.set_key(Saves.CRAWL_KEY, JSON.stringify(next))
	return next


## a new expedition with the town's party (up to 4), each at full life with its equipment; a live one ends alive first
static func depart(seed: int) -> Dictionary:
	var live: Variant = live_expedition()
	if live != null:
		retreat(live)
	var g := group()
	var units := _crawlers(g.deployed)
	var party: Array = []
	for k in g.deployed.size():
		party.append({"id": g.deployed[k], "max": units[k].hp + Equipment.bonus_of(units[k].get("items")).hp, "manaMax": _mana_of(units[k])})
	var exp := Expedition.start(seed, party)
	Store.set_key(Saves.CRAWL_KEY, JSON.stringify(exp))
	Store.set_key(Saves.ROOM_KEY, "")
	return exp


## the party left a saved room before it ended: that loses the expedition like a defeat; the gold that went home, or -1
static func left_room() -> int:
	var exp: Variant = saved_expedition()
	if exp == null or Store.get_key(Saves.ROOM_KEY) == "":
		return -1
	Store.set_key(Saves.ROOM_KEY, "")
	return end_expedition(exp, true)


## the room's whole-tile scenario, built from its seed (a seed that fails moves on to the next one)
static func room_scenario(node: Dictionary) -> Dictionary:
	for s in [node.seed, node.seed + 1]:
		var built := CrawlGen.build_room(s, {"depth": node.floor, "boss": node.boss})
		if not built.is_empty():
			var sc: Dictionary = built.room
			Content.scenarios[sc.id] = sc
			return sc
	return {}


## the room with the party on its hero spawns and the enemies as sheets of their own; {scenario (half tiles), room}
static func cast_room(room: Dictionary, exp: Dictionary, node: int) -> Dictionary:
	var ig := _in_group(exp)
	var enemies: Array = []
	for s in Roster.slots_of(room.id).enemy:
		enemies.append(Roster.unit_from(s.def))
	var sc := Roster.build_scenario({"map": room.id, "heroes": ig.units, "enemies": enemies}, room.id, [room.name, room.en])
	var heroes := {}
	for i in ig.ids.size():
		var id: String = ig.ids[i]
		var saved: Dictionary = exp.party.filter(func(h: Dictionary) -> bool: return h.id == id)[0]
		# never above the sheet's life: the save is read from disk
		var h := {"id": id, "hp": mini(saved.hp, ig.units[i].hp + Equipment.bonus_of(ig.units[i].get("items")).hp)}
		if saved.has("mana"):
			h.mana = saved.mana
		heroes["h%d" % i] = h
	var r := {"node": node, "heroes": heroes}
	if exp.has("bag"):
		r.bag = exp.bag.duplicate()
	return {"scenario": Half.halve(sc), "room": r}


## a new battle with the party's life and mana carried in (stamina starts full in every room)
static func new_battle(scenario: Dictionary, seed: int, room: Variant = null) -> Battle:
	var b := Battle.start(scenario, seed)
	if room != null:
		for u in b.state.units:
			var h: Dictionary = room.heroes.get(u.id, {})
			if h.is_empty():
				continue
			u.hp = h.hp if h.hp else u.hp
			if h.has("mana") and Content.units[u.def].get("vars", {}).get("mana", 0):
				var vars: Dictionary = u.get("vars", {}).duplicate()
				vars.mana = h.mana
				u.vars = vars
		if room.get("bag", {}).size():
			b.state.bag = room.bag.duplicate()
	# the first to act got its regen on the full pool: again on the carried ones
	Combat.regen(b.actor())
	return b


## after a room: a victory carries the life on, a defeat or the last boss down ends the expedition (gold banked)
static func settle_room(room: Dictionary, won: bool, state: Dictionary) -> Variant:
	var exp: Variant = saved_expedition()
	Store.set_key(Saves.ROOM_KEY, "")
	if exp == null:
		return null
	var map := Expedition.map_of(exp.seed)
	if not Expedition.open_nodes(map, exp.path).has(room.node):
		return null
	var left := {}
	var mana_left := {}
	for spawn in room.heroes:
		var u := Combat.find_unit(state, spawn)
		if not u.is_empty():
			left[room.heroes[spawn].id] = u.hp
			mana_left[room.heroes[spawn].id] = Combat.pool_of(u, "mana")
	var next: Variant = Expedition.win_room(exp, room.node, left, mana_left, state.get("bag", {}).duplicate()) if won else null
	var done: bool = next != null and Expedition.cleared(map, next.path)
	var banked := 0
	if next == null:
		banked = end_expedition(exp, true)
	elif done:
		banked = end_expedition(next, false)
	else:
		Store.set_key(Saves.CRAWL_KEY, JSON.stringify(next))
	var n: Dictionary = map[room.node]
	var down: bool = n.next.any(func(i: int) -> bool: return map[i].floor > n.floor)
	var gold := {"room": Expedition.node_gold(n) if next != null else 0, "found": Expedition.descent_gold(next if next != null else exp), "banked": banked}
	return {"next": next, "done": done, "map": map, "node": n, "gold": gold, "down": down}
