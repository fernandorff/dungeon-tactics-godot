class_name HudSkin
## The battle HUD's parchment look (port of the web game's ui3d theme and layout): the paper and ink colours measured on
## FFT: The Ivalice Chronicles' menus (style.css --ui3d-*), the serif, and the regions of ui3d/layout.ts. The regions are
## px of the 1920x1080 reference; the port lays out at 1280x720 (project.godot), so every reference px is K of ours.

const K := 2.0 / 3.0
const PAPER := Color("#ece7d4")
const SHADE := Color("#d5cfb9")
const LIT := Color("#f6f1db")
const BAND := Color("#bbb4a2")
const EDGE := Color("#332b1a")
const INK := Color("#474129")
const INK_SOFT := Color("#5b5440")
const INK_OFF := Color("#a9a28e")
# the unit sheets' night blue (a foe's wine) and their gauges (bar3d/plates.ts, turn3d/card.ts)
const NIGHT := Color("#172958")
const NIGHT_LOW := Color("#101a33")
const WINE := Color("#5a3330")
const WINE_LOW := Color("#322827")
const GROOVE := Color("#0a0e16")
const HP := Color("#9cc93a")
const HP_LOW := Color("#5c8213")
const MP := Color("#b34d4b")
const MP_END := Color("#c99a62")
const ST := Color("#c2785a")
const CT := Color("#b89318")
const DROP := Color("#fc563e") # the life a strike may take
const GAIN := Color("#d9f29a") # the life a heal may give
const LIGHT := Color("#f1ebd2") # ink on the night-blue sheets (bar3d.ts INK)
const LIGHT_SOFT := Color("#cfc8b0")
const ENEMY_TAG := Color("#f4aaab")
const WARN := Color("#ff8a70") # a strike on the user's own side
const MOVE_BLUE := Color("#4c8fd6") # the walk marks' blue, on the Move row's gauge
const HERO := Color("#6fb9f5") # the turn numbers: blue for a hero, pink for an enemy
const FOE := Color("#f06b9a")
const MIN_TEXT := 14 # the touch rule: no text under 14 px

# px on the reference, x and y the box's top left (ui3d/layout.ts REGIONS)
const REGIONS := {
	"turn": Rect2(18, 64, 300, 849),
	"sheet": Rect2(100, 818, 672, 214),
	"menu": Rect2(1152, 688, 414, 327),
	"submenu": Rect2(1284, 688, 414, 327),
	"detail": Rect2(1450, 100, 400, 564),
	"height": Rect2(1500, 95, 420, 85),
	"banner": Rect2(650, 80, 620, 78),
	"preview": Rect2(790, 812, 340, 218),
	"target": Rect2(1140, 818, 680, 214),
	"hints": Rect2(1225, 1035, 660, 28),
	"hintsLeft": Rect2(45, 1035, 206, 28),
}

static var _font: SystemFont
static var _paper: Shader


## a reference region in our px
static func region(name: String) -> Rect2:
	var r: Rect2 = REGIONS[name]
	return Rect2(r.position * K, r.size * K)


## a reference length in our px
static func px(v: float) -> float:
	return v * K


## a reference text size in our px, never under the touch rule's floor
static func text(v: float) -> int:
	return maxi(MIN_TEXT, roundi(v * K))


## lets the cached font and shader go before the engine shuts down (static vars outlive the scene tree and the GPU
## textures behind them were reported leaked at exit); the battle HUD calls it when it leaves
static func release() -> void:
	_font = null
	_paper = null
	Icons.release()


## the theme's serif (--font-ui3d): the system's Palatino or its kin, no font file shipped
static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Palatino Linotype", "Palatino", "Book Antiqua", "Georgia", "serif"])
		_font.font_weight = 500
	return _font


static func label(s: String, size: float, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", text(size))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## the parchment material (paper.gdshader); `head`, `foot`, `icon_w` and `rows` in reference px
static func paper(size: Vector2, head: float = 0.0, foot: float = 0.0, icon_w: float = 0.0, rows: Vector3 = Vector3(0, 1, 0), seed: float = 0.0) -> ShaderMaterial:
	if _paper == null:
		_paper = load("res://src/ui/hud/paper.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _paper
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("pad", px(PAD))
	m.set_shader_parameter("unit", K)
	m.set_shader_parameter("head", head)
	m.set_shader_parameter("foot", foot)
	m.set_shader_parameter("icon_w", icon_w)
	m.set_shader_parameter("rows", rows)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("paper", PAPER)
	m.set_shader_parameter("shade", SHADE)
	m.set_shader_parameter("lit", LIT)
	m.set_shader_parameter("edge", EDGE)
	return m


const PAD := 44.0 # the room the paper's shadow takes around it, reference px


## draws the parchment under `c` (call from its _draw): the quad reaches PAD past every side for the shadow
static func draw_paper(c: CanvasItem, size: Vector2) -> void:
	var p := px(PAD)
	c.draw_rect(Rect2(-p, -p, size.x + 2 * p, size.y + 2 * p), Color.WHITE)
