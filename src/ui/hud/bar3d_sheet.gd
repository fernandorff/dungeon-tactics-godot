class_name Bar3dSheet
extends RefCounted
## A unit sheet of the 3D combat bar (port of the web game's bar3d/bar3d.ts Sheet): the part, its layout, the unit it
## shows and the face on its portrait. The same unit's bars glide to their new values; another unit's land at once.

const INK := Color("#f1ebd2") # light ink on the dark bar, measured on the reference's digits
const SOFT := Color("#cfc8b0") # the labels'
const ENEMY := Color("#f4aaab") # the "Enemy" tag
const SHADER: Shader = preload("res://src/ui/ui3d/sheet3d.gdshader")

var part: Bar3dPart
var view := {}
var _l: Dictionary
var _hp: Array = [1.0, 1.0, 1.0] # the life bar's changed part (its two ends, and where its sure part meets the rest)
var _fill: Array = [0.0, 0.0, 0.0] # first pool, second pool, CT
var _face_of := "" # the def whose face is loaded
var _face := {} # content.json `faces` entry of the loaded sheet
var _frames := 1
var _frame := -1
var _hp_z := 0.0 # 1 while the change is a heal


func _init(mirror: bool, region: String) -> void:
	_l = BarLayout.sheet(mirror)
	part = Bar3dPart.new(SHADER, region, 1.0 if mirror else 0.0)
	var m := part.mat
	var pad := BarLayout.PAD
	m.set_shader_parameter("size", Vector2(_l.w + 2 * pad, _l.h + 2 * pad))
	m.set_shader_parameter("mirror", 1.0 if mirror else 0.0)
	for kv in [["band_box", "band"], ["strip", "strip"], ["portrait", "portrait"], ["hp_bar", "hpBar"], ["pool_bar", "poolBar"], ["ct_bar", "ctBar"], ["box2", "box"], ["box_bar", "boxBar"]]:
		var r: Rect2 = _l[kv[1]]
		m.set_shader_parameter(kv[0], Vector4(r.position.x, r.position.y, r.size.x, r.size.y))


static func _value(g: Dictionary) -> String:
	return "%d/%d" % [g.value, g.max]


static func _frac(g: Variant) -> float:
	return clampf(float(g.value) / g.max, 0.0, 1.0) if g is Dictionary and not g.is_empty() else -1.0


## `v`: BarView.sheet, or {} to fade out
func show(layer: Layer3d, v: Dictionary) -> void:
	part.want = 0.0 if v.is_empty() else 1.0
	if v.is_empty():
		return
	var swap: bool = view.is_empty() or view.unit.id != v.unit.id
	view = v
	var m := part.mat
	m.set_shader_parameter("team", 1.0 if v.enemy else 0.0)
	m.set_shader_parameter("line", 1.0 if v.line != "" else 0.0)
	m.set_shader_parameter("tag", 1.0 if v.tag != "" else 0.0)
	_hp_z = 1.0 if v.change.gain else 0.0
	# another unit: its numbers are there at once, only the same unit's bars glide
	if swap or layer.still:
		_land()
	if _face_of != v.unit.def:
		_set_face(v.unit)
	var l := _l
	part.text(layer, "name", v.name, l.name, INK)
	part.text(layer, "tag", v.tag, l.tag, ENEMY)
	var gap := maxf(6.0, 10.0 * layer.small.s) # a space's width at any page size
	# "+4" starts a space after the label's ink, as drawn
	var hp := part.text(layer, "hpLabel", v.hp.label, l.hpLabel, SOFT)
	var after: Dictionary = l.hpRegen
	if hp:
		after = l.hpRegen.duplicate()
		after.x = (hp.position.x + Text3d.w(hp) / 2 - Text3d.PAD + gap) / layer.small.s
	part.text(layer, "hpRegen", v.hp_regen, after, SOFT)
	part.text(layer, "hpValue", _value(v.hp), l.hpValue, INK)
	var first: Dictionary = v.pools[0] if v.pools.size() > 0 else {}
	var second: Dictionary = v.pools[1] if v.pools.size() > 1 else {}
	part.text(layer, "poolLabel", first.get("label", ""), l.poolLabel, SOFT)
	part.text(layer, "poolValue", _value(first) if first else "", l.poolValue, INK)
	part.text(layer, "boxLabel", second.get("label", ""), l.boxLabel, SOFT)
	part.text(layer, "boxValue", _value(second) if second else "", l.boxValue, INK)
	part.text(layer, "ctLabel", v.ct.get("label", ""), l.ctLabel, SOFT)
	part.text(layer, "ctValue", str(v.ct.value) if v.ct else "", l.ctValue, INK)
	part.text(layer, "line", v.line, l.line, INK)



