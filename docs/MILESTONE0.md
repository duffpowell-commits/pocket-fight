# Milestone 0: what's already built

Moved out of CLAUDE.md on Nov 21 (lean harness): CLAUDE.md loads into every session, this list doesn't need to.

1. Repo files: this CLAUDE.md, QUEUE.md, docs/PITCH.md, docs/style-guide.md, tasks/todo.md + lessons.md.
2. CI (`.github/workflows/build.yml`): parse every script (with autoloads), rule tests, autoplay
   flow, signed APK; on main uploads the APK + version.json to the `dev` release.
3. One signing key for every game except Lethemoor, the **keystone** (Nov 20): `signing/keystone.keystore.enc` + `keystone.sha256`, `KEYSTONE_PASS` secret, made once by `make_keystone.yml`; `signing/unlock.sh` picks the key in CI (docs/SIGNING.md). Lethemoor keeps its own key: never sign another game with it.
4. In-app updater (`scripts/updater.gd`) + version number on the title (`v0.1.<build>`).
5. REPORT A BUG on title + pause (`scripts/bug_report.gd`): GitHub issue or copy-to-text, build/device/state added.
6. Scene flow: boot -> intro (once, skippable) -> title -> game -> pause -> GAME OVER -> title.
   Pauses + saves when the app loses focus (call, home button); Android back pauses, never quits.
7. Autosave/resume (`scripts/save_game.gd`): checkpoint + pause saves, CONTINUE on title, GAME OVER clears.
8. Settings (`scripts/settings.gd`, sheet in `settings_sheet.gd`): music, SFX, brightness, vibration,
   text size, subtitles, high contrast, colorblind colours, left-handed, invert look, sensitivity, low graphics.
9. Touch: buttons >= 72 base units (~56 dp), 18 apart (`ui.gd MIN_TOUCH/GAP`); left-handed mirrors the controls.
10. Audio buses Music + SFX in `default_bus_layout.tres` (must exist at boot for web); `Audio.sfx/music`.
11. Subtitles + sound captions (`Subs.say/cue`), high contrast theme, colorblind-safe key colours
    (`UI.key("good"|"bad"|"info"|"warn")`, Okabe-Ito) plus shape cues.
12. Dev menu (debug builds only; the dev APK is one): 5 taps on the version, 3-finger tap, or F1.
    FPS, god mode, skip level (`debug_skip_level()` on the scene), clear save.
13. Autoplay bot (`scripts/autoplay.gd`, `tools/autoplay.sh`): plays the whole flow with real taps,
    screenshots to docs/renders/, one PASS line per check. CI fails on any FAIL.
14. Placeholder art drawn in code + Foxboard/Forge hookup (docs/ART.md, `foxboard_decode.yml`).
15. **Full range of movement** (Duff, Nov 20; docs/MOVEMENT_3D.md): characters use the full range of
    movement the current engine supports, never faked with bobbing/tilting stills; standard humanoid
    skeleton + glTF so it carries to another engine. Godot today: 8-way + strafe/backpedal, turn in
    place, jump/fall/land, crouch, foot IK, look-at, hit reactions + root-motion knockback, ragdoll,
    climb/vault/swim. `Character3D` (`scripts/character3d.gd`); playground `scenes/character_test.tscn`.
16. **The twelve game standards** (Duff, Nov 20), all in **GROK_STANDARDS.md** (the rulebook any coding AI
    reads; AGENTS.md points to it; copy it into every game repo): game feel (`Feel` autoload), camera
    (`camera_rig.gd`), frame budget (CI `PERF PASS` + dev menu PHONE SPEED TEST), responsive controls
    (buffer, coyote, dodge-cancel in `Character3D`), readability (hero light), audio (footsteps per
    surface, combat layer, ducking in `Audio`), first 60 s (`coach.gd`, `BOOT PASS`), portable assets,
    telemetry + crash hook (`Telemetry`, offline, opt-in), haptics, gamepad + remap (`Controls`,
    Settings -> CONTROLS), offline-first.
17. **Pipeline lessons** (Nov 20, from the Hunter thread): motion only from clips, models normalised
    (metres, feet on 0, +Z; `test_models_portable`), texture imports explicit
    (`test_texture_imports_explicit`), controls legend (`controls_legend.gd`, `LEGEND PASS`), no
    "seamless tile" prompts.
18. **Phone kit + build clip** (Duff, Nov 21): quality tier picked on first launch (`quality.gd`, Settings
    -> GRAPHICS, `TIER PASS`), background scene loads (`Loader.go`, `LOAD PASS`), atlases
    (`atlas.gd` + `tools/pack_atlas.py`, `test_atlas_regions`), ETC2/ASTC check, and the bot's 10 s
    gameplay clip (`CLIP PASS`; 15 s, vertical 720x1280; CI posts `<repo>_gameplay.mp4` to the dev release).
19. **QoL + social** (Duff, Nov 21): battery saver (`Battery` autoload, `BATTERY PASS`), GAME MUSIC off so the
    player's own music plays (iOS mixes with others), Buffer drafts workflow (`buffer_drafts.yml`, needs
    `BUFFER_API_KEY` secret; drafts only, `tools/test_buffer_drafts.py`). After engine upgrades delete
    `.godot/imported/` (stale 4.5 cache = T-pose; `bind_skins` + `SKIN PASS`).
Cut by Duff: playtest link + feedback sheet. (Phone frame-rate check came back as standard 3.)

