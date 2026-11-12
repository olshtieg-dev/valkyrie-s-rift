@tool
extends WeaveArea
## A tall hollow in the heartwood, fungus shelves growing off alternate walls.


func _init() -> void:
	area_name = "hollow"
	tags = PackedStringArray(["trunk"])
	weight = 1.0
	min_size = Vector2i(6, 10)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	var r := slot.rect
	b.fill(r, LevelGenerator.AIR)
	var y := r.end.y - 5
	var left := b.rng.randf() < 0.5
	while y > r.position.y + 2:
		var length := b.rng.randi_range(2, maxi(2, r.size.x / 2 - 1))
		for i in length:
			var x := r.position.x + i if left else r.end.x - 1 - i
			b.put(x, y, LevelGenerator.PLATFORM)
		left = not left
		y -= b.rng.randi_range(4, 5)
