# Studio marketing workflow (template)

Use with [docs/MARKETING.md](../docs/MARKETING.md). This is a **manual approval-first workflow**, not an active publishing integration.

## Each week
1. Choose a verified game build and create three short video briefs using `POST_TEMPLATE.md`.
2. Add one row per channel-specific post to `calendar.csv`; status starts `draft`.
3. Confirm footage, audio, caption, safe areas, accessibility, permissions and working CTA.
4. Request owner approval for the exact asset, caption, channel and proposed date. Set `approved` only after approval.
5. Schedule through an authorized platform integration or native scheduler (Buffer: drafts only; Duff taps post). Set `scheduled` only after saving the platform confirmation ID and exact local time.
6. Verify public post URL after release, then mark `published`.
7. Review at 24 hours and seven days; record metrics privately if sensitive.

## Status gates
`draft -> approved -> scheduled -> published`. `failed` is allowed after a scheduling or publishing error. A rejected item goes back to `draft`. Never infer status from a planned date. Never auto-publish solely because a CSV row exists.

## Automation design for future implementation
- **Inputs:** approved assets, per-platform copy, platform account identity, timezone-aware date, CTA.
- **Adapter:** one authorized publisher per supported platform; platform-specific media and rate-limit validation.
- **Safety:** approval token tied to an immutable asset checksum and caption; idempotency key per channel/post; dry-run default; no tokens in repo; retry with backoff; failure alerts; never silently reschedule.
- **Outputs:** scheduler confirmation, platform post ID, public URL, timestamp, status and audit log.
- **Verification:** check platform-reported status and public URL, never treat HTTP success alone as publication.
- **Analytics:** aggregate at 24h/7d, compare hooks, watch time and clicks; don't fabricate missing metrics.
- **Manual fallback:** if API access is absent, prepare drafts and a checklist for owner to schedule from their phone.

## Release integration
Before a game release, complete [RELEASE_MARKETING_CHECKLIST.md](RELEASE_MARKETING_CHECKLIST.md).
