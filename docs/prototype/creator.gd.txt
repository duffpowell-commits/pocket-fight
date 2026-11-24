extends Control

const Battle = preload("res://battle.gd")
const SAVE_PATH := "user://duo.json"
const FIELDS := {
	"Character": {
		"Hair": ["Short", "Long"],
		"Outfit": ["Coat", "Vest"],
		"Color": ["Rust", "Lake", "Moss"],
		"Background": ["Mechanic", "Climber"],
	},
	"Starter": {
		"Body": ["Round", "Long-legged"],
		"Tail": ["None", "Paddle"],
		"Color": ["Rust", "Lake", "Moss"],
		"Move": ["Splash", "Climb"],
	},
}

var design: Dictionary = {}
var selected := "Character"
var editor: MarginContainer
var rows: VBoxContainer
var preview: Control
var status: Label
var animation_time := 0.0
var demo_until := 0.0


func _ready() -> void:
	design = read_design()
	editor = MarginContainer.new()
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		editor.add_theme_constant_override("margin_" + side, 24)
	add_child(editor)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	editor.add_child(column)
	var title := Label.new()
	title.text = "Wildmade"
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)

	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for category in FIELDS:
		tabs.add_child(make_button(category, func(): select_category(category)))
	preview = Control.new()
	preview.custom_minimum_size.y = 220
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.draw.connect(draw_preview)
	column.add_child(preview)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	column.add_child(rows)
	column.add_child(make_button("Save duo", save_design))
	column.add_child(make_button("Test fight", open_battle))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Saved duo loaded." if FileAccess.file_exists(SAVE_PATH) else "Create your duo."
	column.add_child(status)
	select_category(selected)


func open_battle() -> void:
	var battle := Battle.new()
	battle.signature = design["Starter"]["Move"]
	add_child(battle)
	editor.hide()
	battle.finished.connect(func():
		battle.queue_free()
		editor.show()
	)


func make_button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func select_category(category: String) -> void:
	selected = category
	demo_until = 0.0
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for field in FIELDS[category]:
		var line := HBoxContainer.new()
		rows.add_child(line)
		var label := Label.new()
		label.text = field
		label.custom_minimum_size.x = 130
		line.add_child(label)
		var choice := OptionButton.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size.y = 48
		line.add_child(choice)
		var options: Array = FIELDS[category][field]
		for option in options:
			choice.add_item(option)
		choice.select(options.find(design[category][field]))
		choice.item_selected.connect(func(index: int):
			design[category][field] = options[index]
			demo_until = 0.0
			status.text = "Unsaved changes."
		)
	if category == "Starter":
		rows.add_child(make_button("Preview move", func(): demo_until = animation_time + 0.7))


func read_design() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else {}
	var restored: Dictionary = {}
	for category in FIELDS:
		restored[category] = {}
		var saved: Variant = parsed.get(category, {}) if parsed is Dictionary else {}
		for field in FIELDS[category]:
			var options: Array = FIELDS[category][field]
			var value: Variant = saved.get(field) if saved is Dictionary else null
			restored[category][field] = value if value in options else options[0]
	return restored


func save_design() -> void:
	var temp := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		status.text = "Couldn't save the duo."
		return
	var written := file.store_string(JSON.stringify(design))
	file.close()
	if written and DirAccess.rename_absolute(temp, SAVE_PATH) == OK:
		status.text = "Duo saved."
	else:
		status.text = "Couldn't save the duo."


func _process(delta: float) -> void:
	animation_time += delta
	preview.queue_redraw()


func draw_preview() -> void:
	var current: Dictionary = design[selected]
	var tint: Color = {"Rust": Color("#df8667"), "Lake": Color("#65bbd2"), "Moss": Color("#a5c47a")}[current["Color"]]
	var ground := preview.size * Vector2(0.5, 0.72)
	var bob := sin(animation_time * 3.5) * 3.0
	var active := demo_until > animation_time
	preview.draw_circle(ground, 75, Color("#243a3e"))
	var center := ground + Vector2(0, -48 + bob)
	var ink := Color("#182328")

	if selected == "Character":
		var skin := Color("#d4a488")
		var coat_width := 64 if current["Outfit"] == "Coat" else 48
		preview.draw_rect(Rect2(center + Vector2(-20, 15), Vector2(15, 40)), ink)
		preview.draw_rect(Rect2(center + Vector2(5, 15), Vector2(15, 40)), ink)
		preview.draw_rect(Rect2(center + Vector2(-coat_width / 2.0, -30), Vector2(coat_width, 56)), tint)
		var head := center + Vector2(0, -52)
		if current["Hair"] == "Long":
			preview.draw_rect(Rect2(head - Vector2(24, 20), Vector2(48, 48)), ink)
		preview.draw_circle(head, 21, skin)
		preview.draw_rect(Rect2(head - Vector2(20, 22), Vector2(40, 10)), ink)
		preview.draw_circle(head + Vector2(8, 1), 3, ink)
		return

	var tall: bool = current["Body"] == "Long-legged"
	var paddle: bool = current["Tail"] == "Paddle"
	var splash: bool = active and current["Move"] == "Splash"
	if active:
		center.y += 12 if splash else -32
	if paddle:
		var tail_tip := center + Vector2(-71, 20 if splash else 1)
		preview.draw_line(center, tail_tip, tint, 15, true)
		preview.draw_circle(tail_tip, 15, tint)
	for offset in [-23, 23]:
		var thigh := center + Vector2(offset, 19)
		var foot := thigh + Vector2(10 if splash and not paddle and tall else 0, 29 if tall else 18)
		preview.draw_line(thigh, foot, tint.darkened(0.25), 14, true)
	preview.draw_circle(center, 36 if tall else 46, tint)
	var face := center + Vector2(26, -12)
	preview.draw_circle(face, 25, tint.lightened(0.15))
	preview.draw_circle(face + Vector2(8, -3), 4, ink)
	if splash:
		var impact := ground + Vector2(-66 if paddle else 20, 0)
		preview.draw_arc(impact, 29, 0, TAU, 32, Color("#9ee3ec"), 3, true)
