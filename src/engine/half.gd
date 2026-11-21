class_name Half
## Half tiles (port of half.ts): every battle the game opens is played on a map split into cells (each tile becomes 2x2,
## Grid.sub = 2) with each unit a 2x2 token that walks 1 cell at a time. Abilities stay in whole tiles; pathing.gd measures
## them in cells.

const HALF_ID := "ash_wood_half"
const SUB := 2
const TREE_LOOKS := ["tree", "tree2", "tree3", "tree4"]


## the token of a sheet: the square doubles and so does the movement. Always rebuilt (dev and expedition sheets change)
static func half_def(id: String) -> String:
	var d: Dictionary = Content.units[id]
	var h := d.duplicate()
	h.id = id + Content.HALF
	h.size = d.get("halfSize", d.get("size", 1) * SUB)
	h.move = d.move * SUB
	Content.units[h.id] = h
	return h.id


static func split(g: Grid) -> Grid:
	var out := Grid.new()
	out.width = g.width * 2
	out.height = g.height * 2
	out.sub = SUB
	out.level_height = (g.level_height if g.level_height != 0.0 else 0.5) * 2
	for y in out.height:
		for x in out.width:
			var t := g.tile(Vector2i(x >> 1, y >> 1))
			var c := t.duplicate()
			c.span = SUB if x % 2 == 0 and y % 2 == 0 else 0
			if t.has("ramp"):
				var f: Vector2i = Grid.FACING[t.ramp[0]]
				var near_high := (f.x > 0 and x % 2 == 1) or (f.x < 0 and x % 2 == 0) or (f.y > 0 and y % 2 == 1) or (f.y < 0 and y % 2 == 0)
				if not near_high:
					c.erase("ramp")
			out.tiles.append(c)
	return out


## the battle in half tiles, registered under `<id>½`
static func halve(base: Dictionary) -> Dictionary:
	var sc := base.duplicate()
	sc.id = base.id + Content.HALF
	sc.grid = split(base.grid)
	var spawns: Array = []
	for sp in base.spawns:
		var s: Dictionary = sp.duplicate()
		s.def = half_def(sp.def)
		s.x = sp.x * SUB
		s.y = sp.y * SUB
		spawns.append(s)
	sc.spawns = spawns
	Content.scenarios[sc.id] = sc
	return sc


## Ash Wood in half tiles with big trees and scattered props (the web game's ?scenario=half)
static func register_half() -> Dictionary:
	var sc := halve(Content.scenarios.ash_wood)
	var grid := Grid.from_dict(sc.grid.to_dict().duplicate(true))
	var anchors: Array = []
	for sp in sc.spawns:
		anchors.append(Vector2i(sp.x, sp.y))
	var hero: Dictionary = {}
	var foe: Dictionary = {}
	for sp in sc.spawns:
		if hero.is_empty() and sp.team == "hero":
			hero = sp
		if foe.is_empty() and sp.team == "enemy":
			foe = sp
	_plant_trees(grid, anchors, Vector2i(hero.x, hero.y), Vector2i(foe.x, foe.y))
	_scatter_props(grid, anchors)
	var test := sc.duplicate()
	test.grid = grid
	test.id = HALF_ID
	test.name = "%s (meia casa)" % sc.name
	test.en = "%s (half tiles)" % sc.en
	Content.scenarios[HALF_ID] = test
	return test


class _Lcg:
	var s: int

	func _init(seed: int) -> void:
		s = seed

	func rnd() -> float:
		s = (s * 16807) % 2147483647
		return float(s) / 2147483647.0


