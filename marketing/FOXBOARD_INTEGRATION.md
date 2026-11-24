# Foxboard-first marketing production integration

Foxboard source: https://github.com/duffpowell-commits/Foxboard

## Verified starting capabilities (Foxboard README, 2026-11-23)
Phone-first, single-file browser art editor with layers, text, canvas presets, animation frames, PNG/GIF export, per-game style bibles, and GitHub game-art handoff. Forge creates images; Forge 3D produces draft GLBs. **No verified native video timeline, audio mixing, social scheduling, analytics, or platform authentication exists yet.** Do not claim those features are operational.

## Architecture and staged ownership
- **Foxboard:** creative workspace for campaign cards, vertical title/end cards, thumbnails, approved art and editable design templates. Extend with a 9:16 video editor, audio track, caption track, export worker and preview QA only after tests prove them.
- **Godot game repos:** provide verified build version, release notes, gameplay captures, screenshots, and the approved studio brand; never send signing keys.
- **Marketing tracker:** campaign IDs, source assets, approvals, publishing destinations, schedule and confirmation IDs; follow `marketing/README.md`.
- **Publish adapters (future):** server-side OAuth and tokens per platform, official API permissions, rate limiting, dry-run, idempotent scheduling, audit log, and verified publication URLs. Foxboard's static HTML alone must never contain social API secrets.
- **Analytics (future):** platform-permitted metrics and itch.io plays where authorized; show missing data as unknown.

## Implementation milestones
1. **M1 creative templates:** 1080x1920 Shorts/Reels/TikTok layout, 1920x1080 trailer end card, studio-branded thumbnail, platform-safe zones; editable project files and PNG export. Use approved brand assets.
2. **M2 video proof of concept:** import verified gameplay clip, trim/crop, captions, licensed audio, preview and export on a phone; test playable exported MP4 and audio. Evaluate browser/device limits before selecting a renderer.
3. **M3 content queue:** draft/approval records, per-channel copies and local timezone, no publish capability; export CSV.
4. **M4 platform connectors:** start with YouTube after account authorization and API review; add TikTok/Instagram only when supported. Owner approves each post and account.
5. **M5 analytics:** ingest only authorized metrics; show 24-hour and 7-day comparisons.

## Acceptance tests
- No account credentials or API tokens committed to public repos or embedded in exported art.
- A draft cannot become scheduled without exact-asset approval and a platform confirmation.
- Imported footage retains provenance; no invented gameplay.
- A sample 9:16 export displays correctly on Android; audio and captions are independently checked.
- Failed publish requests cannot duplicate posts.
- Every public URL and schedule status is verifiable.

## Immediate handoff
Create Foxboard implementation issues/PRs in the **Foxboard repository**, not this starter. Keep this file as the contract for games created from the template. Existing marketing schedule remains proposed, not active.
