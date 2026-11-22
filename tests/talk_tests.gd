class_name TalkTests
## The 3D speech box's layout against the web game's own numbers (tests/golden/talk.json, written by
## tools/export-talk.mjs from window3d/talk-layout.ts), and the mouth's frame cycle (talk.ts mouthFrame).


static func _box(mine: Variant, o: Variant) -> bool:
	if o == null or mine == null:
		return o == mine
	return MenuTests._box(mine, o)


func test_talk_layout_matches_web() -> String:
	var golden: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/talk.json"))
	for g: Dictionary in golden:
		var spec: Dictionary = g.spec.duplicate()
		var n: int = spec.n
		spec.lines = func(_w: float, _s: float) -> int: return n
		var mine := TalkLayout.layout(spec)
		var o: Dictionary = g.out
		for k in ["box", "skip", "faceAt", "name", "title"]:
			if not _box(mine[k], o.get(k)): # JSON drops the web's undefined
				return "%s %s %s, web %s" % [g.spec, k, mine[k], o.get(k)]
		var pairs := [[mine.text.x, o.text.x], [mine.text.y, o.text.y], [mine.text.w, o.text.w], [mine.size, o.size], [mine.line, o.line], [mine.face, o.face], [mine.keys.x, o.keys.x], [mine.keys.y, o.keys.y]]
		for i in pairs.size():
			if not MenuTests._near(pairs[i][0], pairs[i][1]):
				return "%s value %d: %s, web %s" % [g.spec, i, pairs[i][0], pairs[i][1]]
	return ""


func test_mouth_frame_cycles_like_web() -> String:
	# talk.ts mouthFrame([1, 2], ms): talk1, talk2, talk1, neutral, 180 ms each; still or done: neutral
	var want := {0: 1, 179: 1, 180: 2, 360: 1, 540: 0, 720: 1}
	for ms: int in want:
		if Talk3d.mouth_frame([1, 2], ms) != want[ms]:
			return "%d ms: %d, web %d" % [ms, Talk3d.mouth_frame([1, 2], ms), want[ms]]
	return "" if Talk3d.mouth_frame([], 200) == 0 and Talk3d.mouth_frame([1, 2], 200, false) == 0 else "still mouth"
