class_name CrawlGen
## Procedural rooms for the dungeon crawl (port of generate.ts): a room is a plain scenario in whole tiles, heroes on one
## side and one enemy group on the other, with height, water, ramps and obstacles between. Same seed, same room.

const TRIES := 200
const SIDE := 12
const BOSS_SIDE := 14


static func version() -> String:
	return Content.data.crawl.version


static func _depth_of(opts: Dictionary) -> int:
	var d: Variant = opts.get("depth", 1)
	var v: int = int(d) if d != null else 1
	if v == 0:
		v = 1
	return mini(99, maxi(1, v))


static func _theme_of(opts: Dictionary) -> String:
	var t: Variant = opts.get("theme")
	return t if t != null and Content.data.crawl.themes.has(t) else "dungeon"


static func room_theme(id: String) -> String:
	return id.substr(id.rfind("-") + 1) if id.begins_with(version() + "-") else ""


static func room_id(seed: int, opts: Dictionary = {}) -> String:
	return "%s-%d-d%d%s-%s" % [version(), Util.i32(seed), _depth_of(opts), "-boss" if opts.get("boss", false) else "", _theme_of(opts)]


## the enemy group a room will hold, without laying it out: {group, rng}
static func room_group(seed: int, opts: Dictionary = {}) -> Dictionary:
	if opts.get("boss", false):
		return {"group": Content.data.crawl.boss, "rng": Util.i32(seed)}
	var depth := _depth_of(opts)
	var tier := -Util.BIG
	for g in Content.data.crawl.groups:
		if g.depth <= depth:
			tier = maxi(tier, g.depth)
	var pool: Array = []
	for g in Content.data.crawl.groups:
		if g.depth == tier:
			pool.append(g)
	var r := Rng.roll_int(Util.i32(seed), 0, pool.size() - 1)
	return {"group": pool[r[0]], "rng": r[1]}


static func generate_room(seed: int, opts: Dictionary = {}) -> Dictionary:
	return build_room(seed, opts).room


class _Stream:
	var rng: int

	func _init(s: int) -> void:
		rng = s

	func int_in(lo: int, hi: int) -> int:
		var r := Rng.roll_int(rng, lo, hi)
		rng = r[1]
		return r[0]


## {room, tries}: layouts drawn from the room's stream until one passes the checks
static func build_room(seed: int, opts: Dictionary = {}) -> Dictionary:
	var theme := _theme_of(opts)
	var rg := room_group(seed, opts)
	var group: Dictionary = rg.group
	var s := _Stream.new(rg.rng)
	var id := room_id(seed, opts)
	for tries in range(1, TRIES + 1):
		var laid: Variant = _layout(s, BOSS_SIDE if opts.get("boss", false) else SIDE, group.enemies, Content.data.crawl.themes[theme])
		if laid == null:
			continue
		var room := {"id": id, "name": group.name[0], "en": group.name[1], "grid": laid.grid, "spawns": laid.spawns}
		if CrawlVerify.verify_room(room).is_empty():
			return {"room": room, "tries": tries}
	push_error("crawl: no room passed the checks for seed %d" % seed)
	return {}


