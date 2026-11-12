class_name ParallaxMotes
extends Node2D
## Code-drawn drifting specks for a parallax layer: Hel's embers, Yggdrasil's
## leaves, the sky's wind streaks, Valhalla's golden sparks. The motes live in a
## `region` that wraps on both axes; put this under a Parallax2D whose
## repeat_size equals `region` and the field tiles endlessly while she climbs.

## Wrapping area, in pixels. Match the parent Parallax2D's repeat_size.
@export var region := Vector2(192, 216)
@export_range(1, 200) var count := 24
## Base drift in px/s (negative y rises).
@export var velocity := Vector2(0, -12)
## Per-mote random spread added to `velocity`.
@export var velocity_jitter := Vector2(4, 4)
## Side-to-side sway amplitude (px) and speed (rad/s).
@export var sway := 3.0
@export var sway_speed := 1.5
## Mote size in pixels; a length > 1 on x draws a streak.
@export var size := Vector2i(1, 1)
## Each mote picks one of these.
@export var colors: PackedColorArray = PackedColorArray([Color(0.8, 0.35, 0.12)])
## 0 = steady; otherwise motes flicker in and out at this rate (Hz).
@export var twinkle := 0.0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _phase := PackedFloat32Array()
var _color := PackedInt32Array()
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) ^ count
	for i in count:
		_pos.append(Vector2(rng.randf() * region.x, rng.randf() * region.y))
		_vel.append(velocity + Vector2(rng.randf_range(-1, 1) * velocity_jitter.x, rng.randf_range(-1, 1) * velocity_jitter.y))
		_phase.append(rng.randf() * TAU)
		_color.append(rng.randi() % maxi(colors.size(), 1))


func _process(delta: float) -> void:
	_time += delta
	for i in count:
		_pos[i] = Vector2(
				fposmod(_pos[i].x + _vel[i].x * delta, region.x),
				fposmod(_pos[i].y + _vel[i].y * delta, region.y))
	queue_redraw()


func _draw() -> void:
	if colors.is_empty():
		return
	for i in count:
		var phase := _phase[i]
		if twinkle > 0.0 and sin(_time * twinkle * TAU + phase * 3.0) < -0.3:
			continue
		var p := _pos[i] + Vector2(sin(_time * sway_speed + phase) * sway, 0.0)
		p = Vector2(fposmod(p.x, region.x), p.y).floor()
		draw_rect(Rect2(p, Vector2(size)), colors[_color[i]])
