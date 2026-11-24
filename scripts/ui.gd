extends RefCounted
## One place for the look and the touch rules. Every screen builds its UI with these helpers,
## so text size, high contrast and colorblind colours apply everywhere.
##
## Touch rule: the base canvas is 540 wide. On a typical 1080-wide, ~420 dpi phone one base unit
## is ~0.77 dp, so 48 dp is ~62 units. MIN_TOUCH = 72 leaves room for fat fingers; GAP keeps
## buttons from touching.

const MIN_TOUCH := 72
const GAP := 18

const BG := Color("12161f")
const PANEL := Color("1d2433")
const INK := Color("e9e4d8")
const DIM := Color("9aa3b5")
const ACCENT := Color("e8a33d")

## Key gameplay colours. Normal set, then Okabe-Ito (safe for every common colour blindness).
const KEYS := {
	"good": [Color("4cc35a"), Color("009e73")],
	"bad": [Color("e5484d"), Color("d55e00")],
	"info": [Color("4f8ef7"), Color("56b4e9")],
	"warn": [Color("f2c94c"), Color("f0e442")],
}


static func _s() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")


static func key(name: String) -> Color:
	var s := _s()
	var cb: bool = s != null and s.get_value("colorblind")
	return KEYS[name][1 if cb else 0]


static func contrast() -> bool:
	var s := _s()
	return s != null and s.get_value("high_contrast")


static func font_size(base: int) -> int:
	var s := _s()
	var k: float = s.text_scale() if s != null else 1.0
	return int(round(base * k))


static func ink() -> Color:
	return Color.WHITE if contrast() else INK


static func panel_color() -> Color:
	return Color.BLACK if contrast() else PANEL


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size(22)
	var hc := contrast()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("2b3448"), "hover": Color("33405a"), "pressed": Color("4a5878"),
			"focus": Color("2b3448"), "disabled": Color("1f2533")}[state]
		if hc:
			sb.bg_color = Color.BLACK if state != "pressed" else Color("333333")
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3 if hc else 2)
		sb.border_color = Color.WHITE if hc else (ACCENT if state == "pressed" else Color("4a5878"))
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", ink())
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_color", "Button", ink())
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_color", "Label", ink())
	var p := StyleBoxFlat.new()
	p.bg_color = panel_color()
	p.set_corner_radius_all(20)
	p.set_border_width_all(3 if hc else 2)
	p.border_color = Color.WHITE if hc else ACCENT.darkened(0.3)
	p.content_margin_left = 24
	p.content_margin_right = 24
	p.content_margin_top = 22
	p.content_margin_bottom = 22
	t.set_stylebox("panel", "PanelContainer", p)
	# Sliders: a fat grabber so a thumb can hold it.
	var grab := GradientTexture2D.new()
	grab.width = 44
	grab.height = 44
	grab.fill = GradientTexture2D.FILL_RADIAL
	grab.fill_from = Vector2(0.5, 0.5)
	grab.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, ACCENT)
	g.set_offset(1, 0.98)
	g.set_color(1, Color(ACCENT, 0))
	grab.gradient = g
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("4a5878")
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	track.set_corner_radius_all(6)
	t.set_stylebox("slider", "HSlider", track)
	return t


static func button(text: String, on_press: Callable = Callable(), h: int = MIN_TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", font_size(24))
	if on_press.is_valid():
		b.pressed.connect(func():
			var a: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Audio")
			if a != null:
				a.sfx("click")
			on_press.call())
	return b


static func label(text: String, size: int = 22, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size(size))
	l.add_theme_color_override("font_color", color if color.a > 0 else ink())
	return l


## A modal sheet: dims everything under it and swallows touches. Returns the VBox to fill.
## The sheet node itself is box.get_meta("sheet"); free it to close.
static func sheet(parent: Node, width: int = 460) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = theme()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_to_group("sheet")
	parent.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	panel.add_child(box)
	box.set_meta("sheet", root)
	return box


static func close_sheet(box: Node) -> void:
	if is_instance_valid(box) and box.has_meta("sheet"):
		box.get_meta("sheet").queue_free()


## Short haptic tick, respecting the Vibration setting.
static func buzz(ms: int = 30) -> void:
	var s := _s()
	if s != null and s.get_value("vibration"):
		Input.vibrate_handheld(ms)
