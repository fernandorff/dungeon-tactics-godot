class_name Synth
## The sounds the web game makes from notes instead of files (sound.ts jingle and blip), rendered here into a short
## AudioStreamWAV: the victory and defeat fanfares and the dialogue's speech blip. The web builds them from WebAudio
## oscillators, gains with exponential ramps and a low-pass; this follows the same numbers sample by sample.

const RATE := 44100
const FLOOR := 0.001 # where WebAudio's exponentialRampToValueAtTime ends each note


## one cycle shape at phase `p` (cycles): WebAudio's square and triangle, -1 to 1
static func wave(kind: String, p: float) -> float:
	var x := fposmod(p, 1.0)
	if kind == "square":
		return 1.0 if x < 0.5 else -1.0
	return 4.0 * x - 1.0 if x < 0.5 else 3.0 - 4.0 * x # triangle, rising from -1 at the cycle's start


## a note's gain at `t` s: setValueAtTime(g0) then an exponential ramp to 0.001 at `ramp`, held there until it stops
static func gain_at(g0: float, t: float, ramp: float) -> float:
	if g0 <= FLOOR:
		return g0
	return g0 * pow(FLOOR / g0, minf(t, ramp) / ramp)


## the fanfare's samples (jingle): C major rising in squares on a victory, A minor falling in triangles on a defeat;
## `g0` is the web's volume(world) × 0.4
static func jingle(win: bool, g0: float) -> PackedFloat32Array:
	var notes: Array = [523.25, 659.25, 783.99, 1046.5] if win else [440.0, 349.23, 293.66]
	var step := 0.14 if win else 0.32
	var out := PackedFloat32Array()
	out.resize(ceili(((notes.size() - 1) * step + 0.9) * RATE))
	for i in notes.size():
		var last: bool = i == notes.size() - 1
		var start := roundi(i * step * RATE)
		var stop := 0.9 if last else step
		var ramp := 0.9 if last else step * 0.95
		var f: float = notes[i]
		for n in roundi(stop * RATE):
			var t := float(n) / RATE
			out[start + n] += wave("square" if win else "triangle", f * t) * gain_at(g0, t, ramp)
	return out


## one speech blip (blip): a 50 ms triangle at the speaker's pitch through a 1200 Hz low-pass; `g0` is the web's
## volume(voice) × 0.3 and `pitch` already holds the web's ±6% wobble
static func blip(pitch: float, g0: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(roundi(0.05 * RATE))
	var lp := _lowpass(1200.0, pow(10.0, 1.0 / 20.0)) # WebAudio's default Q of 1 dB
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for n in out.size():
		var t := float(n) / RATE
		var x := wave("triangle", pitch * t)
		var y: float = lp[0] * x + lp[1] * x1 + lp[2] * x2 - lp[3] * y1 - lp[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[n] = y * gain_at(g0, t, 0.05)
	return out


## the RBJ cookbook low-pass, as WebAudio's BiquadFilterNode: [b0, b1, b2, a1, a2] over a0
static func _lowpass(freq: float, q: float) -> Array:
	var w := TAU * freq / RATE
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	var c := cos(w)
	return [(1.0 - c) / 2.0 / a0, (1.0 - c) / a0, (1.0 - c) / 2.0 / a0, -2.0 * c / a0, (1.0 - alpha) / a0]


## samples (-1 to 1) as a 16-bit mono stream a player can play
static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
