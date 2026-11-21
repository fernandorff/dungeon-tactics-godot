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


static func in_ability_range(grid: Grid, ability: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	var d := Grid.dist(from, to)
	return d >= near_cells(grid, ability.range[0]) and d <= max_range(grid, ability, from, to)
