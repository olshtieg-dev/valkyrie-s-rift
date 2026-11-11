class_name FeatherBurst
extends Node2D
## A burst of small white pixel feathers that fly out, then see-saw down.
## Each feather swaps between three hand-placed pixel poses as it sways,
## so it stays crisp (no rotation). Frees itself when done.

const POSES := [
	# flat
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, -1), Vector2i(2, -1)],
	# tilted /
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, -1), Vector2i(3, -1)],
	# tilted \
	[Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1)],
]
const WHITE := Color(1, 1, 1)
const SHADE := Color(0.78, 0.84, 0.95)

var count := 28
var life := 2.6
var fade_time := 0.7

var _t := 0.0
var _feathers: Array = [] # [pos, vel, sway_phase, sway_rate, flip]


func _ready() -> void:
	z_index = 52
	for i in count:
		var angle := randf_range(-PI, 0.0) if i % 3 else randf() * TAU # mostly upward
		var speed := randf_range(50.0, 140.0)
		_feathers.append([
			Vector2(randf_range(-4, 4), randf_range(-6, 4)),
			Vector2.from_angle(angle) * speed,
			randf() * TAU,
			randf_range(4.0, 7.0),
			randf() < 0.5,
		])


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	for f: Array in _feathers:
		var v: Vector2 = f[1]
		v *= pow(0.12, delta)                  # heavy air drag
		v.y = move_toward(v.y, 22.0, 60.0 * delta) # drift down slowly
		f[1] = v
		f[2] += f[3] * delta
		var sway := sin(f[2]) * 18.0
		f[0] += (v + Vector2(sway, 0)) * delta
	queue_redraw()


func _draw() -> void:
	var alpha := clampf((life - _t) / fade_time, 0.0, 1.0)
	for f: Array in _feathers:
		var s := sin(f[2])
		var pose: int = 0 if absf(s) < 0.35 else (1 if s > 0 else 2)
		var origin := (f[0] as Vector2).round()
		var pts: Array = POSES[pose]
		for j in pts.size():
			var p: Vector2i = pts[j]
			if f[4]:
				p.x = 3 - p.x
			var c: Color = SHADE if j < 2 else WHITE
			draw_rect(Rect2(origin + Vector2(p), Vector2.ONE), Color(c, alpha))
