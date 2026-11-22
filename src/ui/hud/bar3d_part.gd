class_name Bar3dPart
extends RefCounted
## One of the 3D combat bar's three parts (port of the web game's bar3d/bar3d.ts Part): a quad on its region and the
## texts over it. It keeps what it last showed while it fades out; it fades and slides in from its side.

const SLIDE := 26.0 # reference px a part travels as it comes in
const TEXT_ORDER := 6 # the web's renderOrder of the bar's texts: over its quads

var group := Node3D.new()
var mesh := MeshInstance3D.new()
var mat := ShaderMaterial.new()
var alpha := 0.0
var want := 0.0
var region: String
var from: float # the side it slides in from: -1 left, 1 right, 0 none
var _texts := {} # id -> {key, l}
var _at := Vector2.ZERO


func _init(shader: Shader, region_name: String, side: float) -> void:
	region = region_name
	from = side
	mat.shader = shader
	mesh.mesh = QuadMesh.new()
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(mesh)
	group.visible = false


## a text on its spot (BarLayout); an unchanged one keeps its label. Null for an empty text
func text(layer: Layer3d, id: String, words: String, sp: Dictionary, color: Color) -> Label3D:
	# never under the game's smallest text (design system, section 8)
	var px := StageLayout.text_px(sp.size, layer.small.s)
	var key := str([words, px, color, layer.dpr])
	var old: Dictionary = _texts.get(id, {})
	if old.get("key", "") != key:
		if not old.is_empty():
			old.l.queue_free()
		_texts.erase(id)
		if words == "":
			return null
		var l := Text3d.label(layer, words, px, color)
		Text3d.order(l, TEXT_ORDER)
		Text3d.alpha(l, alpha)
		group.add_child(l)
		_texts[id] = {"key": key, "l": l}
	if not _texts.has(id):
		return null
	var m: Label3D = _texts[id].l
	var at := BarLayout.hang(sp, m.get_meta("w"), layer.small.s, Text3d.PAD)
	m.scale = Vector3(at.k, at.k, 1)
	Text3d.put(m, at.x, sp.y * layer.small.s, layer.dpr)
	return m


## the quad over its region, PAD reference px larger on every side
func fit(layer: Layer3d) -> void:
	var b := StageLayout.place(region, layer.small)
	var s: float = layer.small.s
	mesh.scale = Vector3(b.size.x + 2 * BarLayout.PAD * s, b.size.y + 2 * BarLayout.PAD * s, 1)
	mesh.position = Vector3(b.size.x / 2, -b.size.y / 2, 0)
	mat.set_shader_parameter("unit", s)
	_at = b.position


## one step: fades toward `want`, slid aside while it is not all there. True while it moves
func step(layer: Layer3d, e: float) -> bool:
	alpha = Spring3d.ease(alpha, want, e, 14)
	if absf(alpha - want) < 0.004:
		alpha = want
	group.visible = alpha > 0
	mat.set_shader_parameter("alpha", alpha)
	for t: Dictionary in _texts.values():
		Text3d.alpha(t.l, alpha)
	var off: float = from * SLIDE * layer.small.s * (1 - alpha)
	group.position = Vector3(_at.x + off, -_at.y, 0)
	return alpha != want
