class_name Hints3d
extends RefCounted
## The instruction banner, the Height corner and the key hints drawn in 3D (port of the web game's hints3d/hints3d.ts),
## a screen of the shared 3D layer (Layer3d) with four parts: the dark pill top centre with what to do now, springing
## in and out; "Height", the number of the tile under the cursor and the line under them, top right, outlined with no
## plate; the tile's own line small below it; and what each key does on this screen, at the foot (HintRows), each key
## a cap drawn by the web's own glyph-art.ts (tools/export-hints.mjs). Each part is rebuilt only when its text or place
## changes. It takes no input: the corner buttons stay in HudHints.

const WHITE := Color("#f4f1e6") # measured on the reference (labs: refs/fft-ivalice, images 17, 19 and 24)
const GREEN := Color("#4daf7c") # the Height number
const PILL := Color(0.15, 0.18, 0.23, 0.88) # #363f48 over the sky: dark slate, a little see-through
const LINE := Color(0.82, 0.86, 0.92, 0.6)

var _layer: Layer3d
var _banner := Part3d.new()
var _height := Part3d.new()
var _tile := Part3d.new()
var _hints := Part3d.new()
var _open := Spring3d.new(0.0) # the banner: 0 away, 1 in place
var _pop := Spring3d.new(1.0) # the Height number's size as it changes
var _num: Label3D
var _at := Vector2.ZERO # the banner's middle: it grows from there
var _last := {}


func _init(layer: Layer3d) -> void:
	_layer = layer
	for p: Part3d in [_banner, _height, _tile, _hints]:
		layer.flat.add_child(p.group)
	layer.add(self)


## `height`: the tile's number, -1 hides the corner; `line`: the tile's line; `banner`: the pill's text, "" for none;
## `hints`: {left, right} of [[caps], text], empty lists for none (a finger, or the hints turned off)
func update(height: int, line: String, banner: String, hints: Dictionary) -> void:
	_last = {"height": height, "line": line, "banner": banner, "hints": hints}
	_draw()


func resize() -> void:
	_draw()


## text in the theme's serif: `size` in px of the reference, never under the game's 16 px on the page; `shadow`:
## outlined, for a text with no plate; `k`: a scale under that floor (a phone's banner)
func _label(words: String, size: float, color: Color, width: float = -1.0, shadow: bool = false, k: float = 1.0) -> Label3D:
	return Text3d.label(_layer, words, _layer.px(size) * k, color, width, -1.0, shadow)


func _draw() -> void:
	if _last.is_empty():
		return
	var st := _layer.stage
	var s := _layer.s
	var at := str([st, _layer.dpr])
	_layer.wake()

	# the banner: without text it keeps what it showed and leaves
	var text: String = _last.banner
	var k := HintsLayout.message_scale(_layer.page.x, _layer.page.y)
	_banner.want = 1.0 if text != "" else 0.0
	_open.to = _banner.want
	if text != "" and text + at != _banner.key:
		if _banner.key != "" and not _layer.still:
			_open.x = 0.5 # a new line on an open pill drops in again from half way
		_banner.clear()
		_banner.key = text + at
		# the pill takes its text's width, up to the region's; a longer line wraps and the pill grows down
		var r := StageLayout.place("banner", st)
		var pad := 50 * s * k
		var m := _label(text, 30, WHITE, -1.0, false, k)
		if Text3d.w(m) > r.size.x - 2 * pad:
			m.free()
			m = _label(text, 30, WHITE, r.size.x - 2 * pad, false, k)
		var w := minf(r.size.x, Text3d.w(m) + 2 * pad)
		var h := maxf(r.size.y * k, Text3d.h(m) + 36 * s * k)
		_at = Vector2(r.position.x + r.size.x / 2, r.position.y + h / 2)
		_banner.box(-w / 2, -h / 2, w, h, 39 * s * k, PILL)
		_banner.text(m, 0, 0)

	# the Height corner (layout-fft-ic.json altura.*): the label from x 1582, the number ending on x 1832, the line under
	# both; each outlined so it reads over a light floor and a dark one
	var n: int = _last.height
	_height.want = 1.0 if n >= 0 else 0.0
	if n >= 0 and str(n) + at != _height.key:
		if _height.key != "" and not _layer.still:
			_pop.x = 1.18 # a new number lands with a small bounce
		_height.clear()
		_height.key = str(n) + at
		var r := HintsLayout.height_box(st, _layer.inset_top)
		_height.box(r.position.x, r.position.y + 82 * s, r.size.x, maxf(1.0, 2 * s), 0, LINE, Color(0, 0, 0, 0), 1.0)
		var name := _label(Texts.t("Altura", "Height"), 24, WHITE, -1.0, true)
		_height.text(name, r.position.x + 82 * s + Text3d.w(name) / 2, r.position.y + 55 * s)
		_num = _label(str(n), 96, GREEN, -1.0, true)
		_height.text(_num, r.position.x + 332 * s - Text3d.w(_num) / 2, r.position.y + 46 * s)

	# the tile line under the Height's line, from the label's x, wrapping at the region's right edge
	var tile: String = _last.line if n >= 0 else ""
	_tile.want = 1.0 if tile != "" else 0.0
	if tile != "" and tile + at != _tile.key:
		_tile.clear()
		_tile.key = tile + at
		var r := HintsLayout.height_box(st, _layer.inset_top)
		var x := r.position.x + 82 * s
		var m := _label(tile, 18, WHITE, r.end.x - x - 16 * s, true)
		_tile.text(m, x + Text3d.w(m) / 2, r.position.y + 92 * s + Text3d.h(m) / 2)

	var lists: Dictionary = _last.hints
	var key := str([lists, Texts.current()]) + at
	_hints.want = 1.0 if lists.get("left", []).size() + lists.get("right", []).size() > 0 else 0.0
	if _hints.want > 0 and key != _hints.key:
		_hints.clear()
		_hints.key = key
		_row(lists.right, "right")
		_row(lists.left, "left")


