class_name BattleScreen
extends Control
## A battle on screen (port of main.ts and hero-turn.ts): the 3D board, the HUD and the hero's turn screens. Keyboard,
## mouse and gamepad move the same cursor; the enemies play the AI. Emits `finished(won)` when the battle ends and
## `leave()` when the player quits from the pause menu.

signal finished(won: bool)
signal left_battle

var battle: Battle
var view: BattleView
var save_key := ""
var room: Variant = null # the expedition room in play (CrawlFlow), or null
var scenario: Dictionary
var screen: Dictionary
var ui: Dictionary
var cursor := Vector2i.ZERO
var busy := false
var paused := false
var last_log := ""
var _last_act := {}
var _hud: BattleHud


func setup(sc: Dictionary, b: Battle, key: String, r: Variant = null) -> void:
	scenario = sc
	battle = b
	save_key = key
	room = r


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vpc.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(vpc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	view = BattleView.new()
	vp.add_child(view)
	view.build(battle.grid, battle.state)
	_hud = BattleHud.new()
	_hud.screen_ref = self
	add_child(_hud)
	_save()
	_start_turn()


func _save() -> void:
	if save_key != "":
		Store.set_key(save_key, battle.save())


func is_hero_turn() -> bool:
	return not battle.over() and battle.actor().team == "hero"


func _start_turn() -> void:
	if battle.over():
		_refresh()
		Sound.jingle(battle.state.outcome == "victory") # as the web's finish: the fanfare as the battle ends
		await get_tree().create_timer(0.6).timeout
		finished.emit(battle.state.outcome == "victory")
		return
	cursor = battle.actor().pos
	view.focus_on(cursor)
	if is_hero_turn():
		ui = Interaction.fresh_ui(battle)
		screen = Command.start_screen(battle)
		_refresh()
		return
	screen = {"k": "menu", "index": 0}
	busy = true
	_refresh()
	await get_tree().create_timer(0.35).timeout
	var events := Ai.play_turn(battle)
	await _play(events)
	busy = false
	_save()
	_start_turn()


## the events in order: walks tweened, numbers floating, then the units as the state has them
func _play(events: Array) -> void:
	if events.is_empty():
		return
	var log := Texts.event_log(events, battle.state)
	if log != "":
		last_log = log
	_hud.refresh()
	await view.play_events(events)
	view.sync_units(battle.state)


## redraws the marks and the HUD from the screen and the ui
func _refresh() -> void:
	view.sync_units(battle.state)
	var m := marks()
	var size: int = m.get("size", 1)
	var danger := Interaction.charge_danger(battle.grid, battle.state)
	var tiles: Array = []
	for k in danger:
		var parts: PackedStringArray = k.split(",")
		tiles.append({"pos": Vector2i(int(parts[0]), int(parts[1])), "kind": "charge"})
	tiles.append_array(m.tiles)
	view.show_marks(tiles, m.get("path"), cursor if is_hero_turn() and (screen.k == "map" or screen.k == "facing") else null, size)
	# like the web's turnMarks: only while a hero chooses, and not over another unit's painted range
	view.show_rings(Rings.of_screen(battle, screen, cursor) if is_hero_turn() and not busy and ui.get("inspect", "") == "" else {})
	_hud.refresh()


func marks() -> Dictionary:
	if not is_hero_turn():
		return {"tiles": [], "path": null}
	if ActTurn.is_act(screen):
		return ActTurn.marks(battle, screen)
	if screen.k == "facing":
		return {"tiles": Interaction.facing_highlights(battle), "path": null}
	if screen.k == "map":
		return Interaction.highlights(battle, ui, cursor)
	var h := Interaction.highlights(battle, Interaction.fresh_ui(battle).merged({"mode": "idle"}, true))
	if ui.get("inspect", "") != "":
		h.tiles.append_array(Interaction.range_marks(battle, ui.inspect))
	return h


## the preview the HUD shows: the strike from the picked tile
func preview() -> Variant:
	if not is_hero_turn():
		return null
	if ActTurn.is_act(screen):
		return ActTurn.marks(battle, screen).get("preview")
	return null


# --- input ---------------------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	BattleKeys.handle(self, ev)


func key(a: String) -> void:
	if a == "turn_left" or a == "turn_right":
		view.turn(-1 if a == "turn_left" else 1)
		return
	if a == "pause":
		_hud.open_pause()
		return
	if busy or not is_hero_turn():
		return
	var b := battle
	if a == "undo":
		_undo()
		return
	if a == "face":
		screen = {"k": "facing"}
		_refresh()
		return
	if a == "cancel":
		var to: Variant = Command.cancel_step(b, screen)
		if typeof(to) == TYPE_STRING:
			_undo()
		elif to.is_empty():
			if screen.k == "menu":
				_hud.open_pause()
		else:
			Sound.play("cancel")
			screen = to
			cursor = b.actor().pos
			ui = Interaction.fresh_ui(b)
			_refresh()
		return
	if ActTurn.is_act(screen):
		_act_key(a)
		return
	match screen.k:
		"menu":
			if a == "up" or a == "down":
				# every row shown takes the cursor, a greyed Move included (Fernando, Nov 21: it must not be skipped)
				var on: Array = Command.COMMANDS.map(func(c: String) -> bool: return Command.menu_rows(b).has(c))
				screen = {"k": "menu", "index": Command.step_index(screen.index, -1 if a == "up" else 1, on)}
				Sound.play("cursor")
				_refresh()
			elif a == "confirm":
				choose(screen.index)
		"facing":
			if a in ["up", "down", "left", "right"]:
				var st := view.grid_step(a)
				var s: int = Content.units[b.actor().def].get("size", 1)
				_face_to(b.actor().pos + st * s)
			elif a == "confirm":
				_end_turn()
		"map":
			if a in ["up", "down", "left", "right"]:
				var size: int = Content.units[b.actor().def].get("size", 1)
				# one half tile per press; the selector keeps the unit's 2x2 (Fernando, Nov 21)
				var st := view.grid_step(a)
				var next := Vector2i(mini(cursor.x + st.x, b.grid.width - size), mini(cursor.y + st.y, b.grid.height - size))
				if b.grid.in_bounds(next) and next != cursor:
					cursor = next
					view.focus_on(cursor)
					ui = Interaction.hover_tile(b, ui, cursor)
					_refresh()
			elif a == "confirm":
				_map_confirm()


func _act_key(a: String) -> void:
	var r: Dictionary
	if a == "confirm":
		var st := ActTurn.step_of(screen)
		r = ActTurn.pick(battle, screen, st.rows.find(st.at) if not st.is_empty() else screen.get("index", 0))
	elif screen.k == "aim" and a in ["up", "down", "left", "right"]:
		r = BattleKeys.step_aim(self, a)
	elif a == "up" or a == "down":
		r = ActTurn.step(battle, screen, -1 if a == "up" else 1)
	elif (a == "left" or a == "right" or a == "info") and screen.k in ["actions", "acts", "group"]:
		r = ActTurn.page(screen, -1 if a == "left" else 1)
	elif (a == "left" or a == "right") and screen.k in ["spot", "targets"]:
		r = BattleKeys.walk_on_screen(self, a)
	else:
		return
	_apply(r)


func _apply(r: Dictionary) -> void:
	if r.get("sound", "") != "":
		Sound.play(r.sound)
	screen = r.screen
	if r.has("focus"):
		cursor = r.focus
		view.focus_on(r.focus)
	if r.has("run"):
		_run_act(r.run)
		return
	_refresh()


func _run_act(run: Dictionary) -> void:
	busy = true
	_last_act[battle.actor().id] = {"k": run.action.k, "id": run.action.id}
	var res := ActFlow.run_spot(battle, run.action, run.spot, run.lock, run.slot)
	var events: Array = res.walk + (res.act if res.act != null else [])
	await _play(events)
	busy = false
	_save()
	_after_action()


## after acting or walking: the battle may be over, the unit down, or the turn goes on in the menu
func _after_action() -> void:
	if battle.over() or battle.state.turn.actor != battle.actor().id or Combat.find_unit(battle.state, battle.state.turn.actor).is_empty():
		_end_turn()
		return
	ui = Interaction.fresh_ui(battle)
	screen = Command.start_screen(battle)
	cursor = battle.actor().pos
	_refresh()


func choose(index: int) -> void:
	var b := battle
	var c: String = Command.COMMANDS[index]
	if busy or not is_hero_turn() or not Command.menu_rows(b).has(c) or not Command.enabled(b, c):
		Sound.play("cancel")
		return
	if c == "undo":
		_undo()
		return
	Sound.play("confirm")
	match c:
		"status":
			_hud.open_status(b.actor().id)
		"wait":
			_end_turn()
		"act":
			screen = ActTurn.start(b, _last_act.get(b.actor().id, {}))
			_refresh()
		"move":
			screen = {"k": "map", "command": "move"}
			cursor = b.actor().pos
			ui = Interaction.hover_tile(b, Interaction.select_mode(b, ui, "move"), cursor)
			_refresh()


func _map_confirm() -> void:
	if ui.pending == null:
		Sound.play("cancel")
		return
	Sound.play("confirm")
	busy = true
	var r := Interaction.confirm(battle, ui)
	await _play(r.events)
	busy = false
	_save()
	_after_action()


func _face_to(p: Vector2i) -> void:
	var me := battle.actor()
	var s: int = Content.units[me.def].get("size", 1)
	var center := Vector2(me.pos.x + (s - 1) / 2.0, me.pos.y + (s - 1) / 2.0)
	var d := Vector2(p) - center
	var dir := Grid.FACING.find(Vector2i(signi(roundi(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(roundi(d.y))))
	if dir >= 0:
		battle.face(dir)
		Sound.play("cursor")
	_refresh()


func _end_turn() -> void:
	if battle.over():
		_start_turn()
		return
	busy = true
	var events := battle.end_turn()
	await _play(events)
	busy = false
	_save()
	_start_turn()


func _undo() -> void:
	if battle.undo():
		Sound.play("cancel")
		ui = Interaction.fresh_ui(battle)
		screen = Command.start_screen(battle)
		cursor = battle.actor().pos
		view.sync_units(battle.state)
		_save()
		_refresh()
	else:
		Sound.play("cancel")


func tap(p: Vector2i) -> void:
	if busy or not is_hero_turn():
		return
	var r: Variant = ActTurn.tap(battle, screen, p)
	if r != null:
		_apply(r)
		return
	if screen.k == "facing":
		_face_to(p)
		return
	if screen.k == "map" and ui.pending != null and p == ui.pending:
		_map_confirm()
		return
	cursor = p
	if screen.k == "map":
		ui = Interaction.tap_tile(battle, ui, p)
	else:
		ui = Interaction.tap_tile(battle, Interaction.fresh_ui(battle).merged({"mode": "idle"}, true), p)
	_refresh()


func hover(p: Vector2i) -> void:
	if busy or not is_hero_turn() or p == cursor or screen.k == "facing":
		return
	cursor = p
	if screen.k == "aim":
		if Pathing.aim_tile(battle.grid, battle.state, p) != Pathing.aim_tile(battle.grid, battle.state, screen.at):
			_apply(ActTurn.aim_to(screen, p, false))
		return
	if ActTurn.is_act(screen) and not (screen.k in ["actions", "group", "acts"]):
		var i := ActTurn.index_at(battle, screen, p)
		if i >= 0 and i != screen.index:
			var n := screen.duplicate()
			n.index = i
			screen = n
			_refresh()
		return
	if screen.k == "map":
		ui = Interaction.hover_tile(battle, ui, p)
		_refresh()


## Restart: the same battle again, with the life the party entered with
func restart() -> void:
	var b := CrawlFlow.new_battle(scenario, randi() % 2147483647, room)
	battle = b
	for c in get_children():
		if c is SubViewportContainer:
			c.queue_free()
	_hud.queue_free()
	paused = false
	busy = false
	_ready()
