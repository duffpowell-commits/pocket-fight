extends Node
## Autoload "Autoplay": a bot that plays the whole flow with real taps and saves screenshots.
## Off unless the game is started with `-- --autoplay`. Run it (needs a screen, so xvfb):
##   tools/autoplay.sh            -> docs/renders/flow_*.png, prints one PASS line per check
## It ends with "AUTOPLAY PASS" or "AUTOPLAY FAIL <step>"; CI fails without the PASS or on any FAIL line.
## Uses its own settings/save folder (XDG_DATA_HOME in the script), never the player's.
##
## When the game grows, extend `_run()`: drive the real game the way a player would, and add a
## PASS line for each thing that must keep working.

var shots := ""
var clip := ""                          # --clip=DIR: save a gameplay clip's frames there
const CLIP_SECS := 15.0                 # vertical 9:16 (the game is portrait), sized for Shorts/Reels/TikTok
var failed := false
var _start_ms := 0                      # when game code first runs (engine/driver start-up excluded)


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	if not "--autoplay" in OS.get_cmdline_user_args():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
		if a.begins_with("--clip="):
			clip = a.trim_prefix("--clip=")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	get_tree().create_timer(240.0).timeout.connect(func(): _fail("timeout"))
	_run.call_deferred()


# ---------------------------------------------------------------- the run

