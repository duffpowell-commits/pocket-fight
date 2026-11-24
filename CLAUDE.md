@AGENTS.md

# Wildmade (repo pocket-fight)

Say what monster you want, watch it hatch, then see what it can do. Owner: Duff. Read this first;
it is the handoff between sessions. Commands, standing rules and guards: AGENTS.md (imported above).

## Where things stand (Nov 23, 2026)
- **One-week side test.** Verdict due Nov 30, 2026. Lethemoor is Duff's active game. Duff picked
  "the creator is the heart" (Nov 23): making the monster is the game, the fight shows it off.
- Pitch + kill rules: docs/PITCH.md. Queue: QUEUE.md (NOW = Duff playtests; build nothing new).
  Progress: tasks/todo.md. Why things changed: docs/DECISIONS.md.
- Latest build: Releases -> `dev` -> `pocket-fight.apk`, rebuilt on every push to main.
- Done: M0 foundation (copied from godot-game-starter), M1 creator slice.
- Next: nothing until the verdict. If it passes, QUEUE NEXT #1 (photo to monster) needs Duff's OK
  on a paid image service first.
- Waiting on Duff: add the `KEYSTONE_PASS` repo secret (docs/SIGNING.md). Until then CI signs with
  a throwaway key, and a later properly-signed build won't install over it without an uninstall.
- No playtest sheet yet: make it when Duff hands the build to a tester (playtest-loop).

## History worth knowing
- Another AI wrote the first plan and prototype (PRs #1, #2, Nov 23). Their commits are in main's
  history; the old files are kept as text in docs/prototype/. The first plan (HD-2D RPG, Flooded
  Mill) is docs/GAME_DESIGN_PLAN.md: parked under IDEAS, not the current scope.
- NEXT_AI_HANDOFF.md is that AI's checkpoint from before this restart. It is out of date; this file wins.

## Layout (what Wildmade adds to the starter)
- `scripts/monster.gd`: a monster design as plain data. Parts lists, colours, `clean`, `surprise`,
  and `from_text` (the DESCRIBE word list lives here: WORDS and PHRASES).
- `scripts/monster_view.gd`: draws a design with code (no sprites) and plays its little animations.
- `scripts/game.gd`: the creator screen. `scripts/fight.gd` + `scripts/duel.gd`: the test fight
  (duel.gd is rules only, so tests and the bot can play it).
- `tools/monster_sheet.gd`: renders a contact sheet of monsters to docs/renders/monster_sheet.png.

## Adding a part or a word
- New choice: add it to `PARTS` in monster.gd and draw it in monster_view.gd. The creator, saves,
  SURPRISE and the tests pick it up from the list.
- New word: add it to `WORDS` (or `PHRASES` for two or more words). A test checks every word
  points at a real part.

## Claude-only notes
- `.claude/settings.json` runs `.claude/hooks/guard.py` before every Bash/Write/Edit call. A blocked
  call comes back with the reason; fix the cause, don't work around it.
- Commit and push in separate Bash calls: a commit and push in one line is checked before the commit exists.
- A GDScript parse error makes a rendered run hang instead of failing: run `tools/test.sh` first.
