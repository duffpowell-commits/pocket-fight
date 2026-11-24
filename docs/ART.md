# Art pipeline

- **Placeholder first:** everything starts drawn in code (see `game.gd _draw_field`) so the game is
  playable before any art exists. Swap in real art one piece at a time.
- **Foxboard is the art tool** (Duff's own app, repo `duffpowell-commits/Foxboard`; Forge runs the
  free FLUX generator behind it). New art goes into Foxboard's Shared library first.
- **Send to game:** Foxboard's Send to game button commits art into `grok_art/<date>-foxboard/` as
  base64. `.github/workflows/foxboard_decode.yml` turns it back into PNG/GIF. `build.yml` ignores
  `grok_art/`, so a drop never ships by itself: a session cuts/cleans it into `assets/art/`.
- Sounds: placeholders from `tools/gen_audio.py`; list every real clip in `assets/audio/SOURCES.md`.
- Duff's likeness and hand tattoos: follow the project's art rules (never invent his tattoos).
