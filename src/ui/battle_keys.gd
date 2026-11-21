class_name BattleKeys
## The battle's input (split from battle_screen.gd): mouse, keys and pad buttons turned into the screen's actions, and
## the arrows that walk between aims on a map screen.


static func handle(s: BattleScreen, ev: InputEvent) -> void:
	if s.paused:
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			s.view.zoom_by(0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			s.view.zoom_by(1.1)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			var p: Variant = s.view.pick(ev.position)
			if p != null:
				s.tap(p)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			s.key("cancel")
		s.get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseMotion:
		var p: Variant = s.view.pick(ev.position)
		if p != null:
			s.hover(p)
		return
	for pair in [["ui_up", "up"], ["ui_down", "down"], ["ui_left", "left"], ["ui_right", "right"], ["ui_accept", "confirm"], ["ui_cancel", "cancel"], ["turn_left", "turn_left"], ["turn_right", "turn_right"], ["face", "face"], ["undo", "undo"], ["info", "info"], ["pause", "pause"]]:
		if InputMap.has_action(pair[0]) and ev.is_action_pressed(pair[0], true):
			s.key(pair[1])
			s.get_viewport().set_input_as_handled()
			return


## the aim step's free cursor: the whole tile next to it that the arrow points to on screen, anywhere on the map (port
## of stepAim: of the 8 neighbours, the one most that way)
static func step_aim(s: BattleScreen, dir: String) -> Dictionary:
	var at: Vector2i = s.screen.at
	var k := s.battle.grid.sub
	var here := s.view.screen_at(at)
	var want: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[dir]
	var best: Variant = null
	var best_d := INF
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := at + Vector2i(dx, dy) * k
			if (dx == 0 and dy == 0) or not s.battle.grid.in_bounds(p):
				continue
			var d := s.view.screen_at(p) - here
			if d.dot(want) <= 0.0:
				continue
			var score := d.length() + absf(d.dot(Vector2(want.y, want.x))) * 2.0
			if score < best_d:
				best_d = score
				best = p
	return ActTurn.aim_to(s.screen, best) if best != null else {"screen": s.screen, "sound": ""}


## on a map screen an arrow goes to the nearest aim, tile or listed unit that way on screen
static func walk_on_screen(s: BattleScreen, dir: String) -> Dictionary:
	var pts: Array = []
	var idx: Array = []
	if s.screen.k == "targets":
		var rows := ActTurn.rows_of(s.battle, s.screen)
		for i in rows.size():
			if rows[i].k == "unit":
				pts.append(rows[i].pos)
				idx.append(i)
	else:
		pts = ActTurn.map_points(s.battle, s.screen)
		for i in pts.size():
			idx.append(i)
	var at := idx.find(s.screen.index)
	if at < 0 or pts.is_empty():
		return {"screen": s.screen, "sound": ""}
	var here := s.view.screen_at(pts[at])
	var want := Vector2(-1, 0) if dir == "left" else Vector2(1, 0)
	var best := -1
	var best_d := INF
	for i in pts.size():
		if i == at:
			continue
		var d := s.view.screen_at(pts[i]) - here
		if d.dot(want) <= 0.0:
			continue
		var score := d.length() + absf(d.dot(Vector2(want.y, want.x))) * 2.0
		if score < best_d:
			best_d = score
			best = i
	if best < 0:
		return {"screen": s.screen, "sound": ""}
	return ActTurn.hover(s.battle, s.screen, idx[best])
