extends CharacterBody3D
## A real-time 3D character using the full range of movement the engine supports (the house
## standard, docs/MOVEMENT_3D.md). Real skeleton, real clips, physics; nothing faked with stills.
##
##   var c := Character3D.new(); c.model_path = "res://assets/models/<id>.glb"; add_child(c)
##   c.move_input = Vector2(x, y)      # stick, any direction; length = how fast (walk -> sprint)
##   c.aim_at(target)                  # strafe: chest faces the target, legs walk any way (8-way)
##   c.jump()                          # jump / climb a ledge / vault a low wall (context)
##   c.set_crouch(true)                # crouch walk
##   c.act("punch")                    # punch, cross, hook, dodge, slide (see ACTIONS)
##   c.hit(from_pos, power)            # hit reaction: flinch, or knockback when power >= 0.5
##   c.die(impulse) / c.revive()       # physics ragdoll (or the death clip on low graphics)
## Systems a game switches on or off: can_climb, can_vault, can_swim, use_foot_ik, use_ragdoll,
## use_look_at. Models must use the shared humanoid skeleton (UE5 mannequin bone names, the
## Quaternius UAL rig) or be retargeted to it in Godot's import dock (docs/MOVEMENT_3D.md).

signal landed
signal climbed
signal hit_taken(power: float)
signal died

const MODEL_DEFAULT := "res://assets/models/ual1_standard.glb"
const EXTRA_CLIPS := {"ual2": "res://assets/models/ual2_standard.glb"}   # same skeleton, more clips
const TOON = preload("res://shaders/toon.gdshader")
const OUTLINE = preload("res://shaders/outline.gdshader")
const FootIK = preload("res://scripts/foot_ik.gd")
const AimTwist = preload("res://scripts/aim_twist.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")

## Locomotion by ground speed (m/s). Same names in every UAL model.
const LOCO := [["Idle", 0.0], ["Walk", 1.6], ["Jog_Fwd", 3.6], ["Sprint", 6.0]]
const CROUCH := [["Crouch_Idle", 0.0], ["Crouch_Fwd", 1.6]]
const SWIM := [["Swim_Idle", 0.0], ["Swim_Fwd", 2.5]]
## One-shot actions over any mode: name -> clip.
const ACTIONS := {
	"punch": "Punch_Jab", "cross": "Punch_Cross", "hook": "ual2/Melee_Hook", "dodge": "Roll",
	"slide": "ual2/Slide_Start", "hit_chest": "Hit_Chest", "hit_head": "Hit_Head",
	"knockback": "ual2/Hit_Knockback",
}
## Actions whose clip carries the body (root motion), and how much of it to use.
const ROOT_MOTION := {"knockback": 0.5, "slide": 0.6}
const DEATH := "Death01"
const MODES := ["ground", "crouch", "air", "swim", "climb"]
const BUFFER := 0.15                    # a press this early still counts (s)
const COYOTE := 0.12                    # a jump this late off an edge still counts (s)
## Live sliders in DEV MENU -> TUNE (scripts/tune_panel.gd).
const TUNE := {"max_speed": [1.0, 12.0], "accel": [4.0, 40.0], "air_control": [0.0, 1.0],
	"turn_speed": [2.0, 30.0], "jump_speed": [2.0, 10.0], "gravity": [5.0, 30.0], "crouch_speed": [0.5, 4.0]}

@export var model_path := MODEL_DEFAULT
@export var max_speed := 6.0
@export var crouch_speed := 1.8
@export var swim_speed := 2.5
@export var accel := 18.0
@export var air_control := 0.35
@export var turn_speed := 10.0          # radians/s the legs turn toward where they walk
@export var jump_speed := 5.2
@export var gravity := 14.0
@export var tint := Color(1, 1, 1)      # multiplies the model colours (recolour one model per character)
@export var rim := 0.0                  # rim light strength (hero glow); 0 = none
@export var outline_px := 3.0
@export var can_climb := true           # ledges 0.4 - 2.0 m up, on jump()
@export var can_vault := true           # thin walls 0.4 - 1.1 m, on jump()
@export var can_swim := true            # Area3D water in group "water", meta "surface" = y
@export var use_foot_ik := true
@export var use_ragdoll := true
@export var use_look_at := true
@export var hero_light := false         # a soft key light that only lights characters: always readable

