class_name TurnTests
## The 3D turn list's pure parts against the web game's own numbers (tests/golden/turn.json, written by
## tools/export-turn.mjs from turn3d/queue-layout.ts and queue-view.ts): every list layout, line layout, line width,
## card match and repeat must come out the same.

var _golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/turn.json"))


static func _near(a: float, b: float) -> bool:
	return MenuTests._near(a, b)


func _page(p: Array) -> void:
	StageLayout.set_page_floor(p[0], p[1], p[2])


func test_queue_layout_matches_web() -> String:
	for g: Dictionary in _golden.layouts:
		_page(g.page)
		var sp: Dictionary = g.spec.duplicate()
		sp.at = Rect2(sp.at.x, sp.at.y, sp.at.w, sp.at.h)
		var mine := QueueLayout.layout(sp)
		var o: Dictionary = g.out
		for k in ["left", "top", "height", "head", "more"]:
			if not _near(mine[k], o[k]):
				return "%s %s, web %s for %s" % [k, mine[k], o[k], g.spec]
		if not _near(mine.title.x, o.title.x) or not _near(mine.title.y, o.title.y):
			return "title %s, web %s" % [mine.title, o.title]
		var b: Rect2 = mine.box
		if not _near(b.end.x, o.box.right) or not _near(b.end.y, o.box.bottom) or not _near(mine.seat.gap, o.seat.gap):
			return "box %s, web %s" % [b, o.box]
		if mine.rows.size() != o.rows.size():
			return "%d rows, web %d" % [mine.rows.size(), o.rows.size()]
		for i in o.rows.size():
			if not MenuTests._box(mine.rows[i], o.rows[i]):
				return "row %d %s, web %s for %s" % [i, mine.rows[i], o.rows[i], g.spec]
	return ""


func test_stats_layout_matches_web() -> String:
	for g: Dictionary in _golden.stats:
		_page(g.page)
		var mine := QueueLayout.stats_layout(g.h, g.s, g.n)
		for k in ["size", "bar", "x", "hpBar", "stBar"]:
			if not _near(mine[k], g.out[k]):
				return "%s %s, web %s for %s" % [k, mine[k], g.out[k], g]
		if mine.fits != g.out.fits:
			return "fits differs for %s" % g
		for i in g.out.lines.size():
			if not _near(mine.lines[i], g.out.lines[i]):
				return "line %d %s, web %s" % [i, mine.lines[i], g.out.lines[i]]
	for g: Dictionary in _golden.widths:
		var w := QueueLayout.stat_width(g.lines, g.s, 3)
		if not _near(w, g.out):
			return "stat width %s, web %s for %s" % [w, g.out, g.lines]
	return ""


func test_card_matching_matches_web() -> String:
	for g: Dictionary in _golden.matches:
		var mine := QueueView.match_rows(g.prev, g.next, g.passed)
		if mine != g.out.map(func(v: float) -> int: return int(v)):
			return "match %s, web %s for %s" % [mine, g.out, g]
	for g: Dictionary in _golden.repeats:
		if QueueView.repeats(g.rows) != g.out:
			return "repeats %s, web %s" % [QueueView.repeats(g.rows), g.out]
	return ""
