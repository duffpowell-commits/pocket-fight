# Analytics, crash hooks, offline (standards 9 and 12)

## Analytics and crash hooks
Log key events locally; detect a run that didn't close cleanly and report it next launch (offer
REPORT A BUG). Data leaves the phone only if the player turned on "share anonymous stats" AND the
game has an endpoint set. Random install id only, nothing personal.
Godot today: `Telemetry.event()`. Checks: `TELEMETRY PASS`, `test_telemetry_*`.

## Offline-first, no forced login
The whole game plays with no network and no account. Network features (updater, stats) fail
silently and never block play.
