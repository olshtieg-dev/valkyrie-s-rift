@tool
class_name WeaveSlot
extends RefCounted
## One cell of the weave's brick grid: a band of rows in one lane (see
## WeaveBuilder). Inside the body its rect is the room's interior with walls
## left around it; on an open-air flank it spans the whole band.

enum Role { NONE, MAIN, SIDE }

## Lane index, left to right (0 = left flank).
var lane: int
## Band index in its lane, bottom first.
var band: int
## -1 left flank, 1 right flank, 0 inside the body.
var side: int
## Interior box in tiles. Inside slots keep this box's bottom row walkable:
## the solid row below it (`floor_row()`) is the room's floor.
var rect: Rect2i
var role: Role = Role.NONE
## Sub-area template that shapes this slot (null = left as solid body or plain air).
var area: WeaveArea
## Floor cells (solid or one-way tiles a player stands on) where connections
## and level openings arrive. The template's link() makes them reachable.
var ports: Array[Vector2i] = []
## Box handed to the generator as a side room (pickups + reward at its far
## end). Templates that carve less than `rect` set it; defaults to `rect`.
var room_rect := Rect2i()


func _init(p_lane: int, p_band: int, p_side: int, p_rect: Rect2i) -> void:
	lane = p_lane
	band = p_band
	side = p_side
	rect = p_rect


## True on the open-air flanks outside the body.
func is_outside() -> bool:
	return side != 0


## The row the player stands on at the bottom of this slot.
func floor_row() -> int:
	return rect.end.y


func is_used() -> bool:
	return role != Role.NONE
