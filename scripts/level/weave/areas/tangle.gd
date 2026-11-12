@tool
extends WeaveArea
## A root cave: strands of root hang from the ceiling like a curtain. The
## ledges linking its doors cut a way through where they must.


func _init() -> void:
	area_name = "tangle"
	tags = PackedStringArray(["mountain"])
	for_side = true
	weight = 1.2
	min_size = Vector2i(6, 7)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	var r := slot.rect
	b.fill(r, LevelGenerator.AIR)
	var x := r.position.x + b.rng.randi_range(1, 2)
	while x < r.end.x - 1:
		var length := b.rng.randi_range(1, maxi(1, r.size.y / 2 - 1))
		for i in length:
			b.put(x, r.position.y + i, LevelGenerator.SOLID)
		x += b.rng.randi_range(2, 4)
