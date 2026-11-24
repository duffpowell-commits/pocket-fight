# Starting a game: Milestone 0 = copy the template

Every new game starts from `duffpowell-commits/godot-game-starter`, which already has Milestone 0
built and tested. **Do not rebuild any of this. Copy the template and start at Milestone 1.**

To start a game (all from the phone): github.com -> godot-game-starter -> **Use this template** ->
new repo named after the game -> add the `KEYSTONE_PASS` secret -> first push to `main` builds
the APK. Then rename the game in `project.godot` (`config/name`), fill `docs/PITCH.md`, write the
repo's handoff file, and build the core loop (Milestone 1). Replace the placeholder game in
`scripts/game.gd` (its PLAY section); keep everything else.

Milestone 0, already in the template (every game must keep all of it working):
1. Handoff files: README/CLAUDE.md/AGENTS.md, QUEUE.md, docs/PITCH.md, docs/style-guide.md.
2. CI on every push: parse every script, rule tests, autoplay bot, signed APK, 15 s vertical
   gameplay clip (see 11-build-release.md).
3. One signing key for every game (11-build-release.md).
4. **In-app updater**: on launch and when the app returns to the front, it reads `version.json` from
   the `dev` release; if newer, it offers UPDATE NOW and installs the new APK. Version on the title
   (`v0.1.<build>`).
5. **REPORT A BUG** on the title and pause screens: opens a prefilled GitHub issue (or copies the
   text), adding build, device, scene, game state, fps, graphics tier and "crashed last run".
6. Full scene flow: boot -> intro (once, skippable) -> title -> game -> pause -> game over -> title.
   Pause and save when the app loses focus (phone call, home button). Android back pauses, never quits.
7. Autosave + CONTINUE: save at checkpoints and on pause; game over clears the save.
8. Settings: music, GAME MUSIC on/off, SFX, brightness, vibration, text size, subtitles, high
   contrast, colorblind colours, left-handed, invert look, sensitivity, GRAPHICS (LOW/MEDIUM/HIGH),
   controls legend, BATTERY SAVER, share anonymous stats, CONTROLS.
9. Touch: buttons at least 72 base units tall (~56 dp), 18 apart; left-handed mirrors the controls.
10. Audio buses Music + SFX that exist at boot.
11. Subtitles + sound captions, high-contrast theme, colourblind-safe colours plus shape cues.
12. Dev menu in debug builds (5 taps on the version, 3-finger tap, F1): FPS, god mode, skip level,
    3D character test, phone speed test, clear save.
13. Autoplay bot: plays the whole game with real taps (12-testing.md).
14. Placeholder art drawn in code; real art comes from Foxboard (09-art-assets.md).
15. Phone kit: quality tier, background loading, atlases, battery saver (05-performance.md);
    the player's own music keeps playing (07-look-and-audio.md).