var move_input := Vector2.ZERO          # x = right, y = toward the camera is +; like a stick
var aim_target: Node3D = null           # set = strafe mode (chest faces it, 8-way legs)
var look_target: Node3D = null          # head turns to it (defaults to aim_target)
var mode := "ground"
var dead := false
var crouching := false
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var tree: AnimationTree
var foot_ik: FootIK
var twist: AimTwist
var look: LookAtModifier3D
var ragdoll: PhysicalBoneSimulator3D
var heading := 0.0                      # where the legs/hips face (radians, Y axis)
var turned := 0.0                       # total turning done (tests read this)
var backpedal := false
var turning_in_place := false
var air_phase := "fall"
var time_scale := 1.0                   # hit-stop sets 0 for a few frames
var last_ledge := {}                    # what jump() found last (tests read this)
var _col: CollisionShape3D
var _cap: CapsuleShape3D
var _mats: Array[ShaderMaterial] = []
var _coyote := 0.0
var _stop_t := 0.0
var _flash := 0.0
var _climb := {}
var _buffer := {}                       # action -> seconds it stays queued
var steps := {}                         # surface -> footsteps heard (tests read this)
var _foot_up := [false, false]


func _ready() -> void:
	add_to_group("characters")
	_col = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.3
	_cap.height = 1.8
	_col.shape = _cap
	_col.position.y = 0.9
	add_child(_col)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46)
	add_to_group("tunable")
	var dm := get_node_or_null("/root/DebugMenu")
	if dm != null:
		dm.apply_tune(self)
	model = (load(model_path) as PackedScene).instantiate()
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	bind_skins(model, skeleton)
	for lib in EXTRA_CLIPS:
		if anim.has_animation_library(lib):
			continue
		var src: Node = (load(EXTRA_CLIPS[lib]) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		anim.add_animation_library(lib, ap.get_animation_library(""))
		src.free()
	_mats = apply_toon(model, tint, rim, outline_px)
	_build_tree()
	_build_modifiers()
	if hero_light:
		# Readability standard: the hero never goes black-on-black. This light only touches
		# characters (visual layer 2), so the world's mood stays as lit.
		for m in model.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).layers = 1 | 2
		var key := OmniLight3D.new()
		key.name = "HeroLight"
		key.position = Vector3(0.6, 2.4, 1.6)
		key.omni_range = 4.0
		key.light_energy = 0.9
		key.light_color = Color(1.0, 0.93, 0.82)
		key.light_cull_mask = 2
		key.shadow_enabled = false
		add_child(key)


## Swap every material on a model for toon + outline, keeping its colours/textures.
## Every skinned body mesh must follow the skeleton. An import cache left over from an older engine
## can drop that link (Godot 4.5 -> 4.6 did): the character then renders in a T-pose while its
## animation runs fine underneath. Re-link it and say so. Returns how many meshes were fixed.
static func bind_skins(root: Node, sk: Skeleton3D) -> int:
	var fixed := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.skin == null or mi.get_node_or_null(mi.skeleton) is Skeleton3D:
			continue
		mi.skeleton = mi.get_path_to(sk)
		fixed += 1
	if fixed > 0:
		push_warning("Character3D: re-linked %d mesh(es) to the skeleton (stale import? delete .godot/imported)" % fixed)
	return fixed


static func apply_toon(root: Node, tint_c: Color = Color.WHITE, rim_s: float = 0.0, outline: float = 3.0) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var t := ShaderMaterial.new()
			t.shader = TOON
			if src is BaseMaterial3D:
				t.set_shader_parameter("albedo", (src as BaseMaterial3D).albedo_color * tint_c)
				if (src as BaseMaterial3D).albedo_texture != null:
					t.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
			else:
				t.set_shader_parameter("albedo", tint_c)
			t.set_shader_parameter("rim_strength", rim_s)
			if outline > 0.0:
				var o := ShaderMaterial.new()
				o.shader = OUTLINE
				o.set_shader_parameter("width_px", outline)
				t.next_pass = o
			mi.set_surface_override_material(i, t)
			out.append(t)
	return out


