class_name MapTests
## The expedition map's pure parts (port of tests/expedition-places.test.ts, map3d.test.ts and spot-walk.test.ts): the
## chart's states and ways, the layout on the sheet and the cursor that walks by where things are.

const DIRS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]


func _seeds() -> Array:
	return range(40).map(func(i: int) -> int: return i * 7919 + 3)


func _kinds(map: Array) -> Array:
	return map.map(func(n: Dictionary) -> String: return "chest" if n.chest else "boss" if n.boss else "room")


func _lay(seed: int, path: Array = []) -> Dictionary:
	var map := Expedition.map_of(seed)
	return MapLayout.layout(MapChart.chart(map, path), _kinds(map), 4, 3)


func _lead(map: Array) -> int:
	for i in map.size():
		if map[i].floor == 1 and map[i].next.any(func(c: int) -> bool: return map[c].chest):
			return i
	return -1


func _box(x: float, y: float, w: float = 50, h: float = 50) -> Rect2:
	return Rect2(x - w / 2, y - h / 2, w, h)


func _count(arr: Array, v: Variant) -> int:
	return arr.count(v)


func test_map_chart_start() -> String:
	var map := Expedition.map_of(77)
	var c := MapChart.chart(map, [])
	var open := Expedition.open_nodes(map, [])
	var opened: Array = c.places.filter(func(p: Dictionary) -> bool: return p.state == "open").map(func(p: Dictionary) -> int: return p.node)
	if opened != open:
		return "open places %s != %s" % [opened, open]
	if not c.places.all(func(p: Dictionary) -> bool: return p.state in ["open", "ahead"]):
		return "a place not open or ahead at the start"
	if c.party != c.gate:
		return "the party is not at the gate"
	var from_gate: Array = c.links.filter(func(l: Dictionary) -> bool: return l.from == c.gate).map(func(l: Dictionary) -> String: return l.kind)
	return Util.diff(from_gate, open.map(func(_i: int) -> String: return "open"), "gate ways")


func test_map_chart_skips_and_chest() -> String:
	var map := Expedition.map_of(77)
	var lead := _lead(map)
	var chest: int = map[lead].next.filter(func(c: int) -> bool: return map[c].chest)[0]
	var other: int = Expedition.open_nodes(map, []).filter(func(i: int) -> bool: return i != lead)[0]
	var s := MapChart.place_states(map, [other])
	if s[other] != "cleared" or s[lead] != "skipped" or s[chest] != "skipped":
		return "states after the other room: %s %s %s" % [s[other], s[lead], s[chest]]
	if _count(s, "open") != map[other].next.size():
		return "open count"
	var row1: int = map[chest].next[0]
	if MapChart.place_states(map, [lead])[chest] != "open" or MapChart.place_states(map, [lead])[row1] != "open":
		return "chest and next row not open after the lead"
	if MapChart.place_states(map, [lead, row1])[chest] != "skipped":
		return "chest not closed once walked on"
	return Util.diff(MapChart.place_states(map, [lead, chest, row1])[chest], "cleared", "opened chest")


func test_map_chart_whole_descent() -> String:
	for seed in _seeds():
		var map := Expedition.map_of(seed)
		var path: Array = []
		while not Expedition.cleared(map, path):
			var open := Expedition.open_nodes(map, path)
			var c := MapChart.chart(map, path)
			var sorted := open.duplicate()
			sorted.sort()
			var opened: Array = c.places.filter(func(p: Dictionary) -> bool: return p.state == "open").map(func(p: Dictionary) -> int: return p.node)
			if opened != sorted:
				return "seed %d: open %s != %s" % [seed, opened, sorted]
			var kinds: Array = c.links.map(func(l: Dictionary) -> String: return l.kind)
			if _count(kinds, "walked") != path.size() or _count(kinds, "open") != open.size():
				return "seed %d: walked or open ways" % seed
			if c.party != (c.places[path.back()].at if path.size() else c.gate):
				return "seed %d: party spot" % seed
			path.append(open.back())
	return ""


func test_map_chart_spots() -> String:
	for seed in _seeds():
		var map := Expedition.map_of(seed)
		var c := MapChart.chart(map, [])
		var seen := {}
		for p in c.places:
			seen[p.at] = true
			if p.at.x <= 0 or p.at.x >= 1 or p.at.y <= 0 or p.at.y >= c.rows:
				return "seed %d: spot off the chart" % seed
			for n in map[p.node].next:
				if c.places[n].at.y <= p.at.y:
					return "seed %d: a way leads up" % seed
		if seen.size() != map.size():
			return "seed %d: two places share a spot" % seed
		for i in c.floors.size():
			if c.floors[i].floor != i + 1 or c.floors[i].from != (c.floors[i - 1].to + 1 if i else 1):
				return "seed %d: floor rows" % seed
		if c.floors.back().to != c.rows - 1:
			return "seed %d: last floor row" % seed
		for n in map.size():
			if map[n].chest:
				var g := MapChart.gold_range(map[n])
				if [int(g[0]), int(g[1])] != [int(Expedition.run().chest[0]), int(Expedition.run().chest[1])]:
					return "chest gold range"
			var g := MapChart.gold_range(map[n])
			if Expedition.node_gold(map[n]) < g[0] or Expedition.node_gold(map[n]) > g[1]:
				return "seed %d: gold outside its range" % seed
	return ""


