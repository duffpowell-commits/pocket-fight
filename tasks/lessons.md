# Lessons

- `godot --check-only --script` doesn't load autoloads, so any script using `Settings.` etc. fails
  it. Use `tools/check_scripts.gd` (loads every script inside a running tree) instead.
- Adding UI from `_notification` (focus out, back button) fails with "parent busy": call it deferred.
- An imported .wav's loop is set in its .import (`edit/loop_mode=2`), not at runtime (it's compressed).
- Rebuilding a screen's UI after a settings change: move open sheets back on top (`move_child(sheet, -1)`).
- DuffQuest went weeks without a GAME OVER because end screens weren't day-one plumbing. They are now.
- Wildmade, Nov 23: a "describe it" parser must apply exact phrases ("no tail") after single words
  ("cat"), or the animal's kit puts the tail back. A test caught it on its first run.
- Wildmade, Nov 23: a Control added in code needs `set_anchors_and_offsets_preset`, not
  `set_anchors_preset`, or it keeps a zero size and its labels wrap one letter per line.
