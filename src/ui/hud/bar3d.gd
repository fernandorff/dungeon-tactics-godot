class_name Bar3d
extends RefCounted
## The combat bar drawn in 3D (port of the web game's bar3d/bar3d.ts), a screen of the shared 3D layer (Layer3d): the
## acting unit's sheet (portrait, name, life, pools and CT), the strike preview plate in the middle and the target's
## sheet, mirrored, each on its own region of the reference (StageLayout `sheet`, `preview`, `target`).
##   Nothing here decides anything: the HUD hands it the units and forecast, BarView turns them into what to show,
##   BarLayout says where, sheet3d and plate3d paint it and this file moves it. No input: the bar only shows.

const WARN := Color("#ff8a70") # a strike on the user's own side
const PLATE_SHADER: Shader = preload("res://src/ui/ui3d/plate3d.gdshader")

var _layer: Layer3d
var _sheet := Bar3dSheet.new(false, "sheet")
var _target := Bar3dSheet.new(true, "target")
var _plate := Bar3dPart.new(PLATE_SHADER, "preview", -1.0)
var _shown := {}
var _last := {"sheet": {}, "plate": {}, "target": {}} # the last view, shown again when the layer's scale changes


func _init(layer: Layer3d) -> void:
	_layer = layer
	var pad := BarLayout.PAD
	_plate.mat.set_shader_parameter("size", Vector2(BarLayout.PLATE.w + 2 * pad, BarLayout.PLATE.h + 2 * pad))
	for g in [_sheet.part.group, _plate.group, _target.part.group]:
		layer.flat.add_child(g)
	layer.add(self)


## `v`: BarView.of's {sheet, plate, target}, what the HUD's redraw shows
func update(v: Dictionary) -> void:
	_last = v
	_sheet.show(_layer, v.sheet)
	_target.show(_layer, v.target)
	_plate.want = 0.0 if v.plate.is_empty() else 1.0
	var p: Dictionary = v.plate if not v.plate.is_empty() else _shown
	_shown = p
	if not p.is_empty():
		var ink := Bar3dSheet.INK
		_plate.mat.set_shader_parameter("warn", 1.0 if p.warn else 0.0)
		_plate.text(_layer, "chance", p.chance, BarLayout.PLATE.chance, ink)
		_plate.text(_layer, "amount", p.amount, BarLayout.PLATE.amount if p.big else BarLayout.PLATE.amountText, WARN if p.warn else ink)
		_plate.text(_layer, "label", p.label, BarLayout.PLATE.label, WARN if p.warn else ink)
		_plate.text(_layer, "name", p.name, BarLayout.PLATE.name, Bar3dSheet.SOFT)
	_layer.wake()


func resize() -> void:
	for part: Bar3dPart in [_sheet.part, _plate, _target.part]:
		part.fit(_layer)
	update(_last)


func frame(dt: float, t: float) -> bool:
	var a := _sheet.step(_layer, dt, t)
	var b := _target.step(_layer, dt, t)
	var c := _plate.step(_layer, 10.0 if _layer.still else dt)
	return a or b or c
