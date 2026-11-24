# Style guide (template defaults; each game replaces these)

## Colours
- Background `#12161f`, panels `#1d2433`, ink `#e9e4d8`, dim `#9aa3b5`, accent `#e8a33d` (scripts/ui.gd).
- Gameplay meaning always goes through `UI.key("good"|"bad"|"info"|"warn")`; colorblind mode swaps
  to Okabe-Ito. Never let colour be the only cue: add a shape, icon or position difference.

## Type and touch
- Body 22, buttons 24, headings 28-44 (base units at 540x960), all scaled by the Text Size setting.
- Buttons at least 72 tall (`UI.MIN_TOUCH`), 18 apart (`UI.GAP`). Main action goes on the thumb side;
  left-handed mirrors it.

## Screens
- Menus are sheets (`UI.sheet`): dimmed game behind, one column of buttons, primary first and tallest.
- Labels say what happens: RESUME, QUIT TO TITLE, TRY AGAIN. All caps on buttons.

## Art
- Placeholder art is drawn in code. Real art comes through Foxboard (docs/ART.md).

## 3D characters (house standard, docs/MOVEMENT_3D.md)
- The full range of movement the engine supports: real skeleton, real clips, physics. Never a bobbing
  or tilting still.
- Toon shading (3 bands, shade floor 0.35), 3 px ink outline on every character, warm rim light on
  the hero only. Low-poly (~5k tris) so several fit on a phone.
- Camera high three-quarter (~50 degrees), floating stick on one half, actions on the other thumb.
