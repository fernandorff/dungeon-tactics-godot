class_name StageLayout
## Where each piece of the battle interface sits (port of the web game's ui3d/layout.ts): the regions measured on the
## 1920x1080 reference, the edge or corner each holds on to, the stage the regions anchor in (edges or frame), and the
## smallest text a 3D piece draws. Pure; replayed against the web's numbers in tests/menu_tests.gd.

const SCREEN := Vector2(1920, 1080) # the reference
const MIN_SCALE := 0.6
const NARROW_SCALE := 1.0 / 3.0
const TABLET_SIDE := 600.0
const TABLET_TEXT := 14.0
const PHONE_TEXT := 9.0

# px on the reference, x and y the box's top left; `at`: top, middle or bottom, then left, centre or right
const REGIONS := {
	"turn": {"at": "ml", "x": 18, "y": 64, "w": 300, "h": 849},
	"sheet": {"at": "bl", "x": 100, "y": 818, "w": 672, "h": 214},
	"menu": {"at": "br", "x": 1152, "y": 688, "w": 414, "h": 327},
	"submenu": {"at": "br", "x": 1284, "y": 688, "w": 414, "h": 327},
	"detail": {"at": "tr", "x": 1450, "y": 100, "w": 400, "h": 564},
	"height": {"at": "tr", "x": 1500, "y": 95, "w": 420, "h": 85},
	"banner": {"at": "tc", "x": 650, "y": 80, "w": 620, "h": 78},
	"preview": {"at": "bc", "x": 790, "y": 812, "w": 340, "h": 218},
	"target": {"at": "br", "x": 1140, "y": 818, "w": 680, "h": 214},
	"bar": {"at": "bc", "x": 100, "y": 812, "w": 1720, "h": 220},
	"hints": {"at": "br", "x": 1225, "y": 1035, "w": 660, "h": 28},
	"hintsLeft": {"at": "bl", "x": 45, "y": 1035, "w": 206, "h": 28},
	"result": {"at": "mc", "x": 213, "y": 485, "w": 1497, "h": 340},
}

# the page's own text floor, set on each fit (the web's setPageFloor), so every piece's text follows it
static var least := 0.0


static func page_floor(w: float, h: float, coarse: bool = false) -> float:
	if minf(w, h) >= TABLET_SIDE and not (w >= 1152 and h >= 648):
		return TABLET_TEXT
	return PHONE_TEXT if coarse and minf(w, h) < TABLET_SIDE else 0.0


static func set_page_floor(w: float, h: float, coarse: bool = false) -> void:
	least = page_floor(w, h, coarse)


## the smallest text a 3D piece draws, in page px: 16 down to MIN_SCALE, shrinking with the pieces under it, never
## under the page's floor
static func text_px(size: float, s: float, floor_px: float = 16.0, page: float = -1.0) -> float:
	var p := least if page < 0 else page
	return maxf(maxf(minf(floor_px, p), floor_px * minf(1.0, s / MIN_SCALE)), size * s)


## the box the regions anchor in, in page px, and the scale of one reference px: {x, y, w, h, s}
static func stage(w: float, h: float, mode: String = "edges", safe: Vector2 = Vector2.ZERO) -> Dictionary:
	var fit := minf(w / SCREEN.x, h / SCREEN.y)
	if mode == "frame":
		return {"x": (w - SCREEN.x * fit) / 2, "y": (h - SCREEN.y * fit) / 2, "w": SCREEN.x * fit, "h": SCREEN.y * fit, "s": fit}
	var iw := w - 2 * safe.x
	var ih := h - 2 * safe.y
	var s:= maxf(minf(iw / SCREEN.x, ih / SCREEN.y), minf(MIN_SCALE, maxf(NARROW_SCALE, iw / SCREEN.x)))
	return {"x": safe.x, "y": safe.y, "w": iw, "h": ih, "s": s}


# one axis: the distance to the near edge (or to the middle) is the reference's, times the scale
static func _along(at: String, from: float, size: float, v: float, ref: float, s: float) -> float:
	if at == "t" or at == "l":
		return from + v * s
	if at == "b" or at == "r":
		return from + size - (ref - v) * s
	return from + size / 2 + (v - ref / 2) * s


## a region on the page
static func place(name: String, st: Dictionary) -> Rect2:
	return place_box(REGIONS[name], st)


## a box given as a region ({at, x, y, w, h}) on the page
static func place_box(r: Dictionary, st: Dictionary) -> Rect2:
	return Rect2(_along(r.at[1], st.x, st.w, r.x, SCREEN.x, st.s), _along(r.at[0], st.y, st.h, r.y, SCREEN.y, st.s), r.w * st.s, r.h * st.s)