# ---------------------------------------------------------------- animation tree

func _clip(clip_name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = clip_name
	return a


func _space(points: Array, top: float) -> AnimationNodeBlendSpace1D:
	var s := AnimationNodeBlendSpace1D.new()
	s.min_space = 0.0
	s.max_space = top
	for p in points:
		s.add_blend_point(_clip(p[0]), p[1])
	return s


func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.root_motion_track = NodePath("Armature/Skeleton3D:root")
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bt := AnimationNodeBlendTree.new()
	# Ground: speed blend, played backwards when backpedalling (hips face the aim, body moves back).
	bt.add_node("loco", _space(LOCO, max_speed), Vector2(0, 0))
	bt.add_node("loco_dir", AnimationNodeTimeScale.new(), Vector2(150, 0))
	bt.connect_node("loco_dir", 0, "loco")
	bt.add_node("crouch", _space(CROUCH, crouch_speed), Vector2(0, 150))
	bt.add_node("swim", _space(SWIM, swim_speed), Vector2(0, 300))
	# Air: take-off, falling loop, landing.
	var air := AnimationNodeTransition.new()
	for n in ["start", "fall", "land"]:
		air.add_input(n)
	air.xfade_time = 0.12
	bt.add_node("air", air, Vector2(150, 450))
	var start := _clip("Jump_Start")
	start.use_custom_timeline = true
	start.start_offset = 0.55          # skip the long crouch: the jump already left the ground
	start.timeline_length = 0.6
	start.loop_mode = Animation.LOOP_NONE
	bt.add_node("air_start", start, Vector2(0, 450))
	bt.add_node("air_fall", _clip("Jump"), Vector2(0, 520))
	bt.add_node("air_land", _clip("Jump_Land"), Vector2(0, 590))
	bt.connect_node("air", 0, "air_start")
	bt.connect_node("air", 1, "air_fall")
	bt.connect_node("air", 2, "air_land")
	bt.add_node("climb", _clip("ual2/ClimbUp_1m"), Vector2(0, 660))
	bt.add_node("climb_speed", AnimationNodeTimeScale.new(), Vector2(150, 660))
	bt.connect_node("climb_speed", 0, "climb")
	var modes := AnimationNodeTransition.new()
	for m in MODES:
		modes.add_input(m)
	modes.xfade_time = 0.18
	bt.add_node("mode", modes, Vector2(350, 200))
	bt.connect_node("mode", 0, "loco_dir")
	bt.connect_node("mode", 1, "crouch")
	bt.connect_node("mode", 2, "air")
	bt.connect_node("mode", 3, "swim")
	bt.connect_node("mode", 4, "climb_speed")
	var prev := "mode"
	var x := 550
	for act_name in ACTIONS:
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.08
		shot.fadeout_time = 0.15
		bt.add_node("clip_" + act_name, _clip(ACTIONS[act_name]), Vector2(x, 200))
		bt.add_node("shot_" + act_name, shot, Vector2(x, 0))
		bt.connect_node("shot_" + act_name, 0, prev)
		bt.connect_node("shot_" + act_name, 1, "clip_" + act_name)
		prev = "shot_" + act_name
		x += 200
	var alive := AnimationNodeTransition.new()
	alive.add_input("alive")
	alive.add_input("dead")
	alive.xfade_time = 0.15
	bt.add_node("death", _clip(DEATH), Vector2(x, 200))
	bt.add_node("state", alive, Vector2(x + 200, 0))
	bt.connect_node("state", 0, prev)
	bt.connect_node("state", 1, "death")
	bt.connect_node("output", 0, "state")
	tree.tree_root = bt
	tree.active = true
	# A Transition starts with no state: pick one for each, or nothing plays.
	tree.set("parameters/state/transition_request", "alive")
	tree.set("parameters/mode/transition_request", "ground")
	tree.set("parameters/air/transition_request", "fall")


func _build_modifiers() -> void:
	twist = AimTwist.new()
	twist.name = "AimTwist"
	skeleton.add_child(twist)
	if use_look_at:
		look = LookAtModifier3D.new()
		look.name = "LookAt"
		look.bone_name = "Head"
		look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
		look.primary_rotation_axis = Vector3.AXIS_Y
		look.use_angle_limitation = true
		look.symmetry_limitation = true
		look.primary_limit_angle = deg_to_rad(140)
		look.secondary_limit_angle = deg_to_rad(80)
		look.duration = 0.25
		look.influence = 0.0
		skeleton.add_child(look)
	foot_ik = FootIK.new()
	foot_ik.name = "FootIK"
	foot_ik.exclude = [get_rid()]
	skeleton.add_child(foot_ik)


# ---------------------------------------------------------------- moving

func _physics_process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 6.0)
		for m in _mats:
			m.set_shader_parameter("flash", _flash)
	if time_scale < 1.0:
		_stop_t -= dt
		if _stop_t <= 0.0:
			time_scale = 1.0
	if dead:
		if tree.active:
			tree.advance(dt)
		return
	var sdt := dt * time_scale
	for a in _buffer.keys():
		_buffer[a] -= dt
		if _buffer[a] <= 0.0:
			_buffer.erase(a)
	tree.advance(sdt)
	var rm := tree.get_root_motion_position()
	_check_water()
	match mode:
		"climb":
			_do_climb(sdt)
		"swim":
			_do_swim(sdt)
		_:
			_do_walk(sdt, rm)
	_flush_buffer()
	_footsteps()
	_update_look(dt)
	foot_ik.floor_y = global_position.y
	foot_ik.enabled_ik = use_foot_ik and is_on_floor() and mode in ["ground", "crouch"] and not is_acting("dodge")
	foot_ik.influence = 1.0 if foot_ik.enabled_ik else 0.0