func test_map_layout_on_sheet() -> String:
	for seed in _seeds():
		var L := _lay(seed)
		var S := MapLayout.CHART
		if L.step > MapLayout.STEP or L.field.end.y > S.end.y - MapLayout.PAD + 0.001:
			return "seed %d: rows past the sheet" % seed
		for i in L.places.size():
			var a: Dictionary = L.places[i]
			if a.at.x - a.size / 2 < S.position.x + MapLayout.GUTTER - MapLayout.PLACE or a.at.x + a.size / 2 > S.end.x or a.at.y - a.size / 2 < S.position.y or a.at.y + a.size / 2 > S.end.y:
				return "seed %d: place %d off the sheet" % [seed, i]
			for b in L.places.slice(i + 1):
				if a.at.distance_to(b.at) < (a.size + b.size) / 2 + 8:
					return "seed %d: places touch" % seed
		var boss: Dictionary = L.places.filter(func(p: Dictionary) -> bool: return p.kind == "boss")[0]
		if boss.at.x != L.gate.x:
			return "seed %d: boss off the spine" % seed
	var map := Expedition.map_of(77)
	var after := MapLayout.layout(MapChart.chart(map, [0]), _kinds(map), 4, 3)
	if after.links.back().kind != "walked":
		return "walked ways not last"
	var start := _lay(77)
	if start.flag != start.gate + Vector2(76, -22) or after.flag != after.places[0].at + Vector2(20, -56):
		return "flag spot"
	if start.heroes.size() != 4 or start.heroes[1].position.y != start.heroes[0].position.y:
		return "party two a row"
	for h in start.heroes:
		if not MapLayout.PARTY.encloses(h):
			return "hero off its panel"
	return ""


func test_map_arrows_reach_all() -> String:
	for seed in _seeds():
		var L := _lay(seed)
		var boxes: Array = L.places.map(func(p: Dictionary) -> Rect2: return _box(p.at.x, p.at.y, p.size, p.size)) + L.commands
		var seen := {0: true}
		var todo := [0]
		while todo.size():
			var at: int = todo.pop_back()
			for d in DIRS:
				var to := MapLayout.next_spot(boxes, at, d)
				if not seen.has(to):
					seen[to] = true
					todo.append(to)
		if seen.size() != boxes.size():
			return "seed %d: %d of %d reached" % [seed, seen.size(), boxes.size()]
		# down from the room over the boss lands on it
		var boss := -1
		for i in L.places.size():
			if L.places[i].kind == "boss":
				boss = i
		if MapLayout.next_spot(boxes, boss, Vector2.DOWN) != boss or MapLayout.next_spot(boxes, MapLayout.next_spot(boxes, boss, Vector2.UP), Vector2.DOWN) != boss:
			return "seed %d: up and down around the boss" % seed
	return ""


func test_spot_walk() -> String:
	var cross := [_box(300, 300), _box(300, 100), _box(300, 500), _box(100, 300), _box(500, 300)]
	var want := [1, 2, 3, 4]
	for k in 4:
		if MapLayout.next_spot(cross, 0, DIRS[k]) != want[k]:
			return "cross %d" % k
		if MapLayout.next_spot(cross, want[k], DIRS[k]) != want[k]:
			return "edge %d" % k
	var slant := [_box(300, 300), _box(400, 372), _box(230, 228)]
	for d in DIRS:
		if MapLayout.next_spot(slant, 0, d) != 0:
			return "slant"
	var floors := [_box(612, 306), _box(774, 306), _box(666, 370), _box(882, 370), _box(515, 434)]
	if MapLayout.next_spot(floors, 0, Vector2.DOWN) != 0 or MapLayout.next_spot(floors, 0, Vector2.DOWN, true) != 2 or MapLayout.next_spot(floors, 2, Vector2.LEFT, true) != 4 or MapLayout.next_spot(floors, 3, Vector2.UP, true) != 3:
		return "slant option"
	var plaque := [_box(186, 436, 372, 112), _box(556, 470), _box(703, 470), _box(703, 300)]
	if MapLayout.next_spot(plaque, 0, Vector2.RIGHT) != 1 or MapLayout.next_spot(plaque, 1, Vector2.LEFT) != 0 or MapLayout.next_spot(plaque, 3, Vector2.LEFT) != 3:
		return "plaque"
	if MapLayout.next_spot([], 0, Vector2.DOWN) != 0:
		return "empty"
	return ""


func test_map_command_text() -> String:
	var e := Util.diff(MapLayout.command_text("Travel", "", false), {"plaque": "Travel", "help": ""}, "plain")
	e += Util.diff(MapLayout.command_text("Travel", "off", false), {"plaque": "Travel", "help": "Travel: off"}, "off")
	return e + Util.diff(MapLayout.command_text("Confirm: ends it", "", true), {"plaque": "Confirm", "help": "Confirm: ends it"}, "armed")
