@tool
class_name WeaveArea
extends RefCounted
## A sub-area template for the weave styles (LevelGenerator WEAVE / MOUNTAIN).
## WeaveBuilder lays out the slots and the connections between them; a
## template only decides what one slot looks like inside.
##
## Contract:
##   - Stay inside `slot.rect` (connectors and links handle the walls).
##   - Inside slots: keep the rect's bottom row open with the floor below it
##     walkable, so doors at floor level and side-room rewards work.
##   - `slot.ports` are already known when carve() runs, so a template can
##     shape itself around its doors. link() must make every port reachable
##     from the floor (inside) or from the lowest port (flanks);
##     `WeaveBuilder.link_ports()` does that with jump-sized ledges.
##
## Adding a new sub-area type:
##   1. Create scripts/level/weave/areas/<name>.gd with `extends WeaveArea`.
##   2. In _init() set `area_name`, `tags`, `inside`, the roles it may fill
##      (`for_main`, `for_side`, `for_unused`), `weight` and `min_size`.
##   3. Override carve(), and fits() / link() if it needs to.
##   4. Add its script to `WeaveBuilder.AREA_SCRIPTS`.

## Name shown in debug dumps.
var area_name := "area"
## Bodies that offer this template: "trunk" (WEAVE) and/or "mountain" (MOUNTAIN).
var tags := PackedStringArray()
## Carved into the body (true) or placed in the open air of a flank (false).
var inside := true
## May sit on the main route.
var for_main := true
## May be a side detour (and hold its reward).
var for_side := false
## Dresses slots nothing uses (e.g. stray branches on the flanks).
var for_unused := false
## Relative chance among the templates that fit.
var weight := 1.0
## Smallest slot rect (tiles) this template works in.
var min_size := Vector2i(5, 5)


func allows(role: WeaveSlot.Role) -> bool:
	match role:
		WeaveSlot.Role.MAIN: return for_main
		WeaveSlot.Role.SIDE: return for_side
	return for_unused


func fits(slot: WeaveSlot) -> bool:
	return slot.rect.size.x >= min_size.x and slot.rect.size.y >= min_size.y


## Shape the slot. The default hollows out an inside slot and leaves a flank as air.
func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	if inside:
		b.fill(slot.rect, LevelGenerator.AIR)


## Make every port reachable. Runs after all slots are carved and connected.
func link(b: WeaveBuilder, slot: WeaveSlot) -> void:
	b.link_ports(slot)
