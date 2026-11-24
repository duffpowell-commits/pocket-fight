# Performance on phones (standard 3 + the phone kit)

## Frame budget
60 fps on Duff's phone. CI fails a build that breaks the scene budget (draw calls <= 250,
triangles <= 300k, game code + physics <= 8 ms per frame, with a typical fight on screen). The dev
menu's PHONE SPEED TEST runs that fight on the phone and shows PASS (>= 58 fps average, >= 45 fps
worst 1%). Godot today: `perf_test()` in the playground. Check: `PERF PASS`.

## Quality tier, picked on first launch
On the first launch the boot splash times a small 3D scene (never more than ~0.5 s) and picks
LOW / MEDIUM / HIGH; phones with 4 or fewer cores cap at MEDIUM. Saved; Settings -> GRAPHICS
changes it. LOW = `low_graphics` on (no shadows, fewer particles, death clip instead of ragdoll)
and 3D at 70 %; MEDIUM = 3D at 85 %; HIGH = 100 %. UI always stays sharp. Games read
`low_graphics` (or `tier` for finer choices). Godot today: `scripts/quality.gd`.
Checks: `TIER PASS`, `test_quality_tiers`.

## Textures compressed for phones
3D textures import VRAM-compressed for mobile (ETC2/ASTC on). 2D UI art can stay lossless.
Check: `test_mobile_texture_compression`.

## Atlases
Many small images (icons, UI bits, pickups) go into one sheet: fewer draw calls, less memory.
Make one in the cloud with `python3 tools/pack_atlas.py SRC_DIR assets/art/<name>` (PNG + JSON),
read a piece with `Atlas.tex("res://assets/art/<name>", "heart")`. Check: `test_atlas_regions`.

## Battery saver
When nobody is playing, don't burn battery: paused, on a menu (boot, intro, title) or no input for
45 s = 30 fps; app in the background = 5 fps + low-processor mode; full speed the moment play
resumes. On by default, Settings -> BATTERY SAVER. Godot today: `Battery` autoload
(`scripts/battery.gd`; scenes with a `paused` flag count as paused). Checks: `BATTERY PASS`,
`test_battery_saver_states`.

## Background loading
Change scenes with `Loader.go(path)`: it loads on a background thread so the screen keeps drawing,
and shows a LOADING card only if it takes longer than 0.25 s. Never block the frame on a big load.
Godot today: `scripts/loader.gd` (autoload `Loader`). Check: `LOAD PASS`.
