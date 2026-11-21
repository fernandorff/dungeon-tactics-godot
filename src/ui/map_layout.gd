class_name MapLayout
## Where the expedition map puts its parts (port of town3d/map-layout.ts and the town windows' frame, town-layout.ts), in
## px of the 1920x1080 reference. After FFT: The Ivalice Chronicles' world map: the chart takes the middle of the screen
## as one parchment sheet, the party and the picked place beside it, the commands as plaques down the left edge. The
## places stand on a grid (Fernando, Nov 17: down goes to what is straight below, sideways to what is beside): the rooms
## in columns, every row holding the middle one (the gate over it, the boss on it), a floor's chest at the sheet's edge
## in the row of the room that leads to it. Pure numbers; also the cursor that walks by where things are (spot-walk.ts).

const SCREEN := Vector2(1920, 1080)
const CHART := Rect2(410, 100, 700, 830) # the sheet with the descent
const PAD := 20.0
const GUTTER := 100.0 # the floors' names, down the sheet's left edge
const COLS := [0.22, 0.78] # the rooms' columns, from the first to the last, across the field
const SIDE := 0.08 # a chest's column, at either edge of the field
const STEP := 84.0 # a row of the chart at most; a longer descent packs its rows into the sheet
const PLACE := 52.0 # a room or a chest
const BOSS := 68.0
const PARTY := Rect2(1140, 100, 750, 346) # the party: two members a row
const INFO := Rect2(1140, 466, 750, 464) # the picked place
const HEAD := 56.0
const HERO := {"h": 124.0, "face": 96.0, "gap": 18.0}
# the town windows' frame: the title, its hairline, the gold, the help band, the key hints and the plaques
const TITLE := Vector2(42, 40)
const RULE := Rect2(0, 76, 1920, 2)
const GOLD := Vector2(1872, 44)
const HELP := Rect2(0, 944, 1920, 70)
const HINTS := Vector2(1880, 1049)
const PLAQUE := {"x": 0.0, "y": 380.0, "w": 372.0, "h": 112.0, "gap": 14.0}

const ORDER := ["off", "ahead", "open", "walked"]