func _run() -> void:
	await _wait_scene("Boot")
	# Disable the timer in this run so only the tap can dismiss the card.
	get_tree().current_scene.get_node("StudioSplash/DisplayTimer").stop()
	await _shot("studio_splash")
	await _click("Skip splash")
	_check(_find("Skip splash") == null, "STUDIO SPLASH PASS (Skip splash dismisses the publisher card)")
	await _wait_scene("Intro")
	var intro_ms := Time.get_ticks_msec()
	await _frames(10)
	await _shot("intro")
	var skip_ms := Time.get_ticks_msec()
	await _click("SKIP")
	await _wait_scene("Title")
	# Game start -> intro on screen, plus SKIP -> title. Driver start-up (10 s of ALSA/llvmpipe on a CI
	# box, not a phone) and the bot's own frames and screenshot don't count.
	var boot_ms := (intro_ms - _start_ms) + (Time.get_ticks_msec() - skip_ms)
	_check(boot_ms < 10000, "BOOT PASS (title ready %.1f s after game start)" % (boot_ms / 1000.0))
	# Quality tier: picked on first launch and saved; LOW really lowers; then HIGH for the checks below.
	var Q = preload("res://scripts/quality.gd")
	var st: Node = get_node("/root/Settings")
	var picked: int = st.get_value("tier")
	Q.apply(get_tree(), 0)
	var low_ok: bool = st.get_value("low_graphics") and is_equal_approx(get_tree().root.scaling_3d_scale, 0.7)
	Q.apply(get_tree(), 2)
	var high_ok: bool = not st.get_value("low_graphics") and is_equal_approx(get_tree().root.scaling_3d_scale, 1.0)
	_check(picked >= 0 and Q.last_ms > 0.0 and low_ok and high_ok,
		"TIER PASS (first launch picked %s, test frame %.1f ms; LOW and HIGH apply)" % [Q.NAMES[maxi(picked, 0)], Q.last_ms])
	await _frames(10)
	await _shot("title")
	_check(_find("CONTINUE") == null, "TITLE PASS (no save yet)")
	await _click("SETTINGS")
	await _click("CREDITS")
	_check(_has_label("Published by 3 Eyed Fox Studios"), "PUBLISHER CREDITS PASS")
	await _click("DONE")
	await _click("DONE")
	await _click("NEW MONSTER")
	await _wait_scene("Game")
	var game := get_tree().current_scene
	var ld: Node = get_node("/root/Loader")
	_check(ld.loads >= 2 and not ld.busy(), "LOAD PASS (%d scenes loaded in the background, %d frames drawn meanwhile)" % [ld.loads, ld.frames_while_loading])

	# Creator: a new monster is hatched (never a blank) and saved before anything is tapped.
	const Monster = preload("res://scripts/monster.gd")
	var save: Node = get_node("/root/Save")
	await _frames(10)
	await _shot("creator")
	_check(save.exists() and Monster.clean(game.design) == game.design and game.design == Monster.clean(save.read().get("monster")),
		"HATCH PASS (new game hatched %s and saved it)" % game.design["name"])
	# Tap parts: a tab in the strip, then a choice.
	await _click("EARS")
	await _click("FLOPPY")
	await _click("COLOR")
	await _click("PLUM")
	await _click("BACK")
	await _click("WINGS")
	await _frames(5)
	_check(game.design["ears"] == "Floppy" and game.design["color"] == "Plum" and game.design["back"] == "Wings",
		"PARTS PASS (tapped floppy ears, plum, wings)")
	# Shape sliders.
	await _click("SHAPE")
	await _frames(3)
	var chub: HSlider = game.find_child("Slider_chub", true, false)
	chub.value = 1.0
	await _frames(3)
	await _shot("creator_shape")
	_check(is_equal_approx(game.design["chub"], 1.0), "SHAPE PASS (chub slider at 100%)")
	# Describe it: typed words become a draft; the words it got are shown.
	await _click("DESCRIBE")
	await _frames(5)
	await _shot("describe")
	(game.find_child("DescribeText", true, false) as LineEdit).text = "a skinny blue cat with horns and zorp, named Gus"
	await _click("MAKE A NEW ONE")
	await _frames(10)
	await _shot("described")
	var g: Dictionary = game.design
	_check(g["name"] == "Gus" and g["color"] == "Lake" and g["ears"] == "Pointy" and g["top"] == "Horns"
		and g["chub"] < 0.2 and g["back"] == "None" and "zorp" in game.last_missed and "Missed: zorp" in game.status.text,
		"DESCRIBE PASS (typed a skinny blue horned cat named Gus; told the player it missed 'zorp')")
	# Words it can't use change nothing and say so.
	await _click("DESCRIBE")
	await _frames(5)
	(game.find_child("DescribeText", true, false) as LineEdit).text = "zzz qqq"
	await _click("MAKE A NEW ONE")
	await _frames(5)
	_check(game.design == g and game.find_child("DescribeText", true, false) != null, "DESCRIBE MISS PASS (nonsense changed nothing, sheet stayed open)")
	await _click("CANCEL")
	await _frames(5)
	# Surprise rolls a new one; UNDO brings Gus back.
	await _click("SURPRISE")
	await _frames(10)
	await _shot("surprise")
	var rolled: bool = game.design != g
	await _click("UNDO")
	await _frames(5)
	_check(rolled and game.design == g, "UNDO PASS (surprise rolled a new monster, undo restored Gus)")
	# Rename.
	await _click("GUS")
	await _frames(5)
	(game.find_child("NameText", true, false) as LineEdit).text = "Gusto"
	await _click("SAVE NAME")
	await _frames(5)
	_check(game.design["name"] == "Gusto" and _find("GUSTO") != null, "RENAME PASS (Gus is now Gusto)")
	# CHANGE THIS ONE: words change only what they mention.
	await _click("DESCRIBE")
	await _frames(5)
	(game.find_child("DescribeText", true, false) as LineEdit).text = "purple with wings"
	await _click("CHANGE THIS ONE")
	await _frames(10)
	var c: Dictionary = game.design
	_check(c["color"] == "Plum" and c["back"] == "Wings" and c["name"] == "Gusto" and c["ears"] == "Pointy" and c["top"] == "Horns",
		"CHANGE PASS (added purple and wings; name, ears and horns untouched)")
	# A face part: the SNOUT tab.
	await _click("SNOUT")
	await _click("LONG")
	await _frames(5)
	await _shot("creator_snout")
	_check(game.design["snout"] == "Long", "SNOUT PASS (picked a long snout)")
	# The move is the one choice a fight reads: pick Climb from the MOVE tab.
	await _click("MOVE")
	await _click("CLIMB")
	await _frames(5)
	_check(game.design["move"] == "Climb", "MOVE PASS (picked Climb)")
	g = game.design.duplicate()
	var bat: Node = get_node("/root/Battery")
	var playing_full: bool = bat.state == "play" and Engine.max_fps == 60

	# Every change is saved the moment it is made.
	var saved: Dictionary = save.read()
	_check(Monster.clean(saved.get("monster")) == g, "AUTOSAVE PASS (Gusto saved without a save button)")

	# Phone interruption: the app loses focus -> pause + save.
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(10)
	_check(game.paused and _find("RESUME") != null, "INTERRUPT PASS (paused on focus loss)")
	var bg_low: bool = bat.state == "background" and Engine.max_fps == 5
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(3)
	_check(playing_full and bg_low and bat.state == "saver" and Engine.max_fps == 30,
		"BATTERY PASS (play 60 fps, background 5 fps, paused 30 fps)")
	bat.idle_secs = INF                         # the bot plays without input events: don't treat it as idle
	await _shot("pause")

	# Settings from the pause menu: bigger text, colorblind, left-handed.
	await _click("SETTINGS")
	await _frames(10)
	await _shot("settings")
	await _click("TEXT SIZE")
	await _frames(5)
	await _click("COLORBLIND")
	await _click("LEFT-HANDED")
	await _frames(10)
	await _shot("settings_changed")
	var s: Node = get_node("/root/Settings")
	_check(s.get_value("colorblind") and s.get_value("left_handed") and int(s.get_value("text_size")) == 2,
		"SETTINGS PASS (saved)")
	await _click("DONE")
	await _frames(5)

	# Quit to title, CONTINUE, back where we were.
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")
	await _frames(10)
	await _shot("title_continue")
	await _click("CONTINUE")
	await _wait_scene("Game")
	game = get_tree().current_scene
	_check(game.design == g, "RESUME PASS (CONTINUE brought %s back, part for part)" % game.design["name"])
	await _frames(10)
	await _shot("game_lefthanded")

	# Android back = pause, back again = resume.
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	_check(game.paused, "BACK PASS (back button pauses)")
	await _click("RESUME")
	await _frames(5)

	# A phone call while DESCRIBE is open must not leave the game stuck paused.
	await _click("DESCRIBE")
	await _frames(5)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(10)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var was_paused: bool = game.paused
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	var unpaused: bool = not game.paused and game.find_child("DescribeText", true, false) != null
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	var closed: bool = game.find_child("DescribeText", true, false) == null
	await _click("SURPRISE")
	await _frames(5)
	var alive: bool = game.design != g
	await _click("UNDO")
	await _frames(5)
	_check(was_paused and unpaused and closed and alive and game.design == g,
		"UNSTUCK PASS (call during DESCRIBE: back un-pauses, back closes the sheet, buttons still work)")

	# Test fight, played well: Attack on the wind-up, the signature move (or Guard) on the strike.
	await _click("FIGHT")
	await _frames(15)
	await _shot("fight")
	var fight: Control = game.fight
	var turns := 0
	# A call mid-fight pauses it; back resumes; the fight carries on.
	await _click("ATTACK")
	await _frames(3)
	turns += 1
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(10)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var hp_before: int = fight.duel.enemy_hp
	fight.play("Attack")
	var frozen: bool = game.paused and fight.duel.enemy_hp == hp_before
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(5)
	_check(frozen and not game.paused and is_instance_valid(game.fight),
		"FIGHT INTERRUPT PASS (call mid-fight pauses, turns are blocked, back resumes)")
	while not fight.duel.over() and turns < 60:
		if fight.duel.charging:
			await _click_node(fight.b_move if fight.duel.can("Move") else fight.b_guard)
		else:
			await _click("ATTACK")
		await _frames(3)
		turns += 1
	await _frames(10)
	await _shot("fight_won")
	_check(fight.bar_me.value == fight.duel.player_hp and fight.bar_them.value == fight.duel.enemy_hp
		and fight.bar_me.max_value == fight.duel.max_hp and fight.duel.player_hp < fight.duel.max_hp,
		"HP BAR PASS (bars match the numbers: %d and %d of %d)" % [fight.duel.player_hp, fight.duel.enemy_hp, fight.duel.max_hp])
	_check(fight.duel.won() and game.wins == 1 and int(save.read().get("wins", 0)) == 1 and _find("FIGHT ANOTHER") != null,
		"FIGHT PASS (won in %d turns with %d HP left; win saved)" % [turns, fight.duel.player_hp])
	# Played badly (Attack only) the strike wins: the fight is not a formality.
	await _click("FIGHT ANOTHER")
	await _frames(5)
	turns = 0
	while not fight.duel.over() and turns < 60:
		await _click("ATTACK")
		await _frames(3)
		turns += 1
	await _frames(10)
	await _shot("fight_fainted")
	_check(not fight.duel.won() and _find("TRY AGAIN") != null and game.wins == 1 and Monster.clean(save.read().get("monster")) == g,
		"FAINT PASS (attack-only lost in %d turns; monster and win count kept)" % turns)
	# A call on the result screen: back un-pauses (result stays), back again leaves for the creator.
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(10)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var res_paused: bool = game.paused
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(10)
	var res_kept: bool = not game.paused and is_instance_valid(game.fight) and _find("TRY AGAIN") != null and _find("RESUME") == null
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(10)
	_check(res_paused and res_kept and not is_instance_valid(game.fight) and not game.paused,
		"FIGHT BACK PASS (call on the result screen: back un-pauses, back again returns to the creator)")
	# Back during a live fight pauses it; back again resumes it.
	await _click("FIGHT")
	await _frames(10)
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(10)
	var live_paused: bool = game.paused and _find("RESUME") != null
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(10)
	_check(live_paused and not game.paused and _find("RESUME") == null and is_instance_valid(game.fight) and not game.fight.duel.over(),
		"FIGHT PAUSE PASS (back mid-fight pauses, back again resumes, pause sheet gone)")
	game.fight.leave()
	await _frames(10)
	await _click("PAUSE")
	await _click("QUIT TO TITLE")
	await _wait_scene("Title")
	await _frames(5)
	_check(_find("CONTINUE  (GUSTO)") != null, "FLOW PASS (back at title, CONTINUE shows Gusto)")
	# NEW MONSTER with a save asks first, so a mis-tap can't wipe a monster.
	await _click("NEW MONSTER")
	await _frames(5)
	_check(_find("YES, START OVER") != null and save.exists(), "KEEP PASS (NEW MONSTER asks before replacing Gusto)")
	await _click("KEEP GUSTO")
	await _frames(5)

	# Bug report sheet carries the build line.
	await _click("REPORT A BUG")
	await _frames(10)
	await _shot("bug_report")
	var txt: String = preload("res://scripts/bug_report.gd").report_text("test", get_tree())
	_check("build:" in txt and "device:" in txt, "BUGREPORT PASS")
	await _click("CLOSE")

	# Debug menu (dev builds): 5 taps on the version number.
	for i in 5:
		await _click_node(get_tree().current_scene.find_child("Version", true, false))
	await _frames(10)
	_check(_find("GOD MODE") != null, "DEBUG PASS (dev menu opens)")
	await _shot("debug_menu")

	# 3D character standard (docs/MOVEMENT_3D.md): full range of movement, every system proven.
	await _click("3D CHARACTER TEST")
	await _wait_scene("CharacterTest")
	await _frames(20)
	var coach_was: bool = get_tree().current_scene.has_node("UI/Root/Coach_move")
	await _movement_checks(get_tree().current_scene)
	await _standards_checks(get_tree().current_scene, coach_was)
	await _tune_checks(get_tree().current_scene)
	if clip != "":
		await _record_clip(get_tree().current_scene)

	if not failed:
		print("AUTOPLAY PASS")
	get_tree().quit(1 if failed else 0)


