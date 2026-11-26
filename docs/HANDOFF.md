# HANDOFF: Wildmade (repo pocket-fight)

Plain handoff for any coding AI (Claude, Grok, Codex...) or person. Duff, Nov 26, 2026: "keep logs
for another ai to build where you stop". Update this file in every PR. Rules and commands: AGENTS.md.
Design and history: CLAUDE.md, docs/PITCH.md, docs/DECISIONS.md. `NEXT_AI_HANDOFF.md` is old; ignore it.

## Current state (checked 2026-11-26, main `66342e5`)
- **Parked.** Nothing is being built. A one-week side test with a verdict due Nov 30, 2026; keep or
  kill is Duff's call (kill rules in docs/PITCH.md). Don't start work here without Duff saying so.
- The game: say what monster you want, watch it hatch, see what it can do. "The creator is the heart"
  (Duff, Nov 23). Godot 4.7.2 (4.7.x only), GDScript, built on godot-game-starter.
- On main: M0 foundation, M1 creator slice (#4), M1.1 test polish (#5), Godot 4.7.2 (#6), rule lock (#7).
- Live: APK on Releases -> `dev` -> `pocket-fight.apk`. No browser build (no Pages site).
- Open PRs: #2 (Nov 23, another AI's first prototype, draft). Superseded by the rebuild on the starter
  (its files are kept in docs/prototype/). Don't merge; leave it for Duff to close.

## Waiting on Duff
- The Nov 30 keep/kill verdict, after he plays the APK.
- The `KEYSTONE_PASS` repo secret (docs/SIGNING.md). Until then CI signs with a throwaway key and a
  properly signed build later needs an uninstall first.

## If Duff keeps it: next steps, in order
1. Studio mascot: the three-eyed fox is a rare cameo in every game, never a pal, never game-ruining;
   Duff OKs the art on a card first. Copy `docs/MASCOT.md` from godot-game-starter and plan this game's cameo.
2. 8.5 rule: write what it takes to reach an 8.5/10 blind first-timer review, get Duff's OK on one
   card, build it in one pass. Blind reviews only when Duff asks.
3. QUEUE.md NEXT #1 (photo to monster) needs Duff's OK on a paid image service first.
4. Copy the web export job from godot-game-starter (#26) for an iPhone browser build.

## Build and test (cloud sandbox)
- Godot 4.7.2-stable Linux zip from GitHub releases -> `/usr/local/bin/godot`; fresh clone:
  `godot --headless --path . --import`. Once per clone: `git config core.hooksPath .githooks`.
- Before every push: `tools/test.sh` -> `TESTS PASS`, then `tools/autoplay.sh` -> `AUTOPLAY PASS`.
- Monster contact sheet: `tools/monster_sheet.gd` -> docs/renders/monster_sheet.png.

## Gotchas
- New part: add it to `PARTS` in `scripts/monster.gd` and draw it in `scripts/monster_view.gd`.
  New word: `WORDS`/`PHRASES` in monster.gd (a test checks each word points at a real part).
- `scripts/duel.gd` is rules only (tests and the bot play it); `fight.gd` draws it.
- Never force push, push to main, use `--no-verify`, add the `duff-ok` label, or make a signing key.

## Log (newest first)
- 2026-11-26 Claude: wrote this file (handoff refresh across every project). No code changed.
