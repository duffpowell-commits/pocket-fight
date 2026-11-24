extends MarginContainer

signal finished

const MAX_HP := 30
const BASIC_DAMAGE := 5
const CHARGE_DAMAGE := 12

var signature := "Splash"
var player_hp := MAX_HP
var enemy_hp := MAX_HP
var charging := false
var high_ground := false
var cooldown := 0
var round_number := 1
var health: Label
var intent: Label
var log_line: Label
var attack_button: Button
var guard_button: Button
var move_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := Label.new()
	title.text = "Test fight"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	health = add_label(column)
	intent = add_label(column)
	log_line = add_label(column)
	log_line.custom_minimum_size.y = 76
	attack_button = add_button(column, "Attack · 5 damage", func(): play_turn("Attack"))
	guard_button = add_button(column, "Guard · halve damage", func(): play_turn("Guard"))
	move_button = add_button(column, signature, func(): play_turn(signature))
	add_button(column, "Retry fight", reset_fight)
	add_button(column, "Back to creator", func(): finished.emit())
	reset_fight()


func add_label(column: VBoxContainer) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label


func add_button(column: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	column.add_child(button)
	return button


func reset_fight() -> void:
	player_hp = MAX_HP
	enemy_hp = MAX_HP
	charging = false
	high_ground = false
	cooldown = 0
	round_number = 1
	log_line.text = "The mill lurker alternates between winding up and striking."
	refresh()


func play_turn(action: String) -> void:
	if player_hp == 0 or enemy_hp == 0:
		return
	if action == signature and (cooldown > 0 or not charging):
		return

	var incoming := CHARGE_DAMAGE if charging else 0
	var message := ""
	match action:
		"Attack":
			var damage := BASIC_DAMAGE + (3 if high_ground else 0)
			enemy_hp = maxi(0, enemy_hp - damage)
			high_ground = false
			message = "Attack dealt %d damage." % damage
		"Guard":
			incoming /= 2
			message = "You guarded."
		"Splash":
			incoming = 0
			enemy_hp = maxi(0, enemy_hp - 2)
			message = "Splash interrupted the strike and dealt 2 damage."
		"Climb":
			incoming = 0
			high_ground = true
			message = "Climb evaded the strike. Your next attack gains 3 damage."
		_:
			return

	if action == signature:
		cooldown = 2
	elif cooldown > 0:
		cooldown -= 1

	if enemy_hp == 0:
		log_line.text = message + " You won."
	else:
		player_hp = maxi(0, player_hp - incoming)
		if incoming > 0:
			message += " The lurker dealt %d damage." % incoming
		elif not charging:
			message += " The lurker wound up."
		if player_hp == 0:
			message += " Your starter fainted."
		log_line.text = message
		charging = not charging
		round_number += 1
	refresh()


func refresh() -> void:
	health.text = "Starter HP %d/%d        Lurker HP %d/%d" % [player_hp, MAX_HP, enemy_hp, MAX_HP]
	var done := player_hp == 0 or enemy_hp == 0
	if done:
		intent.text = "Fight over"
	else:
		intent.text = "Turn %d · %s" % [round_number, "Heavy strike incoming!" if charging else "Lurker is about to wind up."]
	attack_button.text = "Attack · %d damage" % (BASIC_DAMAGE + (3 if high_ground else 0))
	attack_button.disabled = done
	guard_button.disabled = done
	move_button.disabled = done or cooldown > 0 or not charging
	var effect := "interrupt" if signature == "Splash" else "evade"
	move_button.text = "%s · %s" % [signature, effect]
	if cooldown > 0:
		move_button.text += " (%d turns)" % cooldown
