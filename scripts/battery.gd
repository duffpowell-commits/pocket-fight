extends Node
## Autoload "Battery": the game doesn't burn battery when nobody is playing.
## - Paused, or on a menu scene (boot, intro, title): cap at SAVER_FPS.
## - No touch, key or pad input for idle_secs during play: cap at SAVER_FPS until the next input.
## - App in the background (call, home button): BACKGROUND_FPS and low-processor mode.
## Back to full speed (project max_fps) the moment any of that ends. Settings -> BATTERY SAVER.

const SAVER_FPS := 30
const BACKGROUND_FPS := 5
var idle_secs := 45.0                   # the autoplay bot steers without input events, so it turns this off
const MENU_SCENES := ["Boot", "Intro", "Title"]

var state := "play"                     # play / saver / background (the bot checks this)
var _idle := 0.0
var _full_fps := 60
var _background := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_full_fps = int(ProjectSettings.get_setting("application/run/max_fps", 60))


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag or e is InputEventKey \
			or e is InputEventMouseButton or e is InputEventJoypadButton \
			or (e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.3):
		_idle = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_background = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_background = false
		_idle = 0.0


func _process(dt: float) -> void:
	_idle += dt
	var want := "play"
	var s: Node = get_node_or_null("/root/Settings")
	var on: bool = s == null or bool(s.get_value("battery_saver"))
	if _background:
		want = "background"
	elif on and (get_tree().paused or _scene_paused() or _on_menu() or _idle > idle_secs):
		want = "saver"
	if want != state:
		set_state(want)


func set_state(st: String) -> void:
	state = st
	OS.low_processor_usage_mode = st == "background"
	Engine.max_fps = {"play": _full_fps, "saver": SAVER_FPS, "background": BACKGROUND_FPS}[st]


## Scenes that pause themselves (a `paused` flag, like game.gd) count as paused too.
func _scene_paused() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.get("paused") == true


func _on_menu() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.name in MENU_SCENES
