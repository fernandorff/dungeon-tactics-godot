class_name SettingsTests
## The Options settings: each one's default, its round trip through the web's dt: key in the web's form, a broken value
## falling back, and the Options rows stepping through their values.


func test_settings_defaults_and_fallbacks() -> String:
	Store.reset_memory()
	var want := [Settings.text_speed(), Settings.tutorial(), Settings.hints(), Settings.glyphs(), Settings.fast(), Settings.town_grid(), Settings.marks(), Settings.motion(), Settings.layout(), Settings.slowmo(), Settings.fps(), Settings.pad_side()]
	if want != ["normal", false, "auto", "auto", false, false, "luz", "system", "edges", true, false, "left"]:
		return "defaults %s" % [want]
	# values the web's parsers do not know, and a string where a yes or no belongs
	for k in [Settings.TEXT_KEY, Settings.HINTS_KEY, Settings.GLYPHS_KEY, Settings.MARKS_KEY, Settings.LAYOUT_KEY, Settings.PAD_KEY]:
		Store.set_key(k, "bogus")
	Store.set_key(Settings.TUTORIAL_KEY, "\"yes\"")
	Store.set_key(Settings.SLOWMO_KEY, "0")
	Store.set_key(Settings.MOTION_KEY, "reduce") # not JSON text: the web's parseMotion reads JSON
	var got := [Settings.text_speed(), Settings.hints(), Settings.glyphs(), Settings.marks(), Settings.layout(), Settings.pad_side(), Settings.tutorial(), Settings.slowmo(), Settings.motion()]
	return "" if got == ["normal", "auto", "auto", "luz", "edges", "left", false, true, "system"] else "fallbacks %s" % [got]


## each set writes the web's form under its key: raw text, JSON or "1"
func test_settings_saved_as_the_web() -> String:
	Store.reset_memory()
	Settings.set_text_speed("instant")
	Settings.set_tutorial(true)
	Settings.set_fast(true)
	Settings.set_motion("reduce")
	Settings.set_marks("neon")
	Settings.set_slowmo(false)
	Settings.set_fps(true)
	Settings.set_screen_buttons(true)
	var raw := [Store.get_key("dt:text"), Store.get_key("dt:tutorial"), Store.get_key("dt:fast"), Store.get_key("dt:motion"), Store.get_key("dt:marks"), Store.get_key("dt:death-slowmo"), Store.get_key("dt:fps"), Store.get_key("dt:screen-buttons")]
	if raw != ["instant", "true", "1", "\"reduce\"", "neon", "false", "1", "true"]:
		return "saved %s" % [raw]
	if not Settings.reduced_motion() or Settings.slowmo() or not Settings.screen_buttons():
		return "read back"
	Settings.set_fast(false)
	return "" if Store.get_key("dt:fast") == "" else "fast off saved %s" % Store.get_key("dt:fast")


## every row's value is one of its own, a step goes round the ends, and a bar moves in 5% steps within 0 to 100
func test_options_rows_step() -> String:
	Store.reset_memory()
	Sound.load_levels()
	for g in OptionsList.groups(null, func() -> void: pass):
		for o in g.rows:
			if o.has("values") and not o["values"].any(func(p: Array) -> bool: return p[0] == o.read.call()):
				return "%s shows no value" % o.label
	var speed := OptionsRow.make(OptionsList.groups(null, func() -> void: pass)[0].rows[0])
	speed.step(-1)
	var back := Settings.text_speed()
	speed.step(1)
	speed.step(1)
	var fwd := Settings.text_speed()
	speed.free()
	if back != "instant" or fwd != "fast":
		return "text speed steps %s %s" % [back, fwd]
	var music := OptionsRow.make(OptionsList.percent("m", "", "music"))
	for i in 30:
		music.step(-1)
	var low: int = Sound.levels.music
	music.step(1)
	var up: int = Sound.levels.music
	music.free()
	Sound.load_levels()
	return "" if low == 0 and up == 5 else "bar %d %d" % [low, up]
