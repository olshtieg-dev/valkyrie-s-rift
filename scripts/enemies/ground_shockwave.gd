class_name GroundShockwave
extends Area2D
## A crest of rubble that runs along the floor away from a ground slam (the
## Draugr). Hurts the player on touch; jump over it. It dies at walls, at
## ledges, or when its time runs out. Not hittable: it isn't on layer 1.

const WORLD_MASK := 1
const FLOOR_MASK := 1 | 32 # world + one-way
const DUST := Color(0.75, 0.6, 0.5)
const DARK := Color(0.247, 0.149, 0.192) # #3f2631, the sprite outline color

## Pixels per second; the sign is the direction.
var speed: float = 150.0
## In half-hearts, like all damage to the player.
var damage: int = 2
var element: Hit.Element = Hit.Element.NONE
var life: float = 0.9

var _age := 0.0
var _hit_player := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player
	z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4) # origin sits on the floor
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	var dir := signf(speed)
	var space := get_world_2d().direct_space_state
	# Wall ahead?
	var ahead := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(dir * 6.0, -4), WORLD_MASK)
	# Floor still under the next step?
	var below := PhysicsRayQueryParameters2D.create(global_position + Vector2(dir * 4.0, -2), global_position + Vector2(dir * 4.0, 6), FLOOR_MASK)
	if _age >= life or not space.intersect_ray(ahead).is_empty() or space.intersect_ray(below).is_empty():
		_fizzle()
		return
	position.x += speed * delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _hit_player or not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	_hit_player = true
	body.take_damage(damage, Vector2(signf(speed), -1.0), element)


func _fizzle() -> void:
	set_physics_process(false)
	Sfx.play_at(&"enemy_crumble", global_position)
	CombatFX.burst(self, global_position + Vector2(0, -3), 5.0, DUST, 0.5, 3, 0.15)
	queue_free()


func _draw() -> void:
	# A jagged crest of whole-pixel blocks that flickers as it travels.
	var h := 3 + (int(_age * 30.0) % 3)
	var back := -signf(speed)
	draw_rect(Rect2(-4, -h - 1, 8, h + 1), DARK)
	draw_rect(Rect2(-3, -h, 6, h), DUST)
	draw_rect(Rect2(back * 5.0 - 1.0, -3, 2, 3), DUST)
	draw_rect(Rect2(back * 8.0 - 1.0, -2, 2, 2), DUST.darkened(0.2))