func _do_walk(dt: float, rm: Vector3) -> void:
	var on_floor := is_on_floor() and velocity.y <= 0.0     # rising after a jump = not grounded
	var stick := move_input.limit_length(1.0)
	var top := crouch_speed if crouching else max_speed
	var want := Vector3(stick.x, 0, stick.y) * top
	var rm_act := _root_motion_action()
	if is_acting("dodge"):
		want = Vector3(sin(heading), 0, cos(heading)) * 4.5   # a roll carries you forward
	var k := accel * (1.0 if on_floor else air_control)
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(want, k * dt)
	if rm_act != "" and on_floor and dt > 0.0:
		# The clip moves the body: the hips' real travel, scaled, turned to where the model faces.
		var step := model.global_transform.basis * rm * float(ROOT_MOTION[rm_act])
		flat = Vector3(step.x, 0, step.z) / dt
	velocity.x = flat.x
	velocity.z = flat.z
	# Air and landing.
	if on_floor:
		_coyote = COYOTE
		if mode == "air":
			mode = "crouch" if crouching else "ground"
			_set_air("land")
			landed.emit()
		velocity.y = 0.0
		if _buffer.has("jump"):                # pressed just before landing: jump now
			_buffer.erase("jump")
			_jump_now()
	else:
		_coyote -= dt
		velocity.y -= gravity * dt
		if _coyote <= 0.0 and mode != "air":
			mode = "air"
			_set_air("fall")
	if mode == "air" and velocity.y < 0.0 and air_phase == "start":
		_set_air("fall")
	move_and_slide()
	# Facing. Strafe: legs walk toward the move (or backwards inside the aim arc), chest to aim.
	var speed_now := Vector2(velocity.x, velocity.z).length()
	var aim_h := heading
	if aim_target != null:
		var d := aim_target.global_position - global_position
		aim_h = atan2(d.x, d.z)
	var face := heading
	backpedal = false
	turning_in_place = false
	if speed_now > 0.3 and rm_act == "":
		face = atan2(flat.x, flat.z)
		if aim_target != null and absf(wrapf(face - aim_h, -PI, PI)) > deg_to_rad(110):
			face = wrapf(face + PI, -PI, PI)
			backpedal = true
	elif aim_target != null and absf(wrapf(aim_h - heading, -PI, PI)) > deg_to_rad(60):
		turning_in_place = true                # step round on the spot (real steps, not a spin)
		face = aim_h
	var diff := wrapf(face - heading, -PI, PI)
	var rate := turn_speed * (0.55 if turning_in_place else 1.0)
	var stepped := clampf(diff, -rate * dt, rate * dt)
	heading = wrapf(heading + stepped, -PI, PI)
	turned += absf(stepped)
	model.rotation.y = heading
	twist.yaw = clampf(wrapf(aim_h - heading, -PI, PI), -deg_to_rad(80), deg_to_rad(80)) if aim_target != null else 0.0
	# Feed the tree.
	var blend := speed_now
	if turning_in_place:
		blend = maxf(blend, 1.1)               # feet step while the hips come round
	if mode == "crouch":
		tree.set("parameters/crouch/blend_position", minf(blend, crouch_speed))
	else:
		tree.set("parameters/loco/blend_position", blend)
	tree.set("parameters/loco_dir/scale", -1.0 if backpedal else 1.0)
	if mode == "air":
		_set_mode("air")
	else:
		_set_mode("crouch" if crouching else "ground")


