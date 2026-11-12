@tool
extends WeaveArea
## Switchback root tunnels: the slot is filled with rock and hollowed into
## low passages stacked one above another, each joined to the next by a gap
## at alternating ends, so the way zigzags up from the floor to every door.
## Only for slots whose ports are all doors in the side walls.

const AIR := LevelGenerator.AIR
const SOLID := LevelGenerator.SOLID
## Most rows from one passage floor up to the next (her jump clears ~6-7).
const MAX_STEP := 5


func _init() -> void:
	area_name = "burrow"
	tags = PackedStringArray(["mountain", "trunk"])
	weight = 1.0
	min_size = Vector2i(7, 9)


func fits(slot: WeaveSlot) -> bool:
	if not super(slot):
		return false
	var r := slot.rect
	for p in slot.ports:
		if p.y < r.position.y + 3 or p.y > slot.floor_row():
			return false
		if p.x > r.position.x + 1 and p.x < r.end.x - 2:
			return false # not a wall door (an opening or a hole)
	return true


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	var r := slot.rect
	# Passage floors, lowest first: the room floor, then shelves no more than
	# MAX_STEP apart that land on every door sill.
	var sills: Array[int] = []
	for p in slot.ports:
		if p.y < slot.floor_row() and not sills.has(p.y):
			sills.append(p.y)
	sills.sort()
	sills.reverse()
	var floors: Array[int] = [slot.floor_row()]
	for sill in sills:
		var cur: int = floors.back()
		var gap := cur - sill
		if gap < 3:
			continue # a short hop up from this passage
		var n := ceili(gap / float(MAX_STEP))
		for k in range(1, n + 1):
			floors.append(cur - roundi(gap * float(k) / n))
	var top: int = maxi(r.position.y, floors.back() - 4)
	b.fill(r, SOLID)
	b.g._fill_rect(r.position.x, top, r.end.x - 1, r.end.y - 1, AIR)
	# No hazard pools in passages too low to jump them.
	for y in floors:
		b.g._protect_rect(r.position.x, y - 1, r.end.x - 1, y - 1)
	var at_left := b.rng.randf() < 0.5
	for i in range(1, floors.size()):
		var y: int = floors[i]
		var gap_x := r.position.x if at_left else r.end.x - 3
		for x in range(r.position.x, r.end.x):
			if x < gap_x or x > gap_x + 2:
				b.put(x, y, SOLID)
		at_left = not at_left


func link(_b: WeaveBuilder, _slot: WeaveSlot) -> void:
	pass # the switchbacks are the path
