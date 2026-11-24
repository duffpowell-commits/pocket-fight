# Finished-game quality and release playtests

Why (Nov 23, PR #15): one shared bar for a game's first finished slice before production widens. Each
game names its own first slice in its AGENTS.md or QUEUE.md (kept out of here: this file is copied
unchanged into every game repo).

- Finish one representative playable slice before expanding production. Include clean launch, how a new
  player learns the controls, a complete core interaction, its outcome, and retry or return. Use the
  finished slice as the reference for later scenes.
- Keep in-engine references for normal play, a busy encounter, and dialogue or menus. Record the
  camera, scale, lighting, palette and UI conventions. Review new work beside those references.
- For character and outfit changes, review the turnaround, in-game camera view, and phone capture in
  motion. Link the approved reference, asset revision and build. Characters based on real
  people need Duff's approval; each game's AGENTS.md names who.
- Read the game at actual phone size. The player, threat and next action should be clear in a busy
  frame. Use shape, contrast or motion to reinforce color. Check readable dialogue, touch targets,
  consistent button states, back behavior and transitions.
- Make important actions readable from setup through impact and recovery. Distinguish hits, misses,
  blocks and pickups visually and in audio. Review short captures muted and with sound.
- Profile frame time on Android in a busy scene, through effects and transitions, and after a longer
  play session. Validate broader compatibility claims on a device below Duff's current Galaxy tier.
- Watch a new player attempt one realistic task without coaching. Record the first hesitation,
  incorrect action or request for help, fix repeatable issues, and retest the same moment.
- For a release candidate, play the exact APK from launch to result using touch. Verify background and
  resume, save and reload, and an in-place update from the last compatible signed build when that path
  exists. Record the commit, APK or CI link, device, pass/fail evidence and any checks still pending.
- Capture a short, unedited gameplay clip from that build. Show the player's action and the game's
  response. Attach it with the playtest report so the next AI can review the same evidence.
