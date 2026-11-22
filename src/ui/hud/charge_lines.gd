class_name ChargeLines
extends Control
## The queued charges' lines over the map (port of the web game's charge-lines.ts, drawn on the HUD): from each caster to
## where its spell will land (the followed unit or the locked tile), dashed in the caster's side colour, with a ring on
## the landing tile and a cross where it would fizzle out of range. Projected through the battle camera every frame
## while a charge is queued; with none it does not draw at all.
## shortcut: no counter lines or shot paths yet (charge-lines.ts counters); the line is straight, not the shot's arc

var view: BattleView
var _lines: Array = [] # [{from: Vector3, to: Vector3, hero: bool, ok: bool}]
var _key := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


func show_charges(b: Battle) -> void:
	var key := hash(b.state.charges) ^ hash(b.state.units.size())
	if key == _key:
		return
	_key = key
	_lines.clear()
	for c in b.state.charges:
		var caster := Combat.find_unit(b.state, c.unit)
		if caster.is_empty():
			continue
		var followed := Combat.find_unit(b.state, c.follow) if c.get("follow") != null else {}
		var aim := Pathing.aim_tile(b.grid, b.state, TurnQueue.charge_aim(b.state, c))
		var p := Combat.preview(b.grid, b.state, c.unit, c.ability, aim, true)
		var to_cell: Vector2i = followed.pos if not followed.is_empty() else aim
		var to_size: int = Content.units[followed.def].get("size", 1) if not followed.is_empty() else b.grid.sub
		_lines.append({
			"from": view.cell_center(caster.pos, Content.units[caster.def].get("size", 1)) + Vector3(0, 0.6, 0),
			"to": view.cell_center(to_cell, to_size) + Vector3(0, 0.15, 0),
			"hero": caster.team == "hero", "ok": p.get("ok", false),
		})
	set_process(not _lines.is_empty())
	queue_redraw()


func _process(_dt: float) -> void:
	queue_redraw() # the camera glides and turns


func _draw() -> void:
	if view == null or view.camera == null:
		return
	var cam := view.camera
	# the HUD is laid out at 1280x720 and the 3D view fills the window: project, then scale into our px
	var k := Vector2(1280, 720) / Vector2(view.get_viewport().get_visible_rect().size)
	for l in _lines:
		if cam.is_position_behind(l.from) or cam.is_position_behind(l.to):
			continue
		var a: Vector2 = cam.unproject_position(l.from) * k
		var b: Vector2 = cam.unproject_position(l.to) * k
		var col := HudSkin.HERO if l.hero else HudSkin.FOE
		draw_dashed_line(a, b, Color(0, 0, 0, 0.5), 5.0, 10.0, true, true)
		draw_dashed_line(a, b, col, 2.5, 10.0, true, true)
		draw_arc(b, 10.0, 0, TAU, 24, col, 2.5, true)
		if not l.ok:
			draw_line(b + Vector2(-7, -7), b + Vector2(7, 7), HudSkin.WARN, 3.0, true)
			draw_line(b + Vector2(-7, 7), b + Vector2(7, -7), HudSkin.WARN, 3.0, true)
