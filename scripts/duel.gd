extends RefCounted
## The test fight's rules, with no drawing, so tests and the bot can play it directly.
## Rules carried over from the first prototype (docs/prototype/battle.gd.txt). One number changed:
## the strike is 15, not 12, because at 12 mashing Attack won every time and Guard never mattered.
##
## the wild monster alternates WIND UP and HEAVY STRIKE. Attack always hits. Guard halves a
## strike. The signature move only works on a strike turn and then rests for `cooldown_turns`:
##   Splash: cancels the strike and chips 2.     Climb: dodges it; your next Attack hits harder.
## Looks never change these numbers (docs/PITCH.md pillar 2): only `move` does.

var max_hp := 30
var basic_damage := 5
var strike_damage := 15
var splash_damage := 2
var climb_bonus := 3
var cooldown_turns := 2

var move := "Splash"
var player_hp := 30
var enemy_hp := 30
var charging := false          # true = the heavy strike lands this turn
var high_ground := false
var cooldown := 0
var turn := 1
var god := false               # dev menu GOD MODE: strikes do nothing


func _init(signature: String = "Splash") -> void:
	move = signature


func reset() -> void:
	player_hp = max_hp
	enemy_hp = max_hp
	charging = false
	high_ground = false
	cooldown = 0
	turn = 1


func over() -> bool:
	return player_hp <= 0 or enemy_hp <= 0


func won() -> bool:
	return enemy_hp <= 0


func attack_damage() -> int:
	return basic_damage + (climb_bonus if high_ground else 0)


func can(action: String) -> bool:
	if over():
		return false
	if action == "Move":
		return charging and cooldown == 0
	return action in ["Attack", "Guard"]


## Play one turn. Returns {"ok", "dealt", "taken", "text"}; ok=false means nothing happened.
func play(action: String) -> Dictionary:
	if not can(action):
		return {"ok": false, "dealt": 0, "taken": 0, "text": ""}
	var incoming := strike_damage if charging else 0
	var dealt := 0
	var text := ""
	match action:
		"Attack":
			dealt = attack_damage()
			high_ground = false
			text = "Attack hit for %d." % dealt
		"Guard":
			incoming = incoming / 2
			text = "You guarded."
		"Move":
			incoming = 0
			if move == "Splash":
				dealt = splash_damage
				text = "Splash broke the strike and hit for %d." % dealt
			else:
				high_ground = true
				text = "Climb dodged the strike. Next Attack +%d." % climb_bonus
	if action == "Move":
		cooldown = cooldown_turns
	elif cooldown > 0:
		cooldown -= 1
	if god:
		incoming = 0
	enemy_hp = maxi(0, enemy_hp - dealt)
	var taken := 0
	if enemy_hp > 0:
		taken = incoming
		player_hp = maxi(0, player_hp - taken)
		if taken > 0:
			text += " The strike hit you for %d." % taken
		elif not charging:
			text += " It winds up."
		charging = not charging
		turn += 1
	return {"ok": true, "dealt": dealt, "taken": taken, "text": text}
