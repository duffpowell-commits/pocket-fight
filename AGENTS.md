# AGENTS.md: the rulebook for any coding AI in this repo (Grok, Claude, Codex, Copilot...)

This file is the source of truth for commands and standing rules in this repo. Claude Code loads it
through the `@AGENTS.md` line at the top of CLAUDE.md. CLAUDE.md keeps only the handoff (where
things stand) and Claude-only notes. Topic rules live in `standards/` (index: GROK_STANDARDS.md);
this file points to them rather than copying them. Repo-specific rules here win where they are more
specific than `standards/`.
Why (Nov 21, 2026): Claude Code skips AGENTS.md when a CLAUDE.md exists unless CLAUDE.md imports it,
so rules kept only here were invisible to Claude, and rules kept only in CLAUDE.md to everyone else.

## First step of every session (required, once per clone)
```sh
git config core.hooksPath .githooks
```
This turns on `.githooks/pre-push` for every agent, not just Claude Code (details under Guards).
Why: Claude Code hooks only fire inside Claude Code, so Grok and other agents could skip them.

## Commands
- Engine: Godot 4.7.2-stable. Version lives in `GODOT_VERSION` (build.yml) + `config/features`.
- Godot in a cloud sandbox: 4.7.2-stable Linux zip from GitHub releases -> `/usr/local/bin/godot`.
  Fresh clone: `godot --headless --path . --import`.
- Tests: `tools/test.sh` -> `TESTS PASS` (runs `test_cmd` from `.claude/hooks/guard.cfg`: parse
  check `tools/check_scripts.gd` + rule tests `tests/run_tests.gd` -> `ALL PASS`; records the
  passing tree for the push guard).
- Flow + screenshots: `tools/autoplay.sh` -> last line `AUTOPLAY PASS` (also writes `docs/renders/gameplay.mp4`).
- Push guard self-test: `tools/test_push_guard.sh` -> `PUSH GUARD PASS` (local bare remote, never GitHub).
- CI: `gh api repos/<owner>/<repo>/actions/runs?per_page=3` (gh GraphQL is blocked in sessions).

Before every push: `tools/test.sh` prints `TESTS PASS`, then `tools/autoplay.sh` prints `AUTOPLAY PASS`.
Before any merge: a fresh-eyes review (docs/FRESH_EYES.md); CI keeps the PR pending until then.

## Read first
- `standards/00-core.md` always (phone-only, "green merges itself", what done means), then only the
  `standards/*.md` files your task touches (movement, controls, performance, art, build/signing...).
- CLAUDE.md for where things stand. QUEUE.md for what to work on (only NOW).
- docs/DECISIONS.md: dated log of what changed and why, plus open questions. Read it to catch up.

## Standing rules (the full set is in standards/; these are the ones sessions trip on)
- Duff is phone-only (Godot Android editor, GitHub app). GDScript only. No desktop steps.
- UI through `ui.gd` helpers. Sounds a player must notice: `Subs.cue`. Gameplay colours: `UI.key()` + a shape cue.
- Gameplay scenes handle focus-out (pause + save) and the back button, deferred, like `game.gd`.
  Save at checkpoints; bump `Save.VERSION` + migrate when the format changes.
- 3D characters: `Character3D` on the shared skeleton, real clips only (docs/MOVEMENT_3D.md).
- Every gameplay number gets a TUNE slider (`standards/03`). Every new feature gets an autoplay PASS line.
- Renderer is Compatibility everywhere. Visual decisions need real engine renders, saved to files.
- Push after every chunk; merge to main at the end of every milestone; up to three per session.
- After an engine upgrade delete `.godot/imported/` (stale cache = T-pose).
- Never put secrets in the repo, commits, logs or chat. Duff adds secrets himself.

## Guards (enforced, not just written down)
- One rule script, two triggers: `.claude/hooks/guard.py`. Settings: `.claude/hooks/guard.cfg`.
  - Claude Code runs it before every tool call (`.claude/settings.json`).
  - Every agent runs it on `git push` through `.githooks/pre-push`, once `core.hooksPath` is set (above).
- It blocks: force push (caveat: in Claude Code's mode `--force-with-lease` still gets through; the
  Git hook blocks it), direct push to main, pushing code the tests didn't pass on, writing/generating
  signing keys, committing secret files (.env, keystores, secrets.*; names only, not contents).
- The Git hook sees what a push does, not its flags: any push that rewrites the remote branch counts
  as a force push (so `--force-with-lease` is blocked there too), and deleting main is blocked.
  Empty `test_cmd` in guard.cfg = no test gate.
- `git push --no-verify` skips the Git hook. Don't use it; CI and the fresh-eyes gate stay the backstop.
- PRs: the `fresh-eyes` status stays pending until a fresh-context review posts
  `FRESH-EYES REVIEW: PASS` on the head commit (docs/FRESH_EYES.md). Pending is not green: sessions
  check the combined status and don't merge (GitHub itself doesn't block it).
- Rule lock (Nov 24, 2026, from godot-game-starter): a PR that changes the rules (this file's rules, AGENTS.md, `standards/`, `.claude/`, `.githooks/`, `fresh_eyes.yml`, `rule_lock.yml`; list in `tools/rule_lock.py`) gets a failing `rule-lock` status until Duff adds the `duff-ok` label. **Agents never add, ask a tool to add, or work around that label.** Put rule changes in their own PR and tell Duff it needs his tap. Self-test `tools/test_rule_lock.sh`.
- Signing: one keystone for every game except Lethemoor (docs/SIGNING.md). Never make another key.

## Layout
- `scenes/` boot, intro, title, game (Control + script; UI built in code). `game.gd` = the
  monster creator (Wildmade); `fight.gd` + `duel.gd` = the test fight; `monster.gd` + `monster_view.gd` = the monster.
- `scripts/` autoloads: Controls, Settings, Save, Audio, Subs, Feel, Telemetry, Loader, Battery,
  Updater, DebugMenu, Autoplay. Helpers: `ui.gd`, `config.gd`, `bug_report.gd`, `settings_sheet.gd`,
  `tune_panel.gd`, `camera_rig.gd`, `coach.gd`, `character3d.gd` (+ foot_ik, aim_twist, ragdoll).
- `tests/run_tests.gd` rule tests. `tools/` check_scripts.gd, test.sh, autoplay.sh, gen_audio.py, test_push_guard.sh.
- `assets/audio/` (list every clip in SOURCES.md), `assets/art/`, `assets/models/`. `grok_art/` never ships.
- `signing/` keystone (encrypted) + `unlock.sh`. `docs/renders/` autoplay screenshots.
- `.claude/` Claude Code hooks + guard rules; `.githooks/` the Git pre-push hook for every agent.

## Changing the rules
The master copy of these rules is `duffpowell-commits/godot-game-starter`. Change shared rules
there and copy them here; change only Wildmade-specific lines in this repo.
