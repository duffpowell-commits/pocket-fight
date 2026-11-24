# Queue
Work only on NOW. New asks go under IDEAS with a date until Duff swaps them into NOW.
This repo is a **one-week side test** (verdict Nov 30, 2026). Lethemoor is the active game.

## NOW
- **Playtest week (Duff, on his phone).** Install the dev APK, make monsters, hand it to one other
  person. Nothing gets built here until the verdict, except fixes for things that block the test.
  Pass / kill rules: docs/PITCH.md.

## NEXT (only if the test passes; order is Duff's call)
1. **Photo or sketch to monster.** The other half of the hook. Needs an image-reading service, which
   costs money per picture: Duff picks the service and a spending cap first. Offline text keeps working.
2. **Share card.** Save a picture of your monster with its name to the phone, to send to someone.
3. **Egg hatch + sound per part.** The hatch moment and juice (pillar 3).
4. **Second fight kind** that asks for a different move, plus 2 more moves.

## DONE
- M0 foundation: copied from godot-game-starter (Nov 23). CI, signed APK on every merge, in-app
  updater, saves, settings, pause, bug report, dev menu, autoplay bot.
- M1 creator slice (Nov 23): 4 bodies, 8 part slots, 10 colours, 4 shape sliders, mood, name;
  DESCRIBE (typed words to a draft, tells you what it missed); SURPRISE + UNDO; autosave;
  test fight against a random wild monster.

## IDEAS
- 2026-11-23: Flooded Mill rescue with two routes (first plan, docs/GAME_DESIGN_PLAN.md).
- 2026-11-23: player-character creator sharing the same editor.
- 2026-11-23: evolution choices unlocked by what the duo does together.
- 2026-11-23: PvP with normalised levels (first plan's balance notes; first mover won 63-69% in its sim).
- 2026-11-23: horns sit on top of pointy ears; give horns their own spot.
- 2026-11-23: the build video still shows the starter's 3D test room, not a monster.

## CUT
- 3D character kit from the starter (models, Character3D): unused by a 2D creator. Still in the
  repo because the starter's bot and tests lean on it; strip it if the game is greenlit (saves about 16 MB of APK).
- Real-time exploring + turn-based fights in one slice (Nov 23): two games for one test.
