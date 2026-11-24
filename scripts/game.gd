extends Control
## The game screen: the monster creator. This IS the game for the one-week test (docs/PITCH.md):
## build a monster by tapping parts, by describing it in words, or by rolling a surprise, then
## take it into one short test fight (scripts/fight.gd).
##
## Foundation pieces kept from the starter: PAUSE button, Android back = close sheet / pause,
## auto-pause + save when the app goes to the background, pause menu (resume / settings / bug /
## quit), autosave after every change + CONTINUE, left-handed layout, text size, high contrast.
## There is no GAME OVER here: a creator can't be lost. The fight has its own win / faint screens.

const UI = preload("res://scripts/ui.gd")
const SettingsSheet = preload("res://scripts/settings_sheet.gd")
const BugReport = preload("res://scripts/bug_report.gd")
const Monster = preload("res://scripts/monster.gd")
const View = preload("res://scripts/monster_view.gd")
const Fight = preload("res://scripts/fight.gd")

## The strip of tabs under the monster, in order. "shape" is the four sliders.
const FIELDS := ["body", "ears", "eyes", "mouth", "tail", "marks", "top", "back", "color", "accent", "shape", "move", "mood"]
const EXAMPLES := ["a fat blue cat with horns", "grumpy red dragon named Gus", "tiny shy pink bunny with spots",
	"long green lizard, one eye, no tail", "goofy yellow duck", "black wolf with white stripes"]

var design: Dictionary = Monster.fresh()
var prev: Dictionary = {}            # one step of UNDO for describe / surprise
var wins := 0
var field := "body"
var paused := false
var over := false                    # never true here; the bot and dev menu read it
var rng := RandomNumberGenerator.new()
var last_heard: Array = []           # what the last description understood (shown + tested)
var last_missed: Array = []

var view: View
var name_btn: Button
var pause_btn: Button
var status: Label
var undo_btn: Button
var strip: HBoxContainer
var options: Control
var sheet_box: VBoxContainer
var fight: Control
var _settings: Node
var _save: Node


func _ready() -> void:
	_settings = get_node("/root/Settings")
	_save = get_node("/root/Save")
	_settings.changed.connect(_on_setting)
	rng.randomize()
	var d: Dictionary = _save.read()
	if d.is_empty():
		design = Monster.surprise(rng)      # a new game hatches something, never a blank
	else:
		design = Monster.clean(d.get("monster", {}))
		var w: Variant = d.get("wins", 0)
		wins = int(w) if typeof(w) in [TYPE_INT, TYPE_FLOAT] else 0
	_build()
	checkpoint()
	get_node("/root/Audio").music("music_loop")


# ---------------------------------------------------------------- state + saving

func state() -> Dictionary:
	return {"monster": design, "wins": wins}


func checkpoint() -> void:
	_save.write(state())


func bug_state() -> String:
	if is_instance_valid(fight):
		return fight.bug_state()
	return "creator field %s wins %d paused %s monster %s" % [field, wins, paused, JSON.stringify(design)]


# ---------------------------------------------------------------- layout

func _on_setting(key: String) -> void:
	if key in ["text_size", "high_contrast", "left_handed"]:
		_build()


