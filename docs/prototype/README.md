# Wildmade

A single-player HD 2D RPG about creating an adventurer and hatching a starter you designed.

## Run the creator prototype

Open this folder as a Godot 4.6 project and run its main scene. Choose Character or Starter, edit their options, and select Save duo. Both designs load on the next launch. On the Starter tab, Preview move shows how the selected body and tail perform the move using placeholder art.

Select Test fight to use your starter’s current signature move against the mill lurker. Watch the enemy’s intent and decide when to attack, guard, or use your signature move.

See [the design plan](docs/GAME_DESIGN_PLAN.md) for the Flooded Mill, combat balance goals, and later creator features.

## Duel balance check

Run `godot --headless --path . --script tools/check_duel_balance.gd` to replay the fixed-seed Splash and Climb matchups. The harness gives both sides the same HP and base damage. Its duels use simulated opponents and have no effect on the playable mill fight.

In 12,000 simulated duels, fixed first movers won 62.6–68.6% of their matches. Simultaneous damage removed that resolution advantage, but produced 28.8–32.4% draws under these rules. Both variants used the same scripted decision policy. Treat these figures as a baseline for turn-order design. Human playtests and other player strategies are still needed.
