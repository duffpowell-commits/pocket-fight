extends Node3D
## The house 3D camera: smooth follow with look-ahead, frames a second target (pulls back to keep
## both on screen), never clips through walls (cuts in front of them), and shakes on impacts.
##   var rig := CameraRig.new(); add_child(rig); rig.follow = hero; rig.frame_target = enemy
##   rig.add_trauma(0.4)      # impact shake (Feel.impact does this for you)
## Fixed high three-quarter angle by default; a game changes pitch/distance, not the behaviour.

@export var pitch_deg := 50.0
@export var distance := 7.5
@export var look_ahead := 0.35        # seconds of velocity the camera leads by
@export var smooth := 6.0             # 1/s; higher = tighter follow
@export var frame_extra := 0.55       # extra distance per metre between hero and frame_target
@export var frame_max := 6.0          # never pull back more than this (m)
@export var wall_mask := 1            # what the camera may not pass through
@export var wall_margin := 0.35
@export var fov := 45.0
## Live sliders in DEV MENU -> TUNE (scripts/tune_panel.gd).
const TUNE := {"pitch_deg": [20.0, 85.0], "distance": [3.0, 16.0], "look_ahead": [0.0, 1.0],
	"smooth": [1.0, 20.0], "fov": [25.0, 80.0]}

var follow: Node3D
var frame_target: Node3D
var cam: Camera3D
var trauma := 0.0                     # 0..1, decays; shake = trauma^2
var blocked := false                  # last frame a wall pushed the camera in (tests read this)
var _noise := FastNoiseLite.new()
var _t := 0.0
var _base := Vector3.ZERO


func _ready() -> void:
	add_to_group("camera_rig")
	add_to_group("tunable")
	var dm := get_node_or_null("/root/DebugMenu")
	if dm != null:
		dm.apply_tune(self)
	cam = Camera3D.new()
	cam.fov = fov
	cam.current = true
	add_child(cam)
	_noise.frequency = 2.0
	snap()


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


## Cut straight to the wanted spot (after a teleport or a scene start).
func snap() -> void:
	if follow == null:
		return
	_base = _desired()
	_base = _unclip(_focus(), _base)
	_apply(0.0)


func _focus() -> Vector3:
	var v := Vector3.ZERO
	if follow is CharacterBody3D:
		v = (follow as CharacterBody3D).velocity
	var f := follow.global_position + Vector3(v.x, 0, v.z) * look_ahead + Vector3(0, 1.0, 0)
	if frame_target != null and is_instance_valid(frame_target):
		f = f.lerp(frame_target.global_position + Vector3(0, 1.0, 0), 0.5)
	return f


func _dist() -> float:
	var d := distance
	if frame_target != null and is_instance_valid(frame_target):
		d += minf(follow.global_position.distance_to(frame_target.global_position) * frame_extra, frame_max)
	return d


func _dir() -> Vector3:
	var p := deg_to_rad(pitch_deg)
	return Vector3(0, sin(p), cos(p))


func _desired() -> Vector3:
	return _focus() + _dir() * _dist()


## Walls between the hero and the camera: put the camera just in front of them.
func _unclip(from: Vector3, to: Vector3) -> Vector3:
	var ex: Array[RID] = []
	for c in get_tree().get_nodes_in_group("characters"):
		if c is CollisionObject3D:
			ex.append((c as CollisionObject3D).get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, wall_mask, ex))
	blocked = not hit.is_empty()
	if blocked:
		return hit.position + (from - to).normalized() * wall_margin
	return to


func _process(dt: float) -> void:
	if follow == null or not is_instance_valid(follow):
		return
	_t += dt
	var want := _desired()
	_base = _base.lerp(want, 1.0 - exp(-smooth * dt))
	_base = _unclip(_focus(), _base)        # never smoothed through a wall
	trauma = maxf(0.0, trauma - dt * 1.6)
	_apply(dt)


func _apply(_dt: float) -> void:
	cam.fov = fov
	var s := trauma * trauma
	var off := Vector3(_noise.get_noise_2d(_t * 40.0, 0), _noise.get_noise_2d(0, _t * 40.0), 0) * 0.35 * s
	cam.global_position = _base + off
	cam.look_at(_focus(), Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, _noise.get_noise_2d(_t * 40.0, 99) * 0.05 * s)