# ---------------------------------------------------------------- 3D movement checks

var _bones := {}


func _snap_bones(sk: Skeleton3D) -> void:
	var d := {}
	for b in ["foot_l", "foot_r", "pelvis", "Head"]:
		d[b] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
	d["head_fwd"] = (sk.global_transform.basis * sk.get_bone_global_pose(sk.find_bone("Head")).basis.z).normalized()
	_bones[sk.get_instance_id()] = d


## Bone positions as drawn (after animation, IK and ragdoll), not before the modifiers ran.
func _bone(c: Node, b: String) -> Variant:
	var sk: Skeleton3D = c.skeleton
	if not sk.skeleton_updated.is_connected(_snap_bones.bind(sk)):
		sk.skeleton_updated.connect(_snap_bones.bind(sk))
		await _frames(2)
	await _frames(1)
	return _bones[sk.get_instance_id()][b]


func _place(c: Node, p: Vector3, h: float) -> void:
	c.global_position = p
	c.velocity = Vector3.ZERO
	c.heading = h
	c.model.rotation.y = h
	var sc := get_tree().current_scene
	if sc.has_method("snap_camera") and c == sc.get("hero"):
		sc.snap_camera()                       # cut, don't pan, after a teleport


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ground_gap(c: Node, foot: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(foot + Vector3.UP, foot + Vector3.DOWN * 2.0, 2)
	var r: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q)
	return foot.y - float(r.position.y) if not r.is_empty() else 99.0


