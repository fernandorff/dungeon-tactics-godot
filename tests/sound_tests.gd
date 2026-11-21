class_name SoundTests
## The sound's own rules (port of sound.ts): the saved bars, which effect each battle event and ability plays, and the
## fanfares and speech blip made from notes.


func test_sound_bars_parse() -> String:
	if Util.diff(Sound.parse(null), Sound.DEFAULT) != "":
		return "no save: %s" % [Sound.parse(null)]
	# a save from before the split: its single `sfx` bar fills interface, world and dialogue
	if Util.diff(Sound.parse({"sfx": 30}), {"music": 25, "ui": 30, "world": 30, "voice": 30}) != "":
		return "old bar: %s" % [Sound.parse({"sfx": 30})]
	# the oldest save's 1 and 2 (low, loud) become 45% and 100%
	if Util.diff(Sound.parse({"music": 1, "sfx": 2}), {"music": 45, "ui": 100, "world": 100, "voice": 100}) != "":
		return "legacy: %s" % [Sound.parse({"music": 1, "sfx": 2})]
	var bad := Sound.parse({"music": 7, "ui": 150, "world": "x", "voice": 40})
	return "" if Util.diff(bad, {"music": 25, "ui": 50, "world": 50, "voice": 40}) == "" else "bad values: %s" % [bad]


## every effect the web plays has its file, and each event and ability picks the web's effect
func test_effect_kinds() -> String:
	for k in Sound.FILE:
		if not ResourceLoader.exists("res://assets/sfx/%s.mp3" % Sound.FILE[k]):
			return "no file for %s" % k
	var want := {"strike": "swing", "shove": "swing", "shot": "throw", "throwing_knife": "throw", "firebolt": "fire", "shadow_wave": "fire", "heal": "spell", "focus": "spell", "gust": "spell", "nope": "swing"}
	for a in want:
		if Sound.attack_kind(a) != want[a]:
			return "%s sounds %s" % [a, Sound.attack_kind(a)]
	for a in Content.abilities:
		if not Sound.FX.has(a):
			return "ability %s has no look" % a
	return ""


## the fanfares last as the web's notes do and peak at their gain; the blip is 50 ms and quieter after its low-pass
func test_synth_lengths_and_peaks() -> String:
	var win := Synth.jingle(true, 0.16)
	var lose := Synth.jingle(false, 0.16)
	if win.size() != ceili((3 * 0.14 + 0.9) * Synth.RATE) or lose.size() != ceili((2 * 0.32 + 0.9) * Synth.RATE):
		return "lengths %d %d" % [win.size(), lose.size()]
	var peak := func(s: PackedFloat32Array) -> float:
		var m := 0.0
		for x in s:
			m = maxf(m, absf(x))
		return m
	if absf(peak.call(win) - 0.16) > 0.001 or peak.call(lose) > 0.161 or peak.call(lose) < 0.1:
		return "peaks %f %f" % [peak.call(win), peak.call(lose)]
	var b := Synth.blip(300.0, 0.12)
	if b.size() != roundi(0.05 * Synth.RATE) or peak.call(b) > 0.13 or peak.call(b) < 0.03:
		return "blip %d %f" % [b.size(), peak.call(b)]
	return "" if Synth.to_wav(b).data.size() == b.size() * 2 else "wav size"
