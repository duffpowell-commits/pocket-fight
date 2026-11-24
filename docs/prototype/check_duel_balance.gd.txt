extends SceneTree
## Prototype duel rules. Run with godot --headless --script tools/check_duel_balance.gd.

const Battle = preload("res://battle.gd")
const TRIALS := 1000
const ROUND_LIMIT := 30

enum Action { ATTACK, GUARD, WIND_UP, STRIKE, SIGNATURE }


class Fighter:
	var move: String
	var hp := Battle.MAX_HP
	var cooldown := 0
	var charged := false
	var climb_bonus := false

	func _init(signature: String) -> void:
		move = signature


func _initialize() -> void:
	if not check_counterplay():
		push_error("Duel counterplay check failed.")
		quit(1)
		return
	print("PASS: Splash interrupts, Climb evades and powers the next attack, Guard halves the strike.")
	for moves in [["Splash", "Splash"], ["Splash", "Climb"], ["Climb", "Splash"], ["Climb", "Climb"]]:
		report(moves[0], moves[1], false)
		report(moves[0], moves[1], true)
		report(moves[0], moves[1], false, true)
	quit()


func choose(actor: Fighter, opponent: Fighter, rng: RandomNumberGenerator) -> Action:
	if actor.charged:
		return Action.STRIKE
	if opponent.charged:
		var response := rng.randf()
		if actor.cooldown == 0 and response < 0.65:
			return Action.SIGNATURE
		return Action.GUARD if response < 0.85 else Action.ATTACK
	return Action.WIND_UP if rng.randf() < 0.3 else Action.ATTACK


func resolve(first: Fighter, second: Fighter, first_action: Action, second_action: Action, simultaneous := false) -> int:
	# Both choose from public intent. Guard and reactions are set before attacks.
	var denied := 0
	if first_action == Action.SIGNATURE:
		prepare_signature(first)
		denied += 1 if first.move == "Splash" else 0
	if second_action == Action.SIGNATURE:
		prepare_signature(second)
		denied += 1 if second.move == "Splash" else 0
	apply_action(first, second, first_action, second_action)
	if simultaneous or second.hp > 0:
		apply_action(second, first, second_action, first_action)
	first.charged = first_action == Action.WIND_UP
	second.charged = second_action == Action.WIND_UP
	if first_action != Action.SIGNATURE:
		first.cooldown = maxi(0, first.cooldown - 1)
	if second_action != Action.SIGNATURE:
		second.cooldown = maxi(0, second.cooldown - 1)
	return denied


func prepare_signature(actor: Fighter) -> void:
	actor.cooldown = 2
	if actor.move == "Climb":
		actor.climb_bonus = true


func apply_action(actor: Fighter, target: Fighter, action: Action, response: Action) -> void:
	var damage := 0
	match action:
		Action.ATTACK:
			damage = Battle.BASIC_DAMAGE + (3 if actor.climb_bonus else 0)
			actor.climb_bonus = false
		Action.STRIKE:
			damage = 0 if response == Action.SIGNATURE else Battle.CHARGE_DAMAGE
		Action.SIGNATURE:
			damage = 2 if actor.move == "Splash" else 0
	if response == Action.GUARD:
		damage = floori(damage / 2.0)
	target.hp = maxi(0, target.hp - damage)


func check_counterplay() -> bool:
	for move in ["Splash", "Climb"]:
		var attacker := Fighter.new("Splash")
		var defender := Fighter.new(move)
		attacker.charged = true
		resolve(attacker, defender, Action.STRIKE, Action.SIGNATURE)
		if defender.hp != Battle.MAX_HP or defender.cooldown != 2:
			return false
		if move == "Splash" and attacker.hp != Battle.MAX_HP - 2:
			return false
		if move == "Climb":
			resolve(defender, attacker, Action.ATTACK, Action.GUARD)
			if attacker.hp != Battle.MAX_HP - 4 or defender.climb_bonus:
				return false
	var attacker := Fighter.new("Splash")
	var defender := Fighter.new("Splash")
	resolve(attacker, defender, Action.STRIKE, Action.GUARD)
	return defender.hp == Battle.MAX_HP - 6


func report(left_move: String, right_move: String, right_first: bool, simultaneous := false) -> void:
	var left_rng := RandomNumberGenerator.new()
	var right_rng := RandomNumberGenerator.new()
	left_rng.seed = 51
	right_rng.seed = 73
	var wins := [0, 0, 0]
	var turns := 0
	var denials := 0
	for trial in TRIALS:
		var left := Fighter.new(left_move)
		var right := Fighter.new(right_move)
		for round_index in ROUND_LIMIT:
			var left_action := choose(left, right, left_rng)
			var right_action := choose(right, left, right_rng)
			if right_first:
				denials += resolve(right, left, right_action, left_action)
			else:
				denials += resolve(left, right, left_action, right_action, simultaneous)
			turns += 1
			if left.hp == 0 or right.hp == 0:
				break
		var result := 2
		if left.hp == 0 and right.hp > 0:
			result = 1
		elif right.hp == 0 and left.hp > 0:
			result = 0
		wins[result] += 1
	print("%s vs %s | %s | wins %d–%d, draws %d | %.2f rounds, %.2f interrupts per duel" % [
		left_move, right_move, "simultaneous" if simultaneous else ("right first" if right_first else "left first"),
		wins[0], wins[1], wins[2], float(turns) / TRIALS, float(denials) / TRIALS,
	])
