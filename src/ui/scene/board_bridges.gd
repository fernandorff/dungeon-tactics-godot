class_name BoardBridges
## Each connected crossing shares a deck and rails, as in bridge.ts.

const PLANK := 0.19
const DECK := 0.07
const RAIL := 0.55

var _seed := 7
var _along_z: bool
var _wood := SurfaceTool.new()
var _posts := SurfaceTool.new()
var _ropes := SurfaceTool.new()


func build(space: TileSpace, parent: Node3D) -> void:
	var g := space.grid
	var seen: Dictionary = {}
	for tool: SurfaceTool in [_wood, _posts, _ropes]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in g.tiles.size():
		var p := Vector2i(i % g.width, i / g.width)
		if seen.has(p) or g.tiles[i].get("look") != "bridge":
			continue
		var bounds := Rect2i(p, Vector2i.ONE)
		var queue: Array[Vector2i] = [p]
		seen[p] = true
		while not queue.is_empty():
			var tile: Vector2i = queue.pop_back()
			bounds = bounds.merge(Rect2i(tile, Vector2i.ONE))
			for n in g.neighbors(tile):
				if not seen.has(n) and g.tile(n).get("look") == "bridge":
					queue.append(n)
					seen[n] = true
		_crossing(g, bounds, (g.tile(p).h + 1) * space.step, space.step)
	if not seen.is_empty():
		_finish(parent, _wood, "wood", Color("#c9a37a"))
		_finish(parent, _posts, "bark", Color("#b08860"))
		_finish(parent, _ropes, "", Color("#c9b07c"))


