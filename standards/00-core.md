# Core rules (always read this one)

Owner: Duff. These rules apply to every Duff game repo, for any coding AI.
If a repo's own README/CLAUDE.md/AGENTS.md says something more specific, that wins for that repo.
Rules are engine-agnostic: they stay true if a game moves from Godot to Unity or Unreal.
"Godot today" lines say how the template already does it.

## How Duff works
- **Duff is phone-only.** Phone browser, GitHub on the phone, the Godot Android editor. Never give
  him desktop steps. If something can't be done from a phone, say so up front.
- **Do the work, then tell him.** Ask first only if it costs money, can't be undone, or a wrong
  guess is expensive. Ask once, with tappable choices.
- **Green merges itself.** In game repos a pull request with all checks passing gets merged without
  asking Duff. Red CI never merges. Never skip, disable or delete a test to get green.
- **Nothing is "done" until it's checked**: merged to main, CI green, the build installed or live.
- **Show, don't describe.** Visual changes need real engine screenshots saved in `docs/renders/`.
- **Never put secrets in the repo, commits, logs or chat.** Duff adds secrets himself.
- One AI session per repo at a time. `git fetch` before starting and before pushing. Push after
  every chunk of work. Merge to `main` at the end of every milestone.
- Plain words for Duff: short sentences, no jargon, lead with the result.

## Tech rules
- Godot 4.6 (4.6.3 today), GDScript only (no C#, no native plugins), Compatibility renderer
  everywhere (runs on phones and iPhone Safari). Portrait 540x960 base unless the game says otherwise.
- Build all UI with the template's `ui.gd` helpers (text size, contrast and touch size come free).
- Every sound a player must notice gets a caption (`Subs.cue`). Every gameplay colour comes from
  `UI.key()` plus a shape cue.
- Every gameplay scene pauses + saves on focus loss and handles the back button (close sheet / pause).
- Save at every checkpoint; bump the save version and migrate when the format changes.
- Change scenes with `Loader.go(path)` (background load), not a blocking load.
- Every feature serves the game's pitch, or it gets cut.

## Done means
A change is done when: it's on `main`, CI is green, the bot has a PASS line for it, screenshots are
in `docs/renders/` if it's visual, the handoff file says what changed, and the build is in the
`dev` release for Duff to install.
