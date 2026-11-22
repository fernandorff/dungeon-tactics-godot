class_name WaterMesh
## The water's geometry (port of water-mesh.ts): the subdivided surface of the water tiles, with each vertex's place in
## its tile, the banks and corners with land, the depth for the colour bands and the current, and the sides where the
## water drops (arcing waterfalls inside the map, the volume's straight cut at its edge).

const SUB := 8 # squares per cell
const FLOW := {"deep": 0.45, "shallow": 0.3} # cells/s of the river current inside the map
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)] # N, E, S, W
const CORNERS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)] # NE, SE, SW, NW


## the current on the river crossing the map, from its spring to the other side; 0 elsewhere
static func flow_of(river: Dictionary, p: Vector2i, lv: Dictionary) -> float:
	if river.is_empty() or not river.rows.has(p.y):
		return 0.0
	return -river.dir * (FLOW.deep if lv.deep else FLOW.shallow)


## land: a tile without water; a bridge flush with the water lets it through and gets no foam
static func _land(g: Grid, levels: Dictionary, q: Vector2i) -> bool:
	return g.in_bounds(q) and not levels.has(q) and g.tile(q).get("look", "") != "bridge"


## depth for the colour: land 0 (the colour lightens toward the bank), shallow 0.3, deep 1; past the edge, the edge tile's
static func _depth(g: Grid, levels: Dictionary, i: int, j: int) -> float:
	var lv: Variant = levels.get(Vector2i(clampi(i, 0, g.width - 1), clampi(j, 0, g.height - 1)))
	return 0.0 if lv == null else (1.0 if lv.deep else 0.3)


## the surface: UV the place in the tile, COLOR the banks (N, E, S, W), CUSTOM0 the corners, UV2 (depth, current)
static func surface(g: Grid, levels: Dictionary, river: Dictionary) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var edge := PackedColorArray()
	var corner := PackedFloat32Array()
	var idx := PackedInt32Array()
	for key in levels:
		var p: Vector2i = key
		var lv: Dictionary = levels[p]
		var e := Color(0, 0, 0, 0)
		for k in 4:
			e[k] = 1.0 if _land(g, levels, p + DIRS[k]) else 0.0
		var c := [0.0, 0.0, 0.0, 0.0]
		for k in 4:
			c[k] = 1.0 if _land(g, levels, p + CORNERS[k]) else 0.0
		var f := flow_of(river, p, lv)
		var base := pos.size()
		for b in SUB + 1:
			for a in SUB + 1:
				var u := p.x + float(a) / SUB
				var v := p.y + float(b) / SUB
				# smooth depth: the 4 tiles whose middles surround the vertex, bilinear
				var fu := u - 0.5
				var fv := v - 0.5
				var i0 := floori(fu)
				var j0 := floori(fv)
				var tu := fu - i0
				var tv := fv - j0
				var d := (_depth(g, levels, i0, j0) * (1 - tu) + _depth(g, levels, i0 + 1, j0) * tu) * (1 - tv) \
					+ (_depth(g, levels, i0, j0 + 1) * (1 - tu) + _depth(g, levels, i0 + 1, j0 + 1) * tu) * tv
				pos.append(Vector3(u, lv.surface, v))
				nor.append(Vector3.UP)
				uv.append(Vector2(float(a) / SUB, float(b) / SUB))
				edge.append(e)
				corner.append_array(c)
				# the tile's own weight counts: deep next to the bank stays deep in its middle
				var dep: float = maxf(d, 0.8 if lv.deep else 0.3) * (1.0 if lv.deep else minf(1.0, d / 0.3))
				uv2.append(Vector2(dep, f))
		_quads(idx, base, SUB, SUB)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = edge
	arr[Mesh.ARRAY_CUSTOM0] = corner
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return m


## two triangles per square of a cols x rows grid starting at `base`, clockwise from above (Godot's front face)
static func _quads(idx: PackedInt32Array, base: int, cols: int, rows: int) -> void:
	for b in rows:
		for a in cols:
			var v := base + b * (cols + 1) + a
			var n := v + cols + 1
			idx.append_array([v, v + 1, n, v + 1, n + 1, n])


## the visible sides of the water, from the surface down to the bed or to what is in front: UV (along, 1 at the top),
## UV2.x 1 for a waterfall inside the map, 0 for the cut at the edge (which goes one level past the bed)
static func sides(g: Grid, levels: Dictionary, step: float) -> ArrayMesh:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var nor := PackedVector3Array()
	var idx := PackedInt32Array()
	for key in levels:
		var p: Vector2i = key
		var lv: Dictionary = levels[p]
		var x := p.x + 0.5
		var z := p.y + 0.5
		for d in DIRS:
			var q: Vector2i = p + d
			var inside := g.in_bounds(q)
			var ql: Variant = levels.get(q)
			var front: float = -INF if not inside else (ql.surface if ql != null else (g.tile(q).h + 1) * step)
			var bottom: float = maxf(front, lv.bed) if inside else lv.bed - step
			var drop: float = lv.surface - bottom
			if drop < 0.01:
				continue
			var rows := 8 if inside else 1
			var base := pos.size()
			for r in rows + 1:
				var s := float(r) / rows # 0 at the top, 1 at the foot
				# a waterfall leaves the edge with speed and falls (x ∝ √drop, like a jet); 2 mm out of the block face
				var out := 0.502 + (0.22 * sqrt(s) * minf(1.0, drop / step) if inside else 0.0)
				for t in [-0.5, 0.5]:
					pos.append(Vector3(x + d.x * out - d.y * t, lv.surface - s * drop, z + d.y * out + d.x * t))
					uv.append(Vector2(t + 0.5, 1.0 - s))
					uv2.append(Vector2(1.0 if inside else 0.0, 0.0))
					nor.append(Vector3(d.x, 0, d.y))
			_quads(idx, base, 1, rows)
	if pos.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
