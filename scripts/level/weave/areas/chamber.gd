@tool
extends WeaveArea
## A plain cave room with rounded upper corners and a few drips hanging from
## the ceiling. The fallback for any inside slot; also serves as a detour room.


func _init() -> void:
	area_name = "chamber"
	tags = PackedStringArray(["trunk", "mountain"])
	for_side = true
	weight = 1.0
	min_size = Vector2i(3, 3)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	var r := slot.rect
	b.fill(r, LevelGenerator.AIR)
	if r.size.y < 7 or r.size.x < 7:
		return
	# Round the two upper corners.
	for corner_x: int in [r.position.x, r.end.x - 1]:
		var inward := 1 if corner_x == r.position.x else -1
		b.put(corner_x, r.position.y, LevelGenerator.SOLID)
		b.put(corner_x + inward, r.position.y, LevelGenerator.SOLID)
		b.put(corner_x, r.position.y + 1, LevelGenerator.SOLID)
	# Drips: short stubs off the ceiling.
	for x in range(r.position.x + 2, r.end.x - 2):
		if b.rng.randf() < 0.18:
			for i in b.rng.randi_range(1, 2):
				b.put(x, r.position.y + i, LevelGenerator.SOLID)
