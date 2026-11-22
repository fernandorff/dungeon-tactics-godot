class_name Turn3dTip
extends RefCounted
## The name, life and CT of the turn list's card under the mouse (port of the web game's turn3d/card-tip.ts), beside it
## on a dark plate in the result's dark tokens (style.css --ui3d-result-*). Turn3d says where its left end and middle go.

const TEXT := Color("#dcd5ac") # --ui3d-result-text
const PLATE := Color("#1e1c18") # --ui3d-result-plate
const LINE := Color("#736353") # --ui3d-result-line

var _part := Part3d.new()
var group := _part.group


func _init() -> void:
	_part.lift = 10 # over the hovered card (3) and its lines


## `words`: what to say, or "" for nothing; `x`: its left end; `y`: its middle; page px. Built again only when the words change
func show(layer: Layer3d, words: String, x: float, y: float) -> void:
	_part.want = 1.0 if words != "" else 0.0
	if words == "":
		return
	group.position = Vector3(roundf(x), -roundf(y), 0)
	var key := str([words, layer.dpr, layer.s])
	if key == _part.key:
		return
	_part.clear()
	_part.key = key
	var m := Text3d.label(layer, words, StageLayout.text_px(16, 1.0), TEXT) # the game's 16 px, as the HTML tip's --fs-sm
	var w := Text3d.w(m) + 20
	var h := Text3d.h(m) + 8
	_part.box(0, -h / 2, w, h, 6, Color(PLATE, 0.96), Color(LINE, 0.9))
	_part.text(m, w / 2, 0)


func frame(e: float) -> bool:
	return _part.fade(e)
