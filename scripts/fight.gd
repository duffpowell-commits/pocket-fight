extends Control
## The test fight screen: your monster against a wild one, drawn with the same MonsterView.
## Rules live in scripts/duel.gd. This is the creator's show-off stage, not the game's core
## (docs/PITCH.md): one short fight so a monster you made gets to DO something.
##   var f = Fight.open(game, design)     f.closed is emitted with true/false (won) on leaving

signal closed(won: bool)

const UI = preload("res://scripts/ui.gd")
const Monster = preload("res://scripts/monster.gd")
const View = preload("res://scripts/monster_view.gd")
const Duel = preload("res://scripts/duel.gd")

## Live sliders (DEV MENU -> TUNE). Applied to the next fight.
const TUNE := {"max_hp": [10.0, 60.0], "basic_damage": [1.0, 12.0], "strike_damage": [4.0, 24.0],
	"splash_damage": [0.0, 8.0], "climb_bonus": [0.0, 8.0], "cooldown_turns": [0.0, 4.0]}
var max_hp := 30.0
var basic_damage := 5.0
var strike_damage := 15.0
var splash_damage := 2.0
var climb_bonus := 3.0
var cooldown_turns := 2.0

var design: Dictionary
var foe: Dictionary
var duel: Duel
var won_any := false
var rng := RandomNumberGenerator.new()
var me: View
var them: View
var hp_me: Label
var hp_them: Label
var bar_me: ProgressBar
var bar_them: ProgressBar
var intent: Label
var log_line: Label
var b_attack: Button
var b_guard: Button
var b_move: Button
var end_box: VBoxContainer


static func open(game: Node, monster: Dictionary) -> Control:
	var f: Control = load("res://scripts/fight.gd").new()
	f.design = Monster.clean(monster)
	f.name = "Fight"
	game.add_child(f)
	return f


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.theme()
	add_to_group("tunable")
	get_node("/root/DebugMenu").apply_tune(self)
	rng.randomize()
	_build()
	start()
	get_node("/root/Audio").music("music_combat")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	them = View.new()
	them.flip = true
	_place(them, 0.34, 1.0, 100, 360)
	me = View.new()
	_place(me, 0.0, 0.66, 300, 600)
	var still: bool = get_node("/root/Settings").get_value("low_graphics")
	me.animate = not still
	them.animate = not still
	var left: bool = get_node("/root/Settings").get_value("left_handed")
	hp_them = UI.label("", 22)
	_place(hp_them, 0.03, 0.47, 118, 150)
	bar_them = _hp_bar(0.03, 0.47, 154)
	hp_me = UI.label("", 22)
	_place(hp_me, 0.53, 0.97, 452, 484)
	bar_me = _hp_bar(0.53, 0.97, 488)
	# what just happened: small, up top beside PAUSE
	log_line = UI.label("", 18, UI.DIM)
	_place(log_line, 0.0, 1.0, 30, 30 + UI.MIN_TOUCH)
	log_line.offset_left = 190 if left else 20
	log_line.offset_right = -20 if left else -190
	log_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# what is about to happen: big, right above the thumb buttons
	intent = UI.label("", 30, UI.key("warn"))
	intent.anchor_top = 1.0
	intent.anchor_bottom = 1.0
	_place(intent, 0.0, 1.0, -330, -272)
	intent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pause_b := UI.button("PAUSE", func(): get_parent().pause())
	pause_b.anchor_left = 0.0 if left else 1.0
	pause_b.anchor_right = pause_b.anchor_left
	pause_b.offset_left = 24 if left else -174
	pause_b.offset_right = pause_b.offset_left + 150
	pause_b.offset_top = 30
	pause_b.offset_bottom = 30 + UI.MIN_TOUCH
	add_child(pause_b)
	var col := VBoxContainer.new()
	col.anchor_left = 0.06
	col.anchor_right = 0.94
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_top = -264
	col.offset_bottom = -24
	col.add_theme_constant_override("separation", UI.GAP - 6)
	add_child(col)
	b_attack = UI.button("", func(): play("Attack"))
	b_guard = UI.button("", func(): play("Guard"))
	b_move = UI.button("", func(): play("Move"))
	for b in [b_attack, b_guard, b_move]:
		col.add_child(b)