func _movement_checks(ct: Node) -> void:
	var hero: Node = ct.hero
	var dummy: Node = ct.dummy
	# 360 degrees of movement with real limb animation.
	var top_speed := 0.0
	var foot_travel := 0.0
	var last_foot: Vector3 = await _bone(hero, "foot_l")
	var ang := 0.0
	while ang < TAU * 1.15:
		ct.bot_stick = Vector2(cos(ang), sin(ang))
		await _frames(1)
		ang += 0.06
		top_speed = maxf(top_speed, hero.speed())
		var f: Vector3 = _bones[hero.skeleton.get_instance_id()]["foot_l"] - hero.global_position
		foot_travel += f.distance_to(last_foot)
		last_foot = f
		if absf(ang - PI) < 0.03:
			await _shot("char_run")
	ct.bot_stick = Vector2.ZERO
	_check(hero.turned > 5.6 and top_speed > 4.0,
		"MOVE360 PASS (turned %.1f rad, top speed %.1f m/s)" % [hero.turned, top_speed])
	_check(foot_travel > 2.0, "LIMBS PASS (left foot travelled %.1f m against the hips: real animation)" % foot_travel)
	# The drawn body follows the skeleton (a stale import can leave a T-pose mesh over a live rig).
	var bound := 0
	var skinned := 0
	for c in [ct.hero, ct.dummy]:
		for m in c.model.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).skin != null:
				skinned += 1
				if m.get_node_or_null(m.skeleton) == c.skeleton:
					bound += 1
	_check(skinned > 0 and bound == skinned, "SKIN PASS (%d of %d body meshes follow their skeleton)" % [bound, skinned])
	# Feet planted on a slope and on stairs (foot IK): both ankles at ankle height over the ground.
	for spot in [["SLOPE", Vector3(5, 1.5, -3), PI], ["STAIRS", Vector3(-3.5, 1.2, 3), -PI / 2]]:
		_place(hero, spot[1], spot[2])
		await _physics(50)
		var gl := _ground_gap(hero, await _bone(hero, "foot_l"))
		var gr := _ground_gap(hero, _bones[hero.skeleton.get_instance_id()]["foot_r"])
		_check(absf(gl - gr) < 0.04 and gl < 0.16 and gr < 0.16,
			"FOOTIK %s PASS (feet %.2f / %.2f m over the ground)" % [spot[0], gl, gr])
		if spot[0] == "STAIRS":
			await _shot("char_stairs")
	# Jump: take-off, fall, land.
	_place(hero, Vector3(0, 0.05, 0), 0.0)
	await _physics(10)
	hero.jump()
	var peak := 0.0
	var phases := {}
	for i in 90:
		await _physics(1)
		peak = maxf(peak, hero.global_position.y)
		phases[hero.air_phase] = true
		if i == 20:
			await _shot("char_jump")
	_check(peak > 0.6 and phases.has("start") and phases.has("fall") and phases.has("land") and hero.mode == "ground",
		"JUMP PASS (peak %.2f m, start/fall/land)" % peak)
	# Crouch walk.
	ct.toggle_crouch()
	ct.bot_stick = Vector2(1, 0)
	await _physics(30)
	_check(hero.mode == "crouch" and hero.speed() < 2.0 and hero._cap.height < 1.3, "CROUCH PASS (speed %.1f)" % hero.speed())
	await _shot("char_crouch")
	ct.bot_stick = Vector2.ZERO
	ct.toggle_crouch()
	# Aim: turn in place, strafe (chest on target, legs sideways), backpedal, head looks at it.
	_place(hero, Vector3(0, 0.05, 2), 0.0)
	await _physics(5)
	var turned0: float = hero.turned
	await _click("AIM")
	await _physics(60)
	var start_pos: Vector3 = hero.global_position
	var to_d: Vector3 = (dummy.global_position - hero.global_position).normalized()
	_check(hero.turned - turned0 > 1.0 and start_pos.distance_to(Vector3(0, 0, 2)) < 0.2, "TURN PASS (turned on the spot)")
	var head_fwd: Vector3 = await _bone(hero, "head_fwd")
	_check(Vector2(head_fwd.x, head_fwd.z).normalized().dot(Vector2(to_d.x, to_d.z)) > 0.85, "LOOKAT PASS (head on target)")
	ct.bot_stick = Vector2(1, 0)
	await _physics(25)
	_check(absf(hero.twist.yaw) > 0.5 and hero.speed() > 3.0, "STRAFE PASS (chest twisted %.0f deg)" % rad_to_deg(hero.twist.yaw))
	await _shot("char_strafe")
	_place(hero, Vector3(0, 0.05, 1), PI)
	ct.bot_stick = Vector2(0, 1)
	await _physics(25)
	_check(hero.backpedal and hero.speed() > 3.0, "BACKPEDAL PASS")
	ct.bot_stick = Vector2.ZERO
	await _click("AIM")
	# Punch combo: jab, cross, hook (a real tap, then the same function the button calls); the hook
	# knocks the dummy back (root motion).
	_place(hero, dummy.global_position + Vector3(0, 0.05, 1.0), PI)
	await _physics(5)
	await _click("PUNCH")
	await _physics(4)
	_check(hero.is_acting("punch") and dummy.is_acting("hit_chest"), "ACTION PASS (punch lands, dummy flinches)")
	await _shot("char_punch")
	await _physics(20)
	ct.punch()
	await _physics(25)
	var d0: Vector3 = dummy.global_position
	_place(hero, dummy.global_position + Vector3(0, 0.05, 1.0), PI)
	ct.punch()
	await _physics(60)
	_check(ct.combo == 3 and dummy.global_position.distance_to(d0) > 0.6, "KNOCKBACK PASS (combo hook threw the dummy %.1f m)" % dummy.global_position.distance_to(d0))
	await _click("DODGE")
	await _physics(4)
	_check(hero.is_acting("dodge"), "DODGE PASS")
	await _physics(60)
	# Climb a 1 m ledge, vault a 0.8 m wall, swim, climb out of the water.
	_place(hero, Vector3(0, 0.05, -6.4), PI)
	await _physics(10)
	await _click("JUMP")
	await _physics(12)
	await _shot("char_climb")
	await _physics(60)
	_check(hero.global_position.y > 0.9 and hero.mode == "ground", "CLIMB PASS (on the ledge at %.2f m)" % hero.global_position.y)
	_place(hero, Vector3(9.25, 0.05, 0.9), 0.0)
	await _physics(10)
	await _click("JUMP")
	await _physics(80)
	_check(hero.global_position.z > 2.0 and hero.global_position.y < 0.2, "VAULT PASS (over the wall)")
	_place(hero, Vector3(-6.5, 0.5, -7.5), 0.0)
	await _physics(90)
	_check(hero.mode == "swim", "SWIM PASS")
	await _shot("char_swim")
	_place(hero, Vector3(-6.5, -1.6, -5.8), 0.0)
	await _physics(5)
	await _click("JUMP")
	await _physics(90)
	_check(hero.mode == "ground" and hero.global_position.y > -0.1, "SWIMOUT PASS (climbed out of the pool)")
	# Ragdoll death: the body falls under physics, the pelvis ends near the floor.
	ct.reset_dummy()
	_place(hero, Vector3(2, 0.05, 0), 0.0)
	await _physics(10)
	dummy.die(Vector3(0, 3, -8))
	await _physics(150)
	var pel: Vector3 = await _bone(dummy, "pelvis")
	_check(dummy.is_ragdoll() and pel.y < 0.4, "RAGDOLL PASS (pelvis down to %.2f m)" % pel.y)
	await _shot("char_ragdoll")
	var inked := true
	for m in hero.model.find_children("*", "MeshInstance3D", true, false):
		for i in (m as MeshInstance3D).mesh.get_surface_count():
			var mat := (m as MeshInstance3D).get_surface_override_material(i) as ShaderMaterial
			inked = inked and mat != null and mat.next_pass != null
	_check(inked, "INK PASS (toon + outline on every surface)")


