class_name Paper
## The parchment look of the town windows, the expedition map and the notices (port of the web game's 3D kit tokens,
## style.css --ui3d-*, and the seals of town3d/map-draw.ts): colours, the serif, a sheet with its head band, text set by
## its middle, and the place seals the map and the Information legend share. Drawn with a CanvasItem's draw_* calls.

# the parchment and its ink, measured on FFT: The Ivalice Chronicles' menus
const PAPER := Color("#ece7d4")
const SHADE := Color("#d5cfb9") # head, foot
const BAND := Color("#bbb4a2")
const EDGE := Color("#332b1a") # outline and shadow
const INK := Color("#474129")
const INK_SOFT := Color("#5b5440")
const INK_OFF := Color("#a9a28e")
# the dark frame around the sheets (the result tokens): light text on the darkened screen
const TITLE := Color("#fdebb4")
const TEXT := Color("#dcd5ac")
const SOFT := Color("#a8a184")
const VEIL := Color("#070908")
const DARK_BAND := Color("#151207")
const PLATE := Color("#1e1c18")
const LINE := Color("#736353")
# the town's tokens: the gold of what is open or in focus (light text keeps 4.5:1 on it), the flag, the bars
const GOLD := Color("#7a6126")
const FLAG := Color("#c79a2e")
const TRACK := Color("#2a2619")
const HP := Color("#6fb53a")
const MP := Color("#4c8fd6")
const UP := Color("#2a6426")

static var _font: Font
static var _symbols: Font
static var _para: Font


## the reference's serif from the fonts the system has (the web game loads no font file for it either)
static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino Linotype", "Palatino", "Book Antiqua", "Georgia", "serif"])
		_font = f
	return _font


## the serif with the room between a paragraph's lines (the web sets them 1.3 apart)
static func para_font() -> Font:
	if _para == null:
		var f := FontVariation.new()
		f.base_font = font()
		f.spacing_bottom = 6
		_para = f
	return _para


## the glove and the marks the serif may lack
static func symbols() -> Font:
	if _symbols == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI Emoji", "sans-serif"])
		_symbols = f
	return _symbols


static func width(s: String, size: int, f: Font = null) -> float:
	return (f if f else font()).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## text with its middle on `at.y`; `align` -1 left end, 0 centre, 1 right end at `at.x`; `room` shrinks it to fit
static func say(ci: CanvasItem, s: String, at: Vector2, size: int, col: Color, align: int = -1, room: float = INF, f: Font = null) -> void:
	var fo := f if f else font()
	var w := width(s, size, fo)
	if w > room:
		size = maxi(14, int(size * room / w))
		w = width(s, size, fo)
	var x := at.x - (w if align == 1 else w / 2 if align == 0 else 0.0)
	ci.draw_string(fo, Vector2(x, at.y + (fo.get_ascent(size) - fo.get_descent(size)) / 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## a paragraph wrapped to `w` from its top left; gives back its height
static func para(ci: CanvasItem, s: String, at: Vector2, w: float, size: int, col: Color) -> float:
	var fo := para_font()
	ci.draw_multiline_string(fo, at + Vector2(0, fo.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, w, size, -1, col)
	return fo.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, size).y


static func box(ci: CanvasItem, r: Rect2, col: Color, radius: float = 0, edge: Color = Color.TRANSPARENT, line: float = 0) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 12
	if edge.a > 0:
		s.border_color = edge
		s.set_border_width_all(maxi(1, int(line)))
	ci.draw_style_box(s, r)


## a parchment sheet: its shadow, the paper, the darker head band of `head` px and the worn edge
static func sheet(ci: CanvasItem, r: Rect2, head: float = 0, foot: float = 0) -> void:
	box(ci, Rect2(r.position + Vector2(4, 8), r.size), Color(0, 0, 0, 0.45), 6)
	box(ci, r, PAPER, 4, Color(EDGE, 0.55), 2)
	if head > 0:
		box(ci, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, head - 2)), SHADE, 3)
		ci.draw_line(r.position + Vector2(2, head), r.position + Vector2(r.size.x - 2, head), Color(EDGE, 0.25), 2)
	if foot > 0:
		box(ci, Rect2(r.position.x + 2, r.end.y - foot, r.size.x - 4, foot - 2), SHADE, 3)


