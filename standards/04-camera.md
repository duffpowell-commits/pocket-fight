# Camera (standard 2)

- Smooth follow with look-ahead.
- Never passes through walls: cuts in front of them.
- Frames the current target: pulls back to keep both on screen.
- Shakes on impact.

Godot today: `scripts/camera_rig.gd`. Checks: `CAMERA SMOOTH`, `CAMERA WALL`, `CAMERA FRAME PASS`.