# ---------------------------------------------------------------- house standards (GROK_STANDARDS.md)

func _contrast(img: Image, cam: Camera3D, c: Node) -> float:
	var scale := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
	var lum := func(p: Vector2) -> float:
		var tot := 0.0
		for dx in range(-3, 4, 3):
			for dy in range(-3, 4, 3):
				var q := Vector2i((p * scale) + Vector2(dx, dy))
				q = q.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
				tot += img.get_pixelv(q).get_luminance()
		return tot / 9.0
	var chest: Vector2 = cam.unproject_position(c.global_position + Vector3(0, 1.15, 0))
	var feet: Vector2 = cam.unproject_position(c.global_position + Vector3(0, 0.05, 0))
	var hips: Vector2 = cam.unproject_position(c.global_position + Vector3(0, 0.95, 0))
	var hero_l: float = (lum.call(chest) + lum.call(hips)) / 2.0
	var floor_l := 0.0
	for o in [Vector2(-90, 0), Vector2(90, 0), Vector2(-90, 40), Vector2(90, 40)]:
		floor_l += lum.call(feet + o) / 4.0
	return (maxf(hero_l, floor_l) + 0.05) / (minf(hero_l, floor_l) + 0.05)


func _standards_checks(ct: Node, coach_was: bool) -> void:
	var hero: Node = ct.hero
	var dummy: Node = ct.dummy
	var feel: Node = get_node("/root/Feel")
	var audio: Node = get_node("/root/Audio")
	var controls: Node = get_node("/root/Controls")
	# 7. First 60 seconds: the move hint showed, and went away once the player moved.
	_check(coach_was and not ct.has_node("UI/Root/Coach_move") and preload("res://scripts/coach.gd").seen("move"),
		"COACH PASS (DRAG TO MOVE shown, learned by doing)")
	# 1 + 10. Game feel: the punches earlier fired every part.
	_check(feel.shakes >= 3 and feel.bursts >= 3 and feel.buzzes >= 3 and feel.sounds >= 3,
		"FEEL PASS (hit-stop, shake x%d, sparks x%d, sound, buzz x%d)" % [feel.shakes, feel.bursts, feel.buzzes])
	# 2. Camera: smooth, never through a wall, frames the target.
	ct.reset_dummy()
	_place(hero, Vector3(0, 0.05, 0), 0.0)
	await _physics(10)
	var last: Vector3 = ct.rig.cam.global_position
	var fastest := 0.0
	ct.bot_stick = Vector2(1, 0)
	for i in 50:
		await _frames(1)
		# Smooth = the camera glides: never faster than twice the hero's top speed (no jump cuts).
		fastest = maxf(fastest, ct.rig.cam.global_position.distance_to(last) / maxf(get_process_delta_time(), 0.001))
		last = ct.rig.cam.global_position
	ct.bot_stick = Vector2.ZERO
	_check(fastest < hero.max_speed * 2.0, "CAMERA SMOOTH PASS (camera top speed %.1f m/s)" % fastest)
	_place(hero, Vector3(-12, 0.05, 2.2), 0.0)
	await _physics(30)
	var cam: Camera3D = ct.rig.cam
	var see: Dictionary = get_tree().current_scene.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(cam.global_position, hero.global_position + Vector3(0, 1.2, 0), 1, [hero.get_rid()]))
	_check(ct.rig.blocked and see.is_empty(), "CAMERA WALL PASS (camera came in front of the wall)")
	await _shot("std_camera_wall")
	_place(hero, Vector3(0, 0.05, 4), PI)
	dummy.global_position = Vector3(0, 0, -5)
	ct.toggle_aim()
	await _physics(120)
	var vp := get_viewport().get_visible_rect()
	var both: bool = vp.has_point(cam.unproject_position(hero.global_position + Vector3(0, 1, 0))) \
		and vp.has_point(cam.unproject_position(dummy.global_position + Vector3(0, 1, 0))) \
		and not cam.is_position_behind(dummy.global_position)
	_check(both, "CAMERA FRAME PASS (hero and target both on screen)")
	await _shot("std_camera_frame")
	# 6. Music shifts to the combat layer when fighting.
	_check(audio.intensity > 0.9, "MUSIC PASS (combat layer at %d%%)" % int(audio.intensity * 100))
	ct.toggle_aim()
	ct.reset_dummy()
	# 6. Footsteps per surface: stone floor, wooden ramp, grass.
	hero.steps.clear()
	for spot in [[Vector3(-2, 0.05, -1), Vector2(1, 0)], [Vector3(5, 0.05, 0.5), Vector2(0, -1)], [Vector3(-2, 0.1, 8), Vector2(1, 0)]]:
		_place(hero, spot[0], 0.0)
		ct.bot_stick = spot[1] * 0.5
		await _physics(70)
	ct.bot_stick = Vector2.ZERO
	_check(hero.steps.has("stone") and hero.steps.has("wood") and hero.steps.has("grass"),
		"STEPS PASS (%s)" % str(hero.steps))
	# 6. Ducking: a heavy hit dips the music.
	feel.impact(hero.global_position, 0.8, ct)
	await _frames(8)
	_check(audio.duck_db < -4.0, "DUCK PASS (music dipped %.0f dB)" % audio.duck_db)
	# 4. Responsive: input buffer, coyote time, dodge cancels anything.
	_place(hero, Vector3(0, 0.05, 2), 0.0)
	await _physics(10)
	hero.jump()
	var buffered := false
	var takeoffs := 0
	var prev_vy := 0.0
	for i in 120:
		await _physics(1)
		if hero.velocity.y > 3.0 and prev_vy <= 3.0:
			takeoffs += 1
		prev_vy = hero.velocity.y
		if not buffered and hero.velocity.y < -2.0 and hero.global_position.y < 0.35:
			hero.jump()                         # pressed before landing: must still jump
			buffered = true
	_check(takeoffs >= 2, "BUFFER PASS (jump pressed in the air fired on landing)")
	_place(hero, Vector3(0, 1.05, -8.0), 0.0)
	await _physics(10)
	ct.bot_stick = Vector2(0, 1)
	var coyote_ok := false
	for i in 90:
		await _physics(1)
		if not hero.is_on_floor() and hero.velocity.y <= 0.0 and hero.global_position.y < 0.98:
			await _physics(2)
			hero.jump()
			await _physics(1)
			coyote_ok = hero.velocity.y > 3.0
			break
	ct.bot_stick = Vector2.ZERO
	_check(coyote_ok, "COYOTE PASS (jumped just after leaving the edge)")
	await _physics(60)
	hero.act("punch")
	await _physics(3)
	hero.act("dodge")
	await _physics(3)
	_check(hero.is_acting("dodge") and not hero.is_acting("punch"), "CANCEL PASS (punch cancelled into a dodge)")
	await _physics(110)
	# 11. Gamepad + remapping, through the real input system.
	_place(hero, Vector3(0, 0.05, 2), 0.0)
	ct.bot_stick = Vector2.INF                # hand control back to the real inputs
	await _physics(5)
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 1.0
	Input.parse_input_event(m)
	await _physics(30)
	var pad_speed: float = hero.velocity.x
	m.axis_value = 0.0
	Input.parse_input_event(m)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	await _physics(20)
	Input.parse_input_event(b)
	await _frames(3)                           # parsed input is delivered on the next frame
	var pad_jump: bool = hero.mode == "air" or hero.velocity.y > 1.0
	b.pressed = false
	Input.parse_input_event(b)
	_check(pad_speed > 3.0 and pad_jump, "PAD PASS (stick moves %.1f m/s, A jumps)" % pad_speed)
	await _physics(80)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_T
	controls.rebind("jump", k)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_T
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	var remap_ok: bool = (hero.mode == "air" or hero.velocity.y > 1.0) and FileAccess.file_exists("user://controls.cfg")
	press.pressed = false
	Input.parse_input_event(press)
	controls.reset()
	_check(remap_ok,
		"REMAP PASS (jump moved to T, saved, reset)")
	await _physics(80)
	# Controls legend: hidden for touch players, shows on the first key/pad press, follows remaps,
	# and the Settings toggle hides it.
	var lg: PanelContainer = preload("res://scripts/controls_legend.gd").make(["jump", "pause"])
	lg.top = 420                              # below the scene's own legend
	ct.ui.add_child(lg)
	await _frames(2)
	var hidden_touch := not lg.visible
	var kp := InputEventKey.new()
	kp.physical_keycode = KEY_Z
	kp.pressed = true
	Input.parse_input_event(kp)
	kp.pressed = false
	Input.parse_input_event(kp)
	await _frames(3)
	var shown := lg.visible
	await _frames(2)
	await _shot("legend")
	var kt := InputEventKey.new()
	kt.physical_keycode = KEY_T
	controls.rebind("jump", kt)
	lg.refresh()
	var follows: bool = "T" in lg._label.text.split("\n")[0]
	controls.reset()
	var settings: Node = get_node("/root/Settings")
	settings.set_value("show_legend", false)
	var off := not lg.visible
	settings.set_value("show_legend", true)
	_check(hidden_touch and shown and follows and off and ct.legend != null,
		"LEGEND PASS (hidden on touch, shows on key, follows remap, toggle hides)")
	lg.queue_free()
	# 5. The hero reads against the floor, in normal light and in the dark.
	_place(hero, Vector3(-2, 0.05, 0.5), 0.0)
	await _physics(20)
	await RenderingServer.frame_post_draw
	var c1: float = _contrast(get_viewport().get_texture().get_image(), cam, hero)
	ct.sun.light_energy = 0.08
	await _frames(3)
	await RenderingServer.frame_post_draw
	var c2: float = _contrast(get_viewport().get_texture().get_image(), cam, hero)
	await _shot("std_dark")
	ct.sun.light_energy = 1.2
	_check(c1 >= 2.0 and c2 >= 2.0, "READ PASS (hero vs floor contrast %.1f lit, %.1f dark)" % [c1, c2])
	# 3. Frame budget: draw calls, triangles, code time with 6 characters running.
	var r: Dictionary = await ct.perf_test(3.0, false)
	_check(r.budget_ok, "PERF PASS (%d draw calls, %dk tris, %.1f ms code; budget %s)" % [
		r.draw_calls, r.primitives / 1000.0, r.cpu_ms, str(ct.BUDGET)])
	# 9. Telemetry stays on the phone unless allowed.
	var tel: Node = get_node("/root/Telemetry")
	_check(not tel.allowed() and tel.events().size() > 0, "TELEMETRY PASS (%d events kept on the phone, nothing sent)" % tel.events().size())


