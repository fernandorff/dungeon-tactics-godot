class_name GameTests
## The game around the battles (ports of tests/group, chest, saves and crawl-boot): party, chest, save slots and the
## expedition flow, on a memory-only store.


func _fresh() -> void:
	Store.reset_memory()


func test_party() -> String:
	var heroes := Party.heroes_for(Party.default_group(), {"warrior": {"main": "iron_blade"}})
	var names := heroes.map(func(u: Dictionary) -> String: return "%s:%s" % [u.name, u.base])
	var d := Util.diff(names, ["Bran:warrior", "Tess:archer", "Odo:mage", "Lia:rogue"], "heroes")
	if d != "":
		return d
	if Party.recruit(Party.default_group(), {"gold": Party.RECRUIT_COST - 1, "items": []}, "archer") != null:
		return "recruited without gold"
	var r: Dictionary = Party.recruit(Party.default_group(), {"gold": 500, "items": []}, "archer")
	if r.chest.gold != 300 or r.group.members.back().id != "r1" or r.group.deployed.size() != 4:
		return "recruit"
	var g: Dictionary = r.group
	while g.members.size() < Party.GROUP_MAX:
		g = Party.recruit(g, {"gold": 9999, "items": []}, "mage").group
	var seen := {}
	for m in g.members:
		seen[m.name] = true
	if seen.size() != Party.GROUP_MAX or Party.recruit(g, {"gold": 9999, "items": []}, "mage") != null:
		return "cap or names"
	var rg: Dictionary = Party.recruit(Party.default_group(), {"gold": 500, "items": []}, "rogue").group
	if Party.toggle_deploy(rg, "r1") != null:
		return "deployed a fifth"
	var swapped: Dictionary = Party.toggle_deploy(Party.toggle_deploy(rg, "archer"), "r1")
	d = Util.diff(Party.roster(swapped).map(func(m: Dictionary) -> String: return m.name), ["Bran", "Odo", "Lia", "Ivo", "Tess"], "roster")
	if d != "":
		return d
	var out: Dictionary = Party.dismiss(rg, {"r1": {"main": "iron_blade"}}, {"gold": 0, "items": []}, "r1")
	if out.chest.items != ["iron_blade"] or not out.eq.is_empty() or Party.dismiss(rg, {}, {"gold": 0, "items": []}, "warrior") != null:
		return "dismiss"
	var parsed := Party.parse_group({"members": [{"id": "warrior", "cls": "rogue"}, {"id": "r2", "name": "Ivo", "cls": "mage"}, {"id": "x", "name": "Hack", "cls": "mage"}, {"id": "r3", "name": "Zé", "cls": "brute"}], "deployed": ["r2", "r2", "nada", "warrior"]})
	d = Util.diff(parsed.members.map(func(m: Dictionary) -> String: return "%s:%s" % [m.id, m.cls]), ["warrior:rogue", "archer:archer", "mage:mage", "rogue:rogue", "r2:mage"], "parse")
	if d != "":
		return d
	return Util.diff(parsed.deployed, ["r2", "warrior"], "parse deployed")


func test_chest() -> String:
	if Chest.parse_chest({"gold": 1.5, "items": ["iron_blade", "nope", 3]}) != {"gold": 0, "items": ["iron_blade"]}:
		return "parse chest"
	var eq := Chest.parse_equip({"warrior": {"weapon": "iron_blade", "armor": "chain_mail", "x": "nope"}, "__proto__": {}})
	if eq.warrior != {"main": "iron_blade", "body": "chain_mail"}:
		return "old slots: %s" % eq.warrior
	if Chest.buy({"gold": 0, "items": []}, "iron_blade") != null:
		return "bought without gold"
	var c: Dictionary = Chest.buy({"gold": 1000, "items": []}, "iron_blade")
	if c.items != ["iron_blade"] or c.gold != 1000 - Content.items.iron_blade.price:
		return "buy"
	if Chest.sell(c, "iron_blade").gold != c.gold + Content.items.iron_blade.price / 2:
		return "sell"
	var e: Dictionary = Chest.equip(c, {}, "warrior", "main", "iron_blade")
	if e.eq.warrior.main != "iron_blade" or not e.chest.items.is_empty():
		return "equip"
	if Chest.equip(c, {}, "warrior", "head", "iron_blade") != null:
		return "wrong slot"
	var off: Dictionary = Chest.equip(e.chest, e.eq, "warrior", "main", "")
	return "" if off.chest.items == ["iron_blade"] and not off.eq.warrior.has("main") else "unequip"