## {field: Rect2, step, places: [{at: Vector2 (middle), size, kind, state}] by node, links: [{a, b, kind}] the walked
## last, gate: Vector2, flag: Vector2 (top of its pole), floors: [{floor, box: Rect2}], heroes: [Rect2], commands: [Rect2]}
static func layout(c: Dictionary, kinds: Array, heroes: int, commands: int) -> Dictionary:
	# the chart's rows that hold rooms, each left to right; a chest's own row is dropped (it joins its room's row)
	var rooms := {}
	for i in c.places.size():
		if kinds[i] != "chest":
			var y: float = c.places[i].at.y
			if not rooms.has(y):
				rooms[y] = []
			rooms[y].append(i)
	for y in rooms:
		rooms[y].sort_custom(func(a: int, b: int) -> bool: return c.places[a].at.x < c.places[b].at.x)
	var keys: Array = rooms.keys()
	keys.sort()
	var used: Array = [c.gate.y] + keys
	var cols := 1
	for y in rooms:
		cols = maxi(cols, rooms[y].size())
	var spine := (cols - 1) / 2
	var col_x := func(k: int) -> float: return 0.5 if cols == 1 else COLS[0] + (COLS[1] - COLS[0]) * k / (cols - 1)
	# shortcut: no scroll, the rows shrink to fit; past about 13 rows the places touch and the sheet needs one
	var step := minf(STEP, (CHART.size.y - 2 * PAD) / used.size())
	var field := Rect2(CHART.position.x + GUTTER, CHART.position.y + PAD, CHART.size.x - GUTTER - PAD, step * used.size())
	var point := func(x: float, row: float) -> Vector2: return Vector2(field.position.x + x * field.size.x, field.position.y + (used.find(row) + 0.5) * step)
	var spots := {c.gate: point.call(col_x.call(spine), c.gate.y)}
	for y in rooms:
		var r: Array = rooms[y]
		# the row's rooms side by side, on the columns around the spine
		var first := mini(maxi(spine - (r.size() - 1) / 2, 0), cols - r.size())
		for k in r.size():
			spots[c.places[r[k]].at] = point.call(col_x.call(first + k), y)
	for i in c.places.size():
		if kinds[i] != "chest":
			continue
		var at: Vector2 = c.places[i].at
		# beside the row of the room that leads to it, on the side with fewer rooms in the way
		var lead := at
		for l in c.links:
			if l.to == at:
				lead = l.from
				break
		var r: Array = rooms.get(lead.y, [])
		var k := -1
		for j in r.size():
			if c.places[r[j]].at == lead:
				k = j
		spots[at] = point.call(SIDE if k <= r.size() - 1 - k else 1 - SIDE, lead.y if rooms.has(lead.y) else used[1])
	var spot_of := func(s: Vector2) -> Vector2: return spots.get(s, point.call(col_x.call(spine), c.gate.y))
	var places: Array = []
	for i in c.places.size():
		places.append({"at": spot_of.call(c.places[i].at), "size": BOSS if kinds[i] == "boss" else PLACE, "kind": kinds[i], "state": c.places[i].state})
	var links: Array = c.links.duplicate()
	links = Util.stable_sort(links, func(a: Dictionary, b: Dictionary) -> bool: return ORDER.find(a.kind) < ORDER.find(b.kind))
	var lines: Array = []
	for l in links:
		lines.append({"a": spot_of.call(l.from), "b": spot_of.call(l.to), "kind": l.kind})
	var gate: Vector2 = spot_of.call(c.gate)
	var party: Vector2 = spot_of.call(c.party)
	var floors: Array = []
	for f in c.floors:
		var rows: Array = []
		for k in used.size():
			if used[k] >= f.from and used[k] <= f.to:
				rows.append(k)
		floors.append({"floor": f.floor, "box": Rect2(CHART.position.x + 6, field.position.y + (rows[0] if rows.size() else 0) * step, CHART.size.x - 12, rows.size() * step)})
	var cell_w := (PARTY.size.x - 2 * PAD - HERO.gap) / 2
	var hero_boxes: Array = []
	for i in heroes:
		hero_boxes.append(Rect2(PARTY.position.x + PAD + (i % 2) * (cell_w + HERO.gap), PARTY.position.y + HEAD + 14 + (i / 2) * (HERO.h + 10), cell_w, HERO.h))
	var cmds: Array = []
	for i in commands:
		cmds.append(Rect2(PLAQUE.x, PLAQUE.y + i * (PLAQUE.h + PLAQUE.gap), PLAQUE.w, PLAQUE.h))
	return {
		"field": field, "step": step, "places": places, "links": lines, "gate": gate,
		"flag": gate + Vector2(76, -22) if c.party == c.gate else party + Vector2(20, -56),
		"floors": floors, "heroes": hero_boxes, "commands": cmds,
	}


## What a command's plaque and the help band say. An armed 2nd tap rewrites the button as "Confirm: what it does": the
## plaque keeps the word before the colon and the band says the whole sentence. A command that is off says why; any
## other leaves the band to the picked place ("")
static func command_text(label: String, note: String, armed: bool) -> Dictionary:
	if armed:
		return {"plaque": label.split(":")[0], "help": label}
	return {"plaque": label, "help": "%s: %s" % [label, note] if note != "" else ""}


## The cursor that walks by where things are on screen (spot-walk.ts; Fernando, Nov 17: down goes to what is straight
## below, sideways to what is beside, never by list order and never on a slant). The index of the box to go to from
## `from` in `dir` (a unit Vector2), `from` itself at an edge. A box counts when its middle is past `from`'s that way and
## the two overlap across it; the nearest wins, and of two as near the one less off to the side. `slant` also takes a
## box out of line that is no farther to the side than ahead
static func next_spot(boxes: Array, from: int, dir: Vector2, slant: bool = false) -> int:
	if from < 0 or from >= boxes.size():
		return from
	var a: Rect2 = boxes[from]
	var upright := dir.x == 0
	var sign := dir.x + dir.y
	var best := from
	var least := INF
	for i in boxes.size():
		if i == from:
			continue
		var b: Rect2 = boxes[i]
		var d := b.get_center() - a.get_center()
		var ahead := sign * (d.y if upright else d.x)
		var aside := absf(d.x if upright else d.y)
		var a0 := a.position.x if upright else a.position.y
		var a1 := a.end.x if upright else a.end.y
		var b0 := b.position.x if upright else b.position.y
		var b1 := b.end.x if upright else b.end.y
		if ahead <= 1 or ((b0 >= a1 or a0 >= b1) and not (slant and aside <= ahead)):
			continue
		var cost := ahead + aside / 1000.0
		if cost < least:
			least = cost
			best = i
	return best
