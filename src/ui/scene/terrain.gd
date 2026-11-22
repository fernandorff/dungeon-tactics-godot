class_name Terrain
## The smooth painted ground of the open maps (port of terrain.ts; Fernando, Nov 13: "truly smooth terrain" instead of
## blocks that "look like Minecraft"): one mesh where each tile is flat in the middle, where unit, mark and cursor sit,
## and the step becomes a slope in its outer third. It continues EXT_RING tiles outward, darkening to black, with the
## river bed carried on outside. Visuals only: the rules keep reading each tile's height.

const SUB := 6 # subdivisions per cell: the middle 4 of 6 stay flat, the slope takes a third of a cell at each edge
const TEX := ["grass", "leaves", "dirt", "snow", "cliff"]


## a texture of assets/tex (Godot's resource cache shares it between maps)
static func texture(name: String) -> Texture2D:
	return load("res://assets/tex/%s.jpg" % name)


## the ground's height at world (x, z) inside board cell p: the water bed, the stone hill, the ramp, or the flat top
static func inner(space: TileSpace, p: Vector2i, x: float, z: float) -> float:
	var lv: Variant = space.levels.get(p)
	if lv != null:
		return lv.bed
	var t := space.grid.tile(p)
	if Looks.rock(t):
		return (t.h + 3) * space.step
	if Looks.ground(t):
		return space.surface_y(p, x, z)
	return (t.h + 1) * space.step


static func build(space: TileSpace, river: Dictionary, outside: Dictionary) -> MeshInstance3D:
	var g := space.grid
	var W := g.width
	var H := g.height
	var R := TerrainOuter.EXT_RING
	var NX := (W + 2 * R) * SUB
	var NZ := (H + 2 * R) * SUB
	var raw := PackedFloat32Array()
	raw.resize(NX * NZ)
	var paint := PackedColorArray() # grass, leaves, dirt, snow
	paint.resize(NX * NZ)
	var stone := PackedFloat32Array()
	stone.resize(NX * NZ)
	var tone := PackedFloat32Array()
	tone.resize(NX * NZ)
	var outer := {}
	for b in NZ:
		var v := (b + 0.5) / SUB - R
		var j := floori(v)
		for a in NX:
			var u := (a + 0.5) / SUB - R
			var i := floori(u)
			var c := b * NX + a
			var inside := i >= 0 and j >= 0 and i < W and j < H
			var cell := Vector2i(i, j)
			var wet: Variant = outside.get(cell)
			var flowing := TerrainOuter.stream_at(g, space.step, space.levels, river, u, j) if wet != null else NAN
			if inside:
				raw[c] = inner(space, cell, u, v)
			elif wet != null and not is_nan(flowing):
				raw[c] = flowing - (wet.surface - wet.bed)
			else:
				# the same for the 36 sub-cells of an outside cell, and ext_h scans a square of tiles: measured once
				if not outer.has(cell):
					outer[cell] = TerrainOuter.outer_top(g, space.step, river, i, j)
				raw[c] = outer[cell]
			tone[c] = TerrainOuter.ext_tone(0 if inside else TerrainOuter.ring_of(g, i, j))
			var edge := g.tile(Vector2i(clampi(i, 0, W - 1), clampi(j, 0, H - 1)))
			var pt: Array = Looks.PAINT.water if wet != null else Looks.PAINT.get(edge.get("look", "grass"), Looks.PAINT.grass)
			paint[c] = Color(pt[0], pt[1], pt[2], pt[3])
			stone[c] = pt[4]
	# a vertex is the average of the up to 4 sub-cells around it: the edge between two heights becomes a slope
	var VX := NX + 1
	var VZ := NZ + 1
	var pos := PackedVector3Array()
	pos.resize(VX * VZ)
	var col := PackedColorArray()
	col.resize(VX * VZ)
	var uv := PackedVector2Array()
	uv.resize(VX * VZ)
	for b in VZ:
		var b0 := maxi(b - 1, 0)
		var b1 := mini(b, NZ - 1)
		for a in VX:
			var a0 := maxi(a - 1, 0)
			var a1 := mini(a, NX - 1)
			# the up to 4 sub-cells around the vertex; at the mesh's rim a clamped one counts twice, which keeps the average
			var c00 := b0 * NX + a0
			var c01 := b0 * NX + a1
			var c10 := b1 * NX + a0
			var c11 := b1 * NX + a1
			var vi := b * VX + a
			pos[vi] = Vector3(float(a) / SUB - R, (raw[c00] + raw[c01] + raw[c10] + raw[c11]) * 0.25, float(b) / SUB - R)
			col[vi] = (paint[c00] + paint[c01] + paint[c10] + paint[c11]) * 0.25 # the paint weights, read by the shader
			uv[vi] = Vector2((tone[c00] + tone[c01] + tone[c10] + tone[c11]) * 0.25, (stone[c00] + stone[c01] + stone[c10] + stone[c11]) * 0.25)
	var nor := PackedVector3Array()
	nor.resize(VX * VZ)
	var d := 2.0 / SUB
	for b in VZ:
		for a in VX:
			var l := pos[b * VX + maxi(a - 1, 0)].y
			var r := pos[b * VX + mini(a + 1, VX - 1)].y
			var f := pos[maxi(b - 1, 0) * VX + a].y
			var bk := pos[mini(b + 1, VZ - 1) * VX + a].y
			nor[b * VX + a] = Vector3((l - r) / d, 1.0, (f - bk) / d).normalized()
	var idx := PackedInt32Array()
	idx.resize(NX * NZ * 6)
	var w := 0
	for b in NZ:
		for a in NX:
			var v0 := b * VX + a
			var n0 := v0 + VX
			# clockwise seen from above: Godot's front face
			idx[w] = v0
			idx[w + 1] = v0 + 1
			idx[w + 2] = n0
			idx[w + 3] = v0 + 1
			idx[w + 4] = n0 + 1
			idx[w + 5] = n0
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = material(Vector2(-W / 2.0, -H / 2.0))
	return mi


## the ground's shader with the five textures; `origin` moves the texture as the web's map, centred on its origin
static func material(origin: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/ui/scene/terrain.gdshader")
	for n in TEX:
		m.set_shader_parameter("t_" + n, texture(n))
	m.set_shader_parameter("origin", origin)
	return m
