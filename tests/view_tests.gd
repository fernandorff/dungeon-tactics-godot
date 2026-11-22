class_name ViewTests
## The battle look's pure parts against the web game's numbers: water heights, the ground's heights and the ring past
## the edge. The reference values come from running the web's own functions on the same map (node, Nov 21).


func _ash() -> Grid:
	return Half.halve(Content.scenarios.ash_wood).grid


func test_water_levels_match_web() -> String:
	# web: waterLevels(halve(ash_wood)) → 96 levels, 24 under a bridge, 80 deep, surfaces + beds = 48.8, 8 raised
	var g := _ash()
	var lv := WaterLevels.of_grid(g, g.level_height)
	var under := 0
	var deep := 0
	var sum := 0.0
	for v in lv.values():
		under += 1 if v.under else 0
		deep += 1 if v.deep else 0
		sum += v.surface + v.bed
	var got := [lv.size(), under, deep, WaterLevels.raised_deep(g).size()]
	return "" if got == [96, 24, 80, 8] and is_equal_approx(sum, 48.8) else "got %s, sum %f" % [got, sum]


func test_ramp_and_water_heights() -> String:
	var tiles: Array = []
	for i in 9:
		tiles.append({"terrain": "floor", "h": 1})
	tiles[4] = {"terrain": "floor", "h": 1, "ramp": [1, 1]} # climbs one level towards +x
	tiles[0] = {"terrain": "floor", "h": 0, "look": "water", "depth": 1}
	var s := TileSpace.new(Grid.from_dict({"width": 3, "height": 3, "tiles": tiles}))
	var mid := s.world(Vector2i(1, 1))
	if not is_equal_approx(mid.y, 2.5 * TileSpace.STEP) or mid.x != 1.5:
		return "ramp middle %s" % mid
	if not is_equal_approx(s.surface_y(Vector2i(1, 1), 2.0, 1.5), 3.0 * TileSpace.STEP):
		return "ramp top edge %f" % s.surface_y(Vector2i(1, 1), 2.0, 1.5)
	if not is_equal_approx(s.stand(Vector2i(0, 0)).y, (1 - WaterLevels.WADE) * TileSpace.STEP):
		return "wading %f" % s.stand(Vector2i(0, 0)).y
	return ""


func test_terrain_flat_middle_and_dark_ring() -> String:
	var g := _ash()
	var s := TileSpace.new(g)
	var river := TerrainOuter.river_of(g, s.levels)
	if river.is_empty() or river.dir != 1:
		return "Ash Wood's river %s" % [river]
	var mi := Terrain.build(s, river, TerrainOuter.river_outside(g, s.step, s.levels, river))
	var arr := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	mi.free()
	var R := TerrainOuter.EXT_RING
	var VX := (g.width + 2 * R) * Terrain.SUB + 1
	if pos.size() != VX * ((g.height + 2 * R) * Terrain.SUB + 1):
		return "vertex count %d" % pos.size()
	# a flat grass cell's middle vertex sits on its top, where the unit stands
	for i in g.tiles.size():
		var p := Vector2i(i % g.width, i / g.width)
		var t := g.tile(p)
		if t.get("look", "") != "grass" or t.has("ramp") or t.terrain != "floor":
			continue
		var same := true
		for q in g.neighbors(p):
			same = same and g.tile(q).h == t.h and not g.tile(q).has("ramp")
		if not same:
			continue
		var v := pos[((p.y + R) * Terrain.SUB + 3) * VX + (p.x + R) * Terrain.SUB + 3]
		if not is_equal_approx(v.y, s.world(p).y) or not is_equal_approx(v.x, p.x + 0.5):
			return "flat cell %s drawn at %s" % [p, v]
		break
	# the corner vertex is 6 rings out: black
	return "" if uv[0].x == 0.0 and uv[VX * (R * Terrain.SUB) + R * Terrain.SUB + 1].x > 0.0 else "ring tone"


func test_unit_heights_like_web() -> String:
	# markers.ts unitHeight: 0.85 standing, the Brute 1.05, doubled on the split map's ½ sheets
	var got := [UnitModels.height_of("warrior"), UnitModels.height_of("brute"), UnitModels.height_of("warrior" + Content.HALF)]
	return "" if got == [0.85, 1.05, 1.7] else "heights %s" % [got]


