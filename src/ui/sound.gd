class_name Sound
## The game's sound effects (port of sound.ts): the web's own effect files (assets/sfx, CC0, authors in CREDITS.txt), the
## victory and defeat fanfares and the dialogue's speech blip made from notes (synth.gd). Four volume bars since Nov 21
## (music, interface, world, dialogue), saved in dt:sound; `volume` is the master switch the tests and the shot mode turn
## off. The music bar drives music.gd.

const SOUND_KEY := "dt:sound"
# music on at 25% and effects at 50% by default (Nov 18, Fernando's request); a saved volume of someone who set it wins
const DEFAULT := {"music": 25, "ui": 50, "world": 50, "voice": 50}
# the old save stored 0, 1 or 2 (off, low, loud): 1 and 2 are not multiples of 5, so they become 45% and 100%
const LEGACY := {1: 45, 2: 100}
const INTERFACE := ["cursor", "confirm", "cancel"] # the menus' sounds; every other effect is the world's
const FILE := {
	"cursor": "click", "confirm": "confirm", "cancel": "cancel", "step": "step", "swing": "swing", "throw": "throw",
	"hit": "hit", "miss": "miss", "heal": "heal", "charge": "charge", "spell": "spell", "fire": "fireball", "die": "die",
}
# the sound of each battle event, before its animation (before-event.ts); a move steps and an attack swings apart
const BY_EVENT := {
	"hit": "hit", "bump": "hit", "fall": "hit", "spike": "hit", "miss": "miss", "heal": "heal", "regen": "heal",
	"charge": "charge", "fizzle": "miss", "die": "die",
}
# each ability's effect look (fx.ts LOOKS): what the strike sounds like; an ability not listed looks like Strike
const FX := {
	"strike": "slash", "heavy_strike": "heavy", "shield_bash": "impact", "spin": "spin", "shove": "impact",
	"shot": "arrow", "aimed_shot": "arrow", "knock_shot": "arrow", "sand": "impact", "focus": "heal", "dagger": "stab",
	"firebolt": "fire", "blast": "blast", "shadow_wave": "blast", "gust": "wind", "heal": "heal", "stab": "stab",
	"throwing_knife": "knife", "trip": "impact", "deathblow": "heavy", "cleave": "heavy", "slam": "impact",
	"lance": "stab", "sweep": "impact", "lance_jump": "heavy",
}
const MELEE := ["slash", "heavy", "stab", "impact", "spin", "dash", "debuff"]
const VOICES := 4 # one effect may sound over itself this many times (steps of two walkers, hits of an area)

static var _host: Node
static var _players := {} # effect file -> its AudioStreamPlayer
static var volume := 1.0
static var levels: Dictionary = DEFAULT.duplicate()


## trust boundary for the saved bars (parseSound): whole % from 0 to 100 in steps of 5 or an old 1 or 2, else the
## default; a save from before the split holds one `sfx` bar, which the three effect bars start at
static func parse(raw: Variant) -> Dictionary:
	var r: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var sfx: int = _pct(r.get("sfx"), DEFAULT.world)
	return {"music": _pct(r.get("music"), DEFAULT.music), "ui": _pct(r.get("ui"), sfx), "world": _pct(r.get("world"), sfx), "voice": _pct(r.get("voice"), sfx)}


static func _pct(v: Variant, fallback: int) -> int:
	if typeof(v) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	if LEGACY.has(v):
		return LEGACY[v]
	return int(v) if v >= 0 and v <= 100 and v == int(v) and int(v) % 5 == 0 else fallback


static func load_levels() -> void:
	levels = parse(Store.json(SOUND_KEY))


static func set_level(k: String, pct: int) -> void:
	levels[k] = pct
	Store.set_key(SOUND_KEY, JSON.stringify(levels))
	Music.apply()


## 100% is the web's old "loud" (0.8): the levels measured in dB on the web still hold at maximum
static func gain(pct: int) -> float:
	return volume * pct / 100.0 * 0.8


static func attach(parent: Node) -> void:
	_host = parent
	_players.clear()


## the effect's player, made on first use: one per file, a few voices deep
static func _player(file: String) -> AudioStreamPlayer:
	if not _players.has(file):
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.mp3" % file)
		p.max_polyphony = VOICES
		_host.add_child(p)
		_players[file] = p
	return _players[file]


static func play(kind: String) -> void:
	var g := gain(levels.ui if kind in INTERFACE else levels.world)
	if _host == null or g <= 0.0 or not FILE.has(kind):
		return
	var p := _player(FILE[kind])
	p.volume_db = linear_to_db(g)
	p.play()


## the battle event's own sound (hit, miss, heal, charge, fall); a move's steps and an attack's swing come apart
static func for_event(e: Dictionary) -> void:
	if BY_EVENT.has(e.k):
		play(BY_EVENT[e.k])


## the sound of a strike in the air by the ability's look: a blade swings, fire roars, a spell rings, the rest is thrown
static func attack_kind(ability: String) -> String:
	var fx: String = FX.get(ability, FX.strike)
	if fx in MELEE:
		return "swing"
	if fx == "fire" or fx == "blast":
		return "fire"
	return "spell" if fx in ["heal", "buff", "wind"] else "throw"


## the fanfare at a battle's end, at the world bar
static func jingle(win: bool) -> void:
	_synth(Synth.jingle(win, gain(levels.world) * 0.4))


## one speech beep at the speaker's pitch in Hz, varying a little so it does not sound like an alarm (talk.ts calls it
## per spoken letter). shortcut: the port has no dialogue box yet, so nothing calls it; talk.ts's port will
static func blip(pitch: float) -> void:
	_synth(Synth.blip(pitch * randf_range(0.94, 1.06), gain(levels.voice) * 0.3))


## a made sound plays once on its own player, which goes when it ends
static func _synth(samples: PackedFloat32Array) -> void:
	if _host == null or volume <= 0.0:
		return
	var p := AudioStreamPlayer.new()
	p.stream = Synth.to_wav(samples)
	p.finished.connect(p.queue_free)
	_host.add_child(p)
	p.play()
