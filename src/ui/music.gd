class_name Music
## The game's music (port of music.ts and the music half of sound.ts): one looping track per screen (title, town,
## expedition map, battle), switched with a 0.5 s fade, at the music bar's volume. The files are the web game's own .ogg
## (assets/music; authors in CREDITS.txt).

# file and gain per track, measured on the web (Nov 13): the louder title goes down, the quieter ones stay at 1
const TRACKS := {
	"title": ["title.ogg", 0.6], "world": ["city_pastoral_rica.ogg", 1.0], "crypt": ["crypt.ogg", 1.0],
	"battle": ["battle_dark.ogg", 1.0],
}
const FADE := 0.5
const SILENT := -80.0

static var _host: Node
static var _players := {} # track id -> AudioStreamPlayer, the one playing and any still fading out
static var track := ""


static func attach(parent: Node) -> void:
	_host = parent


## the track's volume, 0 to 1: the bar × 0.8 (the web's ceiling) × 0.6 (the music stays below the effects) × its gain;
## `Sound.volume` is the master switch the tests and the shot mode turn off
static func level(id: String) -> float:
	if not TRACKS.has(id):
		return 0.0
	return Sound.volume * Sound.levels.music / 100.0 * 0.8 * 0.6 * TRACKS[id][1]


static func play(id: String) -> void:
	track = id
	apply()


## brings the players in line with the track and the bar: the wanted one fades to its level, any other fades out
static func apply() -> void:
	if _host == null:
		return
	var want := track if level(track) > 0.0 else ""
	for id in _players.keys():
		if id == want:
			continue
		var old: AudioStreamPlayer = _players[id]
		_players.erase(id)
		_fade(old, SILENT).tween_callback(old.queue_free)
	if want == "":
		return
	if not _players.has(want):
		var p := AudioStreamPlayer.new()
		var stream: AudioStreamOggVorbis = load("res://assets/music/" + TRACKS[want][0])
		stream.loop = true
		p.stream = stream
		p.volume_db = SILENT
		p.autoplay = true # starts as it enters the tree, also when the host is not in it yet
		_host.add_child(p)
		_players[want] = p
	_fade(_players[want], linear_to_db(level(want)))


## one fade per player: a new one stops the last, so a quick bar drag or screen switch never fights itself
static func _fade(p: AudioStreamPlayer, db: float) -> Tween:
	if p.has_meta("fade"):
		(p.get_meta("fade") as Tween).kill()
	var tw := _host.create_tween()
	tw.tween_property(p, "volume_db", db, FADE)
	p.set_meta("fade", tw)
	return tw
