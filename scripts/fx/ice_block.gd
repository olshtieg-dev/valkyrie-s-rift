class_name IceBlock
extends Node2D
## Code-drawn block of ice encasing something (a frozen enemy, the slime
## boulder). Whole pixels only.
##
##   freeze_over()  ice climbs from the bottom up
##   thawing        cracks show and it shivers (set while about to thaw)
##   melt()         drips down and frees itself (fire / thaw timer)
##   shatter()      bursts into shards and frees itself (heavy hit)

const ICE := Color(0.62, 0.86, 1.0, 0.55)
const EDGE := Color(0.85, 0.96, 1.0, 0.9)
const SHINE := Color(1, 1, 1, 0.85)
const CRACK := Color(1, 1, 1, 0.95)
const FREEZE_TIME := 0.16

## Local rect the ice covers.
@export var rect := Rect2(-8, -8, 16, 16)
## 0..1, how far the ice has climbed from the bottom.
@export_range(0.0, 1.0) var fill := 1.0
var thawing := false
var _t := 0.0


func _ready() -> void:
	z_index = 1


func freeze_over() -> void:
	fill = 0.0
	create_tween().tween_property(self, "fill", 1.0, FREEZE_TIME).set_ease(Tween.EASE_OUT)
	CombatFX.burst(self, global_position + rect.get_center(), rect.size.length() * 0.45, EDGE, 1.0, 4, 0.18)


func melt() -> void:
	thawing = false
	var tween := create_tween()
	tween.tween_property(self, "fill", 0.0, 0.25)
	tween.tween_callback(queue_free)


func shatter() -> void:
	CombatFX.shards(self, global_position + rect.get_center(), EDGE)
	CombatFX.burst(self, global_position + rect.get_center(), rect.size.length() * 0.6, SHINE, 1.0, 10, 0.3)
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	# Shiver while thawing: whole-pixel jitter.
	position.x = (1.0 if int(_t * 30.0) % 2 == 0 else -1.0) if thawing else 0.0
	queue_redraw()


func _draw() -> void:
	if fill <= 0.0:
		return
	var h := roundf(rect.size.y * fill)
	var r := Rect2(rect.position.x, rect.end.y - h, rect.size.x, h)
	draw_rect(r, ICE)
	draw_rect(r, EDGE, false, 1.0)
	if fill < 1.0:
		return
	# Shine: a short diagonal of pixels near the top-left corner.
	for i in 3:
		draw_rect(Rect2(rect.position + Vector2(2 + i, 2 + i), Vector2.ONE), SHINE)
	draw_rect(Rect2(rect.position + Vector2(2, 6), Vector2.ONE), SHINE)
	if thawing:
		# Cracks + drips.
		var c := rect.get_center()
		draw_line(c + Vector2(-3, -4), c + Vector2(0, 0), CRACK, 1.0)
		draw_line(c + Vector2(0, 0), c + Vector2(3, 2), CRACK, 1.0)
		draw_line(c + Vector2(0, 0), c + Vector2(-1, 4), CRACK, 1.0)
		var drip := float(int(_t * 8.0) % 4)
		draw_rect(Rect2(Vector2(rect.position.x + 3, rect.end.y + drip), Vector2.ONE), EDGE)
		draw_rect(Rect2(Vector2(rect.end.x - 4, rect.end.y + fmod(drip + 2.0, 4.0)), Vector2.ONE), EDGE)
