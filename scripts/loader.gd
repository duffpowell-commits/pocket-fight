extends Node
## Autoload "Loader": change scene with a background (threaded) load, so the screen keeps drawing
## while a big scene loads. Shows a LOADING card only if it takes longer than SHOW_AFTER.
## Use: Loader.go("res://scenes/game.tscn") instead of get_tree().change_scene_to_file(...)

const UI = preload("res://scripts/ui.gd")
const SHOW_AFTER := 0.25

signal loaded(path: String)

var loads := 0                          # finished background loads (the bot checks this)
var frames_while_loading := 0           # frames drawn during the last load (screen never froze)
var _path := ""
var _t := 0.0
var _card: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func busy() -> bool:
	return _path != ""


func go(path: String) -> void:
	if busy():
		return
	if ResourceLoader.load_threaded_request(path, "PackedScene", true) != OK:
		get_tree().change_scene_to_file(path)       # fallback: plain load
		return
	_path = path
	_t = 0.0
	frames_while_loading = 0


func _process(dt: float) -> void:
	if _path == "":
		return
	_t += dt
	frames_while_loading += 1
	var st := ResourceLoader.load_threaded_get_status(_path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if _t > SHOW_AFTER and _card == null:
			_show_card()
		return
	var p := _path
	_path = ""
	if _card != null:
		_card.queue_free()
		_card = null
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(p))
		loads += 1
		loaded.emit(p)
	else:
		get_tree().change_scene_to_file(p)


func _show_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 120
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(bg)
	var l := UI.label("LOADING", 28, UI.ACCENT)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.add_child(l)
	add_child(_card)
