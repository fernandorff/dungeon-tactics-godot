class_name Portraits
## The painted battle faces (port of battle-face.ts): the web game's face sheets (assets/faces, one square frame per
## expression, described in content.json `faces`) in the HUD's unit card and turn list. A unit without a sheet (the snake,
## the swarm, the Beacon) shows no face, as the web game's portrait has no image for it.
## shortcut: only neutral and wounded; the timed moods the events start (shout, hurt, smile, angry) need the event
## playback's clock, add them when the HUD follows it

# KayKit model of each unit, as markers.ts MODEL; the Brute uses the barbarian, the Archer the ranger
const MODEL := {
	"warrior": "knight", "archer": "ranger", "mage": "mage", "rogue": "rogue_hooded", "soldier": "skeleton_warrior",
	"skeleton_archer": "skeleton_rogue", "dark_mage": "skeleton_mage", "brute": "barbarian", "minion": "skeleton_minion",
	"mini_skeleton": "skeleton_minion", "colossus": "skeleton_warrior", "lancer": "lancer", "acolyte": "mage",
	"veil_knight": "knight", "snake": "snake", "rat": "rat", "spider": "spider", "bat": "bat",
}
# the sheet goes by the model, except the Warrior: Fernando's battle mapping gives it the barbarian's face
const BY_CLASS := {"warrior": "barbarian"}
const WOUNDED := 0.3 # under 30% of life the face stays wounded

static var _sheets := {} # sheet id -> Texture2D


## the face sheet's id for a unit ("" for none): by its starting class, else by its model
static func sheet_of(def: String) -> String:
	var cls := Roster.class_of(def)
	var base := cls if cls != "" else Content.base_def(def)
	var id: String = BY_CLASS.get(base, "")
	if id == "":
		id = MODEL.get(Content.base_def(def), Content.units.get(def, {}).get("model", ""))
	return id if Content.data.get("faces", {}).has(id) else ""


## the expression shown between reactions: wounded under 30% of life, else neutral
static func expression_of(u: Dictionary) -> String:
	return "wounded" if u.hp < Content.units[u.def].hp * WOUNDED else "neutral"


## a sheet without that expression (the small skeletons have only their mouth) stays on neutral
static func frame_of(face: Dictionary, expr: String) -> int:
	return int(face.get("expressions", {}).get(expr, 0))


## the unit's face at `px` square, crisp (nearest filter, as the web's pixelated strip); null without a sheet
static func face(u: Dictionary, px: int) -> TextureRect:
	var id := sheet_of(u.def)
	if id == "":
		return null
	var f: Dictionary = Content.data.faces[id]
	if not _sheets.has(id):
		_sheets[id] = load("res://assets/faces/%s.webp" % id)
	var sheet: Texture2D = _sheets[id]
	var size := sheet.get_height()
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(frame_of(f, expression_of(u)) * size, 0, size, size)
	var r := TextureRect.new()
	r.texture = at
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	return r
