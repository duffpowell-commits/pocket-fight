## Builds a physics ragdoll for the shared humanoid skeleton, in code (11 bodies, no self-collision).
## Made on first death only, so living characters cost nothing. Character3D calls this.

const LAYER := 4                     # physics layer 3: ragdoll bodies
const MASK := 1 | 2                  # collide with the world (body floors + feet floors)

## bone, the bone it points to, radius, mass, joint (0 cone, 1 hinge)
const PARTS := [
	["pelvis", "spine_02", 0.14, 10.0, 0],
	["spine_02", "neck_01", 0.15, 10.0, 0],
	["Head", "", 0.12, 4.0, 0],
	["upperarm_l", "lowerarm_l", 0.06, 2.0, 0],
	["lowerarm_l", "hand_l", 0.05, 1.5, 1],
	["upperarm_r", "lowerarm_r", 0.06, 2.0, 0],
	["lowerarm_r", "hand_r", 0.05, 1.5, 1],
	["thigh_l", "calf_l", 0.08, 6.0, 0],
	["calf_l", "foot_l", 0.06, 4.0, 1],
	["thigh_r", "calf_r", 0.08, 6.0, 0],
	["calf_r", "foot_r", 0.06, 4.0, 1],
]


static func build(sk: Skeleton3D) -> PhysicalBoneSimulator3D:
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	sk.add_child(sim)
	var scale := sk.global_transform.basis.get_scale().y
	for p in PARTS:
		var id := sk.find_bone(p[0])
		if id < 0:
			continue
		var g := sk.get_bone_global_rest(id)
		var tip: Vector3
		if p[1] != "":
			tip = g.affine_inverse() * sk.get_bone_global_rest(sk.find_bone(p[1])).origin
		else:
			tip = g.affine_inverse().basis * (sk.global_transform.affine_inverse().basis * Vector3.UP).normalized() * (0.22 / scale)
		var length := tip.length()
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + p[0]
		pb.bone_name = p[0]
		pb.mass = p[3]
		pb.collision_layer = LAYER
		pb.collision_mask = MASK
		pb.friction = 0.8
		pb.linear_damp = 0.4
		pb.angular_damp = 2.0
		# Capsule along the bone, centred halfway to the next joint.
		var axis := tip.normalized()
		var basis := Basis(Quaternion(Vector3.UP, axis)) if axis.length() > 0.5 else Basis()
		pb.body_offset = Transform3D(basis, tip * 0.5)
		pb.joint_offset = Transform3D(Basis(), -Vector3(0, length * 0.5, 0))
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE if p[4] == 1 else PhysicalBone3D.JOINT_TYPE_CONE
		if p[4] == 1:
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_upper", 0.0)
			pb.set("joint_constraints/angular_limit_lower", -140.0)
		else:
			pb.set("joint_constraints/swing_span", 50.0)
			pb.set("joint_constraints/twist_span", 30.0)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		var r: float = p[2] / scale
		cap.radius = r
		cap.height = maxf(length, r * 2.0 + 0.001)
		col.shape = cap
		pb.add_child(col)
		sim.add_child(pb)
	return sim