func jump() -> void:
	if dead:
		return
	if mode == "climb" or _stunned():
		_buffer["jump"] = BUFFER
		return
	if mode == "swim":
		var l := _find_ledge(true)
		last_ledge = l
		if not l.is_empty() and can_climb:
			_start_climb(l)
		return
	var ledge := _find_ledge(false)
	last_ledge = ledge
	if not ledge.is_empty():
		if (ledge.kind == "vault" and can_vault) or (ledge.kind == "climb" and can_climb):
			_start_climb(ledge)
			return
	if _coyote > 0.0 or is_on_floor():
		_jump_now()
	else:
		_buffer["jump"] = BUFFER               # still in the air: jump the moment you land


func _jump_now() -> void:
	if crouching:
		set_crouch(false)
	velocity.y = jump_speed
	_coyote = 0.0
	mode = "air"
	_set_air("start")


func set_crouch(on: bool) -> void:
	if on == crouching or dead:
		return
	if not on:
		# Only stand up when there's headroom.
		var q := PhysicsShapeQueryParameters3D.new()
		var s := CapsuleShape3D.new()
		s.radius = 0.28
		s.height = 1.7
		q.shape = s
		q.transform = Transform3D(Basis(), global_position + Vector3(0, 0.95, 0))
		q.exclude = [get_rid()]
		q.collision_mask = collision_mask
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return
	crouching = on
	_cap.height = 1.15 if on else 1.8
	_col.position.y = _cap.height * 0.5
	if mode == "ground" or mode == "crouch":
		mode = "crouch" if on else "ground"


func aim_at(t: Node3D) -> void:
	aim_target = t


# ---------------------------------------------------------------- climb, vault, swim

## Looks for a wall in front: how high its top is and whether there is floor right behind it.
func _find_ledge(from_water: bool) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var fwd := Vector3(sin(heading), 0, cos(heading))
	var base := global_position
	var ex: Array[RID] = [get_rid()]
	for h in [0.5, 1.0, 1.5]:
		var a := base + Vector3(0, h, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + fwd * 0.9, 1, ex))
		if hit.is_empty():
			continue
		var wall: Vector3 = hit.position
		var probe := wall + fwd * 0.25
		var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe + Vector3(0, base.y + 2.6 - probe.y, 0), Vector3(probe.x, base.y + 0.2, probe.z), 1, ex))
		if top.is_empty():
			return {}
		var rise: float = top.position.y - base.y
		if rise < 0.4 or rise > 2.0:
			return {}
		var t0: Vector3 = top.position
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(t0 + Vector3(0, 0.05, 0), t0 + Vector3(0, 1.8, 0), 1, ex)).is_empty():
			return {}   # no room to stand up there
		var far_at := wall + fwd * 1.0
		var far := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(far_at.x, t0.y + 0.3, far_at.z), Vector3(far_at.x, base.y - 0.6, far_at.z), 1, ex))
		var thin := not far.is_empty() and float(far.position.y) < t0.y - 0.3
		var kind := "vault" if thin and rise <= 1.1 and not from_water else "climb"
		var land: Vector3 = far.position if kind == "vault" else t0 + fwd * 0.3
		return {"kind": kind, "rise": rise, "top": t0, "wall": wall, "land": land}
	return {}


