# Decisions (newest first)

## 2026-11-23: restart on the starter, creator first
- **Duff's calls:** pocket-fight is a side test with a one-week cap (Lethemoor stays active). The
  heart is the creator: making your own monster, by text or photo. Fights show it off.
- **Why restart:** main held only a README. The first plan and prototype sat on unmerged branches
  with no CI, no APK and no handoff file, so nothing was playable on a phone. godot-game-starter
  already had all of that, so the game was rebuilt on it and the old work kept in history + docs/prototype/.
- **Checked before replacing it:** the prototype parsed and its balance tool ran on Godot 4.6.3
  (PASS line; first mover won 62.6-68.6%, simultaneous turns drew about 30%), matching its README.
- **Cut for the test:** the Flooded Mill, the player-character creator, PvP. One creator has to be fun first.
- **Monsters are drawn by code**, not sprites: every part mix works at once and a look could be
  judged on day one. Real art can replace a part later inside monster_view.gd.
- **DESCRIBE works offline** with a word list. It says which words it missed instead of guessing.
  Photo input is not built: it needs a paid service, so it waits for Duff.
- **Fight number changed:** heavy strike 12 -> 15. At 12, tapping Attack every turn always won, so
  Guard and the signature move never mattered. A test now holds both ends: attack-only loses, smart play wins.
- **Open:** KEYSTONE_PASS secret; who the second tester is; whether photo input is worth paying for.
