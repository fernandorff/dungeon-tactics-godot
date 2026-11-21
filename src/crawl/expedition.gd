class_name Expedition
## The dungeon crawl's expedition (port of expedition.ts): floors of short rooms in a small graph, the party's life and
## mana carried from room to room. Only the seed, the rooms cleared, the party and the bag are saved; the map comes back
## from the seed. An expedition is {v, seed, path, party: [{id, max, hp, manaMax?, mana?}], bag}.


static func run() -> Dictionary:
	return Content.data.crawl.run


## the nodes: [{floor, row, seed, boss, chest, next}]
static func map_of(seed: int) -> Array:
	var s := CrawlGen._Stream.new(Util.i32(seed))
	var r := run()
	var nodes: Array = []
	var prev: Array = []
	var detour: Array = []
	for floor in range(1, r.floors + 1):
		var rows: int = r.rows + (1 if floor == r.floors else 0)
		for row in rows:
			var boss: bool = row == r.rows
			var n := 1 if boss else s.int_in(r.width[0], r.width[1])
			var ids: Array = []
			for k in n:
				ids.append(nodes.size() + k)
			for p in prev:
				nodes[p].next = ids.duplicate()
			if detour.size():
				nodes[detour[0]].next.append(detour[1])
			detour = []
			for _i in ids:
				nodes.append({"floor": floor, "row": row, "seed": s.int_in(0, 2147483647), "boss": boss, "chest": false, "next": []})
			prev = ids
			if row == 0 and r.rows > 1:
				detour = [ids[s.int_in(0, ids.size() - 1)], nodes.size()]
				nodes.append({"floor": floor, "row": row, "seed": s.int_in(0, 2147483647), "boss": false, "chest": true, "next": []})
				prev = ids + [nodes.size() - 1]
	return nodes


static func open_nodes(map: Array, path: Array) -> Array:
	if path.size():
		return map[path.back()].next
	var out: Array = []
	for i in map.size():
		var n: Dictionary = map[i]
		if n.floor == 1 and n.row == 0 and not n.chest:
			out.append(i)
	return out


static func cleared(map: Array, path: Array) -> bool:
	return path.size() > 0 and map[path.back()].next.is_empty()


## party: [{id, max, manaMax?}]
static func start(seed: int, party: Array) -> Dictionary:
	var members: Array = []
	for h in party:
		var m := {"id": h.id, "max": h.max, "hp": h.max}
		if h.get("manaMax", 0):
			m.manaMax = h.manaMax
			m.mana = h.manaMax
		members.append(m)
	return {"v": CrawlGen.version(), "seed": Util.i32(seed), "path": [], "bag": Content.data.start_bag.duplicate(), "party": members}


## the mana pool each hero's class and pieces give now (`max` by member id): a new max enters full once
static func class_mana(exp: Dictionary, max_by: Dictionary) -> Dictionary:
	var out := exp.duplicate()
	var party: Array = []
	for h in exp.party:
		var m: int = max_by.get(h.id, h.get("manaMax", 0))
		var n := {"id": h.id, "max": h.max, "hp": h.hp}
		if m:
			n.manaMax = m
			n.mana = h.get("mana", m) if m == h.get("manaMax", 0) else m
		party.append(n)
	out.party = party
	return out


static func _share(max: int, pct: int) -> int:
	return Util.ceil_div(max * pct, 100)


