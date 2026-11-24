extends RefCounted
## Live tuning (dev builds): sliders for every number a game feels through, changed while you play.
## Stop prompting "make the hit-stop longer": open DEV MENU -> TUNE, drag, play, drag again.
##
## A node opts in by joining group "tunable" and declaring what can move and how far:
##     const TUNE := {"max_speed": [1.0, 12.0], "jump_speed": [2.0, 10.0]}
## and calling DebugMenu.apply_tune(self) at the end of _ready() (picks up saved values).
## Character3D, CameraRig and the Feel autoload already do. Sliders change every live node of that
## kind at once. Values are kept in user://tune.cfg (dev builds only) so they survive a restart.
## SHARE VALUES opens a prefilled GitHub issue (copy on web/desktop): paste-ready lines a session
## turns into the real defaults in code. RESET puts the code defaults back.

const UI = preload("res://scripts/ui.gd")
const Config = preload("res://scripts/config.gd")
const FILE := "user://tune.cfg"


## Tunable kinds currently alive: {kind: {"nodes": [...], "spec": TUNE}}. Kind = script file name.
static func kinds(tree: SceneTree) -> Dictionary:
	var out := {}
	var nodes: Array = tree.get_nodes_in_group("tunable")
	for n in nodes:
		var k := kind_of(n)
		if k == "" or not ("TUNE" in n):
			continue
		if not out.has(k):
			out[k] = {"nodes": [], "spec": n.TUNE}
		out[k]["nodes"].append(n)
	return out


static func kind_of(n: Object) -> String:
	var s: Script = n.get_script()
	return "" if s == null else s.resource_path.get_file().get_basename()


## Saved value for kind/prop, or null.
static func saved(kind: String, prop: String) -> Variant:
	var c := ConfigFile.new()
	if c.load(FILE) != OK:
		return null
	return c.get_value(kind, prop, null)


static func save_value(kind: String, prop: String, v: float) -> void:
	var c := ConfigFile.new()
	c.load(FILE)
	c.set_value(kind, prop, v)
	c.save(FILE)


static func clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))


## Put saved values onto a node that just joined (called from DebugMenu.apply_tune).
static func apply(n: Object) -> void:
	if not ("TUNE" in n):
		return
	var k := kind_of(n)
	var c := ConfigFile.new()
	if c.load(FILE) != OK or not c.has_section(k):
		return
	for prop in n.TUNE:
		if c.has_section_key(k, prop):
			n.set(prop, c.get_value(k, prop))


## Lines like "character3d.max_speed = 7.2 (code 6.0)" for every value moved off its default.
static func changed_lines(tree: SceneTree, defaults: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var ks := kinds(tree)
	for k in ks:
		var n: Object = ks[k]["nodes"][0]
		for prop in ks[k]["spec"]:
			var v: float = float(n.get(prop))
			var d: float = float(defaults.get(k + "." + prop, v))
			if not is_equal_approx(v, d):
				out.append("%s.%s = %s (code %s)" % [k, prop, _num(v), _num(d)])
	return out


static func _num(v: float) -> String:
	return str(snappedf(v, 0.001))


## Builds the panel: bottom half of the screen, no dimming, so the game stays visible and playable
## above it. HIDE folds it into a small TUNE tab at the top. Returns the panel root.
static func open(parent: Node, defaults: Dictionary, on_close: Callable) -> Control:
	var tree := parent.get_tree()
	var root := Control.new()
	root.name = "TunePanel"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # touches above the panel reach the game
	root.theme = UI.theme()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)

	var panel := PanelContainer.new()
	panel.name = "Body"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.55
	panel.anchor_bottom = 1.0
	root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UI.GAP)
	outer.add_child(top)
	var tab := UI.button("TUNE", Callable(), UI.MIN_TOUCH)   # the folded tab
	tab.name = "TuneTab"
	tab.visible = false
	tab.custom_minimum_size = Vector2(160, UI.MIN_TOUCH)
	tab.anchor_left = 1.0          # top right: clear of the BACK / pause corner
	tab.anchor_right = 1.0
	tab.offset_left = -168
	tab.offset_right = -8
	tab.offset_top = 8
	root.add_child(tab)
	var hide_b := UI.button("HIDE", func():
		panel.visible = false
		tab.visible = true)
	hide_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.pressed.connect(func():
		panel.visible = true
		tab.visible = false)
	top.add_child(hide_b)
	var share := UI.button("SHARE VALUES", func(): _share(tree, defaults))
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(share)
	var close_b := UI.button("CLOSE", on_close)
	close_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(close_b)

	var scroll := ScrollContainer.new()
	scroll.follow_focus = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "Sliders"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	scroll.add_child(col)

	scroll.set_deferred("scroll_vertical", 0)
	var ks := kinds(tree)
	if ks.is_empty():
		col.add_child(UI.label("Nothing to tune on this screen. Open a gameplay scene.", 18, UI.DIM))
	for k in ks:
		col.add_child(UI.label(k.to_upper(), 20, UI.ACCENT))
		for prop in ks[k]["spec"]:
			_slider(col, ks[k]["nodes"], k, prop, ks[k]["spec"][prop])
	col.add_child(UI.button("RESET TO CODE VALUES", func():
		clear()
		for k in ks:
			for n in ks[k]["nodes"]:
				if is_instance_valid(n):
					for prop in ks[k]["spec"]:
						if defaults.has(k + "." + prop):
							n.set(prop, defaults[k + "." + prop])
		on_close.call()))
	return root


static func _slider(col: Control, nodes: Array, kind: String, prop: String, range_: Array) -> void:
	var first: Object = nodes[0]
	var lab := UI.label("", 18)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(lab)
	var sl := HSlider.new()
	sl.name = kind + "__" + prop   # node names cannot hold "."
	sl.min_value = float(range_[0])
	sl.max_value = float(range_[1])
	sl.step = float(range_[2]) if range_.size() > 2 else 0.01
	sl.value = float(first.get(prop))
	sl.custom_minimum_size = Vector2(0, UI.MIN_TOUCH - 16)
	sl.focus_mode = Control.FOCUS_NONE
	var show := func(v: float): lab.text = "%s  %s" % [prop.replace("_", " "), _num(v)]
	show.call(sl.value)
	sl.value_changed.connect(func(v: float):
		show.call(v)
		for n in nodes:
			if is_instance_valid(n):
				n.set(prop, v)
		save_value(kind, prop, v))
	col.add_child(sl)


static func _share(tree: SceneTree, defaults: Dictionary) -> void:
	var lines := changed_lines(tree, defaults)
	var body := "Tuned on the phone (DEV MENU -> TUNE). Make these the code defaults:\n\n" + \
		("\n".join(lines) if lines.size() > 0 else "(nothing changed)")
	DisplayServer.clipboard_set(body)
	if OS.has_feature("android"):
		OS.shell_open(share_url(body))


static func share_url(body: String) -> String:
	return "https://github.com/%s/issues/new?labels=tuning&title=%s&body=%s" % [
		Config.repo(), "Tuned values".uri_encode(), body.uri_encode()]
