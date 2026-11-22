class_name HudTests
## The battle HUD's pure parts (ports of the web game's ui3d, turn-list, bar3d and hints3d tests): the menu's rows and
## its Agir lists, the action sheet, the turn list's rounds and scroll, the strike forecast and plate, the key hints.


func _battle() -> Battle:
	return Battle.start(Half.halve(Content.scenarios[Content.data.first_battle]), 9)


## the bare menu: the acting unit on the head, one row per command, Agir's dots, Move's gauge and the focused row
func test_menu_view_commands() -> String:
	var b := _battle()
	while b.actor().team != "hero":
		Ai.play_turn(b)
	var v := MenuView.of(b, Command.start_screen(b), true)
	if v.head != Texts.unit_name(b.actor().def) or v.rows.size() != Command.menu_rows(b).size():
		return "head or rows: %s" % [v]
	var act: Dictionary = v.rows[v.commands.find(Command.index_of("act"))]
	if not act.note.ends_with("⬤ ●") or act.icon != "sword":
		return "Agir row: %s" % [act]
	var move: Dictionary = v.rows[v.commands.find(Command.index_of("move"))]
	if move.gauge != 1.0 or not move.note.contains("/"):
		return "Move row: %s" % [move]
	if not MenuView.of(b, Command.start_screen(b), false).is_empty():
		return "closed menu still shows"
	return ""


## the Agir list beside the menu (depth 1), then the targets with the menu's place taken by the Agir list (depth 2)
func test_menu_view_lists() -> String:
	var b := _battle()
	while b.actor().team != "hero":
		Ai.play_turn(b)
	var acts := MenuView.of(b, {"k": "acts", "index": 0}, true)
	if acts.depth != 1 or acts.sub.is_empty() or acts.sub_title != Texts.t("Agir", "Act"):
		return "acts: depth %d, %d rows" % [acts.depth, acts.sub.size()]
	if acts.index != acts.commands.find(Command.index_of("act")):
		return "the menu must keep Agir focused"
	var targets := MenuView.of(b, {"k": "targets", "index": 0}, true)
	if targets.depth != 2 or targets.head != Texts.t("Agir", "Act") or targets.sub.size() != ActFlow.act_targets(b).size():
		return "targets: depth %d head %s" % [targets.depth, targets.head]
	return ""


## an ability's sheet: three pages, each fact a sentence, the page wrapping around
func test_action_sheet() -> String:
	var b := _battle()
	var sh := MenuView.sheet(b, {"k": "ability", "id": "strike"}, 4)
	if sh.pages.size() != 3 or sh.page != 1 or not sh.pages[0].text.ends_with("."):
		return "sheet: %s" % [sh]
	if not MenuView.sheet(b, {"k": "pick"}).is_empty():
		return "Pick a target has no sheet"
	return ""


## two rounds: the first until every unit and charge shows once, the second until each shows once more
func test_turn_rounds() -> String:
	var rows := [{"unit": "a"}, {"unit": "b"}, {"unit": "a"}, {"unit": "c", "charge": "blast"}, {"unit": "b"}, {"unit": "a"}, {"unit": "b"}]
	if TurnRows.round_length(rows) != 4:
		return "round length %d" % TurnRows.round_length(rows)
	var two := TurnRows.two_rounds(rows)
	if two.size() != 6 or two[3].round != 1 or two[4].round != 2:
		return "two rounds: %s" % [two]
	return ""


## while a charge is aimed, the list puts the spell where it fires and marks whoever it hits
func test_queue_projection() -> String:
	var gs: Array = UnitTests.new()._flat([["m", "mage", "hero", Vector2i(0, 0)], ["s", "soldier", "enemy", Vector2i(4, 0)]])
	var b := Battle.new(gs[0], gs[1])
	var q := TurnRows.queue(b, {"ability": "blast", "target": Vector2i(4, 0)})
	if q.at < 1 or q.rows[q.at].get("charge", "") != "blast" or not q.targets.has("s"):
		return "projection: at %d targets %s" % [q.at, q.targets]
	if TurnRows.queue(b, {}).at != -1 or b.state.charges.size() != 0:
		return "the projection must not touch the state"
	return ""


## the forecast and the plate: "a ≈ b", the chance, ALLY on the user's own side
func test_forecast_plate() -> String:
	var gs: Array = UnitTests.new()._flat([["w", "warrior", "hero", Vector2i(0, 0)], ["s", "soldier", "enemy", Vector2i(1, 0)]])
	var b := Battle.new(gs[0], gs[1])
	var p := b.preview("strike", Vector2i(1, 0))
	var fs := BarView.forecast(b, "strike", p)
	if fs.size() != 1 or fs[0].dmg.is_empty() or fs[0].after[0] > fs[0].after[1]:
		return "forecast: %s" % [fs]
	var pl := BarView.plate(fs[0], "strike", 0)
	if not pl.amount.contains(" ≈ ") or not pl.chance.begins_with("⊕ ") or pl.warn:
		return "plate: %s" % [pl]
	var v := BarView.of(b.state, b.actor(), {}, fs, "strike")
	if v.target.unit.id != "s" or v.target.change.left > v.target.change.sure:
		return "bar view: %s" % [v.target.change]
	return ""


## the key hints follow the screen: Select on the menu, Cancel in a list, Details on the action list, speed-up playing
func test_hints() -> String:
	var b := _battle()
	while b.actor().team != "hero":
		Ai.play_turn(b)
	var menu := HintRows.hints_for(b, {"k": "menu", "index": 0}, true)
	if menu.right[0][1] != Texts.t("Escolher", "Select"):
		return "menu hints: %s" % [menu]
	var acts := HintRows.hints_for(b, {"k": "acts", "index": 0}, true)
	if acts.right[1][1] != Texts.t("Cancelar", "Cancel"):
		return "acts hints: %s" % [acts]
	if HintRows.hints_for(b, {"k": "menu", "index": 0}, false).right.size() != 2:
		return "playing hints"
	if HintRows.height_shown(b, {"k": "actions"}, b.actor().pos) != -1:
		return "the action list's sheet takes the Height corner"
	return ""