# ---------------------------------------------------------------- 15 s gameplay clip (vertical)

## Plays a 15 s scripted fight (run, jump, punch combo, dodge, knockback) and saves every drawn
## frame as JPG in `clip` + fps.txt (frames / real seconds). tools/autoplay.sh turns it into
## gameplay.mp4; CI attaches it to the build. Watch it to see a build without installing it.
func _record_clip(ct: Node) -> void:
	DirAccess.make_dir_recursive_absolute(clip)
	var hero: Node = ct.hero
	var dummy: Node = ct.dummy
	ct.reset_dummy()
	ct.legend.visible = false                   # the clip shows the game, not the key list
	ct.legend.set_process_input(false)
	_place(hero, Vector3(1.5, 0.05, 1.0), PI)
	ct.bot_stick = Vector2.ZERO
	await _physics(10)
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var beats := [   # [seconds from start, what]
		[0.0, "run_circle"], [1.4, "toward"], [1.5, "aim"], [3.0, "punch"], [3.5, "punch"], [4.0, "punch"],
		[4.8, "jump"], [5.6, "dodge"], [6.2, "toward"], [7.2, "punch"], [7.7, "punch"], [8.2, "punch"],
		[9.0, "strafe"], [11.0, "dodge"], [11.6, "toward"], [12.4, "punch"], [12.9, "punch"], [13.4, "punch"],
		[14.2, "back"]]
	var next := 0
	var mode := "stop"
	while true:
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if t >= CLIP_SECS:
			break
		while next < beats.size() and t >= beats[next][0]:
			var what: String = beats[next][1]
			next += 1
			match what:
				"punch": ct.punch()
				"jump": hero.jump()
				"dodge": hero.act("dodge")
				"aim": hero.aim_at(dummy)
				_: mode = what
		var to_dummy: Vector3 = dummy.global_position - hero.global_position
		match mode:
			"run_circle": ct.bot_stick = Vector2(cos(t * 1.6), sin(t * 1.6)) * 0.9
			"toward": ct.bot_stick = Vector2(to_dummy.x, to_dummy.z).normalized() * 0.8 if Vector2(to_dummy.x, to_dummy.z).length() > 1.1 else Vector2.ZERO
			"back": ct.bot_stick = -Vector2(to_dummy.x, to_dummy.z).normalized() * 0.5
			"strafe": ct.bot_stick = Vector2(-to_dummy.z, to_dummy.x).normalized() * 0.7
			_: ct.bot_stick = Vector2.ZERO
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2 * 2, img.get_height() / 2 * 2)   # even size for video
		img.save_jpg(clip.path_join("f%04d.jpg" % frames), 0.85)
		frames += 1
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	ct.bot_stick = Vector2.INF
	hero.aim_at(null)
	var f := FileAccess.open(clip.path_join("fps.txt"), FileAccess.WRITE)
	f.store_string("%.3f" % (frames / secs))
	f.close()
	_check(frames >= 60 and secs >= CLIP_SECS, "CLIP PASS (%d frames over %.1f s saved for the build video)" % [frames, secs])


