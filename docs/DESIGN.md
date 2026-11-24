# Wildmade: baseline design (draft, Nov 23 2026)

Status: **agreed on paper, not built.** Lives on branch `explore/creature-lab` until Duff picks the
art method (two dragons made two ways are rendering in Forge: jobs `wm-dragon-*-20261123`).
This replaces the one-week creator test in docs/PITCH.md once Duff greenlights it.

## One line
Make a monster that is yours, raise it through a small 3D world, and let the way you fight
decide what it grows into.

## Duff's calls (Nov 23)
- Monsters looked too flat and plain as code-drawn shapes: they need painted, shaded art.
- More real animals and more myth, including several kinds of dragon (Eastern and Western at least).
- **Parts give moves.** What you build changes what it can do.
- **One partner**, not a team.
- **Free walking** in a 3D area (not a fixed path).
- Look: high-def 2D monsters in a 3D landscape. Cute, creepy and realistic all have a place:
  that range is the cub -> rookie -> champion stage.
- Art method: undecided, wants to see both (painted parts vs whole painted monster).

## How a monster stays one animal
1. **Body plan** (the skeleton): Beast (4 legs), Serpent, Winged, Upright, Bird, Swimmer.
   A part only fits the plan it was painted for.
2. **Family**: a matched set of head, limbs, tail and skin. Picking a family alone gives a finished animal.
3. **Up to 2 swapped parts** from another family on the same plan: the hybrid.
4. **One skin** (fur, scales, feathers, hide) and **one palette** (body, underside, accent) cover every part.
5. **Stage** reshapes everything together: cub (big head, round eyes), rookie, champion (longer,
   sharper, horns and plates grow in).
6. **Ink**: markings earned from wins, placed on the body like tattoos. Each is a small perk.
   This is the game's own signature (studio: Knife & Needle).

## Roster
Starting animals (the myths they grow into are in the Growth table):
| Family | Plan | Signature part -> move |
|---|---|---|
| Fox | Beast | Brush tail -> Feint (dodge, next hit stronger) |
| Bear | Beast | Heavy paws -> Maul (big hit, slow) |
| Hawk | Bird | Wings -> Gust (push back, cancel a wind-up) |
| Snake | Serpent | Coils -> Bind (enemy skips its heavy strike) |
| Lizard | Beast | Tail whip -> Sweep (hits and pushes back) |
| Stag | Beast | Antlers -> Charge |

Myth forms add a part and its move: Western dragon wings -> Gust and horns -> Charge;
Eastern dragon antlers + mane -> Storm call (hits over two turns); hydra heads -> a second attack.

Later, in rough order: wolf, big cat, stag, owl, turtle, toad, shark, bat, mantis, octopus;
wyvern, feathered serpent, sea serpent, hydra, wingless drake; griffin, phoenix, nine-tailed fox,
kirin, thunderbird, basilisk, three-headed hound, kraken, yeti, golem, jackalope.
All are real animals or old folklore. Names, looks and lore are our own.

## Fight (1v1, turn-based)
- The enemy shows its next action (wind-up, strike, guard). You answer with one of **3 moves**:
  a basic attack, a guard, and moves from your parts (pick 2 if you have more).
- Every build has the same total power. A part trades one strength for another (wings: weaker hit,
  better dodge). There is no wrong monster.
- Starting numbers (from the tested prototype): 30 HP, attack 5, strike 15, guard halves,
  part moves rest 2 turns. Attack-only must lose; reading the tell must win.

## Growth: real animals become myths (Duff's idea, Nov 23)
- You start with a **real animal** cub. Myths are not picked from a menu: they are earned.
- A win earns one **ink** mark. You choose where it goes.
- The game counts how you won: mostly attacks (Fierce), mostly guards (Warden), mostly part moves (Trickster).
- At 3 wins the cub becomes a rookie (still the animal, bigger and sharper). At 8 wins it becomes
  a **mythical form**, and the leading style picks which one.
- Your swaps, palette and ink carry through every stage, so two players' phoenixes never match.
- Before the change, the game shows a silhouette of where you are heading, so the choice is
  made by how you play, not by reading a guide.

| Starts as | Fierce | Warden | Trickster |
|---|---|---|---|
| Fox | Three-headed hound | Guardian fox spirit | Nine-tailed fox |
| Snake | Hydra | Eastern dragon | Basilisk |
| Lizard | Western dragon | Wingless drake | Wyvern |
| Hawk | Thunderbird | Phoenix | Griffin |
| Bear | Yeti | Stone golem | (open) |
| Stag | (open) | Kirin | Jackalope |

First build: **two lines only** (Snake and Lizard, which give the Eastern and Western dragons),
so 2 cubs + 2 rookies + 6 myths = 10 painted monsters, not 24.

## World
- One small 3D zone to walk freely with a thumb stick, monster following you. Painted flat
  sprites standing in a lit 3D place, soft focus top and bottom.
- 5 wild encounters you can see and walk into (no random battles), one boss, one rest spot.
- A run is about 10 minutes. A second zone unlocks 2 new families to mix in.

## Build order (each ends with a build on Duff's phone)
1. **Look test.** One family painted the chosen way, standing in the 3D zone. Duff judges it on
   his phone before anything else is built. (Rule: looks before plumbing.)
2. **Creator** on the new art: plan, family, 2 swaps, skin, palette, name, describe-it.
3. **Fight** with part moves, against 3 wild monsters.
4. **Zone**: free walk, 5 encounters, boss, ink, first evolution.

## What this costs
- It is no longer a one-week side test. Free walking and painted art make it a full game:
  roughly 4 to 6 sessions to step 4. Lethemoor is still marked as the active game, so Duff
  needs to say which one gets the hours.
- Painted parts mean fewer options at first (6 families), growing as art is made.
- Free in money: Forge renders cost nothing. Photo-to-monster still needs a paid service and stays out.

## Not in the first version
Teams, PvP, online, trading, breeding, a story campaign, more than 2 zones, voice.
