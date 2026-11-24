# Start a new game from this template (all from the phone)

1. On github.com (phone browser), open `duffpowell-commits/godot-game-starter` -> **Use this
   template** -> Create a new repository. Name it after the game (that becomes the APK name and the
   package `com.duffpowell.<name>`). Public keeps Actions free.
2. In the new repo add the `KEYSTONE_PASS` secret, same passphrase as every game (docs/SIGNING.md).
3. Tell your coding AI (Claude or Grok): "read AGENTS.md and set up <game>". It renames `config/name` in
   project.godot, fills docs/PITCH.md (game-greenlight), rewrites CLAUDE.md's top, and starts
   Milestone 1 from QUEUE.md.
4. First push to main builds the APK: Releases -> dev -> tap the APK to install. Every later build
   offers itself in-game (UPDATE NOW).

## Marketing setup (required for every new game)

5. Read [the studio marketing playbook](MARKETING.md) before announcing the game. Copy the following checklist into the game's launch plan or `docs/MARKETING.md` and fill it with game-specific details:
   - [ ] Game title, genre, target players, one-sentence hook, and current development stage.
   - [ ] Confirm 3 Eyed Fox Studios branding, approved logo, publisher credits, and splash.
   - [ ] Identify the primary CTA (follow, play demo, wishlist, join playtest) and verified destination URL.
   - [ ] Identify platforms and official account handles; do not assume an account exists.
   - [ ] Prepare a press kit: accurate description, approved images, screenshots, and footage.
   - [ ] Draft three vertical video concepts with audio, captions, and platform-specific copy.
   - [ ] Create a proposed seven-day calendar with America/Chicago times and an approval owner.
   - [ ] Record approval and actual scheduling confirmations; a planned post is not a scheduled post.
   - [ ] Add links to published posts and review engagement and game plays after 24 hours and seven days.
6. At each playable milestone, refresh the marketing assets and release notes. Never announce unshipped features as playable or publish automatically without approval.
7. Before public launch, verify the playable build, download link, studio identity, mobile compatibility where applicable, and post URLs. Use the tracking fields in `docs/MARKETING.md` for accountability.
