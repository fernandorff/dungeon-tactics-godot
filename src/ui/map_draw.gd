class_name MapDraw
extends Control
## The expedition map drawn (port of town3d/map3d.ts and map-draw.ts), in px of the 1920x1080 reference: the screen
## darkened with the title, the gold found, the help band and the keys; the chart's sheet (each floor a band, the ways
## told apart by weight and dash as well as colour, the gate's tag, the seals, the party's flag); the party's and the
## picked place's sheets; the command plaques, the one in focus gold, and the glove. ExpeditionScreen owns the state.

var s: ExpeditionScreen

# walked thick gold, open plain ink, to come thin; closed is dotted
const WAY := {"walked": [7.0, Paper.GOLD], "open": [4.0, Paper.INK], "ahead": [2.0, Color(Paper.INK_SOFT, 0.8)]}


func _init(screen: ExpeditionScreen) -> void:
	s = screen
	mouse_filter = MOUSE_FILTER_IGNORE
	size = MapLayout.SCREEN


func _draw() -> void:
	var L: Dictionary = s.L
	_frame()
	Paper.sheet(self, MapLayout.CHART)
	Paper.sheet(self, MapLayout.PARTY, MapLayout.HEAD)
	Paper.sheet(self, MapLayout.INFO, MapLayout.HEAD)
	_chart(L)
	_party(L)
	_info()
	_commands(L)
	_cursor(L)


func _frame() -> void:
	draw_rect(Rect2(Vector2(-4000, -4000), Vector2(10000, 10000)), Color(Paper.VEIL, 0.94))
	Paper.say(self, "  ›  ".join([Texts.t("Masmorra", "Dungeon"), MapFacts.floor_text(s.floor)]), MapLayout.TITLE, 32, Paper.TEXT)
	draw_rect(MapLayout.RULE, Color(Paper.LINE, 0.7))
	Paper.say(self, str(s.gold), MapLayout.GOLD, 34, Paper.TITLE, 1)
	Paper.say(self, Texts.t("Ouro achado", "Gold found"), MapLayout.GOLD - Vector2(150, 0), 22, Paper.SOFT, 1)
	draw_rect(MapLayout.HELP, Color(Paper.DARK_BAND, 0.8))
	Paper.say(self, s.help_text(), MapLayout.HELP.get_center(), 28, Paper.TEXT, 0, 1700)
	var keys := "↑↓←→: %s   ·   Enter: %s" % [Texts.t("mudar de lugar", "change place"), Texts.t("escolher", "choose")]
	Paper.say(self, keys, MapLayout.HINTS, 24, Paper.SOFT, 1)


func _chart(L: Dictionary) -> void:
	var S := MapLayout.CHART
	for i in L.floors.size():
		var f: Dictionary = L.floors[i]
		if i % 2:
			draw_rect(f.box, Color(Paper.BAND, 0.3))
		if i:
			draw_rect(Rect2(f.box.position, Vector2(f.box.size.x, 2)), Color(Paper.EDGE, 0.25))
		Paper.say(self, Texts.t("Andar %d" % f.floor, "Floor %d" % f.floor), Vector2(S.position.x + 18, f.box.position.y + 22), 22, Paper.INK_SOFT)
	for l in L.links:
		if l.kind == "off":
			var len: float = l.a.distance_to(l.b)
			var d := 0.0
			while d < len:
				draw_circle(l.a.lerp(l.b, d / len), 2, Paper.INK_OFF)
				d += 14
			continue
		draw_line(l.a, l.b, WAY[l.kind][1], WAY[l.kind][0], true)
	var gate: Vector2 = L.gate
	Paper.box(self, Rect2(gate - Vector2(62, 19), Vector2(124, 38)), Color(Paper.PLATE, 0.94), 5, Paper.LINE, 1)
	Paper.say(self, Texts.t("Portão", "Gate"), gate, 22, Paper.TEXT, 0)
	# the picked place's dark ring, under its seal
	var p: Dictionary = L.places[s.picked]
	var d := float(p.size) + 16
	Paper.box(self, Rect2(p.at - Vector2(d, d) / 2, Vector2(d, d)), Color(Paper.EDGE, 0.9), 14.0 if p.kind == "chest" else d / 2)
	for i in L.places.size():
		var q: Dictionary = L.places[i]
		Paper.seal(self, q.at, q.size, q.state, q.kind, s.marks[i])
	Paper.flag(self, L.flag)


