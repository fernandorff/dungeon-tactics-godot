class_name OptionsWindow
extends Control
## Options (port of flow3d/options3d.ts, the parts the port has): the language and the four volume bars, all saved.

var _on_close: Callable


static func open(parent: Control, on_close: Callable) -> OptionsWindow:
	var w := OptionsWindow.new()
	w._on_close = on_close
	w.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	parent.add_child(w)
	w._build()
	return w


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var v := Kit.page(self, Texts.t("Opções", "Options"))
	var lang := Kit.button(Texts.t("Idioma: Português", "Language: English"), func() -> void:
		Texts.set_lang("en" if Texts.current() == "pt" else "pt")
		_build())
	v.add_child(lang)
	# four bars since Nov 21 (Fernando: "split the effects into interface and world, and the dialogue too"), 5% steps
	var bars := [["music", Texts.t("Música", "Music")], ["ui", Texts.t("Interface", "Interface")], ["world", Texts.t("Mundo", "World")], ["voice", Texts.t("Diálogo", "Dialogue")]]
	for bar in bars:
		var k: String = bar[0]
		v.add_child(Kit.label("%s: %d%%" % [bar[1], Sound.levels[k]], 16))
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 5
		s.value = Sound.levels[k]
		s.custom_minimum_size = Vector2(0, 44)
		s.focus_mode = FOCUS_ALL
		var name_label: Label = v.get_child(v.get_child_count() - 1)
		s.value_changed.connect(func(x: float) -> void:
			Sound.set_level(k, int(x))
			name_label.text = "%s: %d%%" % [bar[1], int(x)]
			Sound.play("cursor" if k == "ui" else "hit"))
		v.add_child(s)
	v.add_child(Kit.button(Texts.t("Voltar", "Back"), func() -> void:
		queue_free()
		_on_close.call()))
	lang.call_deferred("grab_focus")
