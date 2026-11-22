class_name Panel3d
## Panels of the 3D UI kit (port of the web game's ui3d/panel.ts): the parchment quad (paper3d.gdshader), the flat
## inset band (band3d.gdshader) and the quad that places either at a box's top left, under a group whose origin is a
## panel's top left (x right, y down). The palette is the theme's (HudSkin, style.css --ui3d-*), as screen colours.

static var _quad := QuadMesh.new()
static var _paper: Shader = preload("res://src/ui/ui3d/paper3d.gdshader")
static var _band: Shader = preload("res://src/ui/ui3d/band3d.gdshader")


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## a quad at x,y (top left) w by h, drawn in `order` (the web's renderOrder)
static func quad(mat: ShaderMaterial, x: float, y: float, w: float, h: float, order: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _quad
	m.material_override = mat
	mat.render_priority = order
	m.scale = Vector3(w, h, 1)
	m.position = Vector3(x + w / 2, -(y + h / 2), 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## `head`, `foot`, `icon_w` and `rows` in px of the 1080p layout (the shader divides by `unit`)
static func paper(w: float, h: float, pad: float, unit: float, seed: float, head: float = 0.0, foot: float = 0.0, icon_w: float = 0.0, rows: Vector3 = Vector3(0, 1, 0)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _paper
	for kv in [["size", Vector2(w, h)], ["pad", pad], ["unit", unit], ["head", head], ["foot", foot], ["icon_w", icon_w], ["rows", rows], ["seed", seed], ["paint", Layer3d.paint], ["paper", _v3(HudSkin.PAPER)], ["shade", _v3(HudSkin.SHADE)], ["lit", _v3(HudSkin.LIT)], ["edge", _v3(HudSkin.EDGE)]]:
		m.set_shader_parameter(kv[0], kv[1])
	return m


static func band(w: float, h: float, unit: float, color: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _band
	m.set_shader_parameter("size", Vector2(w, h))
	m.set_shader_parameter("unit", unit)
	m.set_shader_parameter("color", color)
	return m


static func alpha(m: GeometryInstance3D, a: float) -> void:
	if m is Label3D:
		Text3d.alpha(m as Label3D, a)
	else:
		(m.material_override as ShaderMaterial).set_shader_parameter("alpha", a)