func test_save_slots() -> String:
	_fresh()
	if not Saves.read_saves().slots.is_empty():
		return "nothing saved lists a slot"
	Store.set_key(Chest.CHEST_KEY, JSON.stringify({"gold": 50, "items": []}))
	Saves.new_game(1000)
	var m := Saves.read_saves()
	if m.slots.size() != 2 or m.active != 2 or Chest.parse_chest(Store.json(Chest.CHEST_KEY)).gold != 0:
		return "new game: %s" % m
	if Chest.parse_equip(Store.json(Chest.EQUIP_KEY)).warrior.main != "iron_blade":
		return "new game weapons"
	Store.set_key(Chest.CHEST_KEY, JSON.stringify({"gold": 9, "items": []}))
	Saves.load_slot(1)
	if Chest.parse_chest(Store.json(Chest.CHEST_KEY)).gold != 50:
		return "load slot 1"
	Saves.load_slot(2)
	if Chest.parse_chest(Store.json(Chest.CHEST_KEY)).gold != 9:
		return "slot 2 kept its game"
	var s := Saves.summary(Saves.read_saves().slots[1])
	if s.names != ["Bran", "Tess", "Odo", "Lia"] or s.gold != 9 or s.floor != null or s.leader != "warrior":
		return "summary %s" % s
	Saves.delete_slot(2)
	m = Saves.read_saves()
	if m.slots.size() != 1 or m.active != null or Store.get_key(Chest.CHEST_KEY) != "":
		return "delete active"
	var p := Saves.parse_manifest({"active": 9, "slots": [{"id": 0}, {"id": 3, "data": {"dt:chest": "x", "dt:lang": "en"}}, {"id": 3}]})
	return "" if p.active == null and p.slots == [{"id": 3, "data": {"dt:chest": "x"}}] else "manifest %s" % p


func _expedition(seed: int, max: int) -> Dictionary:
	var party: Array = []
	for id in Party.default_group().deployed:
		party.append({"id": id, "max": max})
	return Expedition.start(seed, party)


func test_room_carries_life() -> String:
	_fresh()
	var exp := _expedition(21, 250)
	exp.party[1].hp = 35
	Store.set_key(Saves.CRAWL_KEY, JSON.stringify(exp))
	var map := Expedition.map_of(21)
	var node: int = Expedition.open_nodes(map, [])[0]
	var room := CrawlFlow.room_scenario(map[node])
	var cast := CrawlFlow.cast_room(room, CrawlFlow.saved_expedition(), node)
	if cast.scenario.id != "%s-%d-d1-dungeon%s" % [CrawlGen.version(), map[node].seed, Content.HALF]:
		return "id %s" % cast.scenario.id
	var b := CrawlFlow.new_battle(cast.scenario, 5, cast.room)
	var hp := func(id: String) -> int: return Combat.find_unit(b.state, id).hp
	if hp.call("h1") != 35 or hp.call("h0") != 210 or hp.call("h2") != 120:
		return "carried life %d %d %d" % [hp.call("h0"), hp.call("h1"), hp.call("h2")]
	b.state.units = b.state.units.filter(func(u: Dictionary) -> bool: return u.team == "hero" and u.id != "h3")
	CrawlFlow.settle_room(cast.room, true, b.state)
	var after: Dictionary = CrawlFlow.saved_expedition()
	var d := Util.diff([after.path, after.party.map(func(h: Dictionary) -> int: return h.hp)], [[node], [250, 98, 183, 63]], "after")
	if d != "":
		return d
	if CrawlFlow.settle_room(cast.room, false, b.state) != null:
		return "settled a closed room"
	var r2: Dictionary = cast.room.duplicate()
	r2.node = Expedition.open_nodes(map, [node])[0]
	CrawlFlow.settle_room(r2, false, b.state)
	return "" if CrawlFlow.saved_expedition() == null else "a defeat kept the expedition"