## after a won room: `left` = each standing hero's life by member id (missing = fell); `mana_left` likewise; `bag_left` the
## bag at the end (null: as it went in)
static func win_room(exp: Dictionary, node: int, left: Dictionary, mana_left: Dictionary = {}, bag_left: Variant = null) -> Dictionary:
	var map := map_of(exp.seed)
	if not open_nodes(map, exp.path).has(node) or map[node].chest:
		return exp
	var down := false
	for n in map[node].next:
		if map[n].floor > map[node].floor:
			down = true
	var r := run()
	var carry := func(now: int, max: int, stood: bool) -> int:
		return mini(max, (now + _share(max, r.roomHeal) if stood else _share(max, r.fallen)) + (_share(max, r.floorHeal) if down else 0))
	var out := exp.duplicate()
	out.path = exp.path + [node]
	if bag_left != null:
		out.bag = bag_left
	var party: Array = []
	for h in exp.party:
		var stood := left.has(h.id)
		var n: Dictionary = h.duplicate()
		n.hp = carry.call(left.get(h.id, 0), h.max, stood)
		if h.get("manaMax", 0):
			n.mana = carry.call(mana_left.get(h.id, h.get("mana", h.manaMax)), h.manaMax, stood)
		party.append(n)
	out.party = party
	return out


static func open_chest(exp: Dictionary, node: int) -> Dictionary:
	var map := map_of(exp.seed)
	if not open_nodes(map, exp.path).has(node) or not map[node].chest:
		return exp
	var item := chest_item(map[node])
	var out := exp.duplicate()
	out.path = exp.path + [node]
	var bag: Dictionary = exp.get("bag", {}).duplicate()
	bag[item] = bag.get(item, 0) + 1
	out.bag = bag
	return out


static func chest_item(n: Dictionary) -> String:
	var r := Rng.roll_int(Util.i32(n.seed ^ 0x17e3), 0, Content.consumables.size() - 1)
	return Content.consumables[r[0]].id


static func node_gold(n: Dictionary) -> int:
	var s := CrawlGen._Stream.new(Util.i32(n.seed ^ 0x601d))
	if n.chest:
		return s.int_in(run().chest[0], run().chest[1])
	var group: Dictionary = CrawlGen.room_group(n.seed, {"depth": n.floor, "boss": n.boss}).group
	var sum := 0
	for e in group.enemies:
		if Content.data.crawl.gold.has(e):
			var g: Array = Content.data.crawl.gold[e]
			sum += s.int_in(g[0], g[1])
	return sum


static func descent_gold(exp: Dictionary) -> int:
	var map := map_of(exp.seed)
	var sum := 0
	for n in exp.path:
		sum += node_gold(map[n])
	return sum


static func gold_home(exp: Dictionary, fell: bool) -> int:
	return descent_gold(exp) / 2 if fell else descent_gold(exp)


## trust boundary (the crawl save): rebuilt field by field; null on any doubt
static func parse(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	if raw.get("v") != CrawlGen.version() or typeof(raw.get("seed")) != TYPE_INT or typeof(raw.get("path")) != TYPE_ARRAY or typeof(raw.get("party")) != TYPE_ARRAY:
		return null
	var map := map_of(raw.seed)
	var path: Array = []
	for n in raw.path:
		if typeof(n) != TYPE_INT or not open_nodes(map, path).has(n):
			return null
		path.append(n)
	var party: Array = []
	for h in raw.party:
		if typeof(h) != TYPE_DICTIONARY:
			return null
		var id: Variant = h.get("id")
		var max: Variant = h.get("max")
		var hp: Variant = h.get("hp")
		if typeof(id) != TYPE_STRING or id == "":
			return null
		for p in party:
			if p.id == id:
				return null
		if typeof(max) != TYPE_INT or typeof(hp) != TYPE_INT or max < 1 or max > 999 or hp < 1 or hp > max:
			return null
		var mm: Variant = h.get("manaMax")
		var mana: Variant = h.get("mana")
		if mm == null and mana != null:
			return null
		var n := {"id": id, "max": max, "hp": hp}
		if mm != null:
			if typeof(mm) != TYPE_INT or mm < 1 or mm > 999 or typeof(mana) != TYPE_INT or mana < 0 or mana > mm:
				return null
			n.manaMax = mm
			n.mana = mana
		party.append(n)
	var bag: Variant = Bag.parse_bag(raw.get("bag"))
	if bag == null or party.size() < 1 or party.size() > 4:
		return null
	return {"v": CrawlGen.version(), "seed": raw.seed, "path": path, "party": party, "bag": bag}
