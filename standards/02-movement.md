# Movement: the full range the engine supports

**Rule:** characters use the full range of movement the current engine supports: real skeletons,
real animation clips, real physics. **Never fake movement** by bobbing, tilting, squashing or
sliding a still image. **Motion comes only from animation clips** (a CC0 library on the shared
skeleton): no hand-coded limb tweens, no sine waves on bones or meshes. A move with no animation
clip doesn't exist yet; placeholder = the stand-in mannequin doing the real clip.

Keep it portable so it survives an engine change:
- One **standard humanoid skeleton** for every character: UE5 mannequin bone names (`pelvis`,
  `spine_01..03`, `neck_01`, `Head`, `thigh_l`, `calf_l`, `foot_l`, `upperarm_r`, `hand_r`...).
- Models and clips in **glTF 2.0 (`.glb`)**, FBX only as a fallback. List every model/clip pack and
  its licence in `assets/models/SOURCES.md`.
- Movement numbers (speeds, jump height, timings) live as plain constants at the top of the
  character script.
- Characters under ~5k triangles each so several fit on a phone.
- **Normalise every imported model:** 1 unit = 1 metre, root scale 1 (watch for 100x centimetre
  roots), feet on y = 0, facing the same way as the template mannequin (glTF +Z forward; the
  character script turns it). Check: `test_models_portable` asserts height, feet and facing.

What "full range" means today (all must work for any game that has 3D characters):
- Locomotion: idle, walk, jog, sprint in any direction; stick length = speed.
- 8-way / strafe: chest faces the target while legs walk any direction; backpedal.
- Turn in place with real steps. Jump with take-off, fall and land. Crouch (won't stand under a roof).
- Foot IK: feet planted on slopes, stairs and kerbs; hips drop to reach.
- Look-at: head turns to the target.
- Hit reactions: flinch, and knockback driven by the clip's root motion.
- Physics ragdoll on death (an animated death on LOW graphics).
- Climb ledges (also out of water), vault low walls, swim. Each switchable per game.

Godot today: `scripts/character3d.gd` (`Character3D`) plus `foot_ik.gd`, `aim_twist.gd`,
`ragdoll.gd`, `LookAtModifier3D`; clips from Quaternius Universal Animation Library 1 + 2 (CC0, one
skeleton). Playground: `scenes/character_test.tscn`. Details: `docs/MOVEMENT_3D.md`.
Checks: MOVE360, LIMBS, SKIN, FOOTIK, JUMP, CROUCH, TURN, LOOKAT, STRAFE, BACKPEDAL, ACTION, KNOCKBACK,
DODGE, CLIMB, VAULT, SWIM, SWIMOUT, RAGDOLL, INK.
