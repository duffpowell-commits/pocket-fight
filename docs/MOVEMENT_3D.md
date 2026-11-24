# Full range of movement (house standard for every game with 3D characters)

## The rule (engine-proof)
**Characters use the full range of movement the current engine supports.** Real skeletons, real
animation clips, real physics. Never fake movement with bobbing, tilting or sliding stills.

This holds in any engine (Godot today; Unity or Unreal later). What changes per engine is only the
implementation list below. To keep characters portable:
- One **standard humanoid skeleton** for every character (UE5 mannequin bone names: `pelvis`,
  `spine_01..03`, `thigh_l`, `foot_l`, `Head`...). Unity's Humanoid and Unreal's IK Retargeter both
  map it; Godot maps it with `SkeletonProfileHumanoid`.
- **Portable formats:** models and clips as glTF 2.0 (`.glb`), FBX as a fallback. No engine-only
  formats as the source. Source art lives in Foxboard (docs/ART.md).
- Movement rules (speeds, ranges, timings) are plain numbers at the top of the character script, so
  they can be copied to another engine.
- A move with no clip doesn't exist yet. Placeholder = the mannequin doing the real clip.

## What "full range" means today (Godot 4.6, Compatibility renderer, phones)
| Area | Built in | How |
|---|---|---|
| Locomotion | idle, walk, jog, sprint, any direction | BlendSpace1D by real ground speed; stick length = speed |
| Strafe / 8-way | chest on target, legs walk any way, backpedal | upper/lower body split: legs face the move, `AimTwist` turns the spine up to 80 deg; behind you = walk clip played backwards |
| Turn in place | hips step round when the target is > 60 deg off | walk clip at step speed while the hips rotate |
| Jump | take-off, fall loop, land | coyote time 0.12 s; landing sets the land clip |
| Crouch | crouch idle/walk, shorter capsule, won't stand under a roof | |
| Foot IK | feet planted on slopes, stairs, kerbs; hips drop to reach | `scripts/foot_ik.gd`, two-bone solve, 2 rays per character |
| Look-at / aim | head turns to a target | `LookAtModifier3D` on `Head` |
| Hit reactions | flinch (head/chest), knockback | knockback uses the clip's own root motion; hit-stop + flash |
| Root motion | where the clip should move the body | knockback, slide (`ROOT_MOTION` in character3d.gd) |
| Death | physics ragdoll (11 bodies) | `scripts/ragdoll.gd`, built on first death only; death clip on low graphics |
| Climb | ledges 0.4 - 2.0 m, also out of water | `jump()` at a wall; path fitted to the ledge, ClimbUp clip time-scaled |
| Vault | thin walls 0.4 - 1.1 m with floor behind | `jump()` at a wall |
| Swim | float, swim idle/forward | `Area3D` in group `water`, meta `surface` = water height |
| Actions | punch, cross, hook, dodge roll, slide | OneShots over any mode (`ACTIONS`) |

Switch systems per game: `can_climb`, `can_vault`, `can_swim`, `use_foot_ik`, `use_ragdoll`,
`use_look_at`. Physics layers: 1 = bodies' floors, 2 = feet's floors (steps, slopes), 3 = ragdoll,
4 = water. Stairs: visual steps on layer 2 (feet), a hidden ramp on layer 1 (body).

## The pieces
| Piece | Where |
|---|---|
| Character | `scripts/character3d.gd` (`Character3D`): CharacterBody3D + model + AnimationTree built in code |
| Skeleton + clips | `assets/models/ual1_standard.glb` + `ual2_standard.glb` (Quaternius UAL 1 + 2, CC0, same 65-bone rig; UAL2 is the root-motion export) |
| Modifiers | `scripts/foot_ik.gd`, `scripts/aim_twist.gd`, `scripts/ragdoll.gd`, Godot's `LookAtModifier3D` |
| Look | `shaders/toon.gdshader` (bands, rim, hit flash), `shaders/outline.gdshader` (ink, constant px) |
| Playground | `scenes/character_test.tscn` (dev menu -> 3D CHARACTER TEST): slope, stairs, ledge, wall, pool, dummy |
| Proof | `scripts/autoplay.gd`: MOVE360, LIMBS, FOOTIK SLOPE/STAIRS, JUMP, CROUCH, TURN, LOOKAT, STRAFE, BACKPEDAL, ACTION, KNOCKBACK, DODGE, CLIMB, VAULT, SWIM, SWIMOUT, RAGDOLL, INK |

