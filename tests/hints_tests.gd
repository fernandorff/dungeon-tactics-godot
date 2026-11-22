class_name HintsTests
## The 3D hints' pure parts against the web game's own numbers (tests/golden/hints.json, written by
## tools/export-hints.mjs from hints3d/hints-view.ts): the Height corner's box, every hint row and the phone's banner.

var _golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/hints.json"))


func test_height_box_matches_web() -> String:
	for g: Dictionary in _golden.heights:
		var mine := HintsLayout.height_box(StageLayout.stage(g.w, g.h), g.top)
		if not MenuTests._box(mine, g.box):
			return "%dx%d: %s, web %s" % [g.w, g.h, mine, g.box]
	return ""


func test_lay_row_matches_web() -> String:
	for g: Dictionary in _golden.rows:
		var mine := HintsLayout.lay_row(g.sizes, g.box.x, g.box.w, g.align, g.s)
		for i in mine.size():
			var o: Dictionary = g.xs[i]
			if not MenuTests._near(mine[i].text, o.text):
				return "%s row text %d: %s, web %s" % [g.align, i, mine[i].text, o.text]
			for k in o.caps.size():
				if not MenuTests._near(mine[i].caps[k], o.caps[k]):
					return "%s row cap %d.%d: %s, web %s" % [g.align, i, k, mine[i].caps[k], o.caps[k]]
	return ""


func test_message_scale_matches_web() -> String:
	var pages := [[1920, 1080], [1280, 720], [2560, 1080], [1024, 768], [844, 390]]
	for i in pages.size():
		var mine := HintsLayout.message_scale(pages[i][0], pages[i][1])
		if not MenuTests._near(mine, _golden.messageScale[i]):
			return "%s: %s, web %s" % [pages[i], mine, _golden.messageScale[i]]
	return ""
