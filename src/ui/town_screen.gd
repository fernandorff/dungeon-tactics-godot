class_name TownScreen
extends Control
## The walkable town (port of game/town.ts and town-folk.ts): the lead hero walks freely (WASD, arrows, the stick),
## sliding along walls and people; the action key talks to whoever is ahead or goes into the place by the door. The rest
## of the party waits by the Guild, the townsfolk tell one rumour more each time. Q/E turn the camera, Esc opens the menu.

const SPEED := 5.0 # half cells a second: about the battle walk's pace

var main: Main
var view: BattleView
var st: Dictionary
var _at := Vector2.ZERO
var _facing := Vector2(0, -1)
var _overlay: Control
var _hint: Label
var _said := {} # townsfolk id → lines told


func _init(m: Main) -> void:
	main = m


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sc: Dictionary = TownMap.scenario()
	st = TownMap.state(sc)
	TownMap.cast_party(st, CrawlFlow.group())
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
	_name_people()
	view.build(sc.grid, st)
	view.zoom = 0.95
	for p in TownMap.town().places:
		var l := Label3D.new()
		l.text = Texts.t(p.name[0], p.name[1])
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 44
		l.pixel_size = 0.008
		l.outline_size = 10
		l.modulate = Kit.ACCENT
		var c: Vector2 = TownMap.centre_of(TownMap.cell(p.at))
		l.position = Vector3(c.x, 3.0, c.y)
		view.add_child(l)
	_at = TownMap.centre_of(_me().pos)
	view.place_free(TownMap.ME, _at, _facing)
	var top := Kit.panel(self, Vector2(16, 16), Vector2(320, 0))
	top.add_child(Kit.label("Vauclair", 20, Kit.ACCENT))
	top.add_child(Kit.label(Texts.t("Ouro no baú: %d", "Gold in chest: %d") % Chest.parse_chest(Store.json(Chest.CHEST_KEY)).gold, 15))
	var bottom := Kit.panel(self, Vector2(0, -16), Vector2(640, 0), PRESET_CENTER_BOTTOM)
	_hint = Kit.label("", 16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	bottom.add_child(Kit.label(Texts.t("WASD ou setas: andar · Enter: falar ou entrar · Q/E: girar · Esc: menu", "WASD or arrows: walk · Enter: talk or go in · Q/E: turn · Esc: menu"), 14, Kit.MUTED))


func _me() -> Dictionary:
	for u in st.units:
		if u.id == TownMap.ME:
			return u
	return {}


func _folk(id: String) -> Dictionary:
	for f in TownMap.town().townsfolk:
		if "f-" + f.id == id:
			return f
	return {}


## the labels over heads: townsfolk and party by name, the walker by name and class
func _name_people() -> void:
	var g := CrawlFlow.group()
	view.names.clear()
	for u in st.units:
		var f := _folk(u.id)
		if not f.is_empty():
			view.names[u.id] = f.name
		elif u.id == TownMap.ME:
			view.names[u.id] = (Party.member(g, g.deployed[0]) if g.deployed.size() else g.members[0]).name
		elif u.id.begins_with("p-"):
			view.names[u.id] = Party.member(g, u.id.substr(2)).get("name", "")


func notice(text: String) -> void:
	_open(Kit.dialog(self, Texts.t("Aviso", "Notice"), text, [[Texts.t("Ok", "Ok"), _close_overlay]]))


func _open(c: Control) -> void:
	_overlay = c


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_recast()


## after a window: classes may have changed and members come or go
func _recast() -> void:
	var dropped: Array = TownMap.cast_party(st, CrawlFlow.group())
	for id in dropped:
		if view._units.has(id):
			view._units[id].queue_free()
			view._units.erase(id)
	_name_people()
	view.sync_units(st)
	view.place_free(TownMap.ME, _at, _facing)


func _busy() -> bool:
	return is_instance_valid(_overlay)


func _process(delta: float) -> void:
	if _busy():
		return
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right")) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left")),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down")) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up")))
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.25:
		v = stick
	if v.length() > 1.0:
		v = v.normalized()
	if v != Vector2.ZERO:
		var d: Vector2 = TownMap.ground_dir(v, view.yaw()) * SPEED * delta
		_facing = d.normalized()
		_at = TownMap.slide(view.grid, st, _at, d)
		_me().pos = TownMap.cell_under(_at)
		view.place_free(TownMap.ME, _at, _facing)
	_hint.text = _hint_text(TownMap.free_target(st, _at, _facing))


func _hint_text(t: Dictionary) -> String:
	if t.is_empty():
		return Texts.t("Ande até alguém ou até uma porta.", "Walk up to someone or to a door.")
	if t.has("unit"):
		return Texts.t("Enter: falar com %s", "Enter: talk to %s") % view.names.get(t.unit.id, "")
	return Texts.t("Enter: entrar em %s", "Enter: go into %s") % Texts.t(t.place.name[0], t.place.name[1])


func _unhandled_input(ev: InputEvent) -> void:
	if _busy() or not ev.is_pressed() or ev.is_echo():
		return
	if ev.is_action("turn_left"):
		view.turn(-1)
	elif ev.is_action("turn_right"):
		view.turn(1)
	elif ev.is_action("ui_cancel") or ev.is_action("pause"):
		_menu()
	elif ev.is_action("ui_accept"):
		_act(TownMap.free_target(st, _at, _facing))
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		view.zoom_by(0.9)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		view.zoom_by(1.1)
	else:
		return
	get_viewport().set_input_as_handled()


func _act(t: Dictionary) -> void:
	if t.is_empty():
		return
	Sound.play("confirm")
	if t.has("unit"):
		_talk(t.unit)
		return
	if t.act == "soon":
		_open(Kit.dialog(self, Texts.t(t.place.name[0], t.place.name[1]), Texts.t(t.place.soon[0], t.place.soon[1]), [[Texts.t("Ok", "Ok"), _close_overlay]]))
		return
	var p := Places.open(self, main, t.act)
	p.closed.connect(_close_overlay)
	_open(p)


func _talk(u: Dictionary) -> void:
	var f := _folk(u.id)
	var who: String = view.names.get(u.id, "")
	if not f.is_empty():
		var k: int = _said.get(f.id, 0)
		var line: Array = f.lines[k % f.lines.size()]
		_said[f.id] = k + 1
		_open(Kit.dialog(self, who, Texts.t(line[0], line[1]), [[Texts.t("Ok", "Ok"), _close_overlay]]))
		return
	if u.id.begins_with("p-"):
		var id: String = u.id.substr(2)
		var gl: Array = TownMap.town().guild_line
		_open(Kit.dialog(self, who, Texts.t(gl[0], gl[1]), [
			[Texts.t("Ver ficha", "See the sheet"), func() -> void:
				_overlay.queue_free()
				var p := Places.open(self, main, "party")
				p.member(id)
				p.closed.connect(_close_overlay)
				_open(p)],
			[Texts.t("Ok", "Ok"), _close_overlay],
		]))


func _menu() -> void:
	_open(Kit.dialog(self, Texts.t("Menu", "Menu"), "", [
		[Texts.t("Continuar", "Resume"), _close_overlay],
		[Texts.t("Grupo", "Party"), func() -> void:
			_overlay.queue_free()
			_act({"act": "party", "place": {}})],
		[Texts.t("Opções", "Options"), func() -> void:
			_overlay.queue_free()
			_open(OptionsWindow.open(self, _close_overlay))],
		[Texts.t("Voltar ao título", "Back to the title"), main.title],
	]))
