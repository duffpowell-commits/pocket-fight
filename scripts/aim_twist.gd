extends SkeletonModifier3D
## Upper/lower body split: legs walk where you move, the spine twists so the chest faces where you
## aim. Spread over the three spine bones so it bends, not snaps. `yaw` is set by Character3D.

const SPINE := ["spine_01", "spine_02", "spine_03"]

var yaw := 0.0                       # radians the chest turns from the hips (+ = left)
var _ids := []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or absf(yaw) < 0.001:
		return
	if _ids.is_empty():
		for n in SPINE:
			_ids.append(sk.find_bone(n))
	var up_s := (sk.global_transform.affine_inverse().basis * Vector3.UP).normalized()
	var q := Quaternion(up_s, yaw / SPINE.size())
	for id in _ids:
		var t := sk.get_bone_global_pose(id)
		sk.set_bone_global_pose(id, Transform3D(Basis(q) * t.basis, t.origin))
