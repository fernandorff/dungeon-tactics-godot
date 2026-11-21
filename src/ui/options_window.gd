class_name OptionsWindow
extends Control
## Options (port of flow3d/options3d.ts, the parts the port has): the language and the effects volume, both saved.

const SFX_KEY := "dt:sfx"

var _on_close: Callable


static func open(parent: Control, on_close: Callable) -> OptionsWindow:
	var w := OptionsWindow.new()
	w._on_close = on_close
	w.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	parent.add_child(w)
	w._build()
	return w


## the saved effects volume, 0 to 1; any doubt keeps the default
static func load_volume() -> void:
	var raw := Store.get_key(SFX_KEY)
	if raw.is_valid_float():
		Sound.volume = clampf(float(raw), 0.0, 1.0)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var v := Kit.page(self, Texts.t("Opções", "Options"))
	var lang := Kit.button(Texts.t("Idioma: Português", "Language: English"), func() -> void:
		Texts.set_lang("en" if Texts.current() == "pt" else "pt")
		_build())
	v.add_child(lang)
	v.add_child(Kit.label(Texts.t("Volume dos efeitos", "Effects volume"), 16))
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 10
	s.value = Sound.volume * 100
	s.custom_minimum_size = Vector2(0, 44)
	s.focus_mode = FOCUS_ALL
	s.value_changed.connect(func(x: float) -> void:
		Sound.volume = x / 100.0
		Store.set_key(SFX_KEY, str(Sound.volume))
		Sound.play("cursor"))
	v.add_child(s)
	v.add_child(Kit.button(Texts.t("Voltar", "Back"), func() -> void:
		queue_free()
		_on_close.call()))
	lang.call_deferred("grab_focus")