func test_left_room_and_gold() -> String:
	_fresh()
	var map := Expedition.map_of(21)
	var exp := _expedition(21, 20)
	while true:
		var open := Expedition.open_nodes(map, exp.path)
		if map[open[0]].boss:
			break
		var chest: Array = open.filter(func(i: int) -> bool: return map[i].chest)
		exp = Expedition.open_chest(exp, chest[0]) if chest.size() else Expedition.win_room(exp, open[0], {})
	Store.set_key(Saves.CRAWL_KEY, JSON.stringify(exp))
	Store.set_key(Chest.CHEST_KEY, JSON.stringify({"gold": 7, "items": []}))
	var found := Expedition.descent_gold(exp)
	var boss: int = Expedition.open_nodes(map, exp.path)[0]
	var won: Dictionary = CrawlFlow.settle_room({"node": boss, "heroes": {}}, true, {"units": [], "bag": {}})
	if not won.done or won.gold.banked != found + 300 or Chest.parse_chest(Store.json(Chest.CHEST_KEY)).gold != 7 + found + 300:
		return "boss gold %s" % won.gold
	Store.set_key(Saves.CRAWL_KEY, JSON.stringify(exp))
	Store.set_key(Saves.ROOM_KEY, "room in play")
	if CrawlFlow.left_room() != found / 2 or CrawlFlow.saved_expedition() != null or CrawlFlow.left_room() != -1:
		return "left room"
	return ""


func test_boss_room() -> String:
	_fresh()
	var map := Expedition.map_of(33)
	var exp := _expedition(33, 20)
	while not map[Expedition.open_nodes(map, exp.path)[0]].boss:
		exp.path = exp.path + [Expedition.open_nodes(map, exp.path)[0]]
	Store.set_key(Saves.CRAWL_KEY, JSON.stringify(exp))
	var node: int = Expedition.open_nodes(map, exp.path)[0]
	var cast := CrawlFlow.cast_room(CrawlFlow.room_scenario(map[node]), CrawlFlow.saved_expedition(), node)
	var b := CrawlFlow.new_battle(cast.scenario, 3, cast.room)
	var sizes: Array = []
	var hps: Array = []
	for u in b.state.units:
		if u.team == "enemy":
			sizes.append(Content.units[u.def].get("size"))
		else:
			hps.append(u.hp)
	if sizes != [4, 2] or hps != [20, 20, 20, 20]:
		return "boss room %s %s" % [sizes, hps]
	var loaded := Battle.load_save(b.save())
	return "" if loaded != null and loaded.state.scenario == cast.scenario.id else "boss save"


## a whole battle where the heroes play through the Agir screens (first target, first action on, the spot picked first)
## and the menu's own reads never fail; the enemies play the AI
func test_heroes_play_through_the_menu() -> String:
	var sc := Half.halve(Content.scenarios[Content.data.first_battle])
	var b := Battle.start(sc, 9)
	var turns := 0
	while not b.over() and turns < 300:
		turns += 1
		if b.actor().team != "hero":
			Ai.play_turn(b)
			continue
		var rows := Command.menu_rows(b)
		if not rows.has("act") or Command.start_screen(b).k != "menu":
			return "menu rows %s" % [rows]
		Interaction.highlights(b, Interaction.fresh_ui(b))
		var acted := false
		for t in ActFlow.act_targets(b):
			for a in ActFlow.act_actions(b, t):
				if a.enabled and not acted:
					var s: Dictionary = a.spots[ActFlow.best_spot(a, b)]
					var lock := "unit" if Command.needs_lock(b, a.id, s.aim) else ""
					var r := ActFlow.run_spot(b, a, s, lock)
					if r.act != null and r.act.is_empty():
						return "turn %d: %s from %s did nothing" % [turns, a.id, s.pos]
					acted = true
			if acted:
				break
		if not b.over() and b.state.turn.actor == b.actor().id:
			Interaction.facing_highlights(b)
			Command.cancel_step(b, {"k": "facing"})
			b.end_turn()
	return "" if b.over() else "no end in 300 turns"


## Agir stays on the menu with both actions spent, greyed like a spent Move (Fernando, Nov 21)
func test_act_greys_out_when_spent() -> String:
	var b := Battle.start(Half.halve(Content.scenarios[Content.data.first_battle]), 9)
	if not Command.enabled(b, "act"):
		return "Agir greyed with both actions free"
	b.state.turn.main = "strike"
	if not Command.enabled(b, "act"):
		return "Agir greyed with the bonus still free"
	b.state.turn.bonus = "ether"
	if Command.enabled(b, "act") or not Command.menu_rows(b).has("act"):
		return "Agir must stay, greyed, with no action left"
	return ""
