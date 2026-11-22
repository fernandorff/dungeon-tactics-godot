class_name Part3d
extends RefCounted
## A piece of a flat 3D screen (port of the web game's hints3d/hints3d.ts Part): rounded boxes and labels under one
## group, faded together. Boxes draw in priority 30 and texts in 32 (their halo in 31); `lift` raises both.

const SHADER: Shader = preload("res://src/ui/ui3d/box3d.gdshader")

var group := Node3D.new()
var key := ""
var alpha := 0.0
var want := 0.0
var lift := 0
var _boxes: Array[MeshInstance3D] = []
var _texts: Array[Label3D] = []


## a box with its top left at x,y (y down), page px; colours with their alpha
func box(x: float, y: float, w: float, h: float, radius: float, color: Color, edge: Color = Color(0, 0, 0, 0), fade: float = 0.0) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = 30 + lift
	for kv in [["size", Vector2(w, h)], ["radius", minf(radius, minf(w / 2, h / 2))], ["color", _v4(color)], ["edge", _v4(edge)], ["fade", fade], ["alpha", alpha]]:
		mat.set_shader_parameter(kv[0], kv[1])
	var m := MeshInstance3D.new()
	m.mesh = QuadMesh.new()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(w, h, 1)
	m.position = Vector3(x + w / 2, -(y + h / 2), 0)
	_boxes.append(m)
	group.add_child(m)
	return m


## a picture (a key cap) w by h, centred on x,y, page px; it fades with the boxes
func image(tex: Texture2D, x: float, y: float, w: float, h: float) -> MeshInstance3D:
	var m := box(x - w / 2, y - h / 2, w, h, 0, Color(0, 0, 0, 0))
	var mat := m.material_override as ShaderMaterial
	mat.set_shader_parameter("image", tex)
	mat.set_shader_parameter("has_image", 1.0)
	mat.render_priority = 32 + lift # with the texts, over the boxes
	return m


static func _v4(c: Color) -> Vector4:
	return Vector4(c.r, c.g, c.b, c.a)


## a label already made (Text3d.label), centred on x,y
func text(m: Label3D, x: float, y: float) -> Label3D:
	m.position = Vector3(x, -y, 0)
	Text3d.order(m, 32 + lift) # over its boxes (30), the halo clear of them
	Text3d.alpha(m, alpha)
	_texts.append(m)
	group.add_child(m)
	return m


## one step toward `want`; true while it moves
func fade(dt: float) -> bool:
	alpha = Spring3d.ease(alpha, want, dt, 14)
	for m in _boxes:
		(m.material_override as ShaderMaterial).set_shader_parameter("alpha", alpha)
	for m in _texts:
		Text3d.alpha(m, alpha)
	group.visible = alpha > 0.002
	return absf(alpha - want) > 0.004


func clear() -> void:
	for c in group.get_children():
		c.queue_free()
	_boxes.clear()
	_texts.clear()
	key = ""
