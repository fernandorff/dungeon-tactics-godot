class_name Sound
## The interface's short sounds (cursor, confirm, cancel, hit), made at run time as plain tones so the port needs no audio
## files. Four volume bars as in sound.ts since Nov 21 (music, interface, world, dialogue), saved in dt:sound; `volume` is
## the master switch the test runner and the shot mode turn off.
## shortcut: synthesized beeps stand in for the web game's sound effects, swap for real samples when assets come over;
## the port has no music or speech yet, so those two bars are only kept for when they come

const SOUND_KEY := "dt:sound"
const OLD_KEY := "dt:sfx" # the single effects bar before the split, 0 to 1
const DEFAULT := {"music": 25, "ui": 50, "world": 50, "voice": 50}
const INTERFACE := ["cursor", "confirm", "cancel"] # the menus' sounds; every other one is the world's
const TONES := {"cursor": [880.0, 0.04], "confirm": [1320.0, 0.07], "cancel": [440.0, 0.08], "hit": [180.0, 0.1]}

static var _player: AudioStreamPlayer
static var volume := 1.0
static var levels: Dictionary = DEFAULT.duplicate()


## trust boundary for the saved bars: whole % from 0 to 100 in steps of 5, else the default; an old save's single
## effects bar (`old`, 0 to 1) fills the three effect bars
static func parse(raw: Variant, old: String) -> Dictionary:
	var pct := func(v: Variant, fallback: int) -> int:
		return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and v == int(v) and v >= 0 and v <= 100 and int(v) % 5 == 0 else fallback
	var sfx: int = pct.call(roundi(float(old) * 100) if old.is_valid_float() else null, DEFAULT.world)
	var r: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	return {"music": pct.call(r.get("music"), DEFAULT.music), "ui": pct.call(r.get("ui"), sfx), "world": pct.call(r.get("world"), sfx), "voice": pct.call(r.get("voice"), sfx)}


static func load_levels() -> void:
	levels = parse(Store.json(SOUND_KEY), Store.get_key(OLD_KEY))


static func set_level(k: String, pct: int) -> void:
	levels[k] = pct
	Store.set_key(SOUND_KEY, JSON.stringify(levels))


static func attach(parent: Node) -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.3
	_player.stream = gen
	parent.add_child(_player)
	_player.play()


static func play(kind: String) -> void:
	var level: float = volume * (levels.ui if kind in INTERFACE else levels.world) / 100.0
	if _player == null or level <= 0.0 or not TONES.has(kind):
		return
	var pb := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var tone: Array = TONES[kind]
	var n := int(22050 * tone[1])
	for i in mini(n, pb.get_frames_available()):
		var env := 1.0 - float(i) / n
		var v := sin(TAU * tone[0] * i / 22050.0) * 0.25 * level * env
		pb.push_frame(Vector2(v, v))
