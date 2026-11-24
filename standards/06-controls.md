# Controls (standards 4 and 11)

## Responsive
- Input buffering: a press up to 0.15 s early still counts.
- Coyote time: jump up to 0.12 s after leaving an edge.
- Every action cancels into a dodge; presses during a stagger are queued.
Checks: `BUFFER`, `COYOTE`, `CANCEL PASS`.

## Controller support + remapping
- Every action works on touch, keyboard and gamepad. Games read named actions (`move_left`,
  `jump`, `attack`, `dodge`, `crouch`, `aim`, `pause`), never raw keys.
- Players remap keys and pad buttons in Settings -> CONTROLS; saved; reset to defaults.
- A **controls legend** lists each action and its current key/button: on by default, shows once a
  key or pad is used (touch players already see labelled buttons), follows remaps,
  Settings -> CONTROLS LEGEND turns it off. Gesture-only touch games add one-time hints instead.
Godot today: `Controls` autoload, `ControlsLegend.make([...])`.
Checks: `PAD`, `REMAP`, `LEGEND PASS`, `test_controls_*`.
