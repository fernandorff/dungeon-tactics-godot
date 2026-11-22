class_name Settings
## The player's settings that Options changes, each under the web game's own dt: key and in its form (raw text or JSON),
## read back through the web's parser: text speed (talk.ts), the help options (key-hints.ts), fast battle (main.ts),
## town grid (town-map.ts), marks (mark-style.ts), motion (motion.ts), layout (layout-mode.ts), screen buttons
## (screen-buttons.ts), slow-motion deaths (hit-weight.ts), fps counter (fps.ts) and the pad side (town-pad.ts).
## Language and the volumes live in texts.gd and sound.gd.

const TEXT_KEY := "dt:text"
const TUTORIAL_KEY := "dt:tutorial"
const HINTS_KEY := "dt:hints"
const GLYPHS_KEY := "dt:glyphs"
const FAST_KEY := "dt:fast"
const GRID_KEY := "dt:town-grid"
const MARKS_KEY := "dt:marks"
const MOTION_KEY := "dt:motion"
const LAYOUT_KEY := "dt:layout"
const BUTTONS_KEY := "dt:screen-buttons"
const SLOWMO_KEY := "dt:death-slowmo"
const FPS_KEY := "dt:fps"
const PAD_KEY := "dt:town-pad"
const FAST := 3.0 # the battle's animations three times faster, as holding Enter on the web

const MARK_STYLES := ["simples", "luz", "pedra", "neon"]


## a raw text value kept only when it is one of `allowed`
static func _pick(key: String, allowed: Array, fallback: String) -> String:
	var v := Store.get_key(key)
	return v if v in allowed else fallback


## a JSON yes or no; anything else is `fallback`
static func _flag(key: String, fallback: Variant) -> Variant:
	var v: Variant = Store.json(key)
	return v if typeof(v) == TYPE_BOOL else fallback


static func _save_flag(key: String, on: bool) -> void:
	Store.set_key(key, JSON.stringify(on))


## Normal ~35 letters a second, Fast ~3 times that, Instant the whole line. shortcut: the port has no dialogue box yet;
## talk.ts's port reads this
static func text_speed() -> String:
	return _pick(TEXT_KEY, ["fast", "instant"], "normal")


static func set_text_speed(v: String) -> void:
	Store.set_key(TEXT_KEY, v)


## the battle's teaching lines, off by default (Nov 18). shortcut: the port shows no tutorial strip yet
static func tutorial() -> bool:
	return _flag(TUTORIAL_KEY, false)


static func set_tutorial(on: bool) -> void:
	_save_flag(TUTORIAL_KEY, on)


## The battle footer follows the last input in automatic mode.
static func hints() -> String:
	return _pick(HINTS_KEY, ["always", "never"], "auto")


static func set_hints(v: String) -> void:
	Store.set_key(HINTS_KEY, v)


## what the key hints draw. shortcut: the port has no key or pad glyphs yet (glyphs.ts)
static func glyphs() -> String:
	return _pick(GLYPHS_KEY, ["keyboard", "xbox", "playstation", "switch"], "auto")


static func set_glyphs(v: String) -> void:
	Store.set_key(GLYPHS_KEY, v)


## the fast battle stays on in the next battle, as the web's ⏩ toggle
static func fast() -> bool:
	return Store.get_key(FAST_KEY) == "1"


static func set_fast(on: bool) -> void:
	Store.set_key(FAST_KEY, "1" if on else "")


## the town's debug grid, off unless chosen (Nov 16). shortcut: the port's town draws no grid yet
static func town_grid() -> bool:
	return _flag(GRID_KEY, false)


static func set_town_grid(on: bool) -> void:
	_save_flag(GRID_KEY, on)


## how the board's marks are drawn; Light by default (measured the lightest of the lit ones on the web's bench).
## shortcut: the port draws one flat style for now; the marks' port reads this
static func marks() -> String:
	return _pick(MARKS_KEY, MARK_STYLES, "luz")


static func set_marks(v: String) -> void:
	Store.set_key(MARKS_KEY, v)


## Yes, No or the system's own (saved as JSON text, as the web's)
static func motion() -> String:
	var v: Variant = Store.json(MOTION_KEY)
	return v if v in ["reduce", "full"] else "system"


static func set_motion(v: String) -> void:
	Store.set_key(MOTION_KEY, JSON.stringify(v))


## Reduce motion as the screens ask it. shortcut: the port has no camera shake, action camera or slow motion yet, and
## Godot gives no system "reduce motion" flag, so System counts as No
static func reduced_motion() -> bool:
	return motion() == "reduce"


## the battle panels at the screen edges or in a centred 16:9 frame. shortcut: the port's HUD has one layout for now
static func layout() -> String:
	return _pick(LAYOUT_KEY, ["frame"], "edges")


static func set_layout(v: String) -> void:
	Store.set_key(LAYOUT_KEY, v)


## a device a finger plays: the screen buttons start on and the town pad's row shows
static func touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()


## Undo and the camera buttons default to visible on a touchscreen.
static func screen_buttons() -> bool:
	return _flag(BUTTONS_KEY, touch_device())


static func set_screen_buttons(on: bool) -> void:
	_save_flag(BUTTONS_KEY, on)


## on unless set to false. shortcut: the port has no slow-motion death yet (hit-weight.ts)
static func slowmo() -> bool:
	return _flag(SLOWMO_KEY, true)


static func set_slowmo(on: bool) -> void:
	_save_flag(SLOWMO_KEY, on)


static func fps() -> bool:
	return Store.get_key(FPS_KEY) == "1"


static func set_fps(on: bool) -> void:
	Store.set_key(FPS_KEY, "1" if on else "0")


## the town joystick's side. shortcut: the port has no town joystick yet (town-pad.ts)
static func pad_side() -> String:
	return _pick(PAD_KEY, ["right"], "left")


static func set_pad_side(v: String) -> void:
	Store.set_key(PAD_KEY, v)


## fullscreen is not saved, as the web's (it dies with the tab there; here with the window)
static func fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


static func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
