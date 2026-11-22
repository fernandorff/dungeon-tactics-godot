class_name Water
extends Node3D
## The board's water (port of water.ts without its wave physics): the surface with its bands, foam and glints, the
## waterfalls and the cut at the edge, and the river carried on past the map. Each frame it hands the shader where the
## units wade, for the foam collar round their legs.

const COLOR := {"shallow": "#3aa6c4", "mid": "#1f6fa3", "deep": "#173d72", "foam": "#eaf8ff", "side": "#2a6ea3"}
const STREAM := "#1d4f7a"
const BODIES := 8

var _levels: Dictionary
var _surface: ShaderMaterial
var _bodies := PackedVector4Array()
var _origin: Vector2 # the web's map centre, where the shaders measure from


func build(space: TileSpace, river: Dictionary, outside: Dictionary) -> void:
	_levels = space.levels
	var g := space.grid
	var origin := Vector2(-g.width / 2.0, -g.height / 2.0)
	_origin = origin
	_bodies.resize(BODIES)
	_surface = ShaderMaterial.new()
	_surface.shader = load("res://src/ui/scene/water.gdshader")
	for k in ["shallow", "mid", "deep"]:
		_surface.set_shader_parameter(k, Color(COLOR[k]))
	_surface.set_shader_parameter("foam_col", Color(COLOR.foam))
	_surface.set_shader_parameter("origin", origin)
	# drawn before the other see-through pieces: marks, path, cursor and the team rings stay on top of the water
	_surface.render_priority = -1
	_add(WaterMesh.surface(g, _levels, river), _surface)
	var sides := WaterMesh.sides(g, _levels, space.step)
	if sides:
		var fall := ShaderMaterial.new()
		fall.shader = load("res://src/ui/scene/water_fall.gdshader")
		fall.set_shader_parameter("side_col", Color(COLOR.side))
		fall.render_priority = -1
		_add(sides, fall)
	if not outside.is_empty():
		for side in [1, -1]:
			var m := ShaderMaterial.new()
			m.shader = load("res://src/ui/scene/water_stream.gdshader")
			m.set_shader_parameter("water_col", Color(STREAM))
			m.set_shader_parameter("origin", origin)
			m.set_shader_parameter("dir", 1.0 if side == river.dir else -1.0)
			m.render_priority = -1
			_add(stream(space, river, side), m)


func _add(mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## the outside river on one side: a strip over the river rows, EXT_RING tiles long, flat then dropping in rapids; UV is
## (tiles from the edge, steepness), COLOR the ring's tone
static func stream(space: TileSpace, river: Dictionary, side: int) -> ArrayMesh:
	var g := space.grid
	var N := 8
	var z0: int = river.rows.min()
	var z1: int = river.rows.max() + 1
	var nu := TerrainOuter.EXT_RING * N
	var nv := (z1 - z0) * 2
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	for b in nv + 1:
		for a in nu + 1:
			var k := float(a) / N
			var u := g.width + k if side > 0 else -k
			var v := z0 + b / 2.0
			var j := mini(z1 - 1, floori(v))
			var y := TerrainOuter.stream_at(g, space.step, space.levels, river, u + 1e-4 * side, j)
			var y2 := TerrainOuter.stream_at(g, space.step, space.levels, river, u + 0.05 * side, j)
			if is_nan(y2):
				y2 = y
			pos.append(Vector3(u, y + 0.01, v))
			var t := TerrainOuter.ext_tone(floori(k) + 1)
			col.append(Color(t, t, t))
			uv.append(Vector2(k, absf(y2 - y) / 0.05))
	var idx := PackedInt32Array()
	WaterMesh._quads(idx, 0, nu, nv)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	normals.resize(pos.size())
	normals.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## per frame: the units standing below the surface get the foam collar (the first BODIES of them); the shader is only
## told when that changes
func update(units: Dictionary) -> void:
	var n := 0
	var was := _bodies.duplicate()
	for h in units.values():
		var p: Vector3 = (h as Node3D).position
		var lv: Variant = _levels.get(Vector2i(floori(p.x), floori(p.z)))
		if n < BODIES and lv != null and (h as Node3D).visible and p.y < lv.surface - 0.01:
			_bodies[n] = Vector4(p.x + _origin.x, p.z + _origin.y, 1.0, float(n) * 1.7)
			n += 1
	for i in range(n, BODIES):
		_bodies[i] = Vector4.ZERO
	if _bodies != was:
		_surface.set_shader_parameter("bodies", _bodies)
