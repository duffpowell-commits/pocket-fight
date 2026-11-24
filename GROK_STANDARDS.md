# Game Standards: the index (for any coding AI: Grok, Claude, Copilot, anyone)

Owner: Duff. The rules for every Duff game repo, split into small files so you load only what a
task needs. **Start at the repo's AGENTS.md**: it is the source of truth for that repo's commands,
standing rules and first-step setup (`git config core.hooksPath .githooks`), and it points here.
Why (Nov 21): one rulebook every agent loads, instead of rules split across files only some agents read.
**Always read `standards/00-core.md`.** Then read only the files your task touches.

| Read this | When the task is about |
|---|---|
| [standards/00-core.md](standards/00-core.md) | Always: how Duff works, tech rules, what "done" means |
| [standards/01-new-game.md](standards/01-new-game.md) | Starting a game; what the template already has (Milestone 0) |
| [standards/02-movement.md](standards/02-movement.md) | Characters, animation, skeletons, importing models |
| [standards/03-feel-and-haptics.md](standards/03-feel-and-haptics.md) | Hits, combat feel, vibration |
| [standards/04-camera.md](standards/04-camera.md) | The camera |
| [standards/05-performance.md](standards/05-performance.md) | Frame rate, graphics quality, textures, atlases, loading |
| [standards/06-controls.md](standards/06-controls.md) | Input, touch/keyboard/gamepad, remapping, controls legend |
| [standards/07-look-and-audio.md](standards/07-look-and-audio.md) | Lighting, readability, sound, music |
| [standards/08-first-minute.md](standards/08-first-minute.md) | Boot, intro, teaching the controls |
| [standards/09-art-assets.md](standards/09-art-assets.md) | Art, textures, Foxboard, asset sources |
| [standards/10-telemetry-offline.md](standards/10-telemetry-offline.md) | Stats, crash reports, network, accounts |
| [standards/11-build-release.md](standards/11-build-release.md) | CI, signing key, APK, dev release, engine version |
| [standards/12-testing.md](standards/12-testing.md) | The autoplay bot, rule tests, before-push checks |
| [standards/13-finished-quality.md](standards/13-finished-quality.md) | Reference slice, phone-size review, new-player test, release-candidate playtest |

If a repo's AGENTS.md (or README/CLAUDE.md) says something more specific, that wins for that repo.

**Copying:** copy this file and the whole `standards/` folder, unchanged, into any game repo. The
master copy lives in `duffpowell-commits/godot-game-starter`. Change rules there, then re-sync.
