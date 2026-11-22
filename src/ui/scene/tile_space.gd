class_name TileSpace
extends RefCounted
## Cell ↔ world of the battle scene (port of scene/space.ts): where a tile, a standing unit and the sloped ground are,
## so a ramp or deep water is measured the same by the board, the marks and the units. Unlike the web, the map's corner
## is the origin: cell (x, y) is centred on (x + 0.5, z = y + 0.5).

const STEP := 0.5 # one level in metres on a whole-tile map; the split maps double it (half.gd)

var grid: Grid
var step: float
var levels: Dictionary # cell → water level (water_levels.gd)
var _raised: Dictionary


func _init(g: Grid) -> void:
	grid = g
	step = g.level_height if g.level_height > 0.0 else STEP
	_raised = WaterLevels.raised_deep(g)
	levels = WaterLevels.of_grid(g, step, _raised)


## the tile's top where marks and the cursor lie: midway up a ramp, lowered on deep water like the drawing
func world(p: Vector2i) -> Vector3:
	var t := grid.tile(p)
	var drop := WaterLevels.DEEP_DROP if int(t.get("depth", 0)) >= 2 and not _raised.has(p) else 0.0
	var rise: float = t.ramp[1] / 2.0 if t.has("ramp") else 0.0
	return Vector3(p.x + 0.5, (t.h + 1 + rise - drop) * step, p.y + 0.5)


## where a unit stands: lower in shallow water, swimming in deep
func stand(p: Vector2i) -> Vector3:
	var w := world(p)
	var d := int(grid.tile(p).get("depth", 0))
	if d:
		w.y -= (WaterLevels.SWIM if d >= 2 else WaterLevels.WADE) * step
	return w


## the middle of a square of `size` cells with its corner on `p`, on its highest cell (where a token stands)
func square_top(p: Vector2i, size: int, standing: bool = false) -> Vector3:
	var w := stand(p) if standing else world(p)
	if size == 1:
		return w
	var top := -INF
	for c in Pathing.cells_of(p, size):
		if grid.in_bounds(c):
			top = maxf(top, (stand(c) if standing else world(c)).y)
	return Vector3(w.x + (size - 1) / 2.0, top, w.z + (size - 1) / 2.0)


## how much the ground rises per metre in x and z on a ramp; ZERO on a flat tile
func slope(p: Vector2i) -> Vector2:
	var t := grid.tile(p)
	if not t.has("ramp"):
		return Vector2.ZERO
	var f: Vector2i = Grid.FACING[t.ramp[0]]
	return Vector2(f.x, f.y) * float(t.ramp[1]) * step


## the drawn ground's height at world point (x, z) inside tile p
func surface_y(p: Vector2i, x: float, z: float) -> float:
	var w := world(p)
	var s := slope(p)
	return w.y + s.x * (x - w.x) + s.y * (z - w.z)


## a unit's height walking between two cells, `k` from 0 to 1: it follows a continuous ground and arcs over a step
func walk_y(from: Vector2i, to: Vector2i, k: float) -> float:
	var a := stand(from)
	var b := stand(to)
	var mx := (a.x + b.x) / 2.0
	var mz := (a.z + b.z) / 2.0
	var ea := surface_y(from, mx, mz)
	var eb := surface_y(to, mx, mz)
	if absf(ea - eb) < 0.01:
		return surface_y(from if k < 0.5 else to, a.x + (b.x - a.x) * k, a.z + (b.z - a.z) * k)
	var lift := maxf(0.0, maxf(ea, eb) - (a.y + b.y) / 2.0)
	return a.y + (b.y - a.y) * k + 4.0 * lift * k * (1.0 - k)
