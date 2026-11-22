class_name Icons
## The 32 px ability icons (port of the web game's icons.ts): one 6x5 atlas (assets/ui/atlas-32.png) in the order of its
## .json, the abilities, then the Move and Wait commands, then Nov 21's row. The menus and the turn list draw them.

const ATLAS := [
	"strike", "heavy_strike", "shield_bash", "spin", "cleave", "slam", "shot", "aimed_shot", "knock_shot", "dagger",
	"throwing_knife", "stab", "firebolt", "blast", "gust", "heal", "shadow_wave", "deathblow", "trip", "sweep", "lance",
	"lance_jump", "move", "wait", "shove", "sand", "focus",
]
const COLUMNS := 6
const CELL := 32
# the commands' cells: Agir shows the plain strike, Undo the boot it takes back; Status has no cell (a scroll is drawn)
const COMMAND := {"act": "strike", "move": "move", "undo": "move", "wait": "wait"}
# the Agir list's group rows, by what most of their actions look like
const GROUP := {"skills": "cleave", "magic": "firebolt", "items": "heal"}

static var _atlas: Texture2D
static var _cache := {}


## the atlas cell of an ability or command, or (-1, -1) for none (a new ability)
static func cell(id: String) -> Vector2i:
	var n := ATLAS.find(id)
	return Vector2i(-1, -1) if n < 0 else Vector2i(n % COLUMNS, n / COLUMNS)


## the icon of `id` as a texture, null without a cell; one texture per id, shared by every row that shows it
static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var c := cell(id)
	var t: AtlasTexture = null
	if c.x >= 0:
		if _atlas == null:
			_atlas = load("res://assets/ui/atlas-32.png")
		t = AtlasTexture.new()
		t.atlas = _atlas
		t.region = Rect2(c.x * CELL, c.y * CELL, CELL, CELL)
	_cache[id] = t
	return t


static func release() -> void:
	_cache.clear()
	_atlas = null