func _start_climb(l: Dictionary) -> void:
	if crouching:
		set_crouch(false)
	mode = "climb"
	_climb = l.duplicate()
	_climb.t = 0.0
	_climb.from = global_position
	_climb.dur = 0.6 if l.kind == "vault" else 0.5 + 0.3 * float(l.rise)
	velocity = Vector3.ZERO
	_col.disabled = true
	tree.set("parameters/climb_speed/scale", anim.get_animation("ual2/ClimbUp_1m").length / _climb.dur)
	_set_mode("climb")


func _do_climb(dt: float) -> void:
	# The clip's own root motion is a 1 m climb; ledges differ, so the body follows a path fitted
	# to this ledge (up first, then over) and the clip is time-scaled to the same duration.
	_climb.t += dt
	var u := clampf(_climb.t / _climb.dur, 0.0, 1.0)
	var from: Vector3 = _climb.from
	var land: Vector3 = _climb.land
	var top_y: float = _climb.top.y
	var p := from.lerp(land, smoothstep(0.35, 1.0, u))
	if _climb.kind == "vault":
		p.y = lerpf(from.y, top_y + 0.15, smoothstep(0.0, 0.5, u)) if u < 0.5 else lerpf(top_y + 0.15, land.y, smoothstep(0.5, 1.0, u))
	else:
		p.y = lerpf(from.y, top_y, smoothstep(0.0, 0.6, u))
	global_position = p
	if u >= 1.0:
		_col.disabled = false
		mode = "ground"
		_set_mode("ground")
		climbed.emit()


