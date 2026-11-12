@tool
extends WeaveArea
## A stretch of the open-air flank on the main route: bark ledges up the
## trunk, or switchback ledges up a cliff of the mountain. The ledges come
## from the default link between its ports.


func _init() -> void:
	area_name = "flank"
	tags = PackedStringArray(["trunk", "mountain"])
	inside = false
	min_size = Vector2i(4, 5)
