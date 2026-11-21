class_name CrawlTests
## The expedition rules (port of tests/crawl-expedition.test.ts): heals between rooms, the floor heal, mana, chests and
## the save's trust boundary. A test returns "" when it passes, else what failed.

const PARTY := [{"id": "bran", "max": 42}, {"id": "odo", "max": 24}]


func _first(e: Dictionary) -> int:
	return Expedition.open_nodes(Expedition.map_of(e.seed), e.path)[0]


func _at(e: Dictionary, hp: Array) -> Dictionary:
	var out := e.duplicate()
	var party: Array = []
	for i in e.party.size():
		var h: Dictionary = e.party[i].duplicate()
		h.hp = hp[i]
		party.append(h)
	out.party = party
	return out


func _hps(e: Dictionary) -> Array:
	return e.party.map(func(h: Dictionary) -> int: return h.hp)


func _down(map: Array, e: Dictionary) -> bool:
	var n: Dictionary = map[_first(e)]
	return n.next.any(func(i: int) -> bool: return map[i].floor > n.floor)


func _check(got: Variant, want: Variant, what: String) -> String:
	return Util.diff(got, want, what)


func test_room_heal() -> String:
	var e := _at(Expedition.start(3, PARTY), [20, 24])
	var node := _first(e)
	var next := Expedition.win_room(e, node, {"bran": 20})
	var d := _check(next.party, [{"id": "bran", "max": 42, "hp": 31}, {"id": "odo", "max": 24, "hp": 6}], "fell")
	if d != "":
		return d
	d = _check(_hps(Expedition.win_room(_at(e, [40, 24]), node, {"bran": 40, "odo": 24})), [42, 24], "cap")
	if d != "":
		return d
	var odd := Expedition.start(3, [{"id": "tess", "max": 41}])
	var hurt := odd.duplicate()
	hurt.party = [{"id": "tess", "max": 41, "hp": 20}]
	if Expedition.win_room(hurt, node, {"tess": 20}).party[0].hp != 31:
		return "41 max: 20 + 25% should be 31"
	return "" if Expedition.win_room(odd, node, {}).party[0].hp == 11 else "41 max fallen should be 11"


func test_floor_heal_and_boss() -> String:
	var map := Expedition.map_of(9)
	var e := Expedition.start(9, PARTY)
	while not _down(map, e):
		e = Expedition.win_room(e, _first(e), {"bran": 42, "odo": 24})
	e = _at(e, [10, 24])
	var down := Expedition.win_room(e, _first(e), {"bran": 10})
	var d := _check(_hps(down), [42, 18], "down")
	if d != "":
		return d
	var mid := Expedition.win_room(_at(down, [10, 10]), _first(down), {"bran": 10, "odo": 10})
	d = _check(_hps(mid), [21, 16], "mid")
	if d != "":
		return d
	var end := mid
	while not Expedition.cleared(map, end.path):
		end = Expedition.win_room(end, _first(end), {"bran": 1, "odo": 1})
	d = _check(_hps(end), [12, 7], "boss")
	if d != "":
		return d
	var r := Expedition.run()
	return "" if end.path.size() == r.floors * r.rows + 1 else "path length %d" % end.path.size()


func test_mana() -> String:
	var map := Expedition.map_of(9)
	var e := Expedition.start(9, [{"id": "mia", "max": 30, "manaMax": 60}, {"id": "bran", "max": 42}])
	var d := _check(e.party, [{"id": "mia", "max": 30, "hp": 30, "manaMax": 60, "mana": 60}, {"id": "bran", "max": 42, "hp": 42}], "start")
	if d != "":
		return d
	var room := Expedition.win_room(e, _first(e), {"mia": 30, "bran": 42}, {"mia": 10})
	if room.party[0].mana != 25 or room.party[1].has("mana"):
		return "room mana"
	if Expedition.win_room(e, _first(e), {"bran": 42}, {}).party[0].mana != 15:
		return "fallen mana"
	while not _down(map, e):
		e = Expedition.win_room(e, _first(e), {"mia": 30, "bran": 42}, {"mia": 60})
	if Expedition.win_room(e, _first(e), {"mia": 30, "bran": 42}, {"mia": 0}).party[0].mana != 45:
		return "down mana"
	return _check(Expedition.parse(Util.ints(JSON.parse_string(JSON.stringify(room)))), room, "save")