## Clips available (one skeleton)
UAL1: Idle, Walk, Walk_Formal, Jog_Fwd, Sprint, Crouch_Idle, Crouch_Fwd, Jump_Start, Jump,
Jump_Land, Roll, Punch_Jab, Punch_Cross, Sword_Idle, Sword_Attack, Hit_Chest, Hit_Head, Death01,
Interact, PickUp_Table, Push, Sitting_*, Swim_Idle, Swim_Fwd, Pistol_*, Spell_Simple_*, Dance...
UAL2 (in code as `ual2/<name>`): ClimbUp_1m, Hit_Knockback, Melee_Hook, Slide_*, NinjaJump_*,
Sword_Regular_A/B/C + combos, Sword_Block, Sword_Dash, Shield_*, OverhandThrow, Walk_Carry,
Zombie_*, Farm_*, Chest_Open, Consume, LayToIdle...
**Not in the free packs:** a kick and side-step strafe clips. Strafe works via the body split
above; a game that wants dedicated strafe/kick clips adds a pack on the same skeleton and lists it
in `assets/models/SOURCES.md`.

## How a character moves (API)
```
var c := Character3D.new(); c.model_path = "res://assets/models/<id>.glb"; add_child(c)
c.move_input = Vector2(x, y)   # stick; length = speed
c.aim_at(target)               # strafe + look; aim_at(null) to stop
c.jump()                       # jump, or climb/vault/climb-out at a wall
c.set_crouch(true)
c.act("punch")                 # punch, cross, hook, dodge, slide
c.hit(from_pos, power)         # < 0.5 flinch, >= 0.5 knockback; flash + hit-stop built in
c.hit_stop(0.06)               # freeze the attacker too
c.die(impulse) / c.revive()
signals: landed, climbed, hit_taken(power), died
```

## New character (keep the skeleton, swap the body)
1. Humanoid in T- or A-pose, **under ~5k triangles** (phones), one material or a small palette.
2. Rig to the UE5 mannequin names (Mixamo-style rigs work too, see 3). Export glTF.
3. Normalise it: 1 unit = 1 m, root scale 1, feet on y = 0, facing +Z like the mannequin
   (`test_models_portable` checks). Drop the `.glb` in `assets/models/`. Other bone names: Import dock -> Skeleton3D -> Retarget ->
   Bone Map -> `SkeletonProfileHumanoid` (same profile on the UAL files) so every clip plays on it.
4. `Character3D.new()`, set `model_path`, `tint`, `rim` (hero only).
5. Autoplay must still pass LIMBS, FOOTIK and INK with it.
The mannequin is ~13.7k tris: fine for a few on screen, replace it for crowds.

## Look, camera, controls
- Toon: 3 light bands, shadows never darker than `shade_floor` 0.35. Ink outline 3 px on every
  character. Warm rim light on the hero only. Hit flash white for a blink.
- Camera: fixed high three-quarter, ~50 degrees down, ~7.5 m back, follows with look-ahead.
- Floating stick on one half (90 px = full speed); JUMP / PUNCH / DODGE / CROUCH / AIM on the other
  thumb, >= 72 units tall, 18 apart. Left-handed swaps the halves. Keyboard: WASD, Space, J, K, C, L.

## Phone budget
Per character: 1 AnimationTree, 2 foot rays, 2 cheap modifiers. Ragdoll bodies exist only after a
death. `low_graphics` swaps the ragdoll for the death clip and turns off shadows.