func _build() -> void:
	for c in get_children():
		if not c.is_in_group("sheet") and c != fight:
			c.queue_free()
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	view = View.new()
	view.design = design
	view.animate = not _settings.get_value("low_graphics")
	view.anchor_right = 1.0
	view.offset_top = 104
	view.offset_bottom = 430
	add_child(view)
	var poke := Control.new()              # tap the monster: it hops
	poke.anchor_left = 0.2
	poke.anchor_right = 0.8
	poke.offset_top = 150
	poke.offset_bottom = 420
	poke.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			view.act("hop")
			get_node("/root/Audio").sfx("good", 1.2))
	add_child(poke)

	var left: bool = _settings.get_value("left_handed")
	pause_btn = UI.button("PAUSE", pause)
	pause_btn.anchor_left = 0.0 if left else 1.0
	pause_btn.anchor_right = pause_btn.anchor_left
	pause_btn.offset_left = 24 if left else -174
	pause_btn.offset_right = pause_btn.offset_left + 150
	pause_btn.offset_top = 30
	pause_btn.offset_bottom = 30 + UI.MIN_TOUCH
	add_child(pause_btn)
	name_btn = UI.button("", _name_sheet)
	name_btn.anchor_right = 1.0
	name_btn.offset_left = 190 if left else 24
	name_btn.offset_right = -24 if left else -190
	name_btn.offset_top = 30
	name_btn.offset_bottom = 30 + UI.MIN_TOUCH
	name_btn.clip_text = true
	add_child(name_btn)

	# status line + UNDO
	status = UI.label("", 18, UI.DIM)
	status.anchor_right = 1.0
	status.offset_left = 20
	status.offset_right = -150
	status.offset_top = 432
	status.offset_bottom = 504
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.clip_text = true
	add_child(status)
	undo_btn = UI.button("UNDO", undo)
	undo_btn.anchor_left = 1.0
	undo_btn.anchor_right = 1.0
	undo_btn.offset_left = -140
	undo_btn.offset_right = -20
	undo_btn.offset_top = 432
	undo_btn.offset_bottom = 504
	add_child(undo_btn)

	# strip of part tabs (swipe sideways)
	var strip_scroll := ScrollContainer.new()
	strip_scroll.name = "Strip"
	strip_scroll.anchor_right = 1.0
	strip_scroll.offset_top = 512
	strip_scroll.offset_bottom = 512 + UI.MIN_TOUCH + 14
	strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(strip_scroll)
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	strip_scroll.add_child(strip)
	for f in FIELDS:
		var b := UI.button(_field_title(f), func(): pick_field(f))
		b.custom_minimum_size.x = 118
		b.toggle_mode = true
		b.set_meta("field", f)
		strip.add_child(b)

	# options for the picked tab
	var opt_scroll := ScrollContainer.new()
	opt_scroll.name = "Options"
	opt_scroll.anchor_right = 1.0
	opt_scroll.anchor_bottom = 1.0
	opt_scroll.offset_left = 16
	opt_scroll.offset_right = -16
	opt_scroll.offset_top = 512 + UI.MIN_TOUCH + 26
	opt_scroll.offset_bottom = -132
	opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(opt_scroll)
	options = VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 10)
	opt_scroll.add_child(options)

	# bottom bar: the three big verbs
	var bar := HBoxContainer.new()
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = -118
	bar.offset_bottom = -30
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	var verbs := [["DESCRIBE", describe_sheet], ["SURPRISE", surprise], ["FIGHT", open_fight]]
	if left:
		verbs.reverse()
	for v in verbs:
		var b2 := UI.button(v[0], v[1], 88)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(b2)

	if is_instance_valid(fight):
		move_child(fight, -1)
	for sh in get_tree().get_nodes_in_group("sheet"):   # open sheets stay on top of the rebuilt screen
		if sh.get_parent() == self:
			move_child(sh, -1)
	_refresh()
	pick_field(field)


func _field_title(f: String) -> String:
	return "SHAPE" if f == "shape" else Monster.TITLES[f]


func _refresh() -> void:
	if view == null:
		return
	view.design = design
	name_btn.text = "%s   (rename)" % design["name"].to_upper()
	undo_btn.disabled = prev.is_empty()
	if status.text == "":
		status.text = "Tap a part, DESCRIBE it, or roll a SURPRISE."


## Show the choices for one tab.
func pick_field(f: String) -> void:
	field = f
	for b in strip.get_children():
		b.set_pressed_no_signal(b.get_meta("field") == f)
	for c in options.get_children():
		options.remove_child(c)
		c.queue_free()
	if f == "shape":
		for k in Monster.SHAPE:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var l := UI.label(Monster.TITLES[k], 20)
			l.custom_minimum_size = Vector2(84, UI.MIN_TOUCH)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(l)
			var s := HSlider.new()
			s.name = "Slider_" + k
			s.min_value = 0.0
			s.max_value = 1.0
			s.step = 0.05
			s.value = design[k]
			s.custom_minimum_size = Vector2(0, UI.MIN_TOUCH)
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.value_changed.connect(func(v: float): set_part(k, v))
			row.add_child(s)
			options.add_child(row)
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	options.add_child(flow)
	for o in Monster.PARTS[f]:
		var b := UI.button(o.to_upper(), func(): set_part(f, o))
		b.custom_minimum_size.x = 118
		b.toggle_mode = true
		b.set_meta("option", o)
		b.set_pressed_no_signal(design[f] == o)
		if f in ["color", "accent"]:
			_swatch(b, Monster.COLORS[o])
		flow.add_child(b)
	if f == "move":
		options.add_child(UI.label("Your move is used in a FIGHT. Looks never change a fight.", 18, UI.DIM))