# ---------------------------------------------------------------- helpers

## Live tuning (DEV MENU -> TUNE): a slider moves every live node of its kind, and the value sticks.
func _tune_checks(ct: Node) -> void:
	var dm: Node = get_node("/root/DebugMenu")
	var Tune = preload("res://scripts/tune_panel.gd")
	dm.open()
	await _frames(5)
	await _click("TUNE")
	await _frames(10)
	var panel: Node = dm.tune_panel
	var sl: HSlider = panel.find_child("character3d__max_speed", true, false) if panel != null else null
	var cam_sl: HSlider = panel.find_child("camera_rig__distance", true, false) if panel != null else null
	var feel_sl: HSlider = panel.find_child("feel__stop_scale", true, false) if panel != null else null
	var was: float = ct.hero.max_speed
	if sl != null:
		sl.value = was + 1.5
	await _frames(3)
	await _shot("tune_panel")
	var moved: bool = sl != null and absf(ct.hero.max_speed - (was + 1.5)) < 0.02
	var kept: bool = Tune.saved("character3d", "max_speed") != null
	var all_kinds: bool = cam_sl != null and feel_sl != null
	var shared: bool = "character3d.max_speed" in "\n".join(Tune.changed_lines(get_tree(), dm.tune_defaults))
	await _click("RESET TO CODE VALUES")
	await _frames(3)
	_check(moved and kept and shared and all_kinds and dm.tune_panel == null
		and is_equal_approx(ct.hero.max_speed, was) and Tune.saved("character3d", "max_speed") == null,
		"TUNE PASS (live sliders for hero, camera, feel; saved, shared, reset)")


