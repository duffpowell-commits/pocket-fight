extends Control
## A skippable publisher card. The parent owns any startup work and scene transition.

signal dismissed

const PUBLISHER := "3 Eyed Fox Studios"
const UI = preload("res://scripts/ui.gd")

var finished := false


func _ready() -> void:
	theme = UI.theme()
	var skip := UI.button("Skip splash")
	skip.custom_minimum_size.x = 184
	skip.pressed.connect(_dismiss)
	%Actions.add_child(skip)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_dismiss()


func _dismiss() -> void:
	if finished:
		return
	finished = true
	set_process_input(false)
	hide()
	dismissed.emit()
