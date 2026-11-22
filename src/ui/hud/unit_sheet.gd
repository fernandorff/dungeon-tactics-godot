class_name UnitSheet
extends Control
## A unit's sheet in the combat bar (port of the web game's bar3d/plates.ts, drawn flat): the portrait in a paper frame
## and the night-blue band beside it, fading out, with the name, life and the first pool over their thick bars, CT over
## a thin one and the second pool in a box, then the class strip. The target's sheet is mirrored, the portrait on the
## right, an enemy's band in wine with the "Enemy" tag on the portrait's foot. While a strike is aimed the life bar shows
## what it takes for sure (solid) and what it may take (blinking). Lengths in reference px of the 672x214 region.

const W := 672.0
const H := 214.0
const PORTRAIT := Vector2(160, 192)

var mirror := false
var _view := {}
var _key := 0
var _face: TextureRect


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(W, H) * HudSkin.K
	set_process(false)


func show_view(v: Dictionary) -> void:
	var key := hash([v, Texts.current()])
	if key == _key:
		return
	_key = key
	_view = v
	visible = not v.is_empty()
	if _face:
		_face.queue_free()
		_face = null
	if v.is_empty():
		set_process(false)
		return
	_face = Portraits.face(v.unit, int(HudSkin.px(PORTRAIT.y)))
	if _face:
		_face.mouse_filter = MOUSE_FILTER_IGNORE
		_face.custom_minimum_size = Vector2.ZERO
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var frame := _portrait_rect().grow(-HudSkin.px(5))
		_face.position = frame.position
		_face.size = frame.size
		_face.clip_contents = true
		add_child(_face)
	var c: Dictionary = v.change
	set_process(c.left != c.up_to)
	queue_redraw()


func _process(_dt: float) -> void:
	queue_redraw() # the part a strike may take blinks


func _portrait_rect() -> Rect2:
	var x := W - PORTRAIT.x if mirror else 0.0
	return Rect2(Vector2(x, 0) * HudSkin.K, PORTRAIT * HudSkin.K)


## x in reference px from the text area's left edge
func _x(v: float) -> float:
	return HudSkin.px((12.0 if mirror else 175.0) + v)


func _draw() -> void:
	if _view.is_empty():
		return
	var v := _view
	var k := HudSkin.K
	var band := Rect2(Vector2(0 if mirror else PORTRAIT.x - 8, 0) * k, Vector2(W - PORTRAIT.x + 8, H) * k)
	var deep: Color = HudSkin.WINE if v.enemy else HudSkin.NIGHT
	var low: Color = HudSkin.WINE_LOW if v.enemy else HudSkin.NIGHT_LOW
	# the band fades out away from the portrait, as the reference's
	var cols := PackedColorArray([Color(deep, 0.95), Color(low, 0.0), Color(low, 0.0), Color(deep, 0.95)])
	if mirror:
		cols = PackedColorArray([Color(low, 0.0), Color(deep, 0.95), Color(deep, 0.95), Color(low, 0.0)])
	draw_polygon(PackedVector2Array([band.position, band.position + Vector2(band.size.x, 0), band.end, band.position + Vector2(0, band.size.y)]), cols)
	var pr := _portrait_rect()
	draw_rect(pr, Color("#684630"))
	draw_rect(pr.grow(-1.5), Color("#efe5c8"))
	draw_rect(pr.grow(-HudSkin.px(5)), Color("#a6b9c6") if not v.enemy else Color("#c8a39a"))
	_text(v.name, _x(5), HudSkin.px(32), 34, HudSkin.LIGHT)
	var hp: Dictionary = v.hp
	var pools: Array = v.pools
	_pair(hp.label, "%d/%d" % [hp.value, hp.max], 5, 237, 92)
	_hp_bar(Rect2(_x(0), HudSkin.px(84), HudSkin.px(240), HudSkin.px(14)), v.change)
	if pools.size() > 0:
		_pair(pools[0].label, "%d/%d" % [pools[0].value, pools[0].max], 257, 487, 92)
		_gauge(Rect2(_x(250), HudSkin.px(84), HudSkin.px(240), HudSkin.px(14)), float(pools[0].value) / maxi(1, pools[0].max), HudSkin.MP, HudSkin.MP_END)
	if not v.ct.is_empty():
		_text("CT", _x(5), HudSkin.px(142), 26, HudSkin.LIGHT)
		_gauge(Rect2(_x(50), HudSkin.px(130), HudSkin.px(135), HudSkin.px(7)), float(v.ct.value) / v.ct.max, HudSkin.CT, HudSkin.CT)
		var s := str(v.ct.value)
		_text(s, _x(237) - _w(s, 26), HudSkin.px(142), 26, HudSkin.LIGHT)
	if pools.size() > 1:
		var box := Rect2(_x(253), HudSkin.px(112), HudSkin.px(234), HudSkin.px(34))
		draw_rect(box, Color("#0d1427", 0.9))
		draw_rect(box, Color("#3a4460", 0.6), false, 1.0)
		_text(pools[1].label, box.position.x + HudSkin.px(8), box.position.y + HudSkin.px(26), 22, HudSkin.LIGHT)
		_gauge(Rect2(box.position.x + HudSkin.px(50), box.position.y + HudSkin.px(14), HudSkin.px(95), HudSkin.px(6)), float(pools[1].value) / maxi(1, pools[1].max), HudSkin.ST, HudSkin.ST)
		var s := "%d/%d" % [pools[1].value, pools[1].max]
		_text(s, box.end.x - HudSkin.px(8) - _w(s, 22), box.position.y + HudSkin.px(26), 22, HudSkin.LIGHT)
	if v.line != "":
		_text(v.line, _x(5), HudSkin.px(190), 22, HudSkin.LIGHT_SOFT)
	if v.tag != "":
		var s: String = v.tag
		draw_rect(Rect2(pr.position.x, pr.end.y - HudSkin.px(30), pr.size.x, HudSkin.px(30)), Color("#3a1216", 0.72))
		_text(s, pr.position.x + (pr.size.x - _w(s, 22)) / 2, pr.end.y - HudSkin.px(8), 22, HudSkin.ENEMY_TAG)


