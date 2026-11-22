class_name UnitMarks
extends RefCounted
## What a unit carries besides its body (port of groundMarks and the bar of unit-view.ts): the team ring on the ground,
## the white front arrow on maps where facing counts, and the health bar over the head, turned to the camera every frame.
## One instance per battle view: every unit shares its meshes and materials.

const TEAM := {"hero": Color("#3d9bff"), "enemy": Color("#ff4d4d")}
const BAR_Y := 1.15 # over a standing unit; a taller one gets its bar 0.3 over the head
const BAR_W := 0.7
const BAR_H := 0.12 # with 0.06 it partly vanished in the 2 px pixel art
const FILL_W := 0.66

var _ring: ArrayMesh
var _arrow: CylinderMesh
var _quad: QuadMesh
var _mats := {}


func _init() -> void:
	_ring = _annulus(0.34, 0.44, 24)
	_arrow = CylinderMesh.new()
	_arrow.top_radius = 0.0
	_arrow.bottom_radius = 0.16
	_arrow.height = 0.3
	_arrow.radial_segments = 3
	_arrow.rings = 1
	_quad = QuadMesh.new()


## a flat ring, its front face up
static func _annulus(r0: float, r1: float, n: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var a := TAU * i / n
		v.append(Vector3(cos(a) * r0, 0, sin(a) * r0))
		v.append(Vector3(cos(a) * r1, 0, sin(a) * r1))
	for i in n:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## a flat colour; `top` draws over everything (the bar), as the web's depthTest false
func _mat(col: Color, top: bool = false) -> StandardMaterial3D:
	var k := "%s%s" % [col.to_html(), top]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if col.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if top:
			m.no_depth_test = true
			m.render_priority = 10
		_mats[k] = m
	return _mats[k]


func _piece(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## the ring and arrow under `holder` (in a "Ground" node, turned with the unit) and the bar ("Bar", turned to the camera)
func add(holder: Node3D, team: String, size: int, facing: bool, height: float) -> void:
	var col: Color = TEAM.get(team, TEAM.hero)
	var ground := Node3D.new()
	ground.name = "Ground"
	var ring := _piece(_ring, _mat(Color(col, 0.9)), Vector3(0, 0.04, 0))
	ring.scale = Vector3.ONE * size # a big unit's ring surrounds its whole square
	ground.add_child(ring)
	if facing:
		# white: the team colour vanished on marked tiles; only where facing counts, as the face is hard to read from above
		var arrow := _piece(_arrow, _mat(Color.WHITE), Vector3(0, 0.05, 0.5))
		arrow.rotation.x = PI / 2
		arrow.scale = Vector3(1, 1, 0.3)
		ground.add_child(arrow)
	holder.add_child(ground)
	var bar := Node3D.new()
	bar.name = "Bar"
	bar.position.y = maxf(BAR_Y, height + 0.3)
	var bg := _piece(_quad, _mat(Color("#1a1020"), true), Vector3.ZERO)
	bg.scale = Vector3(BAR_W, BAR_H, 1)
	bar.add_child(bg)
	var fill := _piece(_quad, _mat(col, true), Vector3(0, 0, 0.001))
	fill.name = "Fill"
	fill.scale = Vector3(FILL_W, 0.08, 1)
	bar.add_child(fill)
	holder.add_child(bar)


## the bar's fill at `k` of the life, shrinking towards its left end
static func set_life(holder: Node3D, k: float) -> void:
	var fill := holder.get_node_or_null("Bar/Fill") as Node3D
	if fill == null:
		return
	var x := clampf(k, 0.001, 1.0)
	fill.scale.x = FILL_W * x
	fill.position.x = -FILL_W / 2.0 * (1.0 - x)


## ring, arrow and bar shown or hidden (the town has none; a fallen body keeps none)
static func show(holder: Node3D, on: bool) -> void:
	for n in ["Ground", "Bar"]:
		var m := holder.get_node_or_null(n) as Node3D
		if m:
			m.visible = on
