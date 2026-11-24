extends Node
## Autoload "Controls": every game action works on touch, keyboard and gamepad, and the player can
## remap keyboard keys and pad buttons (Settings -> CONTROLS). Saved in user://controls.cfg.
## Games read actions, never raw keys: Input.get_vector("move_left", "move_right", "move_up",
## "move_down"), Input.is_action_just_pressed("jump").

const PATH := "user://controls.cfg"
const DEADZONE := 0.25

## action -> [label, default events]. Keyboard + gamepad for every action.
const ACTIONS := {
	"move_left": "MOVE LEFT", "move_right": "MOVE RIGHT", "move_up": "MOVE UP", "move_down": "MOVE DOWN",
	"jump": "JUMP", "attack": "ATTACK", "dodge": "DODGE", "crouch": "CROUCH", "aim": "AIM", "pause": "PAUSE",
}

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "UP", JOY_BUTTON_DPAD_DOWN: "DOWN",
	JOY_BUTTON_DPAD_LEFT: "LEFT", JOY_BUTTON_DPAD_RIGHT: "RIGHT",
}

var _custom := {}                      # action -> {"key": InputEvent, "pad": InputEvent}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply()


static func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


static func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1                      # any pad
	return e


static func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = -1
	return e


static func defaults(action: String) -> Array:
	match action:
		"move_left": return [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)]
		"move_right": return [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)]
		"move_up": return [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)]
		"move_down": return [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)]
		"jump": return [_key(KEY_SPACE), _btn(JOY_BUTTON_A)]
		"attack": return [_key(KEY_J), _btn(JOY_BUTTON_X)]
		"dodge": return [_key(KEY_K), _btn(JOY_BUTTON_B)]
		"crouch": return [_key(KEY_C), _btn(JOY_BUTTON_Y)]
		"aim": return [_key(KEY_L), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]
		"pause": return [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)]
	return []


static func is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


## Rebuild the InputMap: defaults, with the player's remaps replacing the same kind of input.
func apply() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
		else:
			InputMap.add_action(a, DEADZONE)
		var evs := defaults(a)
		var c: Dictionary = _custom.get(a, {})
		if c.has("key"):
			evs = evs.filter(func(e): return is_pad(e))
			evs.push_front(c.key)
		if c.has("pad"):
			evs = evs.filter(func(e): return not is_pad(e))
			evs.append(c.pad)
		for e in evs:
			InputMap.action_add_event(a, e)


## Bind an action to a new key or pad input (replaces that kind; the other kind stays).
func rebind(action: String, e: InputEvent) -> void:
	if not ACTIONS.has(action):
		return
	var c: Dictionary = _custom.get(action, {})
	c["pad" if is_pad(e) else "key"] = e
	_custom[action] = c
	apply()
	_save()


func reset() -> void:
	_custom.clear()
	apply()
	_save()


## "SPACE / A" style text for the CONTROLS sheet.
func describe(action: String) -> String:
	var parts := []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			parts.append(OS.get_keycode_string((e as InputEventKey).physical_keycode).to_upper())
		elif e is InputEventJoypadButton:
			parts.append("PAD " + PAD_NAMES.get((e as InputEventJoypadButton).button_index, str((e as InputEventJoypadButton).button_index)))
		elif e is InputEventJoypadMotion:
			var m := e as InputEventJoypadMotion
			if m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT:
				parts.append("PAD " + ("LT" if m.axis == JOY_AXIS_TRIGGER_LEFT else "RT"))
			else:
				parts.append("STICK %d%s" % [m.axis, "+" if m.axis_value > 0 else "-"])
		if parts.size() >= 2:
			break
	return " / ".join(parts)


func _save() -> void:
	var cfg := ConfigFile.new()
	for a in _custom:
		for kind in _custom[a]:
			cfg.set_value(a, kind, _custom[a][kind])
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for a in cfg.get_sections():
		var c := {}
		for kind in cfg.get_section_keys(a):
			var e = cfg.get_value(a, kind)
			if e is InputEvent:
				c[kind] = e
		_custom[a] = c