func _party(L: Dictionary) -> void:
	var P := MapLayout.PARTY
	Paper.say(self, Texts.t("Grupo", "Party"), P.position + Vector2(28, MapLayout.HEAD / 2), 26, Paper.INK_SOFT)
	var face: float = MapLayout.HERO.face
	for i in s.heroes.size():
		var h: Dictionary = s.heroes[i]
		var b: Rect2 = L.heroes[i]
		var x := b.position.x + face + 16
		var w := b.size.x - face - 16
		Paper.say(self, h.name, Vector2(x, b.position.y + 18), 26, Paper.INK, -1, w - 110)
		Paper.say(self, h.job, Vector2(x + w, b.position.y + 18), 22, Paper.INK_SOFT, 1, 104)
		_gauge(Vector2(x, b.position.y + 50), w, Texts.t("Vida", "HP"), h.hp, h.max, Paper.HP)
		if h.mana_max:
			_gauge(Vector2(x, b.position.y + 90), w, "MP", h.mana, h.mana_max, Paper.MP)


func _gauge(at: Vector2, w: float, name: String, v: int, max: int, col: Color) -> void:
	Paper.say(self, name, at, 22, Paper.INK_SOFT)
	Paper.say(self, "%d/%d" % [v, max], at + Vector2(w, 0), 22, Paper.INK, 1)
	Paper.box(self, Rect2(at + Vector2(0, 15), Vector2(w, 10)), Paper.TRACK, 3)
	if v > 0:
		Paper.box(self, Rect2(at + Vector2(0, 15), Vector2(w * minf(1, float(v) / max), 10)), col, 3)


## the picked place's box: name and floor on the head, then each fact, its label over its value
func _info() -> void:
	var I := MapLayout.INFO
	var f: Dictionary = s.facts
	Paper.say(self, f.name, I.position + Vector2(28, MapLayout.HEAD / 2), 30, Paper.INK, -1, I.size.x - 56 - 200)
	Paper.say(self, f.floor, Vector2(I.end.x - 28, I.position.y + MapLayout.HEAD / 2), 22, Paper.INK_SOFT, 1)
	var y := I.position.y + MapLayout.HEAD + 24
	for kv in f.facts:
		Paper.say(self, kv[0], Vector2(I.position.x + 28, y + 11), 22, Paper.INK_SOFT)
		y += 30
		y += Paper.para(self, kv[1], Vector2(I.position.x + 28, y), I.size.x - 56, 26, Paper.INK) + 36


func _commands(L: Dictionary) -> void:
	for i in s.commands.size():
		var at: Rect2 = L.commands[i]
		var c: Dictionary = s.commands[i]
		var said := MapLayout.command_text(c.label, c.note, c.armed)
		var focused := s.focus_command() == i
		draw_rect(at, Color(Paper.GOLD if focused else Paper.PLATE, 0.94 if focused or not c.disabled else 0.55))
		var mid := Vector2(at.position.x + at.size.x / 2 + 20, at.get_center().y)
		var hex := Paper.SOFT if c.disabled else Paper.TEXT
		Paper.say(self, said.plaque, mid - Vector2(0, 16 if c.note != "" else 0), 30, hex, 0, at.size.x - 110)
		if c.note != "":
			Paper.say(self, c.note, mid + Vector2(0, 22), 22, Paper.SOFT, 0, at.size.x - 110)


## the glove inside the plaque in focus, or at the left of the place in focus
func _cursor(L: Dictionary) -> void:
	var c := s.focus_command()
	if c >= 0:
		var at: Rect2 = L.commands[c]
		Paper.glove(self, Rect2(at.position + Vector2(58 + 62, 0), at.size), 62)
		return
	var n := s.focus_place()
	if n >= 0:
		var p: Dictionary = L.places[n]
		Paper.glove(self, Rect2(p.at - Vector2(p.size / 2 + 4, p.size / 2), Vector2(p.size, p.size)), 62)
