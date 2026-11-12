@tool
extends WeaveArea
## Detour out into the air: from a knot-hole (or cave mouth) a branch or
## rock shelf runs out from the body, and the reward waits at its tip.


func _init() -> void:
	area_name = "branch_tip"
	tags = PackedStringArray(["trunk", "mountain"])
	inside = false
	for_main = false
	for_side = true
	weight = 1.0
	min_size = Vector2i(8, 5)


func carve(b: WeaveBuilder, slot: WeaveSlot) -> void:
	if slot.ports.is_empty():
		return
	var p := slot.ports[0]
	var out := slot.side
	var reach := mini(b.rng.randi_range(6, 10), slot.rect.size.x - 2)
	var x := p.x
	for i in reach:
		x = p.x + out * i
		if b.cell(x, p.y) == LevelGenerator.AIR:
			b.put(x, p.y, LevelGenerator.SOLID)
		for y in range(p.y - 3, p.y):
			b.put(x, y, LevelGenerator.AIR)
	var x0 := mini(x, x - out * 4)
	slot.room_rect = Rect2i(x0, p.y - 3, 5, 3)


func link(_b: WeaveBuilder, _slot: WeaveSlot) -> void:
	pass # walk out along the branch
