# Hel: realm map (draft)

> **Status: draft for the project lead to edit.** Room names, counts, and
> placements are proposals. Serves [`VISION.md`](../../VISION.md): Hel is the
> bottom of the climb. She fell here; she climbs out.

## The feel

Underground and cavernous: brimstone, ember light, lava pools, the drowned
dead. Tight at the bottom, opening into wider galleries, narrowing again into
the gate at the top. Every room on the main path ends **higher** than it
started.

Enemies: Cinder Mite and Draugr (Hel natives), plus Crawler, Hopper, Dropper,
Spitter, Climber, Flyer, and Charger as filler. Hazard: lava.

## Map

Read bottom to top. `══` main path, `──` detour, `[lock]` what it needs.

```
                                             ┌───────────────────┐
                                             │ H13 Hel's Breach  │ ══ north to Yggdrasil (ygg_01)
                                             │ SHAFT             │
                                             └─────────╥─────────┘
                                                       ║ opens when the boss falls
                                             ┌─────────╨─────────┐
                                             │ H12 Warden's Den  │  BOSS
                                             │ ARENA             │
                                             └─────────╥─────────┘
                                                       ║
  ┌───────────────────┐                      ┌─────────╨─────────┐
  │ H10 Draugr Hall   │══════════════════════│ H11 Móðguðr's Rest│
  │ CAVERN hall       │          east → west │ NPC + shrine      │
  │ (heart alcove)    │                      └───────────────────┘
  └─────────╥─────────┘
            ║
  ┌─────────╨─────────┐          ┌───────────────────┐
  │ H04 Ember Hub     │─[slime]──│ H07 Sealed Cache  │
  │ CAVERN, 4 exits   │   east   │ TREASURE          │
  │ shrine (save)     │          │ Ember Mail        │
  └──╥──────────╥─────┘          └───────────────────┘
     ║ south    ║ west
     ║    ┌─────╨─────────────┐  ┌───────────────────┐
     ║    │ H05 Cinder Hall   │──│ H06 Ash Chimney   │
     ║    │ SURFACE hallway   │  │ side SHAFT, climb │
     ║    └───────────────────┘  │ ability: DASH     │
     ║                           └───────────────────┘
  ┌──╨────────────────┐          ┌───────────────────┐
  │ H02 The Pit       │──────────│ H03 Frozen Hollow │
  │ CLIMB (tall)      │   east   │ side CAVERN       │
  └─────────╥─────────┘          │ Ice Rapier        │
            ║                    └───────────────────┘
  ┌─────────╨─────────┐          ┌───────────────────┐
  │ H08 Brimstone     │──[dash]──│ H09 Ember Forge   │
  │ Depths · CAVERN   │   east   │ TREASURE          │
  │ lava, draugr      │          │ Flame Greatsword  │
  └─────────╥─────────┘          └───────────────────┘
            ║
  ┌─────────╨─────────┐
  │ hel_02 Brimstone  │  the original test level,
  │ Ascent · CAVERN   │  kept as built
  └─────────╥─────────┘
            ║
  ┌─────────╨─────────┐
  │ H01 Where She     │  START
  │ Fell · CAVERN     │
  └───────────────────┘
```

The drawing is schematic: lines show which rooms connect and the vertical
order. The **Rooms** table below gives the exact exit sides. In the game,
H05 runs west from the hub and H06 is west of H05.

H05 is a short side hallway off the hub, so the dash detour is two rooms deep
(H04 → H05 → H06). It isn't part of the main path.

## Progression (what unlocks what)

| Order | Get | Where | Opens |
|---|---|---|---|
| 1 | **Ice Rapier** | H03, an easy first detour | Freezes slime boulders. Freeze, then meteor-strike to shatter: H04 → H07 |
| 2 | **Dash** | H06, a harder detour off H05 | Dash gap: H08 → H09 |
| 3 | **Ember Mail** | H07, behind the slime gate | Half lava damage: makes H08 and H12 forgiving |
| 4 | **Flame Greatsword** | H09, behind a dash gap | Burns vine walls: **pays off in Yggdrasil**, whose detours are vine-gated |
| — | Heart container | H10, a lava-crossing alcove (optional) | +1 heart before the boss |

The rule: the main path never needs a find. Every lock guards a detour, and
every find either opens a later Hel detour or pays off in Yggdrasil.

## Rooms

Sizes are in tiles (16 px), width × height. Exit names follow the generator's
anchors (`west` / `east` / `north` / `south`). Extra exits on the same side
are carved by hand after baking and named `east_low`, `east_high`, and so on.
An exit's `target_spawn` is the anchor name of the side you arrive on.

