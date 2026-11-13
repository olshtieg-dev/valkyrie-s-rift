class_name VineWall
extends StaticBody2D
## A wall of living, rubbery vines (Yggdrasil's living wood). Slashes and even
## heavy blows just bounce off: only FIRE (the flame sword) burns it away,
## spreading over the whole wall before it crumbles to ash.
## Origin = top-left corner; size is in tiles.

const TILE := 16
const BURN_TIME := 1.1
const DARK := Color(0.1, 0.2, 0.08)
const VINE := Color(0.28, 0.52, 0.2)
const VINE_LIGHT := Color(0.45, 0.72, 0.3)
const THORN := Color(0.75, 0.65, 0.4)
const CHAR := Color(0.12, 0.08, 0.06)

@export var size_tiles := Vector2i(1, 4)

var burning := false
var _burn := 0.0     # 0..1 how far the fire has eaten it
var _wobble := 0.0
var _t := 0.0
var _iframes := 0.0
var _shape: CollisionShape2D
var _flames: Flames


func _ready() -> void:
	add_to_group("obstacle")
	collision_layer = 1
	collision_mask = 0
	var size := Vector2(size_tiles) * TILE
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)


func _process(delta: float) -> void:
	_t += delta
	_iframes = maxf(0.0, _iframes - delta)
	_wobble = move_toward(_wobble, 0.0, delta * 3.0)
	queue_redraw()


func take_hit(hit: Hit) -> void:
	if burning or _iframes > 0.0:
		return
	_iframes = 0.1
	if hit.element == Hit.Element.FIRE:
		ignite()
		return
	_wobble = 1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		var side := signf(p.global_position.x - (global_position.x + size_tiles.x * TILE / 2.0))
		var at := Vector2(global_position.x + (size_tiles.x * TILE if side > 0 else 0.0),
				clampf(p.global_position.y - 8.0, global_position.y, global_position.y + size_tiles.y * TILE))
		CombatFX.burst(self, at, 7.0, VINE_LIGHT, 1.0, 4, 0.15)
		if p.has_method("recoil") and not p.get("is_dive_attacking") and not hit.ranged:
			p.recoil(side)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	take_hit(Hit.make(amount, knockback))


func ignite() -> void:
	if burning:
		return
	burning = true
	_flames = Flames.new()
	_flames.rect = Rect2(Vector2.ZERO, Vector2(size_tiles) * TILE)
	_flames.rate = 70.0
	add_child(_flames)
	var tween := create_tween()
	tween.tween_property(self, "_burn", 1.0, BURN_TIME)
	tween.tween_callback(_crumble)


func _crumble() -> void:
	_shape.set_deferred("disabled", true)
	var size := Vector2(size_tiles) * TILE
	CombatFX.burst(self, global_position + size / 2.0, size.length() * 0.4, Color(0.35, 0.3, 0.28), 1.0, 12, 0.4)
	_flames.active = false
	# Let the last embers float off before going.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var size := Vector2(size_tiles) * TILE
	draw_rect(Rect2(Vector2.ZERO, size), DARK.lerp(CHAR, _burn))
	var sway := _wobble * 2.0 * sin(_t * 35.0)
	var vine := VINE.lerp(CHAR, _burn)
	var light := VINE_LIGHT.lerp(Color(0.9, 0.4, 0.15), _burn)
	for col in size_tiles.x:
		for strand in 3:
			var base_x := col * TILE + 3.0 + strand * 5.0
			for y in int(size.y):
				# Burnt pixels drop out from the top down.
				if _burn > 0.0 and float(y) / size.y < _burn * 1.2 - _hash(col * 3 + strand, y) * 0.3:
					continue
				var x := roundf(base_x + 2.0 * sin((y + strand * 7 + col * 5) * 0.35) + sway * (1.0 - y / size.y))
				draw_rect(Rect2(x, y, 2, 1), vine)
				if (y + strand * 5) % 9 == 0:
					draw_rect(Rect2(x, y, 1, 1), light)
				if (y + strand * 3) % 11 == 0:
					draw_rect(Rect2(x + (2 if strand % 2 == 0 else -1), y, 1, 1), THORN.lerp(CHAR, _burn))


func _hash(a: int, b: int) -> float:
	return float((a * 73856093 ^ b * 19349663) & 1023) / 1023.0
