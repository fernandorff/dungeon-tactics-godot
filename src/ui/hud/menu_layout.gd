class_name MenuLayout
## Where the 3D command menu sits (port of the web game's menu3d/menu-layout.ts): the menu, the list that cascades over
## it, the action sheet and its two page arrows, from the stage (StageLayout.stage). One layout for what is drawn and for
## the buttons over it. Boxes are Rect2 in page px. Pure; replayed against the web's numbers in tests/menu_tests.gd.

# px on the 1920x1080 reference: a column's head, rows, icon column and plates, the glove's room and the sheet's foot
const HEAD := 42.0
const ROW := 56.5
const FOOT := 2.0
const ICON_W := 55.0
const ICON := 40.0
const HAND := 62.0
const SHEET_FOOT := 48.0
const LEAD := 1284.0 - 1152.0 # how far the submenu starts over the menu (the cascade)
const TAP := 44.0 # the touch target
const TOUCH_ROOM := 700.0 # page px of height per unit of the columns' scale


## on touch the columns keep the smallest full scale wherever the page is tall enough for them
static func touch_scale(st: Dictionary) -> float:
	return maxf(st.s, minf(StageLayout.MIN_SCALE, st.h / TOUCH_ROOM))


static func _tall(n: int, cs: float) -> float:
	return (HEAD + n * ROW + FOOT) * cs


## {cs, main, sub, sheet, prev, next}. Each column is as tall as its own list, standing on the menu region's foot; on a
## short page the sheet reaches past the columns' top and they step left of it, never over the acting unit's sheet.
## `corner`: a phone's corner, the y the columns stand on (corner_layout)
static func layout(st: Dictionary, rows: int, sub_rows: int, touch: bool = false, corner: float = NAN) -> Dictionary:
	if not is_nan(corner):
		return corner_layout(st, rows, sub_rows, corner)
	var s: float = st.s
	var cs := touch_scale(st) if touch else s
	var scaled := st.duplicate()
	scaled.s = cs
	var at := StageLayout.place("menu", scaled)
	var h := _tall(rows, cs)
	var page := StageLayout.place("detail", st)
	var sheet := Rect2(page.position.x, maxf(st.y + 72, page.position.y), page.size.x, page.size.y) # under the help line
	var low := sheet.end.y > at.position.y
	var x := minf(at.position.x, sheet.position.x - 8 * s - LEAD * cs - at.size.x) if low else at.position.x
	# the acting sheet's right end and a gap; a page too narrow for both lets the menu stay on it
	var r: Dictionary = StageLayout.REGIONS.sheet
	var end: float = st.x + (r.x + r.w + 8) * s
	var bar := end if end + at.size.x <= st.x + st.w else 0.0
	var main := Rect2(maxf(maxf(st.x + HAND * cs, bar), x), at.end.y - h, at.size.x, h)
	var lead := maxf(0.0, minf(LEAD * cs, sheet.position.x - 8 * s - at.size.x - main.position.x)) if low else LEAD * cs
	# the page arrows: each half of the foot; a finger's box is 44 px tall about the foot's middle
	var fh := maxf(SHEET_FOOT * s, TAP if touch else 0.0)
	var fy := sheet.end.y - (SHEET_FOOT * s + fh) / 2
	var sub_h := _tall(sub_rows, cs)
	return {
		"cs": cs,
		"main": main,
		"sub": Rect2(main.position.x + lead, main.end.y - sub_h, main.size.x, sub_h),
		"sheet": sheet,
		"prev": Rect2(sheet.position.x, fy, sheet.size.x / 2, fh),
		"next": Rect2(sheet.position.x + sheet.size.x / 2, fy, sheet.size.x / 2, fh),
	}


## a phone's fixed corners: the menu in the combat bar's bottom right corner, 44 px rows where the page has the height,
## never over the Height panel; the submenu replaces it in the same box and the sheet sits left of the columns
static func corner_layout(st: Dictionary, rows: int, sub_rows: int, foot: float) -> Dictionary:
	var s: float = st.s
	var top := StageLayout.place("height", st)
	# the tile's coordinates line hangs about 56 reference px under the Height region
	var room := foot - (top.end.y + (56 + 8) * s)
	var cs := minf(TAP / ROW, room / (HEAD + maxi(rows, sub_rows) * ROW + FOOT))
	var w: float = StageLayout.REGIONS.menu.w * cs
	var x: float = st.x + st.w - w
	var page := StageLayout.place("detail", st)
	var sheet := Rect2(x - 8 * s - page.size.x, maxf(st.y + 72, page.position.y), page.size.x, page.size.y)
	var fh := maxf(SHEET_FOOT * s, TAP)
	var fy := sheet.end.y - (SHEET_FOOT * s + fh) / 2
	return {
		"cs": cs,
		"main": Rect2(x, foot - _tall(rows, cs), w, _tall(rows, cs)),
		"sub": Rect2(x, foot - _tall(sub_rows, cs), w, _tall(sub_rows, cs)),
		"sheet": sheet,
		"prev": Rect2(sheet.position.x, fy, sheet.size.x / 2, fh),
		"next": Rect2(sheet.position.x + sheet.size.x / 2, fy, sheet.size.x / 2, fh),
	}


## row `i` of a column, in page px
static func row_box(col: Rect2, i: int, s: float) -> Rect2:
	return Rect2(col.position.x, col.position.y + (HEAD + i * ROW) * s, col.size.x, ROW * s)