func _check_water() -> void:
	if not can_swim or mode == "climb":
		return
	var q := PhysicsPointQueryParameters3D.new()
	q.position = global_position + Vector3(0, 1.1, 0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var in_water := false
	var surface := 0.0
	for r in get_world_3d().direct_space_state.intersect_point(q, 8):
		if r.collider is Area3D and (r.collider as Area3D).is_in_group("water"):
			in_water = true
			surface = float((r.collider as Area3D).get_meta("surface", 0.0))
	if in_water and mode != "swim":
		mode = "swim"
		set_crouch(false)
		set_meta("surface", surface)
		_set_mode("swim")
	elif not in_water and mode == "swim":
		mode = "ground"
		_set_mode("ground")


func _do_swim(dt: float) -> void:
	var stick := move_input.limit_length(1.0)
	var want := Vector3(stick.x, 0, stick.y) * swim_speed
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(want, accel * 0.5 * dt)
	var float_y: float = float(get_meta("surface", 0.0)) - 1.35
	velocity = Vector3(flat.x, (float_y - global_position.y) * 4.0, flat.z)
	move_and_slide()
	if flat.length() > 0.3:
		var diff := wrapf(atan2(flat.x, flat.z) - heading, -PI, PI)
		var stepped := clampf(diff, -turn_speed * 0.6 * dt, turn_speed * 0.6 * dt)
		heading = wrapf(heading + stepped, -PI, PI)
		turned += absf(stepped)
		model.rotation.y = heading
	twist.yaw = 0.0
	tree.set("parameters/swim/blend_position", flat.length())


# ---------------------------------------------------------------- actions, hits, death

func act(what: String) -> void:
	if dead or not ACTIONS.has(what):
		return
	if mode == "climb" or (_stunned() and what != "dodge"):
		_buffer[what] = BUFFER                 # queued: fires the moment you're free
		return
	if what == "dodge":
		# Every action cancels into a dodge: stop whatever is playing, roll now.
		for a in ACTIONS:
			if a != "dodge" and is_acting(a):
				tree.set("parameters/shot_%s/request" % a, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		if crouching:
			set_crouch(false)
	tree.set("parameters/shot_%s/request" % what, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Knocked back: can't act (except dodge) until the clip ends. Presses made now are buffered.
func _stunned() -> bool:
	return is_acting("knockback")


func _flush_buffer() -> void:
	if mode == "climb" or _stunned() or dead:
		return
	for a in _buffer.keys():
		if a == "jump":
			if is_on_floor() or _coyote > 0.0:
				_buffer.erase(a)
				_jump_now()
		elif ACTIONS.has(a):
			_buffer.erase(a)
			act(a)


func is_acting(what: String) -> bool:
	return bool(tree.get("parameters/shot_%s/active" % what)) if tree != null else false


func _root_motion_action() -> String:
	for a in ROOT_MOTION:
		if is_acting(a):
			return a
	return ""


## Take a hit from a point in the world. power < 0.5 flinches (head or chest), >= 0.5 knocks back.
func hit(from_pos: Vector3, power := 0.3) -> void:
	if dead:
		return
	_flash = 1.0
	var feel := get_node_or_null("/root/Feel")
	hit_stop(0.06 * (feel.stop_scale if feel != null else 1.0))
	var d := from_pos - global_position
	if power >= 0.5:
		heading = atan2(d.x, d.z)          # face the hit; the clip throws you back
		model.rotation.y = heading
		act("knockback")
	else:
		act("hit_head" if from_pos.y > global_position.y + 1.3 else "hit_chest")
	hit_taken.emit(power)


## Freeze this character's animation for a moment (both sides of a hit, ~60 ms).
func hit_stop(sec: float) -> void:
	time_scale = 0.0
	_stop_t = sec


func die(impulse := Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	died.emit()
	_col.disabled = true
	velocity = Vector3.ZERO
	var low: bool = has_node("/root/Settings") and get_node("/root/Settings").get_value("low_graphics")
	if use_ragdoll and not low:
		if ragdoll == null:
			ragdoll = Ragdoll.build(skeleton)
		foot_ik.active = false
		twist.active = false
		if look != null:
			look.active = false
		tree.active = false
		ragdoll.active = true
		ragdoll.influence = 1.0
		ragdoll.physical_bones_start_simulation()
		if impulse != Vector3.ZERO:
			for b in ragdoll.get_children():
				if b is PhysicalBone3D and (b as PhysicalBone3D).bone_name in ["spine_02", "pelvis"]:
					(b as PhysicalBone3D).apply_central_impulse(impulse)
	else:
		tree.set("parameters/state/transition_request", "dead")


func revive() -> void:
	if ragdoll != null:
		ragdoll.physical_bones_stop_simulation()
		ragdoll.active = false
	dead = false
	_col.disabled = false
	tree.active = true
	foot_ik.active = true
	twist.active = true
	if look != null:
		look.active = true
	tree.set("parameters/state/transition_request", "alive")


func is_ragdoll() -> bool:
	return ragdoll != null and ragdoll.is_simulating_physics()


# ---------------------------------------------------------------- helpers

func speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## A footstep each time a foot comes down (from the animation itself), sound picked by the
## surface under it: StaticBody3D meta "surface" ("stone", "wood", "grass", "water"...).
func _footsteps() -> void:
	if mode != "ground" and mode != "crouch" or not is_on_floor() or speed() < 0.4:
		return
	var feet := ["foot_l", "foot_r"]
	for i in 2:
		var y := skeleton.get_bone_global_pose(skeleton.find_bone(feet[i])).origin.y
		if y > 0.16:
			_foot_up[i] = true
		elif y < 0.125 and _foot_up[i]:
			_foot_up[i] = false
			var surface := "stone"
			var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(feet[i])).origin
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.6, 1 | 2, [get_rid()]))
			if not hit.is_empty() and hit.collider is Object and (hit.collider as Object).has_meta("surface"):
				surface = str((hit.collider as Object).get_meta("surface"))
			steps[surface] = int(steps.get(surface, 0)) + 1
			var audio := get_node_or_null("/root/Audio")
			if audio != null:
				audio.step(surface)


func _set_mode(m: String) -> void:
	if tree.get("parameters/mode/current_state") != m:
		tree.set("parameters/mode/transition_request", m)


func _set_air(p: String) -> void:
	air_phase = p
	tree.set("parameters/air/transition_request", p)


func _update_look(dt: float) -> void:
	if look == null:
		return
	var t := look_target if look_target != null else aim_target
	look.target_node = look.get_path_to(t) if t != null else NodePath()
	look.influence = move_toward(look.influence, 1.0 if t != null else 0.0, dt * 4.0)
