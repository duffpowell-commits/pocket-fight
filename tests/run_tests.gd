extends SceneTree
## Rule tests, headless: godot --headless --path . --script tests/run_tests.gd
## Last line is "ALL PASS (N)" or "FAILED k of N". Add a test_* function for every rule.
## A new test only counts once you've seen it fail (break the code, watch it go red, restore).

const Config = preload("res://scripts/config.gd")
const UI = preload("res://scripts/ui.gd")
const Updater = preload("res://scripts/updater.gd")
const BugReport = preload("res://scripts/bug_report.gd")

var n := 0
var bad := 0


func _initialize() -> void:
	await process_frame   # autoloads are ready after the first frame
	for m in get_method_list():
		if m.name.begins_with("test_"):
			n += 1
			var before := bad
			await call(m.name)
			print(("ok   " if bad == before else "FAIL ") + m.name)
	print("ALL PASS (%d)" % n if bad == 0 else "FAILED %d of %d" % [bad, n])
	quit(1 if bad > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
		print("  failed: " + what)


func test_save_roundtrip() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://test_run.json"
	save.clear()
	check(not save.exists(), "no save at start")
	check(save.write({"level": 3, "score": 27, "lives": 1}), "write ok")
	var d: Dictionary = save.read()
	check(int(d.get("level")) == 3 and int(d.get("score")) == 27, "same values back")
	check(int(d.get("_version")) == save.VERSION, "version stamped")
	save.clear()
	check(not save.exists(), "cleared")
	save.path = "user://run.json"


func test_corrupt_save_is_ignored() -> void:
	var save: Node = root.get_node("Save")
	save.path = "user://test_bad.json"
	var f := FileAccess.open(save.path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(save.read().is_empty(), "garbage save reads as empty, no crash")
	save.clear()
	save.path = "user://run.json"


func test_settings_defaults_and_persist() -> void:
	var s: Node = root.get_node("Settings")
	s.reset_for_tests()
	for k in ["music", "sfx", "vibration", "gamma", "text_size", "invert_y", "sensitivity",
			"low_graphics", "left_handed", "subtitles", "high_contrast", "colorblind"]:
		check(s.DEFAULTS.has(k), "setting exists: " + k)
	s.set_value("music", 0.25)
	s.values["music"] = 0.9
	s.load_settings()
	check(absf(float(s.get_value("music")) - 0.25) < 0.001, "music volume saved to disk")
	var bus := AudioServer.get_bus_index("Music")
	check(bus > 0, "Music bus exists at boot")
	check(AudioServer.get_bus_index("SFX") > 0, "SFX bus exists at boot")
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.1, "music slider moves the bus")
	s.reset_for_tests()
	s.save_settings()


func test_text_scale_steps() -> void:
	var s: Node = root.get_node("Settings")
	s.values["text_size"] = 3
	check(UI.font_size(20) > 20, "large text is larger")
	s.values["text_size"] = 1
	check(UI.font_size(20) == 20, "normal is unchanged")


func test_colorblind_swaps_key_colors() -> void:
	var s: Node = root.get_node("Settings")
	s.values["colorblind"] = false
	var a := UI.key("good")
	s.values["colorblind"] = true
	check(UI.key("good") != a, "colorblind palette differs")
	s.values["colorblind"] = false


func test_touch_targets() -> void:
	check(UI.MIN_TOUCH >= 62, "min touch >= 48dp (~62 base units)")
	var b := UI.button("X")
	check(b.custom_minimum_size.y >= UI.MIN_TOUCH, "buttons use the minimum")
	b.free()


func test_updater_compare() -> void:
	check(Updater.is_newer(5, 4), "newer build offered")
	check(not Updater.is_newer(4, 4), "same build not offered")
	check(not Updater.is_newer(9, 0), "editor build (0) never offered")


func test_config_paths() -> void:
	check(Config.apk_name().ends_with(".apk"), "apk name")
	check(Config.release_url().begins_with("https://github.com/") and Config.release_url().ends_with("/releases/download/dev/"), "release url")


func test_bug_report_text() -> void:
	var t := BugReport.report_text("it broke", self)
	check(t.begins_with("it broke"), "note first")
	check("build:" in t and "device:" in t, "build + device added")
	check(BugReport.issue_url(t).contains("/issues/new?"), "issue link")


# ---------------------------------------------------------------- house standards (GROK_STANDARDS.md)

## 11. Every game action works on keyboard AND gamepad, and remaps survive a restart.
func test_controls_keyboard_and_pad() -> void:
	var c: Node = root.get_node("Controls")
	for a in c.ACTIONS:
		var has_key := false
		var has_pad := false
		for e in InputMap.action_get_events(a):
			has_key = has_key or e is InputEventKey
			has_pad = has_pad or c.is_pad(e)
		check(has_key and has_pad, a + " has a key and a pad input")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_G
	c.rebind("attack", k)
	var fresh: Node = load("res://scripts/controls.gd").new()
	fresh._load()
	check(fresh._custom.has("attack") and (fresh._custom.attack.key as InputEventKey).physical_keycode == KEY_G, "remap saved and loaded")
	fresh.free()
	c.reset()
	check(not InputMap.action_has_event("attack", k), "reset restores defaults")


## 9 + 12. Stats stay on the phone unless the player opts in AND an endpoint is set; a run that
## didn't close cleanly is spotted next launch.
func test_telemetry_offline_and_crash_flag() -> void:
	var t: Node = root.get_node("Telemetry")
	check(not t.allowed(), "nothing is sent by default")
	var before: int = t.events().size()
	t.event("unit_test", {"x": 1})
	check(t.events().size() == before + 1, "event kept locally")
	var f := FileAccess.open(t.RUN_FLAG, FileAccess.WRITE)
	f.store_string("Game v0.1.0")
	f = null
	var fresh: Node = load("res://scripts/telemetry.gd").new()
	root.add_child(fresh)
	check(fresh.crashed_last_run, "unclean exit detected")
	fresh.clean_exit()
	check(not FileAccess.file_exists(t.RUN_FLAG), "clean exit clears the flag")
	fresh.queue_free()
	var http := 0
	for n in root.find_children("*", "HTTPRequest", true, false):
		if t.is_ancestor_of(n):
			http += 1
	check(http == 0, "no network request without consent")


## 8. Portable assets: every model is glTF on the standard humanoid skeleton and listed in SOURCES.
func test_models_portable() -> void:
	var sources := FileAccess.get_file_as_string("res://assets/models/SOURCES.md")
	var d := DirAccess.open("res://assets/models")
	var count := 0
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".md"):
			continue
		count += 1
		check(f.ends_with(".glb") or f.ends_with(".gltf"), f + " is glTF")
		check(f in sources, f + " listed in SOURCES.md")
		var scene: Node = (load("res://assets/models/" + f) as PackedScene).instantiate()
		var sk := scene.find_children("*", "Skeleton3D", true, false)
		check(sk.size() == 1, f + " has one skeleton")
		if sk.size() == 1:
			for b in ["pelvis", "spine_01", "Head", "thigh_l", "calf_l", "foot_l", "upperarm_r", "hand_r"]:
				check((sk[0] as Skeleton3D).find_bone(b) >= 0, f + " has bone " + b)
			_check_model_scale(f, scene as Node3D, sk[0] as Skeleton3D)
		scene.free()
	check(count > 0, "models found")


## Normalised import: 1 unit = 1 m, root scale 1, feet on y = 0, same facing as the mannequin
## (glTF +Z forward; Character3D turns it). Catches 100x centimetre roots and floating feet.
func _check_model_scale(f: String, root: Node3D, sk: Skeleton3D) -> void:
	check(root.scale.is_equal_approx(Vector3.ONE), f + " root scale is 1")
	var xf := Transform3D.IDENTITY
	var n: Node = sk
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var head := (xf * sk.get_bone_global_rest(sk.find_bone("Head"))).origin
	var foot := (xf * sk.get_bone_global_rest(sk.find_bone("foot_l"))).origin
	var toe_i := sk.find_bone("ball_l")
	var toe := (xf * sk.get_bone_global_rest(toe_i)).origin if toe_i >= 0 else foot
	check(head.y > 1.2 and head.y < 2.2, f + " is human height in metres (head at %.2f)" % head.y)
	check(minf(toe.y, foot.y) > -0.05 and minf(toe.y, foot.y) < 0.12, f + " feet on y = 0 (%.2f)" % minf(toe.y, foot.y))
	check(toe_i < 0 or toe.z > foot.z, f + " faces +Z like the mannequin")


## Texture imports are explicit: colour maps are sRGB and never normal maps; only *_n / *_normal
## files may be normal maps. (Godot's "detect" setting can flip a colour map to a normal map.)
func test_texture_imports_explicit() -> void:
	for path: String in _files("res://assets", [".png.import", ".jpg.import", ".jpeg.import", ".webp.import"]):
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		var base: String = path.get_file().get_basename().get_basename()
		var is_normal: bool = base.ends_with("_n") or base.ends_with("_normal")
		var nm: int = cfg.get_value("params", "compress/normal_map", 0)
		check(nm == (1 if is_normal else 2), "%s normal_map is %s (set it, don't detect)" % [path, "on" if is_normal else "off"])


func _files(dir: String, ends: Array) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		for e in ends:
			if f.ends_with(e):
				out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub, ends))
	return out


## Phone textures: 3D textures import as ETC2/ASTC (the VRAM formats Android phones read directly).
func test_mobile_texture_compression() -> void:
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false),
		"ETC2/ASTC texture compression is on for phones")


## Atlases: a sheet + json made by tools/pack_atlas.py hands back the right piece.
func test_atlas_regions() -> void:
	var Atlas = preload("res://scripts/atlas.gd")
	var t: AtlasTexture = Atlas.tex("res://tests/fixtures/atlas_demo", "coin")
	check(t != null and t.region == Rect2(26, 0, 16, 16), "coin region read from the json")
	if t != null:
		var c := t.atlas.get_image().get_pixel(26 + 8, 8)
		check(c.r > 0.85 and c.g > 0.7 and c.b < 0.3, "coin pixel is gold (%s)" % c)
	check(Atlas.names("res://tests/fixtures/atlas_demo").size() == 3, "three images in the sheet")
	check(Atlas.tex("res://tests/fixtures/atlas_demo", "coin") == t, "atlas pieces are cached")


## Quality tiers: LOW sets low graphics + a smaller 3D render, HIGH undoes it, the pick is saved.
func test_quality_tiers() -> void:
	var Q = preload("res://scripts/quality.gd")
	var st: Node = root.get_node_or_null("Settings")
	check(st != null, "Settings autoload present")
	if st == null:
		return
	Q.apply(self, 0)
	check(st.get_value("low_graphics") == true and st.get_value("tier") == 0 and is_equal_approx(root.scaling_3d_scale, 0.7), "LOW applies")
	Q.apply(self, 2)
	check(st.get_value("low_graphics") == false and st.get_value("tier") == 2 and is_equal_approx(root.scaling_3d_scale, 1.0), "HIGH applies")
	check(Q.NAMES.size() == 3 and Q.SCALE.size() == 3, "three tiers")


## The rulebook stays split: every standards/ file is listed in the GROK_STANDARDS.md index,
## every link in the index exists, and no topic file grows past 60 lines (load only what you need).
func test_standards_index() -> void:
	var index := FileAccess.get_file_as_string("res://GROK_STANDARDS.md")
	check(index.length() > 0, "GROK_STANDARDS.md index exists")
	var d := DirAccess.open("res://standards")
	check(d != null, "standards/ folder exists")
	if d == null:
		return
	var count := 0
	for f in d.get_files():
		if not f.ends_with(".md"):
			continue
		count += 1
		check(("standards/" + f) in index, f + " is listed in the index")
		var lines := FileAccess.get_file_as_string("res://standards/" + f).split("\n").size()
		check(lines <= 60, "%s is short (%d lines)" % [f, lines])
	check(count >= 10, "topic files present")
	for m in RegEx.create_from_string("\\((standards/[^)]+)\\)").search_all(index):
		check(FileAccess.file_exists("res://" + m.get_string(1)), m.get_string(1) + " exists")


## Your own music: GAME MUSIC off mutes only the Music bus; sound effects keep playing. On iPhone
## the game mixes with other apps' audio. (Android: Godot never grabs audio focus, so Spotify etc.
## keep playing; never add a plugin that does.)
func test_play_your_own_music() -> void:
	var s: Node = root.get_node("Settings")
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	s.set_value("game_music", false)
	check(AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(sfx), "GAME MUSIC off mutes music only")
	s.set_value("game_music", true)
	check(not AudioServer.is_bus_mute(music), "GAME MUSIC on brings it back")
	check(ProjectSettings.get_setting("audio/general/ios/mix_with_others", false), "iPhone mixes with other apps' music")


## Battery saver: paused/menu/idle = 30 fps, background = 5 fps + low-processor, play = full speed.
func test_battery_saver_states() -> void:
	var b: Node = root.get_node("Battery")
	b.set_state("saver")
	check(Engine.max_fps == 30, "saver caps at 30 fps")
	b.set_state("background")
	check(Engine.max_fps == 5 and OS.low_processor_usage_mode, "background drops to 5 fps, low-processor mode")
	b.set_state("play")
	check(Engine.max_fps == 60 and not OS.low_processor_usage_mode, "play is full speed")