static func _layout(s: _Stream, N: int, enemies: Array, theme: Dictionary) -> Variant:
	var hero := s.int_in(0, 1)
	var foe := hero + s.int_in(0, 1)
	var edge: Array[int] = []
	for i in N:
		edge.append(s.int_in(4, N - 4))
	var tiles: Array = []
	for y in N:
		for x in N:
			tiles.append({"terrain": "floor", "h": foe if y < edge[x] else hero})
	var at := func(p: Vector2i) -> Dictionary:
		return tiles[p.y * N + p.x]
	var rect := func(x0: int, y0: int, w: int, h: int) -> Array:
		var out: Array = []
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				out.append(tiles[y * N + x])
		return out
	var middle := func(h: int) -> int:
		return s.int_in(2, N - 2 - h)
	var m := s.int_in(2, 4)
	while m > 0:
		var w := s.int_in(2, 3)
		var h := s.int_in(2, 3)
		var x0 := s.int_in(0, N - w)
		var y0: int = middle.call(h)
		for t in rect.call(x0, y0, w, h):
			t.h = mini(3, t.h + 1)
		if s.int_in(0, 1) or at.call(Vector2i(x0, y0)).h < 2:
			for t in rect.call(x0 + 1, y0 + 1, w - 1, h - 1):
				t.h = mini(3, t.h + 1)
		m -= 1
	var k := s.int_in(0, 2)
	while k > 0:
		var w := s.int_in(1, 3)
		var h := s.int_in(1, 2)
		var px := s.int_in(0, N - w)
		var pool: Array = rect.call(px, middle.call(h), w, h)
		var depth := 1 if s.int_in(0, 3) else 2
		var flat := true
		for t in pool:
			if t.h != pool[0].h:
				flat = false
		if flat:
			for t in pool:
				t.h = maxi(0, t.h - 1)
				t.depth = depth
				t.look = "water"
		k -= 1
	k = s.int_in(N - 3, N + 2)
	while k > 0:
		var tx := s.int_in(0, N - 1)
		var t: Dictionary = at.call(Vector2i(tx, s.int_in(2, N - 3)))
		if not t.has("look"):
			t.merge(theme.props[s.int_in(0, theme.props.size() - 1)], true)
		k -= 1
	if theme.has("hazard"):
		k = s.int_in(0, 6)
		while k > 0:
			var tx := s.int_in(1, N - 2)
			var t: Dictionary = at.call(Vector2i(tx, s.int_in(2, N - 3)))
			if not t.has("look"):
				t.merge(theme.hazard, true)
			k -= 1
	for i in N * N:
		var x := i % N
		var y := i / N
		var side := x == 0 or x == N - 1
		if side or y == 0 or y == N - 1:
			var closed := (side and (y == 0 or y == N - 1)) or s.int_in(0, 4) < 3
			if closed and not tiles[i].has("look"):
				tiles[i].merge(theme.border[s.int_in(0, theme.border.size() - 1)], true)
	var near := func(p: Vector2i) -> Array:
		var out: Array = []
		for f in Grid.FACING:
			var q: Vector2i = p + f
			if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N:
				out.append(q)
		return out
	var plain := func(p: Vector2i, level: int) -> bool:
		var t: Dictionary = at.call(p)
		if t.terrain != "floor" or t.get("depth", 0) or t.get("spikes", false) or t.h != level:
			return false
		for q in near.call(p):
			var n: Dictionary = at.call(q)
			if not (n.h > level - 2) or n.get("spikes", false):
				return false
		return true
	var band := func(y0: int, y1: int, level: int) -> Array:
		var out: Array = []
		for y in range(y0, y1 + 1):
			for x in range(1, N - 1):
				if plain.call(Vector2i(x, y), level):
					out.append(Vector2i(x, y))
		return out
	var pick := func(from: Array, ok: Callable) -> Variant:
		var fit: Array = []
		for p in from:
			if ok.call(p):
				fit.append(p)
		return fit[s.int_in(0, fit.size() - 1)] if fit.size() else null
	var spawns: Array = []
	var taken: Array = []
	for def in Content.data.crawl.party:
		var p: Variant = pick.call(band.call(N - 4, N - 3, hero), func(q: Vector2i) -> bool:
			for t in taken:
				if Grid.dist(q, t) < 2:
					return false
			return true)
		if p == null:
			return null
		spawns.append({"id": "h-%s" % def, "def": def, "team": "hero", "x": p.x, "y": p.y})
		taken.append(p)
	var heroes := taken.duplicate()
	var gap_to := func(tl: Array) -> int:
		var best := Util.BIG
		for p in tl:
			for q in heroes:
				best = mini(best, Grid.dist(p, q))
		return best
	var square := func(p: Vector2i, size: int) -> Array:
		var out: Array = []
		for kk in size * size:
			out.append(Vector2i(p.x + kk % size, p.y + kk / size))
		return out
	var inside := func(p: Vector2i) -> bool:
		return p.x > 0 and p.y > 0 and p.x < N - 1 and p.y < N - 1
	var body := func(p: Vector2i, def: String) -> Array:
		var own: Array = square.call(p, Pathing.size_of(def))
		var f: Vector2i = Grid.FACING[Grid.face_nearest(p, heroes)]
		for kk in range(1, Content.units[def].get("halfLength", 1)):
			var q := Vector2i((p.x * Half.SUB - f.x * kk) >> 1, (p.y * Half.SUB - f.y * kk) >> 1)
			var all_far := true
			for o in own:
				if Grid.dist(o, q) == 0:
					all_far = false
			if all_far:
				own.append(q)
		return own
	for i in enemies.size():
		var def: String = enemies[i]
		var size := Pathing.size_of(def)
		var rng_lr := CrawlVerify.start_range(def)
		var from: Array
		if size > 1:
			from = []
			for p in band.call(1, 1, foe):
				if p.x < N - 2:
					var ok := true
					for q in square.call(p, 2):
						if not plain.call(q, foe):
							ok = false
					if ok:
						from.append(p)
		else:
			from = band.call(1, N - 6, foe)
		var p: Variant = pick.call(from, func(q: Vector2i) -> bool:
			var d: int = gap_to.call(square.call(q, size))
			if d < rng_lr[0] or d > rng_lr[1]:
				return false
			for o in body.call(q, def):
				if not inside.call(o) or not plain.call(o, foe):
					return false
				for t in taken:
					if Grid.dist(o, t) < 2:
						return false
			return true)
		if p == null:
			return null
		if size > 1:
			for q in square.call(p, size):
				at.call(q).h = mini(3, foe + 1)
		spawns.append({"id": "e%d-%s" % [i, def], "def": def, "team": "enemy", "x": p.x, "y": p.y})
		taken.append_array(body.call(p, def))
	for i in tiles.size():
		var p := Vector2i(i % N, i / N)
		var t: Dictionary = tiles[i]
		if t.terrain != "floor" or t.get("depth", 0) or t.get("spikes", false) or taken.has(p):
			continue
		var up: Array = []
		for d in 4:
			var q: Vector2i = p + Grid.FACING[d]
			if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N:
				continue
			var n: Dictionary = at.call(q)
			if n.terrain == "floor" and not n.get("depth", 0) and not n.get("spikes", false) and n.h == t.h + 1:
				up.append(d)
		if up.size() and s.int_in(0, 1):
			t.ramp = [up[s.int_in(0, up.size() - 1)], 1]
	if theme.has("road"):
		var y := N - 1
		var x := s.int_in(2, N - 4)
		while y >= 0:
			for t in [at.call(Vector2i(x, y)), at.call(Vector2i(x + 1, y))]:
				if t.terrain == "floor" and not t.has("look"):
					t.look = theme.road
			y -= 1
			x = mini(N - 3, maxi(1, x + s.int_in(-1, 1)))
	for t in tiles:
		if not t.has("look"):
			t.look = theme.floors[mini(t.h, theme.floors.size() - 1)]
	var g := Grid.new()
	g.width = N
	g.height = N
	g.tiles = tiles
	return {"grid": g, "spawns": spawns}
