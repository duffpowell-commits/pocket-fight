# Testing: the bot and the rule tests

- **Autoplay bot** plays the whole game with real taps, saves screenshots to `docs/renders/`, prints
  one `PASS` line per check, and records the 15 s vertical gameplay clip. CI fails on any `FAIL`.
  **Every new feature adds a PASS line.**
- **Rule tests** (`tests/run_tests.gd`): one `test_*` function per rule.
- **A new test only counts once you've seen it fail** (break the code, watch it go red, restore).
- Bot checks use real time, not frame counts: CI machines are slow.
- Before every push: `tools/test.sh` (runs `test_cmd` from `.claude/hooks/guard.cfg`: parse check +
  rule tests) and `tools/autoplay.sh` -> `AUTOPLAY PASS` (also writes `docs/renders/gameplay.mp4`).
- **Rules that keep getting broken become hooks, not prose** (`.claude/hooks/guard.py`, Claude Code):
  no force push, no direct push to main, no push of code the tests didn't pass on (`tools/test.sh`
  records the tree), no new/changed/committed signing keys or secret files (by name). Corrected twice = add a rule;
  a rule nobody trips in a month = delete it.
- **Every agent gets the push rules, not just Claude**: `.githooks/pre-push` runs the same guard.py
  on `git push` after `git config core.hooksPath .githooks` (first step of every session, AGENTS.md).
  `--no-verify` skips it; CI and the fresh-eyes gate stay the backstop. Self-test: `tools/test_push_guard.sh`.
  Why (Nov 21): Claude Code hooks only fire inside Claude Code, so other agents could skip them.
- **Fresh-eyes review before merge** (`.github/workflows/fresh_eyes.yml`, `docs/FRESH_EYES.md`): the
  `fresh-eyes` status stays pending until a reviewer with a fresh context posts
  `FRESH-EYES REVIEW: PASS` on the PR's head commit. Pending is not green: sessions
  check the combined status and don't merge (GitHub itself doesn't block it).
