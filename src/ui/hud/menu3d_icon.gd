class_name Menu3dIcon
extends RefCounted
## A model standing on its plate (port of the web game's menu3d/column.ts Icon): a dark disc for a command, a red tile
## for an ability, none for the glove and the emblem. The plate stays flat; the model rests a little turned so its depth
## shows, and sways or spins on top. The meshes are the web's own (tools/export-menu.mjs, assets/ui/menu-models.glb).

const REST := Vector2(0.24, -0.42)
const PRIORITY := Layer3d.DEEP

static var _meshes: Dictionary = {}
static var _shader: Shader = preload("res://src/ui/ui3d/icon3d.gdshader")
static var _hull: Shader = preload("res://src/ui/ui3d/icon3d_hull.gdshader")

var group := Node3D.new()
var model: MeshInstance3D
var _mats: Array[ShaderMaterial] = []


static func mesh(name: String) -> Mesh:
	if _meshes.is_empty():
		var scene: Node = preload("res://assets/ui/menu-models.glb").instantiate()
		for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			_meshes[String(part.name)] = part.mesh
		scene.free()
	return _meshes[name]


## lets the cached meshes go before the engine shuts down (HudSkin.release)
static func release() -> void:
	_meshes.clear()


## `kind`: the model's name in the glb (a flame is flame_<element>); `outline`: the ink hull, in model units
func _init(plate: String, kind: String, outline: float = 0.0) -> void:
	if plate != "":
		group.add_child(_mesh(plate))
	model = _mesh(kind)
	if outline > 0:
		var hull := MeshInstance3D.new()
		hull.mesh = mesh(kind)
		var m := ShaderMaterial.new()
		m.shader = _hull
		m.set_shader_parameter("hull", outline)
		m.render_priority = PRIORITY
		hull.material_override = m
		model.add_child(hull)
	if plate != "":
		model.scale = Vector3.ONE * 0.74
		model.position.z = 0.6 # clear of the plate at any turn
	model.rotation_order = EULER_ORDER_XYZ # three.js's order
	model.rotation = Vector3(REST.x, REST.y, 0)
	group.add_child(model)


func _mesh(kind: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh(kind)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.render_priority = PRIORITY
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mats.append(mat)
	return m


func tone(gray: float, flash: float) -> void:
	for m in _mats:
		m.set_shader_parameter("gray", gray)
		m.set_shader_parameter("flash", flash)


func dispose() -> void:
	if group.get_parent():
		group.get_parent().remove_child(group)
	group.queue_free()
