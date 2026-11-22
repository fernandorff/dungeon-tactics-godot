class_name Main
extends Control
## The whole game in one scene (port of entry.ts and nav.ts): one screen at a time — title, town, expedition map, battle —
## each built from the saved game, the next one asked for by the screen in view. `-- --shot <screen> <file>` opens a
## screen, saves a screenshot and quits (the port's look check, tools/shot.sh).

var _screen: Node
var _shot: Array = []


func _ready() -> void:
	Content.ensure()
	_input_map()
	Sound.attach(self)
	Music.attach(self)
	Sound.load_levels()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(FpsCounter.new())
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i >= 0 and args.size() > i + 2:
		_shot = args.slice(i + 1) # screen, file and, for options, the category (help: the Help row) to show
		Store.reset_memory()
		Sound.volume = 0.0
		_open_shot(_shot[0])
		return
	title()


## the keys and pad buttons beyond Godot's own ui_* actions (arrows, Enter, Esc already have them)
func _input_map() -> void:
	var keys := {"turn_left": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER], "turn_right": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER], "face": [KEY_F, JOY_BUTTON_X], "undo": [KEY_Z, JOY_BUTTON_BACK], "info": [KEY_I, JOY_BUTTON_Y], "pause": [KEY_P, JOY_BUTTON_START]}
	for a in keys:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		var k := InputEventKey.new()
		k.keycode = keys[a][0]
		InputMap.action_add_event(a, k)
		var j := InputEventJoypadButton.new()
		j.button_index = keys[a][1]
		InputMap.action_add_event(a, j)


