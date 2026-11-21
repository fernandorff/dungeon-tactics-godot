class_name Sound
## The interface's short sounds (cursor, confirm, cancel, hit), made at run time as plain tones so the port needs no audio
## files. Off under the test runner and when the volume is 0 (dt:sfx).
## shortcut: synthesized beeps stand in for the web game's sound effects, swap for real samples when assets come over

static var _player: AudioStreamPlayer
static var volume := 0.5
const TONES := {"cursor": [880.0, 0.04], "confirm": [1320.0, 0.07], "cancel": [440.0, 0.08], "hit": [180.0, 0.1]}


static func attach(parent: Node) -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.3
	_player.stream = gen
	parent.add_child(_player)
	_player.play()


static func play(kind: String) -> void:
	if _player == null or volume <= 0.0 or not TONES.has(kind):
		return
	var pb := _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var tone: Array = TONES[kind]
	var n := int(22050 * tone[1])
	for i in mini(n, pb.get_frames_available()):
		var env := 1.0 - float(i) / n
		var v := sin(TAU * tone[0] * i / 22050.0) * 0.25 * volume * env
		pb.push_frame(Vector2(v, v))
