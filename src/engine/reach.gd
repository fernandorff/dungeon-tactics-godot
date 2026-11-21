class_name Reach
## Ranges in cells (split from pathing.gd): whole-tile ranges on half grids, the height bonus and whether a target is
## inside an ability's range.


## ranges and radii in whole tiles, measured in cells on the split map
static func far_cells(g: Grid, r: int) -> int:
	return 0 if r <= 0 else g.sub * (r - 1) + 1


static func near_cells(g: Grid, r: int) -> int:
	return maxi(r, g.sub * (r - 1))


static func whole_tiles(g: Grid, d: int) -> int:
	return Util.ceil_div(d + g.sub - 1, g.sub)


static func max_range(grid: Grid, ability: Dictionary, from: Vector2i, to: Vector2i) -> int:
	var up := maxi(0, Grid.stand_h(grid.tile(from)) - Grid.stand_h(grid.tile(to))) if ability.heightRange else 0
	return far_cells(grid, ability.range[1] + up)


## a melee ability (no flight, reach up to one tile) counts the 8 tiles around (Fernando, Nov 21): the king's distance
static func is_melee(a: Dictionary) -> bool:
	return not a.needsSight and a.range[1] <= 1


static func king(p: Vector2i, q: Vector2i) -> int:
	return maxi(absi(p.x - q.x), absi(p.y - q.y))


## the nearest king's distance between two sets of cells (a melee area, the Spin)
static func king_gap(a: Array, b: Array) -> int:
	var best := 1 << 30
	for p in a:
		for q in b:
			best = mini(best, king(p, q))
	return best


static func reach_dist(a: Dictionary, p: Vector2i, q: Vector2i) -> int:
	return king(p, q) if is_melee(a) else Grid.dist(p, q)


static func in_ability_range(grid: Grid, ability: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	var d := reach_dist(ability, from, to)
	return d >= near_cells(grid, ability.range[0]) and d <= max_range(grid, ability, from, to)