func show_screen(n: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = n
	add_child(n)
	move_child(n, 0) # under the fps counter
	# the fast battle (Options) speeds a battle's every tween and timer; any other screen runs at its pace
	Engine.time_scale = Settings.FAST if n is BattleScreen and Settings.fast() else 1.0


func title() -> void:
	Music.play("title")
	show_screen(TitleScreen.new(self))


## `notice`: a window over the town, made by notice.call(town, done) (Notices.lost, Notices.no_room)
func town(notice: Callable = Callable()) -> void:
	var t := TownScreen.new(self)
	Music.play("world") # Pastoral D, the town's music (Fernando, Nov 15)
	show_screen(t)
	if notice.is_valid():
		t.notice(notice)


## ?home: the town, the expedition lost if the party left a room behind
func home(expedition: bool = false) -> void:
	var lost := CrawlFlow.left_room()
	if lost >= 0:
		town(func(t: Control, done: Callable) -> Control: return Notices.lost(t, lost, done))
		return
	var exp: Variant = CrawlFlow.live_expedition()
	if expedition and exp != null:
		expedition_map()
	else:
		town()


func expedition_map() -> void:
	var exp: Variant = CrawlFlow.live_expedition()
	if exp == null:
		town()
		return
	Music.play("crypt")
	show_screen(ExpeditionScreen.new(self, exp))


## an open room of the live expedition; a saved battle of the same room resumes
func room(node: int) -> void:
	var exp: Variant = CrawlFlow.live_expedition()
	var map: Array = Expedition.map_of(exp.seed) if exp != null else []
	if exp == null or not Expedition.open_nodes(map, exp.path).has(node) or map[node].chest:
		town()
		return
	var built := CrawlFlow.room_scenario(map[node])
	if built.is_empty():
		town(Notices.no_room)
		return
	var held: Variant = Store.json(Saves.ROOM_KEY)
	var held_id: Variant = held.get("state", {}).get("scenario") if typeof(held) == TYPE_DICTIONARY else null
	if typeof(held_id) == TYPE_STRING and held_id != built.id + Content.HALF:
		home()
		return
	var cast := CrawlFlow.cast_room(built, exp, node)
	var loaded := Battle.load_save(Store.get_key(Saves.ROOM_KEY))
	var b: Battle = loaded if loaded != null and loaded.state.scenario == cast.scenario.id else CrawlFlow.new_battle(cast.scenario, randi() % 2147483647, cast.room)
	var s := BattleScreen.new()
	s.setup(cast.scenario, b, Saves.ROOM_KEY, cast.room)
	s.finished.connect(func(won: bool) -> void: _room_end(cast.room, won, s.battle.state))
	s.left_battle.connect(func() -> void: home())
	Music.play("battle")
	show_screen(s)


func _room_end(r: Dictionary, won: bool, state: Dictionary) -> void:
	var settled: Variant = CrawlFlow.settle_room(r, won, state)
	if settled == null:
		home()
		return
	show_screen(EndScreen.new(self, settled))


## a standalone battle on one of the game's maps (the title's Battle, the old ?scenario=)
func skirmish(map_id: String) -> void:
	var sc := Half.halve(Content.scenarios[map_id])
	var key := "dt:battle:" + map_id
	var loaded := Battle.load_save(Store.get_key(key))
	var b: Battle = loaded if loaded != null and loaded.state.scenario == sc.id else Battle.start(sc, randi() % 2147483647)
	var s := BattleScreen.new()
	s.setup(sc, b, key)
	s.finished.connect(func(won: bool) -> void:
		Store.set_key(key, "")
		var d := Kit.dialog(s, Texts.t("Vitória!", "Victory!") if won else Texts.t("Derrota", "Defeat"), "", [[Texts.t("Voltar ao título", "Back to the title"), title]]))
	s.left_battle.connect(title)
	Music.play("battle") # every battle plays its own track, Until Dawn too, as the web's entry.ts
	show_screen(s)


## Until Dawn: its own rule and save, the record kept when the battle ends
func survival() -> void:
	var sc := Half.halve(Survival.scenario())
	var key := "dt:battle:" + Survival.ID
	var loaded := Battle.load_save(Store.get_key(key))
	var b: Battle = loaded if loaded != null and loaded.state.scenario == sc.id else Battle.start(sc, randi() % 2147483647)
	var s := BattleScreen.new()
	s.setup(sc, b, key)
	s.finished.connect(func(won: bool) -> void:
		Store.set_key(key, "")
		var lasted := Survival.survived(s.battle.state)
		var best := Survival.best()
		if lasted > best:
			Store.set_key(Survival.BEST_KEY, str(lasted))
		var text := Texts.t("Turnos: %d de %d · Recorde: %s", "Turns: %d of %d · Record: %s") % [lasted, Survival.SURVIVE_TURNS, Texts.t("%d, novo!", "%d, new!") % lasted if lasted > best else str(best)]
		Kit.dialog(s, Texts.t("Amanheceu!", "Dawn came!") if won else Texts.t("Derrota", "Defeat"), text, [[Texts.t("Voltar ao título", "Back to the title"), title]]))
	s.left_battle.connect(title)
	Music.play("battle") # every battle plays its own track, Until Dawn too, as the web's entry.ts
	show_screen(s)


func _open_shot(shot: String) -> void:
	# "map+ui_right+ui_accept": the screen, then the actions pressed one by one before the picture
	var what := shot.get_slice("+", 0)
	match what:
		"title":
			title()
		"town":
			Saves.new_game(1)
			town()
		"battle":
			skirmish(Content.data.first_battle)
		"room":
			Saves.new_game(1)
			CrawlFlow.depart(7)
			room(Expedition.open_nodes(Expedition.map_of(Util.i32(7)), [])[0])
		"map":
			Saves.new_game(1)
			CrawlFlow.depart(7)
			expedition_map()
		"trail":
			# a descent under way: the first floor's room that leads to the chest cleared, the chest in reach
			Saves.new_game(1)
			var e := CrawlFlow.depart(7)
			var m := Expedition.map_of(e.seed)
			for i in Expedition.open_nodes(m, []):
				if m[i].next.any(func(k: int) -> bool: return m[k].chest):
					e = Expedition.win_room(e, i, {})
			Store.set_key(Saves.CRAWL_KEY, JSON.stringify(e))
			expedition_map()
		"lost":
			# a room left mid-fight: the town says the expedition was lost
			Saves.new_game(1)
			CrawlFlow.depart(7)
			Store.set_key(Saves.ROOM_KEY, "{}")
			home()
		"end":
			# the board after the first room, won with everyone down: the life carried and the way on
			Saves.new_game(1)
			var e := CrawlFlow.depart(7)
			var node: int = Expedition.open_nodes(Expedition.map_of(e.seed), [])[0]
			Store.set_key(Saves.ROOM_KEY, "{}")
			_room_end({"node": node, "heroes": {}}, true, {"units": [], "bag": {}})
		"act", "esc":
			skirmish(Content.data.first_battle)
		"dawn":
			survival()
		"options", "help":
			skirmish(Content.data.first_battle)
		_:
			# battle:<map id>: that map's skirmish, to set the look beside the web's ?scenario=<map id>
			if what.begins_with("battle:"):
				skirmish(what.substr(7))
			else:
				title()
	await get_tree().create_timer(2.5).timeout
	if what == "act" and _screen is BattleScreen:
		var bs: BattleScreen = _screen
		while not bs.is_hero_turn():
			await get_tree().create_timer(0.5).timeout
		bs.choose(Command.index_of("act"))
		bs.key("confirm")
		await get_tree().create_timer(0.8).timeout
	for a in shot.split("+").slice(1):
		var ev := InputEventAction.new()
		ev.action = a
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := ev.duplicate() # buttons act on the release
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().create_timer(0.4).timeout
	if what == "esc" and _screen is BattleScreen:
		(_screen as BattleScreen).key("cancel")
		await get_tree().create_timer(0.5).timeout
	if what in ["options", "help"] and _screen is BattleScreen:
		var w := OptionsWindow.open(_screen, func() -> void: pass)
		await get_tree().create_timer(0.5).timeout
		var n := int(_shot[2]) if _shot.size() > 2 else 0
		w._tabs[3 if what == "help" else n].grab_focus()
		await get_tree().create_timer(0.3).timeout
		if what == "help":
			w._rows[n].opt.run.call(w._rows[n])
		await get_tree().create_timer(0.5).timeout
	# --keys up,confirm,...: the battle screen's keys pressed in order before the shot (to compare a screen with the web's)
	var args := OS.get_cmdline_user_args()
	var k := args.find("--keys")
	if k >= 0 and k + 1 < args.size() and _screen is BattleScreen:
		for a in args[k + 1].split(","):
			(_screen as BattleScreen).key(a)
			await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot[1])
	print("shot saved: ", _shot[1])
	get_tree().quit()
