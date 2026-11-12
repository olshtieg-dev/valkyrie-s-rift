class_name DashTrail
extends Node2D
## Speed streaks behind the dash strike, drawn in code: a few 1-pixel lines
## along the dash (any of 8 directions) that stretch from where the dash
## began to where she is, then shrink toward her and fade once it ends.
## Frees itself.
## Spawn with DashTrail.spawn(); call stop() when the dash ends.

## Streaks: sideways offset from her body's centre line (across the dash),
## length share and alpha. Horizontal dashes match the old rows at feet -12,
## -8, -4, -1.
const ROWS := [
	[-5.0, 1.0, 0.9],
	[-1.0, 0.7, 0.7],
	[3.0, 0.85, 0.8],
	[6.0, 0.5, 0.5],
]
## Her body's centre above her feet.
const CENTER := Vector2(0, -7)
const FADE_TIME := 0.16

var color := Color(0.85, 0.95, 1.0)

var _target: Node2D
var _start := Vector2.ZERO
var _tip := Vector2.ZERO
var _dir := Vector2.RIGHT
var _fading := false
var _t := 0.0


## A trail anchored where `who` stands now, following it until stop().
## `dir` is the dash direction (a facing sign as a float also works).
static func spawn(who: Node2D, dir: Variant, tint: Color) -> DashTrail:
	var trail := DashTrail.new()
	trail._target = who
	var v: Vector2 = dir if dir is Vector2 else Vector2(signf(float(dir)), 0.0)
	trail._dir = v.normalized() if v != Vector2.ZERO else Vector2.RIGHT
	trail.color = tint
	var tree := who.get_tree()
	var parent: Node = tree.current_scene if tree and tree.current_scene else who.get_parent()
	parent.add_child(trail)
	trail.global_position = who.global_position.round()
	trail._start = trail.global_position
	trail._tip = trail._start
	return trail


## The dash is over: the streaks catch up with her and fade.
func stop() -> void:
	_fading = true
	_t = 0.0


func _ready() -> void:
	z_index = 4 # behind her (5), over the tiles


func _process(delta: float) -> void:
	if not _fading:
		if is_instance_valid(_target) and _target.is_inside_tree():
			_tip = _target.global_position.round()
		else:
			stop()
	else:
		_t += delta
		if _t >= FADE_TIME:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / FADE_TIME, 0.0, 1.0) if _fading else 0.0
	var full := (_tip - _start).dot(_dir)
	if full < 1.0:
		return
	var tip_local := _tip - global_position + CENTER
	# Across the dash; kept pointing down/right so rows stack the same way
	# whichever way she goes.
	var across := Vector2(-_dir.y, _dir.x)
	if across.y < 0.0 or (across.y == 0.0 and across.x < 0.0):
		across = -across
	for row: Array in ROWS:
		# Each row is a share of the full length, measured back from her; the
		# tail end retracts toward her as it fades.
		var length: float = full * float(row[1]) * (1.0 - k)
		var behind := 3.0 # start a little behind her so she stays readable
		if length <= behind:
			continue
		var base := tip_local + across * float(row[0])
		var col := Color(color, color.a * float(row[2]) * (1.0 - k))
		var a := (base - _dir * behind).round()
		var b := (base - _dir * length).round()
		if a.y == b.y or a.x == b.x:
			# Straight: one crisp rect (pixel-exact, like the original).
			draw_rect(Rect2(a.min(b), (a - b).abs() + Vector2.ONE), col)
		else:
			_pixel_line(a, b, col)


## A 1-pixel line stepped on whole pixels (diagonals stay crisp).
func _pixel_line(a: Vector2, b: Vector2, col: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		draw_rect(Rect2(a.lerp(b, float(i) / maxf(steps, 1)).round(), Vector2.ONE), col)
