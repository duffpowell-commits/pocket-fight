extends RefCounted
## The SETTINGS sheet (title and pause menu): SettingsSheet.open(parent).
## Changing text size or high contrast rebuilds the sheet so the new look shows at once.

const UI = preload("res://scripts/ui.gd")
const Quality = preload("res://scripts/quality.gd")
const StudioSplash = preload("res://branding/studio_splash.gd")


static func open(parent: Node) -> VBoxContainer:
	var s: Node = parent.get_node("/root/Settings")
	var box := UI.sheet(parent, 500)
	box.add_child(UI.label("SETTINGS", 28, UI.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", UI.GAP)
	scroll.add_child(col)

	_slider(col, s, "MUSIC", "music", 0.0, 1.0)
	_toggle(col, s, "GAME MUSIC", "game_music")
	_slider(col, s, "SOUND EFFECTS", "sfx", 0.0, 1.0)
	_slider(col, s, "BRIGHTNESS", "gamma", 0.6, 1.6)
	_toggle(col, s, "VIBRATION", "vibration")
	var text_b := UI.button("TEXT SIZE: " + s.text_name())
	text_b.name = "text_size"
	text_b.pressed.connect(func():
		s.set_value("text_size", (int(s.get_value("text_size")) + 1) % s.TEXT_SCALES.size())
		_reopen(box, parent))
	col.add_child(text_b)
	_toggle(col, s, "SUBTITLES", "subtitles")
	_toggle(col, s, "HIGH CONTRAST", "high_contrast", func(): _reopen(box, parent))
	_toggle(col, s, "COLORBLIND COLORS", "colorblind")
	_toggle(col, s, "LEFT-HANDED CONTROLS", "left_handed")
	_toggle(col, s, "INVERT LOOK", "invert_y")
	_slider(col, s, "LOOK SENSITIVITY", "sensitivity", 0.3, 2.0)
	var q_b := UI.button("GRAPHICS: " + Quality.NAMES[maxi(int(s.get_value("tier")), 0)])
	q_b.name = "tier"
	q_b.pressed.connect(func():
		Quality.apply(parent.get_tree(), (maxi(int(s.get_value("tier")), 0) + 1) % 3)
		q_b.text = "GRAPHICS: " + Quality.NAMES[int(s.get_value("tier"))])
	col.add_child(q_b)
	_toggle(col, s, "CONTROLS LEGEND", "show_legend")
	_toggle(col, s, "BATTERY SAVER", "battery_saver")
	_toggle(col, s, "SHARE ANONYMOUS STATS", "share_stats")
	col.add_child(UI.button("CONTROLS", func(): open_controls(parent)))
	col.add_child(UI.button("CREDITS", func(): _open_credits(parent)))
	box.add_child(UI.button("DONE", func(): UI.close_sheet(box)))
	return box


static func _open_credits(parent: Node) -> void:
	var box := UI.sheet(parent, 500)
	box.add_child(UI.label("CREDITS", 28, UI.ACCENT))
	box.add_child(UI.label("Published by " + StudioSplash.PUBLISHER))
	box.add_child(UI.button("DONE", func(): UI.close_sheet(box)))


static func _reopen(box: VBoxContainer, parent: Node) -> void:
	UI.close_sheet(box)
	open(parent)


static func _toggle(col: Control, s: Node, title: String, key: String, after: Callable = Callable()) -> void:
	var b := UI.button(title + ": " + ("ON" if s.get_value(key) else "OFF"))
	b.name = key
	b.pressed.connect(func():
		s.set_value(key, not s.get_value(key))
		b.text = title + ": " + ("ON" if s.get_value(key) else "OFF")
		if after.is_valid():
			after.call())
	col.add_child(b)


static func _slider(col: Control, s: Node, title: String, key: String, lo: float, hi: float) -> void:
	col.add_child(UI.label(title, 20))
	var sl := HSlider.new()
	sl.name = key
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = float(s.get_value(key))
	sl.custom_minimum_size = Vector2(0, UI.MIN_TOUCH - 16)
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float): s.set_value(key, v))
	col.add_child(sl)


## CONTROLS: every action with its key / pad input. Tap one, then press the new key or button.
static func open_controls(parent: Node) -> VBoxContainer:
	var c: Node = parent.get_node("/root/Controls")
	var box := UI.sheet(parent, 500)
	box.add_child(UI.label("CONTROLS", 28, UI.ACCENT))
	var hint := UI.label("Tap an action, then press a key or pad button", 18, UI.DIM)
	box.add_child(hint)
	for a in c.ACTIONS:
		var b := UI.button(c.ACTIONS[a] + ": " + c.describe(a), Callable(), 64)
		b.name = a
		b.pressed.connect(func():
			hint.text = "Press a key or button for " + c.ACTIONS[a]
			var cap := _Capture.new()
			cap.done = func(e: InputEvent):
				c.rebind(a, e)
				b.text = c.ACTIONS[a] + ": " + c.describe(a)
				hint.text = "Saved"
			box.add_child(cap))
		box.add_child(b)
	box.add_child(UI.button("RESET TO DEFAULTS", func():
		c.reset()
		UI.close_sheet(box)
		open_controls(parent)))
	box.add_child(UI.button("DONE", func(): UI.close_sheet(box)))
	return box


## Grabs the next key / pad button / stick push, then removes itself.
class _Capture extends Node:
	var done: Callable

	func _input(e: InputEvent) -> void:
		var ok: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventJoypadButton and e.pressed) \
			or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.6)
		if not ok:
			return
		if e is InputEventJoypadMotion:
			e.axis_value = signf(e.axis_value)
		get_viewport().set_input_as_handled()
		done.call(e)
		queue_free()
