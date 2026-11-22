class_name MenuTests
## The 3D command menu's pure parts against the web game's own numbers (tests/golden/menu.json, written by
## tools/export-menu.mjs from menu3d/menu-layout.ts and ui3d/layout.ts and spring.ts): every layout, text size, spring
## trace and page step must come out the same.

var _golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/menu.json"))


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 1e-6 * maxf(1.0, absf(b))


static func _box(r: Rect2, b: Dictionary) -> bool:
	return _near(r.position.x, b.x) and _near(r.position.y, b.y) and _near(r.size.x, b.w) and _near(r.size.y, b.h)


func test_menu_layout_matches_web() -> String:
	if not _near(MenuLayout.LEAD, _golden.lead) or not _near(MenuLayout.ROW, _golden.ref.row) or not _near(MenuLayout.HAND, _golden.ref.hand):
		return "REF or LEAD differ from menu-layout.ts"
	for g: Dictionary in _golden.layouts:
		var st: Dictionary = g.st
		var at := MenuLayout.layout(st, g.rows, g.subRows, g.touch, g.get("corner", NAN))
		if not _near(at.cs, g.at.cs):
			return "cs %s, web %s for %s" % [at.cs, g.at.cs, g]
		for k in ["main", "sub", "sheet", "prev", "next"]:
			if not _box(at[k], g.at[k]):
				return "%s %s, web %s for %s" % [k, at[k], g.at[k], st]
	return ""


func test_stage_matches_web() -> String:
	for g: Dictionary in _golden.layouts:
		var st: Dictionary = g.st
		# edges and frame give the same page size back only through their own math: replay the pages the golden used
		for mode in ["edges", "frame"]:
			for page in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080), Vector2(1024, 768), Vector2(844, 390), Vector2(250, 700)]:
				var mine := StageLayout.stage(page.x, page.y, mode)
				if _near(mine.x, st.x) and _near(mine.y, st.y) and _near(mine.w, st.w) and _near(mine.h, st.h) and _near(mine.s, st.s):
					st = {}
					break
			if st.is_empty():
				break
		if not st.is_empty():
			return "no page gives the web's stage %s" % [g.st]
	return ""


func test_text_px_matches_web() -> String:
	for g: Dictionary in _golden.texts:
		StageLayout.set_page_floor(g.w, g.h, g.coarse)
		var px := StageLayout.text_px(g.size, g.s)
		if not _near(px, g.px):
			return "text %s at %s on %sx%s: %s, web %s" % [g.size, g.s, g.w, g.h, px, g.px]
	StageLayout.set_page_floor(1280, 720)
	return ""


func test_springs_match_web() -> String:
	for g: Dictionary in _golden.springs:
		var sp := Spring3d.new(0.0)
		sp.to = 1.0
		for i in g.frames.size():
			sp.step(g.frames[i], g.k, g.c)
			if not _near(sp.x, g.trace[i][0]) or not _near(sp.v, g.trace[i][1]):
				return "spring %s/%s frame %d: %s %s, web %s" % [g.k, g.c, i, sp.x, sp.v, g.trace[i]]
	for st: Array in _golden.steps:
		if Spring3d.page_step(st[0], st[1], st[2]) != st[3]:
			return "pageStep%s" % [st]
	return ""
