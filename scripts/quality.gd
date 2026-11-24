extends RefCounted
## Graphics quality tier: LOW / MEDIUM / HIGH. Picked once on first launch by a short GPU test
## (boot splash, ~0.5 s), saved in Settings "tier", changeable in Settings -> GRAPHICS.
## Games read Settings "low_graphics" (true on LOW) and may read "tier" for finer choices.
##   LOW    = low_graphics on (no shadows, particles trimmed, death clip instead of ragdoll), 3D at 70 %
##   MEDIUM = full effects, 3D at 85 %
##   HIGH   = full effects, 3D at 100 %

const NAMES := ["LOW", "MEDIUM", "HIGH"]
const SCALE := [0.7, 0.85, 1.0]        # 3D render scale per tier (UI always stays sharp)
const FAST_MS := 9.0                   # test frame under this = HIGH
const OK_MS := 18.0                    # under this = MEDIUM, else LOW
const CUBES := 300
const BUDGET_MS := 500.0               # the test never takes longer than this (after 2 warm-up frames)

static var last_ms := 0.0              # the test's average frame time (shown in bug reports)


## Apply a tier now and save it.
static func apply(tree: SceneTree, tier: int) -> void:
	tier = clampi(tier, 0, 2)
	var s: Node = tree.root.get_node("Settings")
	s.set_value("tier", tier)
	s.set_value("low_graphics", tier == 0)
	tree.root.scaling_3d_scale = SCALE[tier]


## Re-apply the saved tier (boot does this every launch).
static func restore(tree: SceneTree) -> void:
	var t: int = tree.root.get_node("Settings").get_value("tier")
	if t >= 0:
		tree.root.scaling_3d_scale = SCALE[t]


## First launch: draw a small lit 3D scene off-screen for a few frames, time it, pick a tier.
## Returns the tier. Cheap phones with few cores are capped at MEDIUM.
static func pick(parent: Node) -> int:
	var tree := parent.get_tree()
	var vp := SubViewport.new()
	vp.size = Vector2i(270, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	parent.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 14)
	cam.rotation.x = -0.4
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation = Vector3(-0.9, 0.5, 0)
	vp.add_child(sun)
	var mm := MultiMeshInstance3D.new()
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.mesh = SphereMesh.new()
	m.instance_count = CUBES
	for i in CUBES:
		m.set_instance_transform(i, Transform3D(Basis(), Vector3((i % 20) - 10, 0, -(i / 20))))
	mm.multimesh = m
	vp.add_child(mm)
	for i in 2:                                   # warm up (shader compile)
		await RenderingServer.frame_post_draw
	# Up to 12 frames, but never longer than BUDGET_MS: a slow phone is LOW anyway, and boot must
	# stay under 10 s (standard 7).
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while frames < 12 and (frames < 2 or Time.get_ticks_usec() - t0 < BUDGET_MS * 1000):
		await RenderingServer.frame_post_draw
		frames += 1
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0 / frames
	vp.queue_free()
	var tier := 2 if last_ms < FAST_MS else (1 if last_ms < OK_MS else 0)
	if OS.get_processor_count() <= 4:
		tier = mini(tier, 1)
	apply(tree, tier)
	return tier
