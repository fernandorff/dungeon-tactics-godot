class_name Board
extends Node3D
## The ground the battle happens on (port of scene/board.ts): the smooth painted terrain on open maps with its water,
## plain blocks on the rest. Built once from the map; after that it only hands the water where the units wade.

var space: TileSpace
var river: Dictionary
var outside: Dictionary # the river's tiles past the map's edge
var water: Water # null on a map without water
var crowns: ShaderMaterial
var _points := PackedVector4Array()


func build(s: TileSpace) -> void:
	space = s
	if not Looks.smooth(space.grid):
		BoardBlocks.build(space, self)
		return
	river = TerrainOuter.river_of(space.grid, space.levels)
	outside = TerrainOuter.river_outside(space.grid, space.step, space.levels, river)
	add_child(Terrain.build(space, river, outside))
	crowns = BoardTrees.build(space, self)
	if crowns:
		_points.resize(64)
	BoardBridges.new().build(space, self)
	if not space.levels.is_empty():
		water = Water.new()
		add_child(water)
		water.build(space, river, outside)


## per frame: what moves on the board (the water's foam collars)
func update(units: Dictionary, camera: Camera3D, marks: PackedVector4Array) -> void:
	if water:
		water.update(units)
	if not crowns:
		return
	var view := camera.get_camera_transform().affine_inverse() * global_transform
	var n := 0
	for unit: Node3D in units.values():
		if unit.visible and n < _points.size():
			var h: float = unit.get_meta("height")
			var p := view * (unit.position + Vector3.UP * h * 0.6)
			_points[n] = Vector4(p.x, p.y, p.z, maxf(0.75, h * 0.75))
			n += 1
	for mark in marks:
		if n == _points.size():
			break
		var p := view * Vector3(mark.x, mark.y, mark.z)
		_points[n] = Vector4(p.x, p.y, p.z, mark.w)
		n += 1
	crowns.set_shader_parameter("count", n)
	crowns.set_shader_parameter("points", _points)