## Colour chips show the colour itself; the name stays on them, so colour is never the only cue.
func _swatch(b: Button, c: Color) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(6 if st == "pressed" else 2)
		sb.border_color = Color.WHITE if st == "pressed" else Color("1b2028")
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		b.add_theme_stylebox_override(st, sb)
	var dark := c.get_luminance() > 0.5
	for n in ["font_color", "font_pressed_color", "font_hover_color"]:
		b.add_theme_color_override(n, Color("1b2028") if dark else Color.WHITE)


# ---------------------------------------------------------------- changing the monster

## One part or slider changes. Every change is saved straight away.
func set_part(key: String, value: Variant) -> void:
	var next := design.duplicate()
	next[key] = value
	design = Monster.clean(next)
	var now: Variant = design[key]          # what it really became (clean() may have adjusted it)
	status.text = "%s: %s" % [Monster.TITLES.get(key, key.to_upper()), str(now) if typeof(now) == TYPE_STRING else "%d%%" % int(round(float(now) * 100.0))]
	if key in ["color", "accent"] and next["accent"] != design["accent"]:
		status.text = "2ND COLOR moved to %s so markings still show." % design["accent"]
	_refresh()
	if key in Monster.PARTS and field == key:
		for row in options.get_children():
			for b in row.get_children():
				if b is Button and b.has_meta("option"):
					b.set_pressed_no_signal(b.get_meta("option") == design[key])
	if key == "move":
		view.act(design["move"])
	checkpoint()


func _replace(next: Dictionary, note: String) -> void:
	prev = design.duplicate()
	design = Monster.clean(next)
	status.text = note
	_refresh()
	pick_field(field)
	view.act("hop")
	checkpoint()


func surprise() -> void:
	if paused:
		return
	var d := Monster.surprise(rng)
	_replace(d, "Hatched %s. UNDO brings the last one back." % d["name"])
	get_node("/root/Audio").sfx("level")
	UI.buzz(20)


func undo() -> void:
	if prev.is_empty() or paused:
		return
	var back := prev
	prev = {}
	design = Monster.clean(back)
	status.text = "%s is back." % design["name"]
	_refresh()
	pick_field(field)
	checkpoint()


## Build from typed words. fresh=true starts from a blank monster, false changes the current one.
## Returns false (and changes nothing) when no word was understood.
func describe(text: String, fresh: bool) -> bool:
	var r: Dictionary = Monster.from_text(text, {} if fresh else design)
	last_heard = r["heard"]
	last_missed = r["missed"]
	if last_heard.is_empty() and r["design"]["name"] == (Monster.fresh()["name"] if fresh else design["name"]):
		return false
	var d: Dictionary = r["design"]
	if fresh and not ("named" in text.to_lower() or "called" in text.to_lower()):
		d["name"] = Monster.NAMES[rng.randi() % Monster.NAMES.size()]
	var note := ("Got: " + ", ".join(last_heard)) if not last_heard.is_empty() else "Named %s" % d["name"]
	if not last_missed.is_empty():
		note += ".  Missed: " + ", ".join(last_missed)
	_replace(d, note)
	return true


