class_name Rings
## The dotted outlines on the ground (port of range-ring.ts and the ring of turn-marks.ts): gold around the tiles the
## acting unit's longest range reaches, blue around the cells it can still walk over (Fernando, Nov 21: "a blue preview
## of the movement too"). The cell sets are pure; `outline` builds the mesh the battle view lays on the map.

const RANGE := Color("#ffd27a")
const WALK := Color("#6ab0ff")
const LIFT := 0.06 # over the tiles' marks (0.04) and under the path (0.07)
const HALF_W := 0.07 # half width of a dash: the web's 0.035 of a whole tile, and a cell here is half a tile wide


## the farthest-reaching ability of the acting unit, in whole tiles
static func longest_range(b: Battle) -> int:
	var most := 0
	for id in Content.units[b.actor().def].abilities:
		most = maxi(most, Content.abilities[id].range[1])
	return most


## the cells the unit's body would cover from every spot it can still end its move on, its own included; none once it
## cannot walk
static func walk_cells(b: Battle) -> Dictionary:
	var out := {}
	var spots: Array = b.reach().values()
	if spots.is_empty():
		return out
	var size: int = Content.units[b.actor().def].get("size", 1)
	for c in Pathing.footprint(b.actor()):
		out[c] = true
	for r in spots:
		for c in Pathing.cells_of(r.pos, size):
			out[c] = true
	return out


## the cells whose whole tile is within `range` cells of the unit's cells `from`, measured like the rule
static func ring_cells(grid: Grid, from: Array[Vector2i], range: int) -> Dictionary:
	var out := {}
	var k := maxi(1, grid.sub)
	for y in grid.height:
		for x in grid.width:
			var tile := Pathing.cells_of(Vector2i(x - x % k, y - y % k), k)
			if Pathing.gap(from, tile) <= range:
				out[Vector2i(x, y)] = true
	return out


## where the rings go on this screen: on the menu the gold ring round the unit and the blue walk outline; choosing where
## to move, the gold ring round the cursor when the move can end there (to see where the strike reaches from it)
static func of_screen(b: Battle, screen: Dictionary, cursor: Vector2i) -> Dictionary:
	var at: Variant = null
	if screen.k == "menu":
		at = b.actor().pos
	elif screen.k == "map" and b.reach().has(Grid.pos_key(cursor)):
		at = cursor
	if at == null:
		return {}
	var size: int = Content.units[b.actor().def].get("size", 1)
	var out := {"range": ring_cells(b.grid, Pathing.cells_of(at, size), Reach.far_cells(b.grid, longest_range(b)))}
	if screen.k == "menu":
		out.walk = walk_cells(b)
	return out


## the outline of `cells` on the ground: each side of a cell that touches an outside cell becomes 3 short flat dashes
static func outline(view: BattleView, cells: Dictionary, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector2i in cells:
		var y := view.top_of(p) + LIFT
		for side in [[Vector2i(0, -1), Vector2(0, 0), Vector2(1, 0)], [Vector2i(0, 1), Vector2(0, 1), Vector2(1, 1)], [Vector2i(-1, 0), Vector2(0, 0), Vector2(0, 1)], [Vector2i(1, 0), Vector2(1, 0), Vector2(1, 1)]]:
			if cells.has(p + side[0]):
				continue
			var a: Vector2 = Vector2(p) + side[1]
			var e: Vector2 = Vector2(p) + side[2]
			var n := (e - a).orthogonal().normalized() * HALF_W
			for k in 3:
				var d0 := a.lerp(e, (k + 0.2) / 3.0)
				var d1 := a.lerp(e, (k + 0.8) / 3.0)
				for q in [d0 + n, d0 - n, d1 + n, d1 + n, d0 - n, d1 - n]:
					st.add_vertex(Vector3(q.x, y, q.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi
