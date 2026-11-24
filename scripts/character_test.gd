extends Node3D
## 3D CHARACTER TEST (dev menu): the full-movement standard working end to end (docs/MOVEMENT_3D.md).
## A playground with a slope, stairs, a ledge to climb, a low wall to vault and a pool to swim in.
## Hero = UAL mannequin with the orange rim; dummy = same model and skeleton, recoloured.
## Left half: floating stick (any direction, push further = faster). Right: JUMP (climbs/vaults at a
## wall), PUNCH (3 in a row = hook, knocks back), DODGE, CROUCH, AIM (strafe facing the dummy).
## Keyboard: WASD/arrows, Space jump, J punch, K dodge, C crouch, L aim. Camera: fixed high
## three-quarter (50 degrees down), follows with look-ahead, never rotates.

const UI = preload("res://scripts/ui.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Coach = preload("res://scripts/coach.gd")
const ControlsLegend = preload("res://scripts/controls_legend.gd")
const Character3D = preload("res://scripts/character3d.gd")
const TOON = preload("res://shaders/toon.gdshader")

const WORLD := 1 | 2              # body floors + feet floors
const FEET := 2                   # only feet (visual steps); bodies use the hidden ramp
const COMBO_GAP := 0.8

var hero: Character3D
var dummy: Character3D
var rig: CameraRig
var sun: DirectionalLight3D
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var stick_down := false
var bot_stick := Vector2.INF     # the autoplay bot steers through this when set
var stick_area: Control
var ui: CanvasLayer
var legend: PanelContainer
var combo := 0
var combo_t := 0.0
var _landed_on := ""            # the swing that already landed (one hit per swing)
var _dummy_spawn := Vector3(0, 0, -2.5)


func _ready() -> void:
	var settings: Node = get_node("/root/Settings")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1b1f2a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("5b6175")
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = not settings.get_value("low_graphics")
	add_child(sun)
	_build_world()
	hero = Character3D.new()
	hero.rim = 1.4
	hero.hero_light = true
	add_child(hero)
	dummy = Character3D.new()
	dummy.tint = Color(0.75, 0.35, 0.35)
	dummy.position = _dummy_spawn
	add_child(dummy)
	rig = CameraRig.new()
	rig.follow = hero
	add_child(rig)
	rig.snap()
	_build_ui()
	var audio := get_node("/root/Audio")
	audio.music_layers("music_loop", "music_combat")
	audio.set_intensity(0.0)
	if get_tree().root.get_meta("perf_test", false):
		get_tree().root.remove_meta("perf_test")
		perf_test.call_deferred()


# ---------------------------------------------------------------- the playground

func _build_world() -> void:
	var floor_c := Color("3a4256")
	# Floor in four pieces round the pool (x -9..-4, z -10..-5).
	_box(Vector3(-20, -1, -20), Vector3(20, 0, -10), floor_c)   # floors default to "stone"
	_box(Vector3(-20, -1, -5), Vector3(20, 0, 20), floor_c)
	_box(Vector3(-20, -1, -10), Vector3(-9, 0, -5), floor_c)
	_box(Vector3(-4, -1, -10), Vector3(20, 0, -5), floor_c)
	_box(Vector3(-9, -3.2, -10), Vector3(-4, -2.2, -5), Color("2a3346"))       # pool bottom
	var water := Area3D.new()
	water.add_to_group("water")
	water.set_meta("surface", -0.3)
	water.collision_layer = 8
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(5, 1.9, 5)
	ws.shape = wb
	ws.position = Vector3(-6.5, -1.25, -7.5)
	water.add_child(ws)
	add_child(water)
	var wm := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(5, 5)
	wm.mesh = wp
	wm.position = Vector3(-6.5, -0.3, -7.5)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.25, 0.55, 0.85, 0.35)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.material_override = wmat
	add_child(wm)
	# Slope: 15 degrees up toward -z, then a deck.
	var ramp := _box(Vector3(-1.25, -0.1, -2.5), Vector3(1.25, 0.1, 2.5), Color("7a5a3a"))
	ramp.set_meta("surface", "wood")
	ramp.position = Vector3(5, 0.55, -3)          # near edge flush with the floor
	ramp.rotation.x = deg_to_rad(15)
	_box(Vector3(3.75, 0, -8.5), Vector3(6.25, 1.3, -5.4), Color("4a5168"))
	# Stairs up toward -x: visual steps for the feet, a hidden ramp for the body.
	for i in 8:
		var x0 := -2.0 - i * 0.35
		_box(Vector3(x0 - 0.35, 0, 2), Vector3(x0, 0.18 * (i + 1), 4), Color("7a5a3a"), FEET).set_meta("surface", "wood")
	_box(Vector3(-7.6, 0, 2), Vector3(-4.8, 1.44, 4), Color("7a5a3a")).set_meta("surface", "wood")
	# Grass patch, and a tall wall the camera must not see through.
	_box(Vector3(-3, 0, 6), Vector3(3, 0.02, 10), Color("3f6b3a")).set_meta("surface", "grass")
	_box(Vector3(-14, 0, 4), Vector3(-10, 6, 4.4), Color("4a5168"))
	var stair_ramp := StaticBody3D.new()
	stair_ramp.collision_layer = 1
	var sr := CollisionShape3D.new()
	var srb := BoxShape3D.new()
	srb.size = Vector3(2.95, 0.05, 2)
	sr.shape = srb
	stair_ramp.add_child(sr)
	stair_ramp.position = Vector3(-3.4, 0.72, 3)
	stair_ramp.rotation.z = -atan2(1.44, 2.8)
	add_child(stair_ramp)
	# Ledge to climb (1 m) and a thin wall to vault (0.8 m).
	_box(Vector3(-1.5, 0, -9), Vector3(1.5, 1.0, -7), Color("6a5a48"))
	_box(Vector3(8, 0, 1.5), Vector3(10.5, 0.8, 1.8), Color("6a5a48"))


func _box(a: Vector3, b: Vector3, c: Color, layer: int = WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = (a + b) * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (b - a).abs()
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	mi.material_override = m
	body.add_child(mi)
	add_child(body)
	return body


## Cut the camera to the hero (after a teleport).
func snap_camera() -> void:
	rig.snap()


func _process(dt: float) -> void:
	var v := Vector2.ZERO
	if bot_stick != Vector2.INF:
		v = bot_stick
	elif stick_down:
		v = stick_vec
	else:
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")   # keys + pad stick
	hero.move_input = v.limit_length(1.0)
	rig.frame_target = dummy if hero.aim_target != null else null
	# Music: explore layer, crossfading to the combat layer near a live enemy.
	var near := not dummy.dead and hero.global_position.distance_to(dummy.global_position) < 4.0
	get_node("/root/Audio").set_intensity(1.0 if near or hero.aim_target != null else 0.0)
	if Coach.seen("move") and not Coach.seen("punch") and not has_node("UI/Root/Coach_punch"):
		Coach.teach($UI/Root, "punch", "TAP PUNCH", func(): return hero.is_acting("punch"))
	combo_t -= dt
	# A punch lands if it reaches: close, in front, mid-swing. The dummy flinches or is knocked back.
	var swing := ""
	for a in ["hook", "cross", "punch"]:          # newest swing first: combos overlap
		if hero.is_acting(a):
			swing = a
			break
	if swing != _landed_on:
		_landed_on = ""
	if swing != "" and _landed_on == "" and not dummy.dead:
		var to := dummy.global_position - hero.global_position
		var fwd := Vector3(sin(hero.heading), 0, cos(hero.heading))
		if to.length() < 1.5 and fwd.dot(to.normalized()) > 0.5:
			_landed_on = swing
			dummy.hit(hero.global_position + Vector3(0, 1.2, 0), 0.6 if swing == "hook" else 0.3)
			hero.hit_stop(0.06)                # the attacker freezes too: hit-stop sells the impact
			get_node("/root/Feel").impact(dummy.global_position + Vector3(0, 1.3, 0), 0.6 if swing == "hook" else 0.3, self)
	stick_area.queue_redraw()


# ---------------------------------------------------------------- frame budget

## Budgets a 3D scene must stay under (GROK_STANDARDS.md #3). CI checks these numbers on every
## push (they don't depend on the GPU); the PHONE SPEED TEST checks real fps on the phone.
const TARGET_FPS := 60
const BUDGET := {"draw_calls": 250, "primitives": 300000, "cpu_ms": 8.0}   # cpu = physics step + game code

var perf_result := {}


## A typical fight: hero + 3 others on screen (2 extra runners + the dummy) for `secs` running laps for `secs`, then shows the numbers.
## In the dev menu: PHONE SPEED TEST. Pass on the phone = average >= 58 fps, 1% low >= 45.
func perf_test(secs: float = 10.0, show := true) -> Dictionary:
	var crowd: Array[Character3D] = []
	for i in 2:
		var c := Character3D.new()
		c.tint = Color.from_hsv(0.1 * i + 0.5, 0.5, 0.9)
		c.position = Vector3(-4 + i * 2.5, 0, -1)
		add_child(c)
		crowd.append(c)
	var frames: Array[float] = []
	var calls := 0.0
	var prims := 0.0
	var cpu := 0.0
	var n := 0
	var t := 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	while t < secs:
		var dt := get_process_delta_time()
		t += dt
		for i in crowd.size():
			crowd[i].move_input = Vector2(cos(t * 1.3 + i), sin(t * 1.3 + i))
		bot_stick = Vector2(cos(t), sin(t)) * 0.7
		await get_tree().process_frame
		frames.append(dt)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	bot_stick = Vector2.INF
	for c in crowd:
		c.queue_free()
	frames.sort()
	var avg_dt := 0.0
	for f in frames:
		avg_dt += f
	avg_dt /= maxf(frames.size(), 1)
	var low_dt: float = frames[int(frames.size() * 0.99)] if frames.size() > 0 else 1.0
	perf_result = {
		"fps": 1.0 / maxf(avg_dt, 0.0001), "low_fps": 1.0 / maxf(low_dt, 0.0001),
		"draw_calls": calls / n, "primitives": prims / n, "cpu_ms": cpu / n,
	}
	perf_result["budget_ok"] = perf_result.draw_calls <= BUDGET.draw_calls and perf_result.primitives <= BUDGET.primitives and perf_result.cpu_ms <= BUDGET.cpu_ms
	perf_result["phone_ok"] = perf_result.fps >= TARGET_FPS - 2 and perf_result.low_fps >= 45
	get_node("/root/Telemetry").event("perf_test", perf_result)
	if show:
		var box := UI.sheet(self, 460)
		box.add_child(UI.label("SPEED TEST: " + ("PASS" if perf_result.phone_ok and perf_result.budget_ok else "FAIL"), 28, UI.key("good" if perf_result.phone_ok else "bad")))
		box.add_child(UI.label("%d fps average, %d fps worst 1%%\n%d draw calls, %dk triangles, %.1f ms code" % [
			perf_result.fps, perf_result.low_fps, perf_result.draw_calls, perf_result.primitives / 1000.0, perf_result.cpu_ms], 20))
		box.add_child(UI.button("DONE", func(): UI.close_sheet(box)))
	return perf_result


func punch() -> void:
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = COMBO_GAP
	hero.act(["punch", "cross", "hook"][(combo - 1) % 3])


func toggle_aim() -> void:
	hero.aim_at(null if hero.aim_target != null else dummy)


func toggle_crouch() -> void:
	hero.set_crouch(not hero.crouching)


func reset_dummy() -> void:
	dummy.revive()
	dummy.global_position = _dummy_spawn


func _unhandled_input(e: InputEvent) -> void:
	# Actions, not keys: works with keyboard, gamepad and the player's remaps (Controls autoload).
	if e.is_action_pressed("jump"):
		hero.jump()
	elif e.is_action_pressed("attack"):
		punch()
	elif e.is_action_pressed("dodge"):
		hero.act("dodge")
	elif e.is_action_pressed("crouch"):
		toggle_crouch()
	elif e.is_action_pressed("aim"):
		toggle_aim()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_X:
		reset_dummy() if dummy.dead else dummy.die(Vector3(0, 2, -6))


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	ui.name = "UI"
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	ui.add_child(root)
	legend = ControlsLegend.make(["move_up", "jump", "attack", "dodge", "crouch", "aim", "pause"])
	legend.name = "Legend"
	root.add_child(legend)
	var left: bool = get_node("/root/Settings").get_value("left_handed")
	stick_area = Control.new()
	stick_area.anchor_left = 0.5 if left else 0.0
	stick_area.anchor_right = 1.0 if left else 0.5
	stick_area.anchor_bottom = 1.0
	stick_area.offset_top = 120
	stick_area.gui_input.connect(_stick_input)
	stick_area.draw.connect(_draw_stick)
	root.add_child(stick_area)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UI.GAP)
	col.anchor_left = 0.0 if left else 1.0
	col.anchor_right = col.anchor_left
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = 24 if left else -24 - 180
	col.offset_right = col.offset_left + 180
	col.offset_top = -40 - 5 * 84 - 4 * UI.GAP
	col.offset_bottom = -40
	col.add_child(UI.button("JUMP", hero.jump, 84))
	col.add_child(UI.button("PUNCH", punch, 84))
	col.add_child(UI.button("DODGE", func(): hero.act("dodge"), 84))
	col.add_child(UI.button("CROUCH", toggle_crouch, 84))
	col.add_child(UI.button("AIM", toggle_aim, 84))
	root.add_child(col)
	var back := UI.button("BACK", func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	back.anchor_left = 0.0
	back.offset_left = 24
	back.offset_right = 24 + 150
	back.offset_top = 30
	back.offset_bottom = 30 + UI.MIN_TOUCH
	root.add_child(back)
	Coach.teach(root, "move", "DRAG TO MOVE", func(): return hero.speed() > 1.0)


func _stick_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		stick_down = e.pressed
		stick_origin = e.position
		stick_vec = Vector2.ZERO
	elif e is InputEventMouseMotion and stick_down:
		stick_vec = ((e.position - stick_origin) / 90.0).limit_length(1.0)


func _draw_stick() -> void:
	if not stick_down:
		return
	stick_area.draw_circle(stick_origin, 90, Color(1, 1, 1, 0.08))
	stick_area.draw_arc(stick_origin, 90, 0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
	stick_area.draw_circle(stick_origin + stick_vec * 90, 36, Color(UI.ACCENT, 0.7))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")


func bug_state() -> String:
	return "3d test: hero %s mode %s speed %.1f aim %s dead %s" % [hero.global_position, hero.mode, hero.speed(), hero.aim_target != null, hero.dead]
