class_name Crawler
extends Enemy
## Walks back and forth, turning at walls and ledges. The baseline mob.

@export var speed: float = 45.0


func _ai(delta: float) -> void:
	crawl(delta, speed)
	play_row(1)
