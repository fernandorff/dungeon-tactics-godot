class_name TerrainOuter
## Outside the board (port of terrain-outer.ts): the heights of the ring around the map, darkening to black, and the
## river that continues off it, higher on the spring side and dropping in rapids on the other. terrain.gd draws the
## ground with these heights; water_stream.gd draws the outside river.

## the ring darkens over EXT_FADE tiles and reaches full black over the next EXT_DARK (Fernando, Nov 13)
const EXT_FADE := 2
const EXT_DARK := 4
const EXT_RING := EXT_FADE + EXT_DARK
## tone of each outer ring: dark right past the edge, black by the 4th (Nov 13: "darkens stronger and faster")
const TONES := [1.0, 0.4, 0.16, 0.05, 0.0]
const RISE := 0.5 # how much the spring side rises, in levels, every 2 tiles outward


static func ext_tone(ring: int) -> float:
	return TONES[mini(ring, TONES.size() - 1)]


## the lowest tile's h within `ring` tiles of (i, j): the ring never goes above it, or a tall column in front of a unit on
## a low tile would hide half of it (the camera looks diagonally)
static func ext_h(g: Grid, i: int, j: int, ring: int) -> int:
	var h := 1 << 30
	for b in range(maxi(0, j - ring), mini(g.height, j + ring + 1)):
		for a in range(maxi(0, i - ring), mini(g.width, i + ring + 1)):
			h = mini(h, g.tile(Vector2i(a, b)).h)
	return h


static func ring_of(g: Grid, i: int, j: int) -> int:
	return maxi(maxi(-i, -j), maxi(i - g.width + 1, j - g.height + 1))


## the river crossing the map (rows with water on both edges): {rows, dir}; dir 1 when the spring is on the right
static func river_of(g: Grid, levels: Dictionary) -> Dictionary:
	var rows: Array[int] = []
	for y in g.height:
		if levels.has(Vector2i(0, y)) and levels.has(Vector2i(g.width - 1, y)):
			rows.append(y)
	if rows.is_empty():
		return {}
	var y0 := rows[0]
	var right: float = levels[Vector2i(g.width - 1, y0)].surface
	return {"rows": rows, "dir": 1 if right >= levels[Vector2i(0, y0)].surface else -1}


static func _rise_at(g: Grid, river: Dictionary, i: int) -> float:
	if river.is_empty():
		return 0.0
	var k: int = i - g.width + 1 if river.dir > 0 else -i
	return ceili(k / 2.0) * RISE if k > 0 else 0.0


## top of the outside ground at (i, j), in metres
static func outer_top(g: Grid, step: float, river: Dictionary, i: int, j: int) -> float:
	return (ext_h(g, i, j, ring_of(g, i, j)) + 1 + _rise_at(g, river, i)) * step


static func smooth(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## the outside river's surface at `u` (tiles, continuous) on row j: flat on the first half of each pair of tiles and
## dropping as rapids on the second; NAN off the river rows or on the board
static func stream_at(g: Grid, step: float, levels: Dictionary, river: Dictionary, u: float, j: int) -> float:
	if river.is_empty() or not river.rows.has(j) or (u >= 0.0 and u < g.width):
		return NAN
	var right := u >= g.width
	var lv: Dictionary = levels[Vector2i(g.width - 1 if right else 0, j)]
	var k := u - g.width if right else -u
	var up := 1.0 if (1 if right else -1) == river.dir else -1.0
	return lv.surface + up * (floorf(k / 2.0) + smooth(0.5, 1.0, fmod(k / 2.0, 1.0))) * RISE * step


## the outside tiles with water (the middle of each), so the ground and the surroundings know where the river is
static func river_outside(g: Grid, step: float, levels: Dictionary, river: Dictionary) -> Dictionary:
	var out := {}
	if river.is_empty():
		return out
	for y in river.rows:
		for side in [[g.width - 1, 1], [0, -1]]:
			var deep: bool = levels[Vector2i(side[0], y)].deep
			for k in range(1, EXT_RING + 1):
				var i: int = side[0] + side[1] * k
				var surface := stream_at(g, step, levels, river, i + 0.5, y)
				out[Vector2i(i, y)] = {"surface": surface, "bed": surface - (step if deep else WaterLevels.WADE * step), "deep": deep}
	return out