## one row of hints on its region: each key's cap and its text
func _row(all: Array, align: String) -> void:
	# a phone draws the combat bar smaller (layer.small); the foot's hints follow it with smaller caps
	var phone: bool = _layer.small.s < _layer.stage.s
	var st: Dictionary = _layer.small if phone else _layer.stage
	var s: float = st.s
	var r := StageLayout.place("hints" if align == "right" else "hintsLeft", st)
	var h := maxf(16.0 if phone else 22.0, HintsLayout.ROW.cap * s)
	var mid := r.position.y + r.size.y / 2
	var made: Array = []
	for hint: Array in all:
		var caps: Array = []
		for key: String in hint[0]:
			var tex: Texture2D = load("res://assets/ui/caps/%s.png" % key.to_lower())
			caps.append([tex, h * tex.get_width() / tex.get_height()])
		made.append({"caps": caps, "text": _label(hint[1], HintsLayout.ROW.text, WHITE)})
	var sizes := made.map(func(m: Dictionary) -> Dictionary:
		return {"caps": m.caps.map(func(c: Array) -> float: return c[1]), "text": Text3d.w(m.text)})
	var xs := HintsLayout.lay_row(sizes, r.position.x, r.size.x, align, s)
	for i in made.size():
		for j in made[i].caps.size():
			var c: Array = made[i].caps[j]
			_hints.image(c[0], xs[i].caps[j] + c[1] / 2, mid, c[1], h)
		var m: Label3D = made[i].text
		_hints.text(m, 0, 0)
		Text3d.put(m, xs[i].text + Text3d.w(m) / 2, mid, _layer.dpr)


func frame(dt: float, _t: float) -> bool:
	var still := _layer.still
	var e := 10.0 if still else dt # reduced motion: every ease is already there
	_pop.to = 1.0
	for sp: Spring3d in [_open, _pop]:
		sp.move(dt, still, 210, 19) # a little under critical: it passes its place and settles
	# the banner drops in from a little above, growing; it leaves the same way backwards
	var o := _open.x
	_banner.group.position = Vector3(_at.x, -(_at.y - (1 - o) * 16 * _layer.s), 0)
	_banner.group.scale = Vector3.ONE * (0.9 + 0.1 * o)
	if is_instance_valid(_num):
		_num.scale = Vector3.ONE * _pop.x
	var fading := false
	for p: Part3d in [_banner, _height, _tile, _hints]:
		if p.fade(e):
			fading = true
	return not still and (fading or not _open.settled() or not _pop.settled())
