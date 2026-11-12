@tool
extends WeaveArea
## Dresses unused stretches of the trunk's flanks with an odd branch, too far
## apart to climb, so the outside isn't a second way up but a fall can be caught.


func _init() -> void:
	area_name = "stray_branches"
	tags = PackedStringArray(["trunk"])
	inside = false
	for_main = false
	for_unused = true
	min_size = Vector2i(5, 8)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	if b.rng.randf() > 0.7:
		return
	var r := slot.rect
	var y := b.rng.randi_range(r.position.y + 3, r.end.y - 3)
	var x0 := r.end.x - 1 if slot.side < 0 else r.position.x
	var length := b.rng.randi_range(3, mini(6, r.size.x - 1))
	b.put(x0 - slot.side, y, LevelGenerator.SOLID) # stub against the bark
	for i in length:
		b.put(x0 + slot.side * i, y, LevelGenerator.PLATFORM)
