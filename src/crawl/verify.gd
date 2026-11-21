class_name CrawlVerify
## Checks a crawl room the way the game will play it (port of verify.ts): split into half tiles, walked with the real
## `reachable`, shot at with the real shot trace. Returns the problems in words; an empty list is a good room.

const NEAR := 5
const FAR := 7
const MAX_WATER := 0.15
const MAX_SPIKES := 6
const MAX_H := 3
const HIGH := 2
const MIN_COVER := 2
const SCRATCH := "crawl-verify"


static func start_range(def: String) -> Array:
	return [8, 10] if Content.units[def].has("size") else [NEAR, FAR]


static func _tiles_of(s: Dictionary) -> Array[Vector2i]:
	return Pathing.cells_of(Vector2i(s.x, s.y), Pathing.size_of(s.def))


static func verify_room(room: Dictionary) -> Array:
	var out: Array = []
	var g0: Grid = room.grid
	var heroes: Array = []
	var foes: Array = []
	for s in room.spawns:
		(heroes if s.team == "hero" else foes).append(s)
	if heroes.is_empty() or foes.is_empty():
		return ["a side has no units"]
	var water := 0
	var spikes := 0
	var off_h := false
	for t in g0.tiles:
		if t.get("depth", 0):
			water += 1
		if t.get("spikes", false):
			spikes += 1
		if t.h < 0 or t.h > MAX_H:
			off_h = true
	if water > MAX_WATER * g0.tiles.size():
		out.append("water on %d tiles, more than 15%%" % water)
	if spikes > MAX_SPIKES:
		out.append("%d spike tiles, more than %d" % [spikes, MAX_SPIKES])
	if off_h:
		out.append("a tile outside heights 0 to %d" % MAX_H)
	for s in room.spawns:
		var tiles := _tiles_of(s)
		var where := "%s at %d,%d" % [s.id, s.x, s.y]
		var off := false
		for p in tiles:
			if not g0.in_bounds(p):
				off = true
		if off:
			out.append(where + ": off the map")
			continue
		for p in tiles:
			if p.x == 0 or p.y == 0 or p.x == g0.width - 1 or p.y == g0.height - 1:
				out.append(where + ": on the map border")
				break
		var own_h: int = g0.tile(Vector2i(s.x, s.y)).h
		var ledge := false
		var spiky := false
		for p in tiles:
			for f in Grid.FACING:
				var q: Vector2i = p + f
				if g0.in_bounds(q):
					if g0.tile(q).h <= own_h - 2:
						ledge = true
					if g0.tile(q).get("spikes", false):
						spiky = true
		if ledge:
			out.append(where + ": on a ledge")
		if spiky:
			out.append(where + ": next to spikes")
	for f in foes:
		var d := Util.BIG
		for h in heroes:
			d = mini(d, Pathing.gap(_tiles_of(h), _tiles_of(f)))
		var r := start_range(f.def)
		if d < r[0] or d > r[1]:
			out.append("%s starts %d tiles from the nearest hero (%d to %d)" % [f.id, d, r[0], r[1]])
	var scratch := room.duplicate()
	scratch.id = SCRATCH
	var half := Half.halve(scratch)
	half.rules = {"jump": 1}
	var g: Grid = half.grid
	var state := Scenarios.initial_state(half, 1)
	var units: Array = state.units
	var used := {}
	for u in units:
		var cells := Pathing.footprint(u)
		var where := "%s at %d,%d" % [u.id, u.pos.x / Half.SUB, u.pos.y / Half.SUB]
		var bad := false
		for c in cells:
			if not g.in_bounds(c) or not Grid.can_stand(g.tile(c)):
				bad = true
		if bad:
			out.append(where + ": on ground nobody stands on")
			continue
		if not Pathing.rests_on(g, u.pos, Pathing.size_of(u.def)):
			out.append(where + ": not on even ground")
		for c in cells:
			if Grid.is_deep(g.tile(c)) or g.tile(c).get("spikes", false):
				out.append(where + ": in deep water or on spikes")
				break
		for c in cells:
			if used.has(Grid.pos_key(c)):
				out.append(where + ": on top of another unit")
				break
		for c in cells:
			used[Grid.pos_key(c)] = true
	if out.size():
		return out
	var dry := Grid.new()
	dry.width = g.width
	dry.height = g.height
	dry.sub = g.sub
	dry.level_height = g.level_height
	for t in g.tiles:
		if Grid.is_deep(t):
			var w: Dictionary = t.duplicate()
			w.terrain = "wall"
			dry.tiles.append(w)
		else:
			dry.tiles.append(t)
	var walk := func(grid: Grid, u: Dictionary) -> Array:
		var alone := state.duplicate()
		alone.units = [u]
		var stops: Array = [u.pos]
		for st in Pathing.reachable(grid, alone, u.id, 999).values():
			stops.append(st.pos)
		return stops
	var hs: Array = []
	var es: Array = []
	for u in units:
		(hs if u.team == "hero" else es).append(u)
	var hero_dry: Array = []
	for h in hs:
		hero_dry.append(walk.call(dry, h))
	for i in hs.size():
		for e in es:
			var ok := false
			for p in hero_dry[i]:
				if Pathing.gap(Pathing.cells_of(p, Pathing.size_of(hs[i].def)), Pathing.footprint(e)) == 1:
					ok = true
					break
			if not ok:
				out.append("%s cannot reach %s with jump 1 on dry ground" % [hs[i].id, e.id])
	var stops := {}
	for p in walk.call(g, hs[0]):
		stops[Grid.pos_key(p)] = true
	for y in range(0, g.height, Half.SUB):
		for x in range(0, g.width, Half.SUB):
			var p := Vector2i(x, y)
			var ok := true
			for c in Pathing.cells_of(p, Half.SUB):
				if not Grid.can_stand(g.tile(c)) or g.tile(c).get("noStop", false):
					ok = false
			if ok and not stops.has(Grid.pos_key(p)):
				out.append("tile %d,%d is cut off" % [x / Half.SUB, y / Half.SUB])
	var high := func(p: Vector2i) -> bool:
		if p.x % Half.SUB != 0 or p.y % Half.SUB != 0 or g.tile(p).h < HIGH:
			return false
		for c in Pathing.cells_of(p, Half.SUB):
			if used.has(Grid.pos_key(c)):
				return false
		return true
	var hero_high := {}
	for stops_of in hero_dry:
		for p in stops_of:
			if high.call(p):
				hero_high[Grid.pos_key(p)] = true
	var reached := false
	for e in es:
		if Content.units[e.def].move <= 0:
			continue
		for p in walk.call(dry, e):
			if hero_high.has(Grid.pos_key(p)):
				reached = true
				break
		if reached:
			break
	if not reached:
		out.append("no high point (level %d+) that both sides reach with jump 1" % HIGH)
	var blocks := {}
	for e in es:
		var shot: Dictionary = {}
		for a in Content.units[e.def].abilities:
			var ab: Dictionary = Content.abilities[a]
			if ab.needsSight and ab.range[1] > 1:
				shot = ab
				break
		var hidden := false
		for h in hs:
			var two := state.duplicate()
			two.units = [e, h]
			var stop: Variant = Shot.trace(g, two, e, h.pos, shot.get("arc", false)).stop
			if stop != null:
				blocks[Grid.pos_key(stop.pos)] = true
				hidden = true
		if not shot.is_empty() and not hidden:
			out.append("%s sees every hero from its start" % e.id)
	if blocks.size() < MIN_COVER:
		out.append("%d tiles stop a shot between the sides (min %d)" % [blocks.size(), MIN_COVER])
	return out
