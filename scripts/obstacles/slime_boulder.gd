class_name SlimeBoulder
extends StaticBody2D
## A 2x2-tile slime plugging a passage. It never attacks and takes no damage:
## blades just wobble it and bounce her off, and landing on top springs her up
## (a movement tool in itself). To get rid of it:
##   ICE (rapier)   freezes it solid: no more bounce, a plain ice block
##   heavy hit      (hammer slash, meteor) shatters the frozen block for good
##   FIRE           thaws it back to slime
## The freeze wears off after `freeze_time`, so swap swords quickly.
## Origin = bottom center, so it sits on the floor where it's placed.

const SIZE := Vector2(32, 32)
const BOUNCE := -330.0
const BOUNCE_HELD := -430.0          # holding jump on landing
const THAW_WARNING := 1.5
const OUTLINE := Color(0.08, 0.24, 0.12)
const BODY := Color(0.33, 0.72, 0.36)
const SHADE := Color(0.24, 0.55, 0.28)
const LIGHT := Color(0.62, 0.94, 0.56)
const FROZEN_BODY := Color(0.55, 0.78, 0.8)

@export var freeze_time: float = 8.0
## Coins that spill out when it shatters.
@export var coin_reward: int = 2

var frozen := false
var _freeze_timer := 0.0
var _ice: IceBlock
var _wobble := 0.0
var _t := 0.0
var _top: Area2D
var _iframes := 0.0


func _ready() -> void:
	add_to_group("obstacle")
	collision_layer = 1 # solid, like the world (and swords scan layer 1)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0)
	add_child(shape)
	# Thin sensor just above the top: she's standing (or landing) on it.
	_top = Area2D.new()
	_top.collision_layer = 0
	_top.collision_mask = 2
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(SIZE.x - 4, 4)
	top_shape.shape = top_rect
	top_shape.position = Vector2(0, -SIZE.y - 2)
	_top.add_child(top_shape)
	add_child(_top)


func _physics_process(delta: float) -> void:
	_t += delta
	_iframes = maxf(0.0, _iframes - delta)
	_wobble = move_toward(_wobble, 0.0, delta * 2.5)
	if frozen:
		_freeze_timer -= delta
		if _ice:
			_ice.thawing = _freeze_timer < THAW_WARNING
		if _freeze_timer <= 0.0:
			thaw()
	else:
		for body in _top.get_overlapping_bodies():
			if body.is_in_group("player") and body.velocity.y >= -10.0 and body.has_method("spring"):
				body.spring(BOUNCE_HELD if Input.is_action_pressed("jump") else BOUNCE)
				_wobble = 1.0
	queue_redraw()


func take_hit(hit: Hit) -> void:
	if _iframes > 0.0:
		return
	_iframes = 0.1
	if frozen:
		if hit.heavy:
			_shatter()
		elif hit.element == Hit.Element.FIRE:
			thaw()
		else:
			if hit.element == Hit.Element.ICE:
				_freeze_timer = freeze_time
			CombatFX.burst(self, _hit_point(), 6.0, Color(0.9, 0.97, 1.0), 1.0, 3, 0.12)
		return
	if hit.element == Hit.Element.ICE:
		freeze()
		return
	# Rubbery: wobbles, bounces her off, no damage.
	_wobble = 1.0
	CombatFX.burst(self, _hit_point(), 7.0, LIGHT, 1.0, 4, 0.15)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("recoil") and not p.get("is_dive_attacking") and not hit.ranged:
		p.recoil(signf(p.global_position.x - global_position.x))


## Older damage callers.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	take_hit(Hit.make(amount, knockback))


func freeze() -> void:
	frozen = true
	_freeze_timer = freeze_time
	_wobble = 0.0
	_ice = IceBlock.new()
	_ice.rect = Rect2(-SIZE.x / 2.0 - 1, -SIZE.y - 1, SIZE.x + 2, SIZE.y + 1)
	add_child(_ice)
	_ice.freeze_over()


func thaw() -> void:
	frozen = false
	if _ice:
		_ice.melt()
		_ice = null
	_wobble = 1.0


func _shatter() -> void:
	if _ice:
		_ice.shatter()
		_ice = null
	CombatFX.shards(self, global_position + Vector2(0, -16), FROZEN_BODY)
	CombatFX.shake(self, 3.0, 0.2)
	for i in coin_reward:
		Pickup.spawn(self, global_position + Vector2(-6 + 12 * i, -12), Pickup.Kind.COIN)
	queue_free()


func _hit_point() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var side := signf(p.global_position.x - global_position.x) if p else 1.0
	return global_position + Vector2(side * SIZE.x * 0.45, -SIZE.y * 0.5)


func _draw() -> void:
	# Blob in whole pixels; wobble squashes it (visual only, the collider stays).
	var squash := roundf(_wobble * 3.0 * sin(_t * 28.0))
	var w := SIZE.x + squash * 2.0
	var h := SIZE.y - squash
	var body := FROZEN_BODY if frozen else BODY
	var shade := FROZEN_BODY.darkened(0.2) if frozen else SHADE
	var x0 := -w / 2.0
	# Outline then fill, corners stepped for a round silhouette.
	_rounded(x0, -h, w, h, OUTLINE)
	_rounded(x0 + 1, -h + 1, w - 2, h - 2, body)
	draw_rect(Rect2(x0 + 2, -6, w - 4, 4), shade)
	# Highlight
	var light := LIGHT if not frozen else Color(0.9, 0.98, 1.0)
	draw_rect(Rect2(x0 + 5, -h + 4, 6, 2), light)
	draw_rect(Rect2(x0 + 4, -h + 6, 2, 3), light)
	# Face: eyes open when soft, shut when frozen.
	var eye_y := -h * 0.55
	if frozen:
		draw_rect(Rect2(-7, eye_y + 1, 4, 1), OUTLINE)
		draw_rect(Rect2(3, eye_y + 1, 4, 1), OUTLINE)
	else:
		draw_rect(Rect2(-7, eye_y, 3, 4), OUTLINE)
		draw_rect(Rect2(4, eye_y, 3, 4), OUTLINE)
		draw_rect(Rect2(-7, eye_y, 1, 1), Color.WHITE)
		draw_rect(Rect2(4, eye_y, 1, 1), Color.WHITE)


func _rounded(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x + 4, y, w - 8, h), color)
	draw_rect(Rect2(x + 2, y + 1, w - 4, h - 1), color)
	draw_rect(Rect2(x + 1, y + 2, w - 2, h - 2), color)
	draw_rect(Rect2(x, y + 4, w, h - 4), color)
