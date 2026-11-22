class_name ActionSheet
extends Control
## The sheet of the action in focus on the Agir lists (port of the web game's menu3d/sheet.ts): who has it on the head,
## its icon on a tile and its name on a band, then one page at a time (Description, Effects, Cost) under the page's title,
## and the page counter on the foot, whose two halves turn the page back and on (click or touch).

signal turned(dir: int)

const HEAD := 47.0 # reference px
const FOOT := 48.0

var _paper := Control.new()
var _key := 0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_paper.mouse_filter = MOUSE_FILTER_IGNORE
	_paper.draw.connect(func() -> void: HudSkin.draw_paper(_paper, size))
	add_child(_paper)


## `d`: MenuView.sheet's {owner, name, icon, page, pages}
func show_sheet(d: Dictionary) -> void:
	var key := hash([d, Texts.current()])
	if key == _key:
		return
	_key = key
	for c in get_children():
		if c != _paper:
			c.queue_free()
	var r := HudSkin.region("detail")
	size = r.size
	_paper.size = size
	_paper.material = HudSkin.paper(size, HEAD, FOOT, 0.0, Vector3(0, 1, 0), 5.3)
	_paper.queue_redraw()
	_band(Rect2(117, 60, 267, 46), HudSkin.SHADE)
	_band(Rect2(16, 167, 368, 33), HudSkin.BAND)
	_put(HudSkin.label("♦", 22, HudSkin.INK_SOFT), 22, 23)
	_put(HudSkin.label(d.owner, 25, HudSkin.INK_SOFT), 52, 23)
	_put(HudSkin.label(d.name, 28, HudSkin.INK), 126, 83)
	var tile := ColorRect.new()
	tile.color = Color("#b8463a")
	tile.position = Vector2(HudSkin.px(18), HudSkin.px(62))
	tile.size = Vector2.ONE * HudSkin.px(88)
	tile.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tile)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(d.icon)
	icon.texture_filter = TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = tile.size * 0.8
	icon.position = tile.size * 0.1
	tile.add_child(icon)
	var p: Dictionary = d.pages[d.page]
	# on the darkest band only the full ink reads (4.9:1; the soft one 3.6:1)
	_put(HudSkin.label(p.title, 21, HudSkin.INK), 24, 183.5)
	var body := HudSkin.label(p.text, 25, HudSkin.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size.x = HudSkin.px(356)
	body.position = Vector2(HudSkin.px(20), HudSkin.px(208))
	add_child(body)
	var n := HudSkin.label("‹  %d / %d  ›" % [d.page + 1, d.pages.size()], 22, HudSkin.INK_SOFT)
	_put(n, 200, 541)
	n.position.x = (size.x - n.get_minimum_size().x) / 2


func _band(r: Rect2, col: Color) -> void:
	var b := ColorRect.new()
	b.color = col
	b.position = r.position * HudSkin.K
	b.size = r.size * HudSkin.K
	b.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(b)


## a label at reference x with its middle at reference y
func _put(l: Label, x: float, mid: float) -> void:
	add_child(l)
	l.position = Vector2(HudSkin.px(x), HudSkin.px(mid) - l.get_minimum_size().y / 2)


func _gui_input(ev: InputEvent) -> void:
	var press: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	# the foot's halves are the page arrows; a finger's box is 44 px tall about the foot's middle
	if press and ev.position.y > size.y - maxf(HudSkin.px(FOOT), 44.0):
		turned.emit(-1 if ev.position.x < size.x / 2 else 1)
		accept_event()