## 7. Coach hints are short (no text walls).
func test_coach_hints_short() -> void:
	var re := RegEx.create_from_string('Coach\\.teach\\([^,]+,\\s*"[^"]+",\\s*"([^"]+)"')
	for f in ["res://scripts/character_test.gd", "res://scripts/game.gd"]:
		if not FileAccess.file_exists(f):
			continue
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			check(m.get_string(1).split(" ", false).size() <= 4, "hint '%s' is 4 words or fewer" % m.get_string(1))


func test_tune_saves_applies_and_reports() -> void:
	var Tune = preload("res://scripts/tune_panel.gd")
	var feel: Node = root.get_node("Feel")
	var dm: Node = root.get_node("DebugMenu")
	Tune.clear()
	check(feel.is_in_group("tunable") and "feel" in Tune.kinds(self), "Feel is tunable")
	check(dm.tune_defaults.get("feel.shake_scale") == 1.0, "code value remembered")
	Tune.save_value("feel", "shake_scale", 2.0)
	feel.shake_scale = 1.0
	Tune.apply(feel)
	check(is_equal_approx(feel.shake_scale, 2.0), "saved value applied")
	var lines: PackedStringArray = Tune.changed_lines(self, dm.tune_defaults)
	check("feel.shake_scale = 2.0 (code 1.0)" in lines, "changed value reported: %s" % [lines])
	check("labels=tuning" in Tune.share_url("x"), "share link files a tuning issue")
	Tune.clear()
	feel.shake_scale = 1.0
	check(Tune.saved("feel", "shake_scale") == null, "reset clears saved values")


# ---------------------------------------------------------------- Wildmade: monsters + the test fight

const Monster = preload("res://scripts/monster.gd")
const Duel = preload("res://scripts/duel.gd")


## A design is always complete and valid, whatever was saved or typed.
func test_monster_clean_repairs_anything() -> void:
	var d: Dictionary = Monster.clean({"body": "Nope", "ears": "Long", "chub": 7, "name": "  A very long name indeed  ", "junk": 1})
	check(d["body"] == Monster.PARTS["body"][0] and d["ears"] == "Long", "bad part falls back, good part kept")
	check(is_equal_approx(d["chub"], 1.0), "slider clamped to 0..1")
	check(d["name"].length() <= Monster.NAME_MAX and d["name"] == d["name"].strip_edges(), "name trimmed")
	check(not d.has("junk") and d.size() == Monster.PARTS.size() + Monster.SHAPE.size() + 1, "only known fields")
	check(Monster.clean("garbage") == Monster.fresh() and Monster.clean(null) == Monster.fresh(), "garbage -> the default monster")
	check(Monster.clean({"color": "Snow", "accent": "Snow"})["accent"] != "Snow", "markings never match the body colour")
	check(Monster.clean(d) == d, "cleaning twice changes nothing")


func test_monster_surprise_is_valid_and_varied() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen := {}
	for i in 60:
		var d: Dictionary = Monster.surprise(rng)
		check(Monster.clean(d) == d, "surprise %d is a valid design" % i)
		seen[JSON.stringify(d)] = true
	check(seen.size() >= 55, "surprises differ (%d of 60 unique)" % seen.size())


## A monster comes back from the save file (JSON) exactly as it went in, sliders included.
func test_monster_survives_the_save_file() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lost := 0
	for i in 300:
		var d: Dictionary = Monster.surprise(rng)
		if Monster.clean(JSON.parse_string(JSON.stringify(d))) != d:
			lost += 1
	check(lost == 0, "%d of 300 monsters changed on a save round trip" % lost)


