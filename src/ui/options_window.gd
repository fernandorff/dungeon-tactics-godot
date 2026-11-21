class_name OptionsWindow
extends Control
## The Options screen (port of game/options.ts and flow3d/options3d.ts): the screen darkened under a title over a
## hairline and three columns, the categories, the open category's rows (options_row.gd) and a box with what the row
## in focus does; the window's commands side by side under them and a band at the foot saying what the keys do.
## Q and E (the shoulders) change category, Esc on a row goes back to its category and anywhere else closes.

const GOLD := Color("#f0dca0")
const INK := Color("#e8e0cc")
const PANEL := Color("#15130e")
const EDGE := Color("#3a3324")

var _on_close: Callable
var _battle: BattleScreen # the battle it was opened over, for its own rows and commands; null elsewhere
var _cat := 0
var _tabs: Array[Button] = []
var _rows: Array[OptionsRow] = []
var _actions: Array[Button] = []
var _list: VBoxContainer
var _desc_title: Label
var _desc: Label


static func open(parent: Control, on_close: Callable) -> OptionsWindow:
	var w := OptionsWindow.new()
	w._on_close = on_close
	w.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	parent.add_child(w)
	var up: Node = parent
	while up and not up is BattleScreen:
		up = up.get_parent()
	w._battle = up
	w._build()
	return w


