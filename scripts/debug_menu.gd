extends CanvasLayer
## Autoload "DebugMenu": dev-only tools. Exists in debug exports (the dev APK) and the editor,
## never in a release export. Open it: tap the version number on the title 5 times, tap with
## three fingers anywhere, or press F1.
## TUNE = live sliders for game feel (scripts/tune_panel.gd).
## Scenes opt in to SKIP LEVEL with `func debug_skip_level()`. Games read DebugMenu.god_mode.

const UI = preload("res://scripts/ui.gd")
const Config = preload("res://scripts/config.gd")
const Tune = preload("res://scripts/tune_panel.gd")

var enabled := false
var god_mode := false
var show_fps := false
var box: VBoxContainer
var _fps: Label
var _touches := {}
var tune_defaults := {}                 # "kind.prop" -> the value in code, before saved tuning
var tune_panel: Control


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = Config.dev_build() or "--dev" in OS.get_cmdline_user_args()
	_fps = Label.new()
	_fps.position = Vector2(8, 4)
	_fps.add_theme_font_size_override("font_size", 16)
	_fps.add_theme_color_override("font_color", Color.YELLOW)
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_constant_override("outline_size", 4)
	_fps.visible = false
	add_child(_fps)
	var feel := get_node_or_null("/root/Feel")
	if feel != null:
		apply_tune(feel)


## Tunable nodes call this at the end of _ready(): remembers the code values, then puts saved
## tuning on (dev builds only; a release build always plays the code values).
func apply_tune(n: Object) -> void:
	if not ("TUNE" in n):
		return
	var k := Tune.kind_of(n)
	for prop in n.TUNE:
		if not tune_defaults.has(k + "." + prop):
			tune_defaults[k + "." + prop] = n.get(prop)
	if enabled:
		Tune.apply(n)


func open_tune() -> void:
	close()
	if tune_panel != null:
		return
	tune_panel = Tune.open(self, tune_defaults, close_tune)


func close_tune() -> void:
	if tune_panel != null:
		tune_panel.queue_free()
		tune_panel = null


func _process(_dt: float) -> void:
	if show_fps:
		_fps.text = "%d fps  %.1f ms  draws %d" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func _input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
		toggle()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = true
			if _touches.size() >= 3:
				_touches.clear()
				toggle()
		else:
			_touches.erase(e.index)


func toggle() -> void:
	if box != null:
		close()
	else:
		open()


func open() -> void:
	if not enabled or box != null:
		return
	box = UI.sheet(self)
	box.add_child(UI.label("DEV MENU", 26, UI.key("warn")))
	box.add_child(UI.label("%s  %s" % [Config.version_label(), Config.build_info()], 16, UI.DIM))
	var fps_b := UI.button("")
	fps_b.text = "SHOW FPS: " + ("ON" if show_fps else "OFF")
	fps_b.pressed.connect(func():
		show_fps = not show_fps
		_fps.visible = show_fps
		fps_b.text = "SHOW FPS: " + ("ON" if show_fps else "OFF"))
	box.add_child(fps_b)
	var god_b := UI.button("")
	god_b.text = "GOD MODE: " + ("ON" if god_mode else "OFF")
	god_b.pressed.connect(func():
		god_mode = not god_mode
		god_b.text = "GOD MODE: " + ("ON" if god_mode else "OFF"))
	box.add_child(god_b)
	box.add_child(UI.button("TUNE (LIVE SLIDERS)", open_tune))
	box.add_child(UI.button("SKIP LEVEL", func():
		var s := get_tree().current_scene
		if s != null and s.has_method("debug_skip_level"):
			s.debug_skip_level()
		close()))
	box.add_child(UI.button("3D CHARACTER TEST", func():
		close()
		get_node("/root/Loader").go("res://scenes/character_test.tscn")))
	box.add_child(UI.button("PHONE SPEED TEST", func():
		close()
		get_tree().root.set_meta("perf_test", true)
		get_node("/root/Loader").go("res://scenes/character_test.tscn")))
	box.add_child(UI.button("CLEAR SAVE", func():
		get_node("/root/Save").clear()
		Tune.clear()
		close()))
	box.add_child(UI.button("CLOSE", close))


func close() -> void:
	UI.close_sheet(box)
	box = null