## Describe it: typed words become parts; unknown words are reported, not guessed.
func test_monster_from_text() -> void:
	var r: Dictionary = Monster.from_text("A fat blue cat with horns, no tail and white spots named Gus!")
	var d: Dictionary = r["design"]
	check(d["color"] == "Lake" and d["accent"] == "Snow", "first colour = body, second = markings")
	check(d["ears"] == "Pointy" and d["top"] == "Horns", "cat ears and horns together")
	check(d["tail"] == "None", "'no tail' beats the cat's tail")
	check(d["marks"] == "Spots" and is_equal_approx(d["chub"], 1.0) and d["name"] == "Gus", "spots, fat, named Gus")
	check(r["missed"].is_empty(), "nothing missed: %s" % [r["missed"]])
	r = Monster.from_text("grumpy zorp dragon")
	check(r["missed"] == ["zorp"] and r["design"]["mood"] == "Grumpy" and r["design"]["back"] == "Wings", "unknown word reported, the rest used")
	check(Monster.from_text("blue fox")["design"]["color"] == "Lake" and Monster.from_text("fox")["design"]["color"] == "Rust",
		"a typed colour beats the animal's usual colour")
	# Changing the current monster only touches what the words mention.
	var base: Dictionary = Monster.clean({"body": "Slink", "color": "Plum", "name": "Pip", "back": "Spikes"})
	var c: Dictionary = Monster.from_text("with wings", base)["design"]
	check(c["back"] == "Wings" and c["body"] == "Slink" and c["color"] == "Plum" and c["name"] == "Pip", "only the named part changed")
	check(Monster.from_text("zzz qqq")["heard"].is_empty(), "nonsense is not understood")
	for w in Monster.WORDS:
		for k in Monster.WORDS[w]:
			if k == "_color":
				check(Monster.COLORS.has(Monster.WORDS[w][k]), "word '%s' names a real colour" % w)
			elif k in Monster.SHAPE:
				check(typeof(Monster.WORDS[w][k]) == TYPE_FLOAT, "word '%s' sets slider %s with a number" % [w, k])
			else:
				check(Monster.PARTS.has(k) and Monster.WORDS[w][k] in Monster.PARTS[k], "word '%s' sets a real part (%s)" % [w, k])


## Animals get their own face: a wolf has a snout, a dragon a long one, a cat a flat face.
func test_monster_snouts() -> void:
	check(Monster.PARTS.has("snout") and Monster.PARTS["snout"][0] == "Flat", "snout is a part; flat is the default")
	if not Monster.PARTS.has("snout"):
		return
	check(Monster.from_text("black wolf")["design"]["snout"] == "Snout", "wolf has a snout")
	check(Monster.from_text("red dragon")["design"]["snout"] == "Long", "dragon has a long snout")
	check(Monster.from_text("fat bear")["design"]["snout"] == "Muzzle", "bear has a muzzle")
	var wolf: Dictionary = Monster.from_text("wolf")["design"]
	check(Monster.from_text("cat", wolf)["design"]["snout"] == "Flat", "changing a wolf into a cat flattens the face")
	check(Monster.from_text("cat with a long snout")["design"]["snout"] == "Long", "an asked-for snout beats the animal's")
	var old: Dictionary = Monster.fresh()
	old.erase("snout")
	check(Monster.clean(old)["snout"] == "Flat", "a save from before snouts loads with a flat face")


## The test fight's rules (carried over from the prototype's own check).
func test_duel_rules() -> void:
	var s := Duel.new("Splash")
	s.reset()
	check(not s.can("Move"), "no move on a wind-up turn")
	s.play("Attack")
	check(s.enemy_hp == s.max_hp - s.basic_damage and s.player_hp == s.max_hp and s.charging, "attack hits; the strike is next")
	s.play("Move")
	check(s.player_hp == s.max_hp and s.enemy_hp == s.max_hp - s.basic_damage - s.splash_damage, "Splash cancels the strike and chips")
	check(s.cooldown == s.cooldown_turns, "the move rests")
	s.play("Attack")
	check(not s.can("Move") and s.charging, "still resting on the next strike")
	s.play("Guard")
	check(s.player_hp == s.max_hp - s.strike_damage / 2, "Guard halves the strike")
	var c := Duel.new("Climb")
	c.reset()
	c.play("Attack")
	c.play("Move")
	check(c.player_hp == c.max_hp and c.attack_damage() == c.basic_damage + c.climb_bonus, "Climb dodges and powers the next attack")
	c.play("Attack")
	check(c.attack_damage() == c.basic_damage, "the bonus is spent")
	# Mashing Attack must lose; playing the strike turns must win. Otherwise Guard and the move are decoration.
	for move in ["Splash", "Climb"]:
		var mash := Duel.new(move)
		mash.reset()
		while not mash.over():
			mash.play("Attack")
		check(not mash.won(), "%s: attack-only loses" % move)
		var smart := Duel.new(move)
		smart.reset()
		while not smart.over():
			smart.play(("Move" if smart.can("Move") else "Guard") if smart.charging else "Attack")
		check(smart.won() and smart.player_hp >= smart.max_hp / 3, "%s: smart play wins with HP to spare (%d)" % [move, smart.player_hp])
	var g := Duel.new("Splash")
	g.god = true
	g.reset()
	g.play("Attack")
	g.play("Attack")
	check(g.player_hp == g.max_hp, "god mode takes no damage")