func test_class_mana() -> String:
	var e := Expedition.start(9, [{"id": "mia", "max": 30, "manaMax": 60}, {"id": "bran", "max": 42}])
	var to_mage := Expedition.class_mana(e, {"mia": 0, "bran": 60})
	var d := _check(to_mage.party, [{"id": "mia", "max": 30, "hp": 30}, {"id": "bran", "max": 42, "hp": 42, "manaMax": 60, "mana": 60}], "swap")
	if d != "":
		return d
	var room := Expedition.win_room(to_mage, _first(to_mage), {"mia": 30, "bran": 42}, {"bran": 4})
	if Expedition.class_mana(room, {"mia": 0, "bran": 60}).party[1].mana != 19:
		return "carried mana"
	d = _check(Expedition.class_mana(room, {}), room, "missing member")
	if d != "":
		return d
	var old: Dictionary = Expedition.parse(Expedition.start(9, [{"id": "odo", "max": 24}]))
	return _check(Expedition.class_mana(old, {"odo": 60}).party[0], {"id": "odo", "max": 24, "hp": 24, "manaMax": 60, "mana": 60}, "old save")


func test_bad_saves() -> String:
	var old := Expedition.start(8, PARTY)
	if Expedition.parse(old).party[0].has("mana"):
		return "old save got mana"
	var hero := {"id": "mia", "max": 30, "hp": 30}
	for extra in [{"mana": 5}, {"manaMax": 60, "mana": 61}, {"manaMax": 60, "mana": -1}, {"hp": 0}, {"max": 1000, "hp": 5}]:
		var bad := hero.merged(extra, true)
		var raw := old.duplicate()
		raw.party = [bad]
		if Expedition.parse(raw) != null:
			return "accepted %s" % bad
	for raw in [null, 5, {}, old.merged({"v": "x"}, true), old.merged({"path": [99]}, true), old.merged({"party": []}, true), old.merged({"bag": {"nope": 1}}, true)]:
		if Expedition.parse(raw) != null:
			return "accepted %s" % str(raw).left(80)
	return ""


func test_not_open() -> String:
	var e := Expedition.start(4, PARTY)
	var map := Expedition.map_of(4)
	var once := Expedition.win_room(e, _first(e), {"bran": 42, "odo": 24})
	if not is_same(Expedition.win_room(once, once.path[0], {"bran": 42, "odo": 24}), once):
		return "won a cleared room"
	var far := -1
	for i in map.size():
		if map[i].floor == 2:
			far = i
			break
	return "" if is_same(Expedition.win_room(e, far, {}), e) else "won a room off the path"


func test_chests() -> String:
	var r := Expedition.run()
	for seed in 50:
		var map := Expedition.map_of(seed)
		for f in range(1, r.floors + 1):
			var chests: Array = []
			var first_row: Array = []
			var second: Array = []
			for i in map.size():
				var n: Dictionary = map[i]
				if n.floor != f:
					continue
				if n.chest:
					chests.append(i)
				elif n.row == 0:
					first_row.append(i)
				if n.row == 1:
					second.append(i)
			if chests.size() != 1:
				return "seed %d floor %d: %d chests" % [seed, f, chests.size()]
			if first_row.filter(func(i: int) -> bool: return map[i].next.has(chests[0])).size() != 1:
				return "seed %d floor %d: chest not off one room" % [seed, f]
			if map[chests[0]].next != second:
				return "seed %d floor %d: chest leads elsewhere" % [seed, f]
	var map := Expedition.map_of(6)
	var c := -1
	for i in map.size():
		if map[i].chest:
			c = i
			break
	var from := -1
	for i in map.size():
		if map[i].next.has(c):
			from = i
			break
	var e := _at(Expedition.start(6, PARTY), [20, 24])
	if not is_same(Expedition.open_chest(e, c), e):
		return "opened a closed chest"
	e = Expedition.win_room(e, from, {"bran": 20, "odo": 24})
	if not is_same(Expedition.win_room(e, c, {"bran": 20, "odo": 24}), e):
		return "won a chest as a room"
	if not is_same(Expedition.open_chest(e, _first(e)), e):
		return "opened a room as a chest"
	var opened := Expedition.open_chest(e, c)
	if opened.path != [from, c] or opened.party != e.party:
		return "chest path or party"
	var item := Expedition.chest_item(map[c])
	if opened.bag.get(item, 0) != e.bag.get(item, 0) + 1:
		return "chest item not in the bag"
	return _check(Expedition.parse(Util.ints(JSON.parse_string(JSON.stringify(opened)))), opened, "chest save")


func test_gold_home() -> String:
	var map := Expedition.map_of(1)
	var e := Expedition.start(1, PARTY)
	for i in 3:
		e = Expedition.win_room(e, _first(e), {"bran": 42, "odo": 24})
	var sum := 0
	for n in e.path:
		sum += Expedition.node_gold(map[n])
	if Expedition.descent_gold(e) != sum or Expedition.gold_home(e, false) != sum:
		return "gold alive"
	return "" if Expedition.gold_home(e, true) == sum / 2 else "gold fell"
