# The Magigonne

A flared, rune-banded hand cannon that fires seidr shots on mana. A side-route
ability, planned for **Yggdrasil** (Hel stays the test bench for core
features). Code: `scripts/combat/magigonne.gd` (gun, aim, mana),
`scripts/combat/magigonne_shot.gd` (the shot), `scripts/ui/mana_bar.gd` (HUD).

## How it serves the vision

- **Small detours, real rewards:** it's found at the end of a side route
  (an `ability:magigonne` AbilityShrine), never handed out on the main path.
- **Broken wings:** it works alongside the flutter rather than replacing it.
  A downward shot in the air kicks her up, but mana is the limit, so it's a
  crutch for her wings, not flight.
- **It's a climb:** the aim reaches nearly straight up, so shots work
  upward: switches, mobs and targets above her.

## Decisions (project lead, 2026-11-13)

- **Aim:** two modes, a player setting (F1 > Controller setup): **Sweep**
  (the classic cursor that swings up and down an arc by itself; let go to
  fire) and **Stick** (aim where you hold).
- **Freedom:** with mana in the bar she can fire anywhere, on the ground or
  in the air. Juggling the gun, the flutter and the recoil is up to the player.
- **Element:** shots take the active sword's element (the hammer's are heavy).
- **Mana:** 4 shots. Drops come from enemies once she owns it. When the bar is
  empty, one shot trickles back (every 3 s), so a room that needs a shot can
  never strand her.
- **Placement:** Yggdrasil, with its levels designed around it later.

## Testing

**Magigonne Range** (debug realm: F1 warp list or its Debug Room portal),
built in `scripts/level/magigonne_range.gd`. It grants the gun on entry and has:
a mana well, element sword pedestals, targets on the floor, up high, in the
air and in armor, a bank shot, a recoil-climb shaft (ledges at 10, 13 and 16
tiles), and a vine wall plus slime boulder.

## Still to do

- Carry mana between rooms (`GameManager` player state and saves). For now
  each room starts with a full bar.
- Mana vessels (bigger bar) as side-route finds.
- Range toys: switches and targets that only a shot can reach, more mobs.
- Place the find in Yggdrasil and design the levels around it.
