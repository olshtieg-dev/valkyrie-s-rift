class_name Burst
extends Node2D
## One-shot impact effect drawn in code: an expanding ring (optionally squashed
## flat for ground impacts) plus a spray of square pixel debris. Frees itself.
## Spawn through CombatFX rather than directly.

var radius := 24.0
var flatten := 1.0          # 1 = circle, < 1 = ellipse hugging the ground
var color := Color.WHITE
var duration := 0.25
var debris := 6
var debris_speed := 90.0
var debris_up_only := false
var ring_width := 2.0

var _t := 0.0
var _bits: Array = []       # [velocity, size]


func _ready() -> void:
	z_index = 6
	for i in debris:
		var angle := randf_range(PI, TAU) if debris_up_only else randf() * TAU
		var speed := randf_range(0.5, 1.0) * debris_speed
		_bits.append([Vector2.from_angle(angle) * speed, float(randi_range(1, 2))])


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - k, 3.0)
	var fade := Color(color, color.a * (1.0 - k))
	# Ring
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, flatten))
	draw_arc(Vector2.ZERO, maxf(1.0, radius * ease_out), 0.0, TAU, 24, fade, ring_width / maxf(flatten, 0.3))
	draw_set_transform(Vector2.ZERO)
	# Debris: whole-pixel squares under light gravity
	for bit: Array in _bits:
		var v: Vector2 = bit[0]
		var p := v * _t + Vector2(0, 160.0) * _t * _t
		var s: float = bit[1]
		draw_rect(Rect2(p.round() - Vector2(s, s) * 0.5, Vector2(s, s)), fade)