static func _plant_trees(g: Grid, spawns: Array, hero: Vector2i, foe: Vector2i) -> void:
	var r := _Lcg.new(4242)
	var W := g.width
	var H := g.height
	for y in range(0, H, 2):
		for x in range(0, W, 2):
			var t := g.tile(Vector2i(x, y))
			if t.terrain != "forest":
				continue
			t.tree = 2
			for c in [Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
				g.tile(c).look = "grass"
	var near := func(p: Vector2i, look: Array, rad: int) -> bool:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var q := Vector2i(p.x + dx, p.y + dy)
				if q.x < 0 or q.y < 0 or q.x >= W or q.y >= H:
					continue
				var t := g.tile(q)
				if look.has(t.get("look", "")) or t.get("depth", 0):
					return true
		return false
	var spawn_close := func(p: Vector2i, sz: int) -> bool:
		for sp in spawns:
			if sp.x + 2 >= p.x - 1 and sp.x <= p.x + sz and sp.y + 2 >= p.y - 1 and sp.y <= p.y + sz:
				return true
		return false
	var ok := func(p: Vector2i) -> bool:
		if p.x < 0 or p.y < 0 or p.x + 1 >= W or p.y + 1 >= H:
			return false
		for c in [p, Vector2i(p.x + 1, p.y), Vector2i(p.x, p.y + 1), Vector2i(p.x + 1, p.y + 1)]:
			var t := g.tile(c)
			if t.terrain != "floor" or t.get("depth", 0) >= 2:
				return false
		return true
	var open := func() -> bool:
		var seen := {Grid.pos_key(hero): true}
		var queue: Array[Vector2i] = [hero]
		var i := 0
		while i < queue.size():
			var p: Vector2i = queue[i]
			i += 1
			if absi(p.x - foe.x) <= 3 and absi(p.y - foe.y) <= 3:
				return true
			for f in Grid.FACING:
				var n: Vector2i = p + f
				if seen.has(Grid.pos_key(n)) or not ok.call(n) or absi(g.tile(n).h - g.tile(p).h) > 1:
					continue
				seen[Grid.pos_key(n)] = true
				queue.append(n)
		return false
	var placed := 0
	var tries := 0
	while tries < 4000 and placed < 26:
		tries += 1
		var sz := 3 + floori(r.rnd() * 3)
		var p := Vector2i(floori(r.rnd() * (W - sz)), floori(r.rnd() * (H - sz)))
		var cells: Array[Vector2i] = []
		for dy in sz:
			for dx in sz:
				cells.append(Vector2i(p.x + dx, p.y + dy))
		var h: int = g.tile(p).h
		var bad: bool = spawn_close.call(p, sz)
		if not bad:
			for c in cells:
				var t := g.tile(c)
				if absi(t.h - h) > 1 or near.call(c, ["bridge", "water"], 1) or not (not t.has("look") or t.look == "grass") or t.terrain != "floor":
					bad = true
					break
		if bad:
			continue
		var before: Array = []
		for c in cells:
			before.append(g.tile(c).duplicate())
		for k in cells.size():
			var t := g.tile(cells[k])
			t.terrain = "forest"
			t.look = TREE_LOOKS[floori(r.rnd() * TREE_LOOKS.size())] if k == 0 else "grass"
			if k == 0:
				t.tree = sz
		if not open.call():
			for k in cells.size():
				g.tiles[cells[k].y * W + cells[k].x] = before[k]
			continue
		placed += 1


static func _scatter_props(g: Grid, spawns: Array) -> void:
	var r := _Lcg.new(777)
	var kinds := [
		{"terrain": "wall", "look": "crates", "span": 1},
		{"terrain": "wall", "look": "barrel", "span": 1},
		{"terrain": "floor", "look": "corpse", "noStop": true, "span": 1},
		{"terrain": "floor", "look": "corpse", "noStop": true, "span": 1},
	]
	var placed := 0
	var tries := 0
	while tries < 600 and placed < 14:
		tries += 1
		var p := Vector2i(floori(r.rnd() * g.width), floori(r.rnd() * g.height))
		var t := g.tile(p)
		if t.terrain != "floor" or t.get("depth", 0) or t.has("ramp") or t.get("look", "") == "bridge" or t.get("noStop", false):
			continue
		var close := false
		for sp in spawns:
			if absi(sp.x - p.x) <= 3 and absi(sp.y - p.y) <= 3:
				close = true
		if close:
			continue
		t.merge(kinds[placed % kinds.size()], true)
		placed += 1
