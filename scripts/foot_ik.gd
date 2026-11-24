extends SkeletonModifier3D
## Foot IK: plants each foot on the real ground (slopes, stairs, kerbs) after the animation runs.
## Rays down from each foot; the hips drop so the lower foot can reach; a two-bone solve bends the
## knee toward where the animation already had it. Cheap: 2 rays + a little maths per character.

const LEGS := [["thigh_l", "calf_l", "foot_l"], ["thigh_r", "calf_r", "foot_r"]]
const PELVIS := "pelvis"

@export var ray_mask := 2            # physics layer 2 = "feet" (floors, steps, slopes)
@export var max_drop := 0.45         # how far the hips may sink to reach a low foot (m)
@export var max_raise := 0.45        # how high a foot may be lifted onto a step (m)
@export var smooth := 14.0           # 1/s; how fast hips and feet settle

var exclude: Array[RID] = []
var floor_y := 0.0                   # character's own floor height (set by Character3D each frame)
var enabled_ik := true
var last_error := [0.0, 0.0]         # |foot - ground| after the solve, per foot (tests read this)
var _hip := 0.0
var _off := [0.0, 0.0]
var _ids := []


func _process_modification_with_delta(dt: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _ids.is_empty():
		for l in LEGS:
			_ids.append([sk.find_bone(l[0]), sk.find_bone(l[1]), sk.find_bone(l[2])])
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var space := sk.get_world_3d().direct_space_state
	var want := [0.0, 0.0]
	var normals := [Vector3.UP, Vector3.UP]
	var feet_w := []
	for i in 2:
		var foot_w: Vector3 = xf * sk.get_bone_global_pose(_ids[i][2]).origin
		feet_w.append(foot_w)
		if not enabled_ik:
			continue
		var q := PhysicsRayQueryParameters3D.create(foot_w + Vector3.UP * (max_raise + 0.3), foot_w + Vector3.DOWN * (max_drop + 0.3), ray_mask, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		want[i] = clampf(hit.position.y - floor_y, -max_drop, max_raise)
		normals[i] = hit.normal
	var k := clampf(dt * smooth, 0.0, 1.0)
	for i in 2:
		_off[i] = lerpf(_off[i], want[i], k)
	_hip = lerpf(_hip, minf(0.0, minf(want[0], want[1])), k)
	var up_s := (inv.basis * Vector3.UP).normalized()
	var p_id := sk.find_bone(PELVIS)
	var p := sk.get_bone_global_pose(p_id)
	p.origin += up_s * _hip / xf.basis.get_scale().y
	sk.set_bone_global_pose(p_id, p)
	for i in 2:
		var target_w: Vector3 = feet_w[i] + Vector3.UP * _off[i]
		_two_bone(sk, _ids[i], inv * target_w, inv.basis * normals[i])
		var got: Vector3 = xf * sk.get_bone_global_pose(_ids[i][2]).origin
		last_error[i] = got.distance_to(target_w)


static func _two_bone(sk: Skeleton3D, ids: Array, t: Vector3, normal_s: Vector3) -> void:
	var ta := sk.get_bone_global_pose(ids[0])
	var tb := sk.get_bone_global_pose(ids[1])
	var tc := sk.get_bone_global_pose(ids[2])
	var a := ta.origin
	var b := tb.origin
	var c := tc.origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var d := clampf(a.distance_to(t), 0.01, l1 + l2 - 0.001)
	var dir := (t - a).normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole.length() < 0.0001:
		pole = Vector3.FORWARD
	var knee := a + dir * along + pole.normalized() * h
	var q1 := Quaternion((b - a).normalized(), (knee - a).normalized())
	var nta := Transform3D(Basis(q1) * ta.basis, a)
	sk.set_bone_global_pose(ids[0], nta)
	var c1 := a + q1 * (c - a)
	var q2 := Quaternion((c1 - knee).normalized(), (t - knee).normalized())
	sk.set_bone_global_pose(ids[1], Transform3D(Basis(q2 * q1) * tb.basis, knee))
	# Foot keeps its animated angle, tilted to the ground under it.
	var up_s := (sk.global_transform.affine_inverse().basis * Vector3.UP).normalized()
	var tilt := Quaternion(up_s, normal_s.normalized()) if normal_s.length() > 0.5 else Quaternion()
	sk.set_bone_global_pose(ids[2], Transform3D(Basis(tilt) * tc.basis, t))
