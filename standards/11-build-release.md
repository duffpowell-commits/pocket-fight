# Build, signing and release

## Signing: one key for every game
- Android only installs an update over an app signed with the same key. Every Duff game is signed
  with ONE key, the **keystone**: `signing/keystone.keystore.enc` (encrypted) +
  `signing/keystone.sha256` (fingerprint), unlocked in CI by the repo secret **`KEYSTONE_PASS`**
  via `signing/unlock.sh`. Games made from the template already carry it.
- Each game repo needs the `KEYSTONE_PASS` secret (Duff adds it: Settings -> Secrets and variables
  -> Actions). Without it CI signs with a throwaway key and warns; that APK can't update an
  installed copy.
- Package name `com.duffpowell.<repo>`, APK `<repo>.apk`, version code = CI run number. All derived
  from the repo name; no edits needed.
- **Lethemoor is the exception**: it keeps its own key. Never sign another game with it.
- Never make a new key, never commit an unlocked keystore or the passphrase, never print it.

## What CI ships
Every push to `main`: parse check, rule tests, autoplay bot, signed APK. Then the repo's `dev`
release gets `<repo>.apk`, `version.json` (the in-app updater reads it) and
`<repo>_gameplay.mp4`: 15 s of real play recorded by the bot, vertical 9:16 at 720x1280 (ready for
TikTok, Shorts, Reels), so Duff can watch a build without installing it. PRs keep the same files
as run artifacts.

## Clip to social: Buffer drafts only
Actions -> "send clip to Buffer drafts" -> Run (works from the phone). It leaves one DRAFT per video
channel in Buffer; **nothing is published or queued to go live** until Duff schedules it in the
Buffer app. Needs the `BUFFER_API_KEY` repo secret (Duff: publish.buffer.com/settings/api ->
create key -> repo Settings -> Secrets -> Actions). Free Buffer = 3 channels, 10 queued posts each: TikTok, YouTube Shorts, Instagram (Duff, Nov 21; workflow default).
The clip link must be public (public repos). `tools/test_buffer_drafts.py` proves drafts-only.

## Engine version
Godot 4.7.2 (`GODOT_VERSION` in `.github/workflows/build.yml`, `config/features` in
`project.godot`). Move up only to a stable release, and only once every check passes on it.
After an engine upgrade, delete `.godot/imported/` (or Project -> Reimport): a cache from the old
version left the mannequin's mesh unlinked from its skeleton (T-pose). `Character3D` re-links it
and the bot's `SKIN PASS` catches it.
