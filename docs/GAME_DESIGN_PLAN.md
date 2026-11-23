# Pocket Fight — Game brief and first playable

## The pitch

Design yourself and hatch a monster you made. Then see what the two of you can do together. Pocket Fight is a single-player HD 2D RPG with hand-drawn sprites, a fixed three-quarter camera, and encounters with more than one solution.

**Core loop:** Create your duo → explore → use both characters’ abilities to solve an encounter → grow together. Later, what you do together can unlock evolution options. The player chooses whether and how the starter evolves.

## Two creators, one workflow

| | Player character | Starter monster |
|---|---|---|
| Look | Face, skin tone, hair, outfit, colors, marks, accessories | Body shape, proportions, face, ears, markings, colors, optional tail |
| Gameplay choice | Background and field skill | Signature move and temperament |
| First playable | One humanoid base, two backgrounds | Round and long-legged bases, with tail and no-tail options |

Each creator has a close-up preview and an exploration-scale preview. Start by hand, describe the design, or select a photo or sketch. A reference suggests supported parts, colors, and proportions. The player can combine reference and text, change every suggestion, and confirm the design. When the input is unclear, leave the choice for the player. A tailless reference can produce a tailless draft.

Use one shared editor shell and separate part catalogs. Keep appearance and gameplay selections in separate save fields. Set safe adjustment ranges per body and define where parts attach and which layers cover them. Show the selected move in the preview. Splash can use a tail slap, paw slap, or belly-flop. All versions share the same effect, timing, and range. Background selection is explicit, so clothing and personal features carry no gameplay assumptions.

## First playable — The Flooded Mill

A worker is stuck on a raised platform. The lower room is flooded, a sluice is jammed, and a territorial creature patrols the water.

| Route | Player contribution | Starter contribution |
|---|---|---|
| Sluice | Mechanic frees the jammed gears | Splash draws the patrol away from the mechanism |
| Rafters | Climber anchors a rope from a reachable ledge | Climb crosses a broken stretch of beam and carries the rope across |

Both routes reach the worker and end at the same exit. Make hazards readable before committing. If a duo lacks a route skill, the player can return to the entry and use a slower service passage. The rescue should reward the chosen abilities without trapping a player for a creator decision.

**Proposed encounter format:** Real-time movement and field actions for the rescue, with one small turn-based fight to test command selection, feedback, and the shared Splash effect. Prototype the fight before committing to a broader combat system.

## Build order

| Milestone | Deliverable | Done when |
|---|---|---|
| 1. Creator prototype | Godot 4 project, touch-friendly manual editors, two previews, local saves | Both designs survive a restart. A tailless monster previews Splash correctly. Parts remain aligned in idle and walk. |
| 2. Playable mill | Graybox routes, patrol, one short encounter, rescue completion and restart | Both routes and the mixed-loadout fallback are playable from a fresh save. The chosen player and monster appear in the mill. |
| 3. Art and Android build | Hand-drawn mill and layered sprite parts, creator and encounter polish, Android test build | Touch controls, basic readability, saves, and both routes pass a phone playtest. Check sprite alignment while walking and using moves. |
| 4. Prompt and reference drafts | Text input and Android image picker for both creators | Both inputs produce editable, validated drafts. Cancel, invalid input, and unavailable analysis leave manual editing usable and preserve the current design. |

Milestones 1–3 are the first playable. Milestone 4 adds the full creator experience once the manual workflow and art pipelines are proven. If analysis uses a remote service, ask before sending an image and save the resulting design choices locally. Keep reference images out of the game save.

## Scope and decisions to revisit

- Start with HD 2D sprites and environments. Use one animation set per base body and attachment layers for swappable parts. Draw dedicated poses for actions where the silhouette matters.
- Draft art for the player base, both monster silhouettes, and the mill camera angle before expanding the part catalog.
- Test combat pacing and how expressive the base bodies feel before investing in more body shapes, evolution, or a larger world. Full 3D can be revisited after the slice.
- Milestone 1 starts with placeholder parts. Final character art and combat rules are still open for review.
