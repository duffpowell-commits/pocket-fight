extends PanelContainer
## On-screen controls legend: "JUMP  SPACE / PAD 0" for each action a scene uses.
## On by default (Settings -> CONTROLS LEGEND). Shows once the player touches a key or a pad;
## touch players already see labelled buttons, so it stays out of their way (no text walls).
## Use: add_child(ControlsLegend.make(["jump", "attack", "dodge", "pause"]))

const ControlsLegend = preload("res://scripts/controls_legend.gd")
const UI = preload("res://scripts/ui.gd")

var actions: Array = []
var top := 120.0                      # distance from the top edge (clear the scene's HUD)
var used_keys := false                 # set by the first key / pad press
var _label: Label


static func make(acts: Array) -> PanelContainer:
	var l: PanelContainer = ControlsLegend.new()
	l.actions = acts
	return l


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UI.panel_color(), 0.8)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	_label = UI.label("", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -12
	offset_left = -12
	offset_top = top
	get_node("/root/Settings").changed.connect(func(_k): refresh())
	refresh()


func _input(e: InputEvent) -> void:
	if not used_keys and (e is InputEventKey or e is InputEventJoypadButton or
			(e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.5)):
		used_keys = true
		refresh()


func refresh() -> void:
	var c: Node = get_node("/root/Controls")
	var lines := []
	for a in actions:
		lines.append("%s  %s" % [c.ACTIONS.get(a, a), c.describe(a)])
	_label.text = "\n".join(lines)
	visible = used_keys and bool(get_node("/root/Settings").get_value("show_legend"))