## A real HP bar. The number stays in the label above it, so the bar is never the only cue.
func _hp_bar(l: float, r: float, top: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color("1b2028")
	back.set_corner_radius_all(7)
	back.set_border_width_all(2)
	back.border_color = Color("3a4760")
	var fill := StyleBoxFlat.new()
	fill.bg_color = UI.key("good")
	fill.set_corner_radius_all(7)
	b.add_theme_stylebox_override("background", back)
	b.add_theme_stylebox_override("fill", fill)
	_place(b, l, r, top, top + 18)
	return b


func _place(c: Control, l: float, r: float, top: int, bottom: int) -> void:
	c.anchor_left = l
	c.anchor_right = r
	c.offset_top = top
	c.offset_bottom = bottom
	add_child(c)


## A new wild monster and full HP on both sides.
func start() -> void:
	UI.close_sheet(end_box)
	end_box = null
	foe = Monster.surprise(rng)
	foe["eyes"] = "Fierce"
	foe = Monster.clean(foe)
	them.design = foe
	me.design = design
	me.act_name = ""
	them.act_name = ""
	duel = Duel.new(design["move"])
	duel.max_hp = int(max_hp)
	duel.basic_damage = int(basic_damage)
	duel.strike_damage = int(strike_damage)
	duel.splash_damage = int(splash_damage)
	duel.climb_bonus = int(climb_bonus)
	duel.cooldown_turns = int(cooldown_turns)
	duel.reset()
	log_line.text = "A wild %s! It winds up, then strikes." % foe["name"]
	refresh()


func play(action: String) -> void:
	if get_parent().paused or duel.over():
		return
	duel.god = get_node("/root/DebugMenu").god_mode
	var striking := duel.charging
	var r := duel.play(action)
	if not r["ok"]:
		return
	var audio: Node = get_node("/root/Audio")
	match action:
		"Attack":
			me.act("attack")
		"Guard":
			me.act("guard")
		"Move":
			me.act(design["move"])
			audio.sfx("whoosh")
	if r["dealt"] > 0:
		them.act("hurt")
		audio.sfx("hit")
	if striking and not duel.won():
		them.act("attack")
	if r["taken"] > 0:
		me.act("hurt")
		audio.sfx("hit_heavy")
		get_node("/root/Subs").cue("[heavy strike lands]")
		UI.buzz(60)
	log_line.text = r["text"]
	refresh()
	if duel.over():
		_finish()


func _finish() -> void:
	var won := duel.won()
	var audio: Node = get_node("/root/Audio")
	if won:
		won_any = true
		them.act("faint")
		me.act("hop")
		audio.sfx("level")
		get_node("/root/Subs").cue("[win chime]")
		get_parent().fight_won()
	else:
		me.act("faint")
		audio.sfx("bad")
		get_node("/root/Subs").cue("[low thud: fainted]")
	end_box = UI.sheet(self)
	end_box.add_child(UI.label("%s WINS!" % design["name"].to_upper() if won else "%s FAINTED" % design["name"].to_upper(),
		34, UI.key("good") if won else UI.key("bad")))
	end_box.add_child(UI.label("Beat wild %s in %d turns." % [foe["name"], duel.turn] if won
		else "Tip: GUARD or use your move when it says STRIKE.", 22))
	end_box.add_child(UI.button("FIGHT ANOTHER" if won else "TRY AGAIN", start, 88))
	end_box.add_child(UI.button("BACK TO CREATOR", leave))


func ended() -> bool:
	return duel.over()


func leave() -> void:
	UI.close_sheet(end_box)
	get_node("/root/Subs").clear()
	closed.emit(won_any)
	queue_free()


## Dev menu SKIP LEVEL: win this fight now.
func debug_win() -> void:
	if not duel.over():
		duel.enemy_hp = 0
		refresh()
		_finish()


func refresh() -> void:
	hp_me.text = "%s  %d/%d" % [design["name"], duel.player_hp, duel.max_hp]
	hp_them.text = "Wild %s  %d/%d" % [foe["name"], duel.enemy_hp, duel.max_hp]
	for pair in [[bar_me, duel.player_hp], [bar_them, duel.enemy_hp]]:
		pair[0].max_value = duel.max_hp
		pair[0].value = pair[1]
		var low: bool = pair[1] * 3 <= duel.max_hp
		(pair[0].get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UI.key("bad") if low else UI.key("good")
	if duel.over():
		intent.text = ""
	elif duel.charging:
		intent.text = "!! STRIKE COMING !!"      # words + marks, not only colour
		intent.add_theme_color_override("font_color", UI.key("bad"))
	else:
		intent.text = "It winds up..."
		intent.add_theme_color_override("font_color", UI.key("warn"))
	b_attack.text = "ATTACK  (%d)" % duel.attack_damage()
	b_guard.text = "GUARD  (halve a strike)"
	var what := "break the strike" if design["move"] == "Splash" else "dodge, hit harder"
	b_move.text = "%s  (%s)" % [design["move"].to_upper(), what]
	if duel.cooldown > 0:
		b_move.text = "%s  (rests %d)" % [design["move"].to_upper(), duel.cooldown]
	elif not duel.charging:
		b_move.text = "%s  (wait for a strike)" % design["move"].to_upper()
	b_attack.disabled = not duel.can("Attack")
	b_guard.disabled = not duel.can("Guard")
	b_move.disabled = not duel.can("Move")


func bug_state() -> String:
	return "fight turn %d hp %d/%d foe %d move %s" % [duel.turn, duel.player_hp, duel.max_hp, duel.enemy_hp, design["move"]]