func _check(ok: bool, line: String) -> void:
	if ok:
		print(line)
	else:
		failed = true
		print("FAIL: " + line)


func _fail(step: String) -> void:
	print("AUTOPLAY FAIL " + step)
	get_tree().quit(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_scene(node_name: String) -> void:
	for i in 600:
		var s := get_tree().current_scene
		if s != null and s.name == node_name:
			await _frames(2)
			return
		await _frames(1)
	_fail("scene " + node_name)


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join("flow_%s.png" % name))


## The visible, enabled button whose text starts with `prefix` (topmost sheet wins).
func _find(prefix: String) -> Button:
	var found: Button = null
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix) and not b.is_queued_for_deletion():
			found = b
	return found


func _click(prefix: String) -> void:
	var b := _find(prefix)
	if b == null:
		_fail("no button " + prefix)
		return
	await _click_node(b)


func _click_node(c: Control) -> void:
	if c == null:
		_fail("no node")
		return
	var sc := c.get_parent()
	while sc != null and not sc is ScrollContainer:
		sc = sc.get_parent()
	if sc != null:
		(sc as ScrollContainer).ensure_control_visible(c)
		await _frames(3)
	await _tap_at(c.get_global_rect().get_center())


## A real tap at a canvas point: converted to window pixels and sent through Input.
func _tap_at(p: Vector2) -> void:
	var w := get_viewport().get_final_transform() * p
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = w
		e.global_position = w
		Input.parse_input_event(e)
		await _frames(2)



func _has_label(text: String) -> bool:
	for label in get_tree().root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text == text:
			return true
	return false
