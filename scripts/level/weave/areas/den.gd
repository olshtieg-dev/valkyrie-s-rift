@tool
extends WeaveArea
## A low snug den at the end of a detour: only the bottom of the slot is
## hollowed (up to its door), so the reward sits in a cosy pocket.


func _init() -> void:
	area_name = "den"
	tags = PackedStringArray(["trunk", "mountain"])
	for_main = false
	for_side = true
	weight = 1.5
	min_size = Vector2i(5, 5)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	var r := slot.rect
	var top := r.end.y - 5
	for p in slot.ports:
		top = mini(top, p.y - 4)
	top = clampi(top, r.position.y, r.end.y - 3)
	var room := Rect2i(r.position.x, top, r.size.x, r.end.y - top)
	b.fill(room, LevelGenerator.AIR)
	if room.size.x >= 6:
		b.put(room.position.x, room.position.y, LevelGenerator.SOLID)
		b.put(room.end.x - 1, room.position.y, LevelGenerator.SOLID)
	slot.room_rect = room