func describe_sheet() -> void:
	if paused:
		return
	var box := UI.sheet(self, 500)
	box.add_child(UI.label("DESCRIBE YOUR MONSTER", 26, UI.ACCENT))
	var edit := LineEdit.new()
	edit.name = "DescribeText"
	edit.placeholder_text = EXAMPLES[rng.randi() % EXAMPLES.size()]
	edit.custom_minimum_size = Vector2(0, UI.MIN_TOUCH)
	edit.add_theme_font_size_override("font_size", UI.font_size(22))
	edit.max_length = 120
	box.add_child(edit)
	var hint := UI.label("Animals, colours, parts, moods. Two colours = body, then markings. \"named Gus\" names it.", 18, UI.DIM)
	hint.name = "DescribeHint"
	box.add_child(hint)
	var go := func(fresh: bool):
		var text := edit.text if edit.text.strip_edges() != "" else edit.placeholder_text
		if describe(text, fresh):
			UI.close_sheet(box)
			get_node("/root/Audio").sfx("level")
		else:
			hint.text = "Didn't catch any of that. Try: " + EXAMPLES[rng.randi() % EXAMPLES.size()]
			hint.add_theme_color_override("font_color", UI.key("warn"))
	box.add_child(UI.button("MAKE A NEW ONE", func(): go.call(true), 88))
	box.add_child(UI.button("CHANGE THIS ONE", func(): go.call(false)))
	box.add_child(UI.button("CANCEL", func(): UI.close_sheet(box)))
	edit.text_submitted.connect(func(_t: String): go.call(true))
	edit.grab_focus.call_deferred()


func _name_sheet() -> void:
	if paused:
		return
	var box := UI.sheet(self)
	box.add_child(UI.label("NAME", 26, UI.ACCENT))
	var edit := LineEdit.new()
	edit.name = "NameText"
	edit.text = design["name"]
	edit.max_length = Monster.NAME_MAX
	edit.custom_minimum_size = Vector2(0, UI.MIN_TOUCH)
	edit.add_theme_font_size_override("font_size", UI.font_size(24))
	box.add_child(edit)
	var save := func():
		set_part("name", edit.text)
		status.text = "Named %s." % design["name"]
		UI.close_sheet(box)
	box.add_child(UI.button("SAVE NAME", save, 88))
	box.add_child(UI.button("CANCEL", func(): UI.close_sheet(box)))
	edit.text_submitted.connect(func(_t: String): save.call())
	edit.grab_focus.call_deferred()
	edit.select_all.call_deferred()


# ---------------------------------------------------------------- the test fight

func open_fight() -> void:
	if paused or is_instance_valid(fight):
		return
	checkpoint()
	fight = Fight.open(self, design)
	fight.closed.connect(func(_won: bool):
		fight = null
		get_node("/root/Audio").music("music_loop")
		status.text = "%s has %d win%s." % [design["name"], wins, "" if wins == 1 else "s"])


## Called by the fight on a win: counted and saved at once (checkpoint).
func fight_won() -> void:
	wins += 1
	checkpoint()


## Dev menu SKIP LEVEL: win the open fight, or just bank a win.
func debug_skip_level() -> void:
	if is_instance_valid(fight):
		fight.debug_win()
	else:
		fight_won()
		status.text = "%s has %d wins." % [design["name"], wins]


# ---------------------------------------------------------------- pause

func pause() -> void:
	if paused:
		return
	paused = true
	checkpoint()
	get_node("/root/Subs").clear()
	sheet_box = UI.sheet(self)
	sheet_box.add_child(UI.label("PAUSED", 30, UI.ACCENT))
	sheet_box.add_child(UI.button("RESUME", resume, 88))
	sheet_box.add_child(UI.button("SETTINGS", func(): SettingsSheet.open(self)))
	sheet_box.add_child(UI.button("REPORT A BUG", func(): BugReport.open(self)))
	sheet_box.add_child(UI.button("QUIT TO TITLE", quit_to_title))


func resume() -> void:
	if is_instance_valid(sheet_box):
		UI.close_sheet(sheet_box)
	sheet_box = null
	paused = false


func quit_to_title() -> void:
	checkpoint()
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _notification(what: int) -> void:
	match what:
		# The phone took the app away (call, home button, notification shade): pause + save.
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause.call_deferred()
		# Android back / back gesture: close the top sheet, else pause. Never quits.
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back.call_deferred()


func _go_back() -> void:
	var sheets := get_tree().get_nodes_in_group("sheet")
	var pause_sheet: Variant = sheet_box.get_meta("sheet") if is_instance_valid(sheet_box) else null
	if paused and (sheets.is_empty() or sheets[-1] == pause_sheet or pause_sheet == null):
		resume()                            # the pause sheet is on top (or lost): un-pause, never just free it
	elif not paused and is_instance_valid(fight) and fight.ended():
		fight.leave()                       # back on the win / faint screen = back to the creator
	elif sheets.size() > 0:
		sheets[-1].queue_free()
	else:
		pause()