func test_pack_gestures_reach_the_knight_and_snake_stand_ins() -> String:
	var views := UnitsView.new()
	var holder := Node3D.new()
	var body := UnitModels.body("warrior", holder, views.pack)
	var ap := UnitsView.player(holder)
	var sk: Skeleton3D = body.find_child("Skeleton3D", true, false)
	var walk := ap.get_animation(UnitClips.find(ap, "Walking_A"))
	var bone := String(walk.track_get_path(0)).get_slice(":", 1)
	var err := ""
	if UnitClips.find(ap, "Melee_1H_Attack_Chop") != "pack/Melee_1H_Attack_Chop" or sk.find_bone(bone) < 0:
		err = "pack track on bone '%s'" % bone
	elif not is_equal_approx(UnitModels._box(body).size.y * body.scale.y, 0.85):
		err = "knight not fitted to 0.85"
	holder.free()
	if err != "":
		return err
	holder = Node3D.new()
	UnitModels.body("snake", holder, views.pack)
	ap = UnitsView.player(holder)
	var walking := UnitClips.find(ap, "Walking_A")
	var death := UnitClips.find(ap, "Death_A")
	var strike := UnitClips.find(ap, "Melee_1H_Attack_Chop")
	holder.free()
	return "" if walking == "SnakeArmature|Snake_Walk" and death == "" and strike == "SnakeArmature|Snake_Attack" else "snake %s %s %s" % [walking, death, strike]


func test_water_surface_and_current() -> String:
	var g := _ash()
	var s := TileSpace.new(g)
	var river := TerrainOuter.river_of(g, s.levels)
	var mesh := WaterMesh.surface(g, s.levels, river)
	var n := mesh.surface_get_array_len(0)
	var per := (WaterMesh.SUB + 1) * (WaterMesh.SUB + 1)
	if n != s.levels.size() * per:
		return "surface vertices %d" % n
	# the river flows away from its spring (dir 1: from +x): towards -x, faster where deep
	var row: int = river.rows[0]
	for key in s.levels:
		var p: Vector2i = key
		if p.y == row:
			var f := WaterMesh.flow_of(river, p, s.levels[p])
			if f >= 0.0:
				return "current %f at %s" % [f, p]
	if WaterMesh.flow_of(river, Vector2i(0, row + 100), {"deep": true}) != 0.0:
		return "current off the river"
	# the outside strip: EXT_RING tiles of 8 columns plus one, over the river rows' half steps
	var strip := Water.stream(s, river, 1)
	var rows: int = (river.rows.max() + 1 - river.rows.min()) * 2 + 1
	return "" if strip.surface_get_array_len(0) == rows * (TerrainOuter.EXT_RING * 8 + 1) else "strip"


func test_forest_group_and_large_tree_share_one_mesh_per_footprint() -> String:
	var tile := {"terrain": "forest", "h": 1, "look": "tree"}
	var tiles: Array = []
	for i in 8:
		tiles.append(tile.duplicate())
	tiles[2].tree = 2
	var g := Grid.from_dict({"width": 4, "height": 2, "tiles": tiles})
	var root := Node3D.new()
	BoardTrees.build(TileSpace.new(g), root)
	var centers: Array[Vector3] = []
	for tree: MeshInstance3D in root.get_children():
		centers.append(tree.position)
	root.free()
	if centers != [Vector3(1, 1, 1), Vector3(3, 1, 1)]:
		return "expected one tree centered on each four-cell footprint, got %s" % [centers]
	return ""


func test_bridge_reaches_the_web_banks_in_ash_wood() -> String:
	var root := Node3D.new()
	BoardBridges.new().build(TileSpace.new(_ash()), root)
	var wood: AABB = root.get_child(0).mesh.get_aabb()
	var batches := root.get_child_count()
	root.free()
	# Web bridge.ts, merged planks and beams, shifted from its centered origin to the Godot corner.
	var lo := Vector3(1.970000, 1.080251, 7.727528)
	var hi := Vector3(12.030000, 1.997473, 12.894749)
	return "" if batches == 3 and wood.position.distance_to(lo) < 0.001 and wood.end.distance_to(hi) < 0.001 else "bridge bounds %s" % [wood]
