class_name Grid
extends RefCounted
## The battle map: tiles with terrain and height, immutable during a battle (the state keeps only the scenario id). Port of
## src/shared/battle/grid.ts. A tile is a Dictionary with the web game's keys: terrain, h, look, ramp, depth, spikes, noStop,
## tree, span (all but terrain and h optional).

const TERRAIN := {
	"floor": {"walkable": true, "blocks": 0, "cover": false},
	"forest": {"walkable": false, "blocks": 2, "cover": true},
	"rubble": {"walkable": true, "blocks": 1, "cover": true},
	"wall": {"walkable": false, "blocks": 4, "cover": false},
}
## low objects block sight only 1 level above the ground
const LOW := ["crates", "barrel", "corpse", "chest", "rubble"]
## directions of a unit's facing, in turning order: +y, +x, -y, -x
const FACING: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int
var height: int
var tiles: Array
## cells per whole tile on each side: 2 on a map split into half tiles (half.gd)
var sub: int = 1
var level_height: float = 0.0


static func from_dict(d: Dictionary) -> Grid:
	var g := Grid.new()
	g.width = d.width
	g.height = d.height
	g.tiles = d.tiles
	g.sub = d.get("sub", 1)
	g.level_height = d.get("levelHeight", 0.0)
	return g


func to_dict() -> Dictionary:
	var d := {"width": width, "height": height, "tiles": tiles}
	if sub != 1:
		d.sub = sub
	if level_height != 0.0:
		d.levelHeight = level_height
	return d


func tile(p: Vector2i) -> Dictionary:
	return tiles[p.y * width + p.x]


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func neighbors(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var q := p + d
		if in_bounds(q):
			out.append(q)
	return out


static func blocks_of(t: Dictionary) -> int:
	return 1 if t.has("look") and LOW.has(t.look) else TERRAIN[t.terrain].blocks


static func is_deep(t: Dictionary) -> bool:
	return t.get("depth", 0) >= 2


## height of whoever stands on the tile: in deep water, the tile minus the depth
static func stand_h(t: Dictionary) -> int:
	return t.h - (t.depth if is_deep(t) else 0)


static func can_stand(t: Dictionary) -> bool:
	return TERRAIN[t.terrain].walkable


static func walkable(t: Dictionary) -> bool:
	return TERRAIN[t.terrain].walkable


static func cover(t: Dictionary) -> bool:
	return TERRAIN[t.terrain].cover


static func step_cost(_t: Dictionary) -> int:
	return 1


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func pos_key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]


## direction from `from` to `to` along the axis of greatest difference (tie: the x axis)
static func facing_to(from: Vector2i, to: Vector2i) -> int:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if absi(dx) >= absi(dy):
		return 1 if dx >= 0 else 3
	return 0 if dy > 0 else 2


## toward the nearest foe; with none, the first direction
static func face_nearest(from: Vector2i, foes: Array) -> int:
	if foes.is_empty():
		return 0
	var best: Vector2i = foes[0]
	for f in foes:
		if dist(from, f) < dist(from, best):
			best = f
	return facing_to(from, best)


## where the attack comes from: front, side or back (BMG 1.4)
static func side_of(target: Vector2i, facing: Vector2i, attacker: Vector2i) -> String:
	var dx := attacker.x - target.x
	var dy := attacker.y - target.y
	var ahead := dx * facing.x + dy * facing.y
	var lateral := absi(dx * facing.y - dy * facing.x)
	if ahead > 0 and ahead >= lateral:
		return "front"
	return "back" if ahead < 0 and -ahead > lateral else "side"