func _targets(v: Dictionary) -> Array:
	return [[v.change.left, v.change.up_to, v.change.sure], [_frac(v.pools[0] if v.pools.size() > 0 else null), _frac(v.pools[1] if v.pools.size() > 1 else null), _frac(v.ct)]]


func _land() -> void:
	if view.is_empty():
		return
	var to := _targets(view)
	_hp = to[0]
	_fill = to[1]


## the face of a unit on its portrait: its painted sheet's frame, cut to the picture inside the frame, in the unit's glow
## colour when it has one (the HUD's .tinted filter, approximated)
## shortcut: no rendered-portrait fallback (the web's /chars/<model>.webp) for a unit without a face sheet; every model
## with a portrait render has a sheet today, add it with the first unit that has none
func _set_face(u: Dictionary) -> void:
	var m := part.mat
	var tint: String = Content.units[u.def].get("tint", "")
	var c := Color(tint) if tint != "" else Color(0, 0, 0)
	m.set_shader_parameter("tint", Vector4(c.r, c.g, c.b, 0.55 if tint != "" else 0.0))
	m.set_shader_parameter("has_face", 0.0)
	_face_of = u.def
	_frame = -1
	var id := Portraits.sheet_of(u.def)
	_face = Content.data.faces[id] if id != "" else {}
	if _face.is_empty():
		return
	var tex: Texture2D = load("res://assets/faces/%s.webp" % id)
	_frames = maxi(1, roundi(float(tex.get_width()) / tex.get_height()))
	m.set_shader_parameter("face", tex)
	m.set_shader_parameter("has_face", 1.0)


func _crop(frame: int) -> void:
	var p: Rect2 = _l.portrait
	var ratio := (p.size.x - 9) / (p.size.y - 9) # the picture inside the frame
	part.mat.set_shader_parameter("face_uv", Vector4((frame + (1 - ratio) / 2) / _frames, 0, ratio / _frames, 1))


## one step; true while something of it still moves
func step(layer: Layer3d, dt: float, t: float) -> bool:
	var moving := part.step(layer, 10.0 if layer.still else dt)
	if view.is_empty():
		return moving
	var to := _targets(view)
	var glide := func(x: float, goal: float) -> float:
		if goal < 0 or x < 0 or layer.still:
			return goal
		var next := Spring3d.ease(x, goal, dt, 9)
		return goal if absf(next - goal) < 0.002 else next
	for i: int in 3:
		_hp[i] = glide.call(_hp[i], to[0][i])
		_fill[i] = glide.call(_fill[i], to[1][i])
	if _hp != to[0] or _fill != to[1]:
		moving = true
	var m := part.mat
	m.set_shader_parameter("hp", Vector3(_hp[0], _hp[1], _hp_z))
	m.set_shader_parameter("sure", _hp[2])
	m.set_shader_parameter("fill", Vector3(_fill[0], _fill[1], _fill[2]))
	m.set_shader_parameter("time", t)
	if not _face.is_empty():
		var n := Portraits.frame_of(_face, Portraits.expression_of(view.unit))
		if n != _frame:
			_frame = n
			_crop(n)
			layer.wake()
	# the part an aimed strike changes blinks for as long as it shows
	return moving or (not layer.still and part.want > 0 and view.change.up_to > view.change.left)
