@tool
extends WeaveArea
## A broad two-storey hall: a one-way gallery walkway runs across the middle,
## broken by a gap, so the room reads as a lower and an upper level.


func _init() -> void:
	area_name = "gallery"
	tags = PackedStringArray(["trunk", "mountain"])
	weight = 0.8
	min_size = Vector2i(9, 11)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	var r := slot.rect
	b.fill(r, LevelGenerator.AIR)
	var row := r.end.y - r.size.y / 2
	var gap := b.rng.randi_range(r.position.x + 1, r.end.x - 4)
	for x in range(r.position.x, r.end.x):
		if x < gap or x > gap + 2:
			b.put(x, row, LevelGenerator.PLATFORM)
	# Beams: the walkway's ends sit on a solid corbel in each wall.
	b.put(r.position.x, row, LevelGenerator.SOLID)
	b.put(r.end.x - 1, row, LevelGenerator.SOLID)