func _finish(parent: Node3D, tool: SurfaceTool, texture: String, tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	if texture != "":
		mat.albedo_texture = load("res://assets/tex/%s.jpg" % texture)
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = mat
	parent.add_child(instance)


func _random() -> float:
	_seed = (_seed * 16807) % 2147483647
	return _seed / 2147483647.0


func _at(a: float, c: float, y: float) -> Vector3:
	return Vector3(c, y, a) if _along_z else Vector3(a, y, c)


func _dry(g: Grid, p: Vector2i) -> bool:
	return g.in_bounds(p) and not g.tile(p).get("depth", 0) and g.tile(p).get("look") != "bridge"


func _crossing(g: Grid, bounds: Rect2i, top: float, step: float) -> void:
	var low := bounds.position
	var high := bounds.end
	_along_z = _dry(g, low + Vector2i.UP) or _dry(g, Vector2i(low.x, high.y))
	var a0 := low.y if _along_z else low.x
	var a1 := high.y if _along_z else high.x
	var c0 := low.x if _along_z else low.y
	var c1 := high.x if _along_z else high.y
	var mid := (c0 + c1) * 0.5
	var width := c1 - c0 - 0.1
	var start := float(a0)
	var end := float(a1)
	var banks: Array[Vector2i] = []
	for station: int in [a0 - 1, a1]:
		var bank := Vector2i(floori(mid), station) if _along_z else Vector2i(station, floori(mid))
		banks.append(bank)
		if _dry(g, bank) and absf(top - (g.tile(bank).h + 1) * step) < 0.08:
			if station < a0:
				start -= 0.26
			else:
				end += 0.26
	var a := start + 0.02
	while a + PLANK <= end:
		var w := width * (0.96 + 0.04 * _random())
		var shift := _random() * 4
		var pos := _at(a + PLANK / 2, mid + (_random() - 0.5) * 0.06, top - DECK / 2 - _random() * 0.012)
		_plank(Vector3(w, DECK, PLANK), pos, shift, (_random() - 0.5) * 0.05)
		a += PLANK + 0.03
	var beams := [c0 + 0.25, c1 - 0.25]
	if c1 - c0 >= 3:
		beams.insert(1, mid)
	for c: float in beams:
		_plank(Vector3(0.14, 0.14, end - start + 0.3), _at((start + end) / 2, c, top - DECK - 0.07), 0.0, PI / 2)
	for side in 2:
		var bank := banks[side]
		if g.in_bounds(bank):
			var drop: float = top - (g.tile(bank).h + 1) * step
			if drop >= 0.08:
				_approach(a0 if side == 0 else a1, -1 if side == 0 else 1, mid, width, top, drop, g.tile(bank).has("ramp"))
	for side in 2:
		_rail(a0, a1, c0 + 0.04 if side == 0 else c1 - 0.04, top, side == 1 and c1 - c0 >= 3)


func _plank(size: Vector3, pos: Vector3, shift: float, turn: float = 0.0, pitch: float = 0.0) -> void:
	var box := BoxMesh.new()
	box.size = size
	var basis := Basis(Vector3.UP, (0.0 if _along_z else PI / 2) + turn) * Basis(Vector3.RIGHT, pitch)
	var data := box.get_mesh_arrays()
	var positions: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
	for i: int in data[Mesh.ARRAY_INDEX]:
		_wood.set_uv(uvs[i] * Vector2(size.x * 0.5, 0.11) + Vector2(shift, fmod(shift, 1.0)))
		_wood.set_normal(basis * normals[i])
		_wood.add_vertex(pos + basis * positions[i])


func _approach(end: int, dir: int, mid: float, width: float, top: float, drop: float, ramp: bool) -> void:
	if ramp:
		var pitch := atan2(drop, 1)
		var a := 0.02
		while a + PLANK <= 1.0:
			var at := a + PLANK / 2
			var pos := _at(end + dir * at, mid, top - drop * at - DECK / 2 + 0.01)
			_plank(Vector3(width * 0.96, DECK, PLANK / cos(pitch)), pos, _random() * 4, 0.0, dir * (1 if _along_z else -1) * pitch)
			a += PLANK + 0.03
		return
	var n := maxi(2, roundi(drop / 0.13))
	var run := 0.36 / n
	for k in range(1, n + 1):
		var y := top - drop * k / (n + 0.5)
		var a := end + dir * (k - 0.5) * run
		_plank(Vector3(width * 0.9, DECK, run + 0.02), _at(a, mid, y - DECK / 2), _random() * 4)
		for sign_c: int in [-1, 1]:
			var c := mid + sign_c * ((width + 0.1) / 2 - 0.2)
			_plank(Vector3(0.08, y - top + drop + 0.05, 0.08), _at(a, c, (y + top - drop) / 2 - 0.03), 0)


func _rail(start: int, end: int, c: float, top: float, broken: bool) -> void:
	for a in range(start, end + 1):
		var rail := 0.16 + 0.1 * _random() if broken and a > start and a < end else RAIL
		var post := CylinderMesh.new()
		post.top_radius = 0.05
		post.bottom_radius = 0.06
		post.height = rail + 1.2
		post.radial_segments = 6
		post.rings = 0
		_posts.append_from(post, 0, Transform3D(Basis.IDENTITY, _at(a, c, top + rail - post.height / 2 + 0.05)))
		for row in 2:
			var y := top + (RAIL if row == 0 else RAIL * 0.5)
			if broken and (a == start or a == end):
				var dir := 1 if a == start else -1
				var tip := _at(a + dir * (0.3 if row == 0 else 0.16), c + 0.14, top - (0.3 if row == 0 else 0.5))
				_rope(_at(a, c, y), tip, 0.2 if row == 0 else 0.1)
			elif not broken and a > start:
				_rope(_at(a - 1, c, y), _at(a, c, y), 0.08 if row == 0 else 0.06)


func _rope(start: Vector3, end: Vector3, sag: float) -> void:
	var control := (start + end) / 2 + Vector3.DOWN * sag
	var side := (end - start).cross(Vector3.UP).normalized()
	var prev := PackedVector3Array()
	var prev_normals := PackedVector3Array()
	for k in 13:
		var t := k / 12.0
		var a := start.lerp(control, t)
		var b := control.lerp(end, t)
		var center := a.lerp(b, t)
		var up := (b - a).normalized().cross(side)
		var ring := PackedVector3Array()
		var normals := PackedVector3Array()
		for j in 5:
			var angle := j * TAU / 5.0
			var normal := side * cos(angle) + up * sin(angle)
			ring.append(center + normal * 0.018)
			normals.append(normal)
		if k > 0:
			for j in 5:
				var n := (j + 1) % 5
				for idx: int in [j, j + 5, n, n, j + 5, n + 5]:
					_ropes.set_normal(normals[idx - 5] if idx >= 5 else prev_normals[idx])
					_ropes.add_vertex(ring[idx - 5] if idx >= 5 else prev[idx])
		prev = ring
		prev_normals = normals
