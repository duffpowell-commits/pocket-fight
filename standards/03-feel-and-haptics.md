# Game feel and haptics (standards 1 and 10)

- **Every hit gets all five:** hit-stop (~60 ms freeze on both fighters), screen shake, a sound,
  a particle burst, and a phone buzz. Bigger hits = more of each.
- **Haptics:** a buzz on every hit, scaled by power; respects the Vibration setting.

Godot today: `Feel.impact(pos, power, parent)` + `Character3D.hit()` / `hit_stop()`.
Check: `FEEL PASS`.

## Tune on the phone, not by prompt (Duff, Nov 21)
- **Every number a game feels through gets a live slider** in the dev build: speeds, jump, gravity,
  hit-stop, shake, camera distance/angle/fov, enemy speed and timings. Duff drags it while playing
  instead of asking for "a bit faster" and waiting for a build. SHARE VALUES sends the tuned numbers
  back as a GitHub issue; a session makes them the code defaults.
- Godot today: DEV MENU -> TUNE (`scripts/tune_panel.gd`). A node joins group `tunable`, declares
  `const TUNE := {"prop": [min, max]}` and calls `DebugMenu.apply_tune(self)` at the end of
  `_ready()`. Character3D, CameraRig and Feel already do. New gameplay numbers: add them to TUNE.
  Check: `TUNE PASS`.