## a label at the left and its value right-aligned at `right` (reference px of the text area), on one baseline
func _pair(label: String, value: String, left: float, right: float, base: float) -> void:
	_text(label, _x(left), HudSkin.px(base) - HudSkin.px(18), 30, HudSkin.LIGHT)
	_text(value, _x(right) - _w(value, 30), HudSkin.px(base) - HudSkin.px(18), 30, HudSkin.LIGHT)


func _w(s: String, ref_size: float) -> float:
	return HudSkin.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, HudSkin.text(ref_size)).x


func _text(s: String, x: float, y: float, ref_size: float, col: Color) -> void:
	var n := HudSkin.text(ref_size)
	draw_string_outline(HudSkin.font(), Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, 3, Color(0, 0, 0, 0.55))
	draw_string(HudSkin.font(), Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, n, col)


func _gauge(r: Rect2, fill: float, a: Color, b: Color) -> void:
	draw_rect(r.grow(1), HudSkin.GROOVE)
	var w := r.size.x * clampf(fill, 0.0, 1.0)
	if w > 0:
		draw_polygon(PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w, r.size.y), r.position + Vector2(0, r.size.y)]), PackedColorArray([a, b, b.darkened(0.25), a.darkened(0.25)]))


## life: green up to what stays for sure; the part a strike may take blinks, the part it takes for sure is solid red (a
## heal's gain in pale green the same way)
func _hp_bar(r: Rect2, c: Dictionary) -> void:
	draw_rect(r.grow(1), HudSkin.GROOVE)
	var w := r.size.x

	_gauge(Rect2(r.position, Vector2(w * c.left, r.size.y)), 1.0, HudSkin.HP, HudSkin.HP_LOW)
	if c.left == c.up_to:
		return
	var part: Color = HudSkin.GAIN if c.gain else HudSkin.DROP
	var maybe := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	var lo: float = c.left
	var mid: float = c.sure
	var hi: float = c.up_to
	# damage: left..sure may stay or go (blinks), sure..up_to goes for sure; a heal: left..sure for sure, sure..up_to may
	var first := Color(part, maybe) if not c.gain else part
	var second := part if not c.gain else Color(part, maybe)
	draw_rect(Rect2(r.position.x + w * lo, r.position.y, w * (mid - lo), r.size.y), first)
	draw_rect(Rect2(r.position.x + w * mid, r.position.y, w * (hi - mid), r.size.y), second)
