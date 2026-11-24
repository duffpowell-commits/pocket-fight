extends Node
## Autoload "Telemetry": analytics + crash hooks, offline-first and private by default.
##   Telemetry.event("level_done", {"level": 2, "time": 41.5})
## Events go to user://events.jsonl on the phone (capped). They leave the phone only when BOTH
## the player turned on Settings -> SHARE ANONYMOUS STATS and the game sets ENDPOINT. No login,
## no ids beyond a random install id, nothing personal. Nothing ever blocks play on the network.
## Crash hook: a run that didn't close cleanly (killed, crashed, froze) is noticed next launch:
## event "crash_suspected" with the last scene + build, and `crashed_last_run` is true so the
## game can offer REPORT A BUG.

const ENDPOINT := ""                    # e.g. "https://<your-collector>/events"; empty = never send
const EVENTS := "user://events.jsonl"
const RUN_FLAG := "user://running.flag"
const MAX_LINES := 500

var crashed_last_run := false
var install_id := ""
var sent := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	install_id = _install_id()
	if FileAccess.file_exists(RUN_FLAG):
		crashed_last_run = true
		event("crash_suspected", {"last": FileAccess.get_file_as_string(RUN_FLAG)})
	_mark_running("boot")
	event("session_start", {})


var _scene := ""
var _poll := 0.0


func _process(dt: float) -> void:
	_poll -= dt
	if _poll > 0.0:
		return
	_poll = 2.0
	var cs := get_tree().current_scene
	if cs != null and cs.name != _scene:
		_scene = cs.name
		_mark_running(_scene)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE, NOTIFICATION_APPLICATION_PAUSED, \
				NOTIFICATION_APPLICATION_FOCUS_OUT:
			clean_exit()                       # backgrounded / closed on purpose: not a crash
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_mark_running(_scene)


## Call when the app closes on purpose (also done on quit / close request).
func clean_exit() -> void:
	if FileAccess.file_exists(RUN_FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_FLAG))


func event(name: String, props: Dictionary = {}) -> void:
	var line := JSON.stringify({"e": name, "t": int(Time.get_unix_time_from_system()), "build": _build(), "id": install_id, "p": props})
	var lines: PackedStringArray = []
	if FileAccess.file_exists(EVENTS):
		lines = FileAccess.get_file_as_string(EVENTS).split("\n", false)
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	var f := FileAccess.open(EVENTS, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
	_maybe_send()


func events() -> Array:
	var out := []
	if FileAccess.file_exists(EVENTS):
		for l in FileAccess.get_file_as_string(EVENTS).split("\n", false):
			var v = JSON.parse_string(l)
			if v != null:
				out.append(v)
	return out


## Only with the player's yes and a configured endpoint; fire and forget, never blocks play.
func allowed() -> bool:
	var s: Node = get_node_or_null("/root/Settings")
	return ENDPOINT != "" and s != null and bool(s.get_value("share_stats"))


func _maybe_send() -> void:
	if not allowed():
		return
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, _b):
		if result == HTTPRequest.RESULT_SUCCESS and code < 300:
			sent += 1
			DirAccess.remove_absolute(ProjectSettings.globalize_path(EVENTS))
		req.queue_free())
	req.request(ENDPOINT, ["Content-Type: application/x-ndjson"], HTTPClient.METHOD_POST, FileAccess.get_file_as_string(EVENTS))


func _mark_running(where: String) -> void:
	var f := FileAccess.open(RUN_FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string("%s %s" % [where, _build()])


func _build() -> String:
	return preload("res://scripts/config.gd").version_label()


func _install_id() -> String:
	var cfg := ConfigFile.new()
	cfg.load("user://install.cfg")
	var id: String = cfg.get_value("install", "id", "")
	if id == "":
		var c := Crypto.new()
		id = c.generate_random_bytes(8).hex_encode()
		cfg.set_value("install", "id", id)
		cfg.save("user://install.cfg")
	return id