| Room | Type / style | Size | Exits → target (spawn) | Contents |
|---|---|---|---|---|
| **H01** Where She Fell | Start · CAVERN | 40×30 | north → hel_02 (south) | Landing spot, no enemies. A safe place to learn jump and flutter. The game's main scene. |
| **H08** Brimstone Depths | Ascent · CAVERN | 64×100 | south → hel_02 (north) · east → H09 (west) `[dash]` · north → H02 (south) | Lava, draugr on wide ledges, chargers. The second ascent. |
| **H09** Ember Forge | Treasure · CAVERN | 40×28 | west → H08 (east) | **Flame Greatsword** on a pedestal in an old forge. |
| **hel_02** Brimstone Ascent | Ascent · CAVERN | 64×100 | south → H01 (north) · north → H08 (south) | The original Brimstone Ascent test level, kept in the run as built. The first ascent; side route holds a Wing Feather. |
| **H02** The Pit | Shaft · CLIMB | 48×130 | south → H08 (north) · east → H03 (west) · north → H04 (south) | Crawlers, droppers, a flyer guarding the shaft. Teaches the climb. |
| **H03** Frozen Hollow | Side · CAVERN | 36×24 | west → H02 (east) | **Ice Rapier** pedestal. Cold blue pocket in the brimstone. A slime boulder to practise on. |
| **H04** Ember Hub | Hub · CAVERN | 90×60 | south → H02 (north) · west → H05 (east) · east → H07 (west) `[slime]` · north → H10 (south) | First shrine (save, barter). Wide, warm, layered ledges. |
| **H05** Cinder Hall | Hallway · SURFACE | 70×20 | east → H04 (west) · west → H06 (east) | Cinder mite swarms, lava pools in the floor. |
| **H06** Ash Chimney | Side shaft · SHAFT | 24×90 | east (at the bottom) → H05 (west) | Hard flutter climb to an **Ability Shrine: dash** at the top. The hardest platforming in Hel. |
| **H07** Sealed Cache | Treasure · CAVERN (small) | 30×24 | west → H04 (east) | **Ember Mail**. Coins. One spitter. |
| **H10** Draugr Hall | Hall · CAVERN (low, wide) | 80×30 | south → H04 (north) · east → H11 (west) | A gauntlet: draugr and cinder mites. Heart container. |
| **H11** Móðguðr's Rest | Rest · CAVERN (small) | 36×24 | west → H10 (east) · north → H12 (south) | Second shrine. **NPC: Móðguðr**, the giantess who guards the road of the dead, surprised to see someone climbing out. She warns about Garmr. No enemies. |
| **H12** Garmr's Den | Boss · ARENA | 60×24 | south → H11 (north) · north → H13 (south), locked until the boss falls | **Boss: Garmr**, the hound chained at Hel's gate. Three draugr stand in until Garmr exists. |
| **H13** Hel's Breach | Exit · SHAFT | 24×60 | south → H12 (north) · north → **ygg_01** (south) | A short, quiet climb into the first roots. Light changes from ember to green. |

14 rooms: 9 on the main path, plus 5 detours.

**Play order (project lead, 2026-11-12):** H01 Where She Fell → hel_02 Brimstone
Ascent → H08 Brimstone Depths → H02 The Pit → H04 Ember Hub → H10 → H11 →
H12 → H13 → ygg_01. Detours: H09 off H08; H03 off H02; H05 → H06 and H07 off
H04. The old `hel_01` (The Pit) is off the path: debug warp only, its north
exit leads into hel_02.

## Not built yet

- **Boss.** There is no boss enemy yet. H12 needs one designed and built.
- **Boss-locked exit.** H13's door needs a "locked until the boss falls" exit.
- **Hubs with 5 exits.** H04 uses 4. A 5th means a hand-carved exit, or
  extending the generator so a side can have several openings.
- **Dash gaps.** Gaps too wide to cross without dash. These are hand-built
  in the baked rooms, using the reach checker (`scripts/level/reach_check.gd`)
  to confirm they really need dash.

## Mapping from the current test bed

| Now | Becomes |
|---|---|
| `hel_01` The Pit (CLIMB 48×130, seed 1013; finds: Ice Rapier + dash, slime gate) | **H02** The Pit. The finds move out into H03 and H06. |
| `hel_02` Brimstone Ascent (find: Flame Greatsword) | Kept as its own room in the run, right after H01 and before **H08** Brimstone Depths (which reuses its seed). The Flame Greatsword find moved into H09. |

## Test run (built 2026-11-12)

All 13 rooms exist as scenes in `levels/hel/h01_…` through `h13_…`, registered
as `hel_h01` to `hel_h13` and reachable from the debug room's Hel portals. They
still generate live from fixed seeds. Bake the ones you like with the
generator's **Save As New Level** button, or by pressing Generate and saving.

- **Built:** every exit and its return trip; the H04 → H07 slime gate (the
  generator's `east_gate`); every find; Móðguðr (`scripts/npc/npc.gd`) in H11.
- **Reach check:** every main-path exit is reachable with the Valkyrie Blade
  alone. Rooms entered from the side (H03, H05, H06, H07, H09, H11) aren't
  covered by the checker yet.
- **Stand-ins:** Garmr is three draugr, H12's north exit is always open, and
  the H08 → H09 dash gap isn't enforced.
- **Changed from the plan:** H07 is a small cavern (arenas give the find
  nowhere to stand), H08 keeps the old Brimstone Ascent cavern, H10 is a
  cavern so it can have a floor entrance, and H12 is shorter so the exit
  needs no flutters.
- **Reordered (2026-11-12):** the project lead liked the first Brimstone
  Ascent, so `hel_02` is back in the run as the first room after H01, followed
  by H08 (renamed **Brimstone Depths** so the two don't share a name), then
  H02. H04's north exit now leads straight to H10. The game starts
  in H01. `ygg_01`'s south exit leads back to H13.
- **Open question:** H08 now comes before the dash (H06), so its `[dash]`
  gap to H09 can't be enforced without locking the Flame Greatsword until
  the player backtracks. Decide whether H09 stays off H08.
- The old test level `hel_01` is still registered, off the main path.

## Decisions (project lead, 2026-11-12)

- 13 rooms is the scale for this first test run of Hel.
- The boss in H12 is **Garmr**.
- Hubs stay at 4 exits, one per side. Anything custom gets hand-edited into the baked room.
- The NPC in H11 is **Móðguðr**, the giantess who guards the road into Hel.
