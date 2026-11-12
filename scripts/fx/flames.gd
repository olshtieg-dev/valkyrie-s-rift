class_name Flames
extends Node2D
## Code-drawn pixel flames licking up from a rect (burning enemies, burning
## vines). Embers rise, shrink and go from yellow to red. Set `active` false
## to let the last embers die out; `free_when_done` then frees it.

const COLORS := [Color(1.0, 0.95, 0.55), Color(1.0, 0.7, 0.25), Color(0.95, 0.35, 0.15), Color(0.5, 0.15, 0.1)]

@export var rect := Rect2(-6, -6, 12, 12)
## Embers spawned per second per 16 px of width.
@export var rate := 40.0
var active := true
var free_when_done := true

var _embers: Array = [] # [pos: Vector2, life: float, max_life: float]
var _spawn := 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	if active:
		_spawn += delta * rate * maxf(rect.size.x, 4.0) / 16.0
		while _spawn >= 1.0:
			_spawn -= 1.0
			var life := randf_range(0.25, 0.5)
			var at := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.get_center().y, rect.end.y))
			_embers.append([at, life, life])
	for e: Array in _embers:
		e[0].y -= 28.0 * delta
		e[0].x += randf_range(-12.0, 12.0) * delta
		e[1] -= delta
	_embers = _embers.filter(func(e: Array) -> bool: return e[1] > 0.0)
	if not active and _embers.is_empty() and free_when_done:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for e: Array in _embers:
		var age: float = 1.0 - e[1] / e[2]
		var color: Color = COLORS[mini(int(age * COLORS.size()), COLORS.size() - 1)]
		var size := 2.0 if age < 0.5 else 1.0
		draw_rect(Rect2(e[0].round(), Vector2(size, size)), color)