## the dark cover with a centred title over a hairline (this window's and its help sheets'); returns the cover
static func backdrop(parent: Control, title: String) -> Control:
	var cover := ColorRect.new()
	cover.color = Color(0.035, 0.035, 0.03, 0.97) # the battle all but hidden, as the web's darkened scene
	cover.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cover.mouse_filter = MOUSE_FILTER_STOP
	parent.add_child(cover)
	var t := Kit.label(title, 28, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	t.anchor_left = 0.0
	t.anchor_right = 1.0
	t.offset_top = 44
	cover.add_child(t)
	var line := ColorRect.new()
	line.color = Color("#5a4f38")
	line.anchor_left = 0.2
	line.anchor_right = 0.8
	line.offset_top = 96
	line.offset_bottom = 97
	cover.add_child(line)
	return cover


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_tabs.clear()
	_actions.clear()
	var cover := backdrop(self, Texts.t("Opções", "Options"))
	var body := HBoxContainer.new()
	body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	body.offset_left = 86
	body.offset_right = -86
	body.offset_top = 120
	body.offset_bottom = -162
	body.add_theme_constant_override("separation", 28)
	cover.add_child(body)
	var cats := VBoxContainer.new()
	cats.custom_minimum_size = Vector2(194, 0)
	cats.add_theme_constant_override("separation", 6)
	body.add_child(cats)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	body.add_child(_desc_box())
	var groups := OptionsList.groups(_battle, _to_title)
	for i in groups.size():
		var b := _tab(groups[i].title)
		b.focus_entered.connect(func() -> void:
			_open_cat(i)
			_describe(groups[i].title, groups[i].help))
		b.pressed.connect(func() -> void:
			_open_cat(i)
			if _rows.size():
				_rows[0].grab_focus())
		cats.add_child(b)
		_tabs.append(b)
	_footer(cover)
	_band(cover)
	set_meta("groups", groups)
	_open_cat(_cat)
	_tabs[_cat].call_deferred("grab_focus")


func _tab(text: String) -> Button:
	var b := Kit.button(text, func() -> void: pass)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_stylebox_override("normal", Kit._box(PANEL, EDGE))
	var open := Kit.label("▸", 14, GOLD) # the open category's mark, at the tab's right end
	open.set_anchors_and_offsets_preset(PRESET_CENTER_RIGHT)
	open.offset_left = -26
	open.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(open)
	return b


func _desc_box() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(288, 0)
	var s := OptionsRow.box(PANEL, EDGE, 3)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	_desc_title = Kit.label("", 20, GOLD)
	v.add_child(_desc_title)
	var line := ColorRect.new()
	line.color = Color("#4a4434")
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_desc = Kit.label("", 17, INK)
	v.add_child(_desc)
	return p


func _describe(title: String, help: String) -> void:
	_desc_title.text = title
	_desc.text = help


## the category's rows in the middle column; the tab stays marked as the open one
func _open_cat(i: int) -> void:
	_cat = i
	for t in _tabs.size():
		_tabs[t].add_theme_stylebox_override("normal", Kit._box(Color("#3a3326") if t == i else PANEL, Color("#6a5c3e") if t == i else EDGE))
		_tabs[t].get_child(0).visible = t == i
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for o in get_meta("groups")[i].rows:
		var r := OptionsRow.make(o)
		r.described.connect(_describe)
		r.changed.connect(_relang.bind(Texts.current()))
		_list.add_child(r)
		_rows.append(r)
	_link()


## where the arrows go: up and down walk the rows round the ends, left goes back to the tab, down past the tabs to
## the commands
func _link() -> void:
	for k in _rows.size():
		var r := _rows[k]
		r.focus_neighbor_top = _rows[posmod(k - 1, _rows.size())].get_path()
		r.focus_neighbor_bottom = _rows[posmod(k + 1, _rows.size())].get_path()
		r.focus_neighbor_left = _tabs[_cat].get_path()
		r.focus_neighbor_right = r.get_path()
	for k in _tabs.size():
		_tabs[k].focus_neighbor_right = _rows[0].get_path() if _rows.size() else NodePath()
		_tabs[k].focus_neighbor_left = _tabs[k].get_path()
	_tabs[-1].focus_neighbor_bottom = _actions[0].get_path() if _actions.size() else NodePath()
	for a in _actions:
		a.focus_neighbor_top = _tabs[_cat].get_path()


## the language changed: every text is drawn again in the new one, on the same category
func _relang(was: String) -> void:
	if Texts.current() != was:
		_build()


## restart and home are a battle's only (Developer: shortcut: the port has no developer menu yet); Back closes
func _footer(cover: Control) -> void:
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	h.offset_left = 86
	h.offset_right = -86
	h.offset_top = -146
	h.offset_bottom = -102
	h.add_theme_constant_override("separation", 12)
	cover.add_child(h)
	if _battle:
		# during the animation or the enemy turn the old battle is still running; the 1st press only asks
		var busy := _battle.busy or not _battle.is_hero_turn()
		var restart := Kit.button(Texts.t("Reiniciar batalha: espere a sua vez", "Restart battle: wait for your turn") if busy else Texts.t("Reiniciar batalha", "Restart battle"), func() -> void: pass)
		restart.disabled = busy
		restart.pressed.connect(func() -> void:
			if OptionsRow.second_press(restart, Texts.t("Confirmar: reiniciar a batalha", "Confirm: restart the battle")):
				close()
				_battle.restart())
		_actions.append(restart)
		var room := _battle.room != null
		var home := Kit.button(Texts.t("Sair da sala", "Leave the room") if room else Texts.t("Cidade", "Town"), func() -> void: pass)
		home.pressed.connect(func() -> void:
			if room and not OptionsRow.second_press(home, Texts.t("Confirmar: perde a expedição", "Confirm: the expedition is lost")):
				return
			close()
			_battle.left_battle.emit() if room else _main().home())
		_actions.append(home)
	_actions.append(Kit.button(Texts.t("Voltar", "Back"), close))
	for a in _actions:
		a.size_flags_horizontal = SIZE_EXPAND_FILL
		a.add_theme_font_size_override("font_size", 18)
		a.add_theme_stylebox_override("normal", Kit._box(PANEL, EDGE))
		h.add_child(a)


## what the keys do here, for the input in use: the keys on a PC, the drawn arrows on touch
func _band(cover: Control) -> void:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", OptionsRow.box(Color("#1c170e"), Color("#4a4030"), 0))
	band.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	band.offset_top = -90
	band.offset_bottom = -36
	cover.add_child(band)
	var keys := "%s %s: %s  ·  ← →: %s  ·  %s: %s" % [OptionsHelp.keys_of(["turn_left"]), OptionsHelp.keys_of(["turn_right"]), Texts.t("mudar a categoria", "change category"), Texts.t("mudar o valor", "change the value"), OptionsHelp.keys_of(["ui_cancel"]), Texts.t("voltar às categorias", "back to categories")]
	var l := Kit.label(Texts.t("◀ ▶ mudam o valor", "◀ ▶ change the value") if Settings.touch_device() and not DisplayServer.has_hardware_keyboard() else keys, 17, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(l)


func _main() -> Main:
	var up: Node = self
	while up and not up is Main:
		up = up.get_parent()
	return up


## back to the title; a room left behind loses the expedition, as the web's title does on its next boot
func _to_title() -> void:
	var m := _main()
	close()
	CrawlFlow.left_room()
	m.title()


func close() -> void:
	queue_free()
	_on_close.call()


func _unhandled_input(ev: InputEvent) -> void:
	var sheet := get_child(get_child_count() - 1)
	if sheet.has_meta("close"): # a help sheet is open over the window: Esc closes it alone
		if ev.is_action_pressed("ui_cancel"):
			sheet.get_meta("close").call()
			get_viewport().set_input_as_handled()
		return
	var on_row := get_viewport().gui_get_focus_owner() is OptionsRow
	if ev.is_action_pressed("turn_left") or ev.is_action_pressed("turn_right"):
		var i := posmod(_cat + (-1 if ev.is_action_pressed("turn_left") else 1), _tabs.size())
		_tabs[i].grab_focus()
		Sound.play("cursor")
	elif ev.is_action_pressed("ui_cancel"):
		Sound.play("cancel")
		if on_row:
			_tabs[_cat].grab_focus()
		else:
			close()
	else:
		return
	get_viewport().set_input_as_handled()