## A place's seal (map-draw.ts): round for a room, square for the chest; gold while open, sunk once cleared, an empty
## pale ring when no way leads there any more, on its shade except when skipped. `glyph` on it, or the kind's drawing
static func seal(ci: CanvasItem, mid: Vector2, size: float, state: String, kind: String, glyph: String) -> void:
	var r := Rect2(mid - Vector2(size, size) / 2, Vector2(size, size))
	var round := 9.0 if kind == "chest" else size / 2
	var body: Color = {"open": GOLD, "cleared": BAND, "ahead": SHADE, "skipped": Color.TRANSPARENT}.get(state, SHADE)
	if state != "skipped":
		box(ci, Rect2(r.position + Vector2(2, 5), r.size), Color(EDGE, 0.3), round)
	box(ci, r, body, round, INK_OFF if state == "skipped" else EDGE, 3 if state == "open" else 2)
	var hex: Color = {"open": TITLE, "cleared": UP, "skipped": INK_SOFT}.get(state, INK)
	if glyph != "":
		say(ci, glyph, mid, maxi(21, int(size / 2)), hex, 0, INF, symbols() if glyph in ["✓", "✕"] else null)
	elif kind == "boss":
		sword(ci, mid, size * 0.6, TITLE if state == "open" else INK)
	else:
		gem(ci, mid, size * 0.6, TITLE if state == "open" else INK)


static func gem(ci: CanvasItem, mid: Vector2, size: float, col: Color) -> void:
	var h := size / 2
	ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -h), mid + Vector2(h * 0.75, 0), mid + Vector2(0, h), mid + Vector2(-h * 0.75, 0)]), col)
	ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -h * 0.5), mid + Vector2(h * 0.35, 0), mid + Vector2(0, h * 0.5), mid + Vector2(-h * 0.35, 0)]), Color(PAPER, 0.55))


## a sword point down-left to up-right, as the boss's low-poly icon stands
static func sword(ci: CanvasItem, mid: Vector2, size: float, col: Color) -> void:
	var d := Vector2(1, -1).normalized()
	var n := Vector2(d.y, -d.x)
	var tip := mid + d * size * 0.5
	var hilt := mid - d * size * 0.2
	ci.draw_colored_polygon(PackedVector2Array([hilt + n * size * 0.07, tip, hilt - n * size * 0.07]), col)
	ci.draw_line(hilt + n * size * 0.2, hilt - n * size * 0.2, col, size * 0.08)
	ci.draw_line(hilt, mid - d * size * 0.45, col, size * 0.09)


## the party's flag: its pole from `top` down and its cloth
static func flag(ci: CanvasItem, top: Vector2, h: float = 40) -> void:
	ci.draw_rect(Rect2(top, Vector2(4, h)), EDGE)
	box(ci, Rect2(top + Vector2(4, 0), Vector2(h * 0.6, h * 0.4)), FLAG, 2, EDGE, 2)


## the pointing glove at the left of `at` (a rect), its finger on the rect's middle
static func glove(ci: CanvasItem, at: Rect2, size: float) -> void:
	var f := symbols()
	var s := int(size)
	var p := Vector2(at.position.x - width("☞", s, f) - 4, at.get_center().y + (f.get_ascent(s) - f.get_descent(s)) / 2)
	ci.draw_string_outline(f, p, "☞", HORIZONTAL_ALIGNMENT_LEFT, -1, s, 3, EDGE)
	ci.draw_string(f, p, "☞", HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color.WHITE)
