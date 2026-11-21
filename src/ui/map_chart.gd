class_name MapChart
## The expedition map as a chart (port of expedition-places.ts, pure): where each place of the descent sits, what the
## party may do with it, how the places link and what a place pays, for the expedition screen to draw.
## A spot is a Vector2: x from 0 to 1 across the chart, y in rows from the gate (row 0) down.

# cleared: on the path walked; open: the party may enter now; ahead: still reachable further down; skipped: no way
# leads there any more (another room of its row was taken, or the chest's room was not)
const CLEARED := "cleared"
const OPEN := "open"
const AHEAD := "ahead"
const SKIPPED := "skipped"
# the chest's column, at the edge of the chart: clear of the ways between the rows of rooms
const SIDE := 0.1


static func place_states(map: Array, path: Array) -> Array:
	var open := Expedition.open_nodes(map, path)
	var ahead := {}
	var visit := func(i: int, me: Callable) -> void:
		for c in map[i].next:
			if not ahead.has(c):
				ahead[c] = true
				me.call(c, me)
	for i in open:
		visit.call(i, visit)
	var out: Array = []
	for i in map.size():
		out.append(CLEARED if path.has(i) else OPEN if open.has(i) else AHEAD if ahead.has(i) else SKIPPED)
	return out


## {rows, gate, party, places: [{node, at, state}], links: [{from, to, kind}], floors: [{floor, from, to}]};
## a link's kind: walked (a step of the path), open (from the party to a place it may enter), ahead, off (closed for good)
static func chart(map: Array, path: Array) -> Dictionary:
	var states := place_states(map, path)
	var gate := Vector2(0.5, 0)
	var y := 0
	var spots: Array = []
	for i in map.size():
		var n: Dictionary = map[i]
		# the map lists a row's rooms together and the floor's chest right after its row: each run takes one row
		if i == 0 or map[i - 1].floor != n.floor or map[i - 1].row != n.row or map[i - 1].chest != n.chest:
			y += 1
		spots.append(Vector2(0, y))
	for i in map.size():
		if map[i].chest:
			continue
		var row: Array = []
		for k in map.size():
			if spots[k].y == spots[i].y and not map[k].chest:
				row.append(k)
		spots[i].x = float(row.find(i) + 1) / (row.size() + 1)
	# the chest on the side of the one room that leads to it, so that way crosses no other room
	for i in map.size():
		if map[i].chest:
			var lead := 0
			while not map[lead].next.has(i):
				lead += 1
			spots[i].x = SIDE if spots[lead].x < 0.5 else 1 - SIDE
	var links: Array = []
	for i in map.size():
		var n: Dictionary = map[i]
		if n.floor == 1 and n.row == 0 and not n.chest:
			links.append({"from": gate, "to": spots[i], "kind": "walked" if path.size() and path[0] == i else "off" if path.size() else "open"})
		var step := path.find(i)
		for c in n.next:
			var kind: String
			if step < 0:
				kind = "off" if states[i] == SKIPPED else "ahead"
			elif step + 1 < path.size() and path[step + 1] == c:
				kind = "walked"
			else:
				kind = "open" if step == path.size() - 1 else "off"
			links.append({"from": spots[i], "to": spots[c], "kind": kind})
	var floors: Array = []
	for i in map.size():
		var f: int = map[i].floor
		if floors.is_empty() or floors.back().floor != f:
			floors.append({"floor": f, "from": int(spots[i].y), "to": int(spots[i].y)})
		floors.back().from = mini(floors.back().from, int(spots[i].y))
		floors.back().to = maxi(floors.back().to, int(spots[i].y))
	var places: Array = []
	for i in map.size():
		places.append({"node": i, "at": spots[i], "state": states[i]})
	return {"rows": y + 1, "gate": gate, "party": spots[path.back()] if path.size() else gate, "places": places, "links": links, "floors": floors}


## The gold a place may pay, before it is won: the chest's range, or the sum of its enemies' drops (node_gold rolls
## inside it); [0, 0] when none of them carries gold
static func gold_range(n: Dictionary) -> Array:
	if n.chest:
		return Expedition.run().chest.duplicate()
	var lo := 0
	var hi := 0
	for e in CrawlGen.room_group(n.seed, {"depth": n.floor, "boss": n.boss}).group.enemies:
		if Content.data.crawl.gold.has(e):
			lo += Content.data.crawl.gold[e][0]
			hi += Content.data.crawl.gold[e][1]
	return [lo, hi]
