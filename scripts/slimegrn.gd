extends CharacterBody2D


const SPEED = 60.0
const DOWN_RAY_X_OFFSET = 6.0
const MAX_FALL_SPEED = 600.0
var direction = 1
var is_dead = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var ray_cast_right = $RayCastright
@onready var ray_cast_left = $RayCastleft
@onready var ray_cast_down = $RayCastDown
@onready var hurtbox = $killzone

func _ready() -> void:
	add_to_group("enemy")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_direction(direction)
	_update_down_ray_position()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0
		if direction < 0 and ray_cast_left.is_colliding():
			_set_direction(1)
		elif direction > 0 and ray_cast_right.is_colliding():
			_set_direction(-1)

		_update_down_ray_position()
		ray_cast_down.force_raycast_update()
		if not ray_cast_down.is_colliding():
			_set_direction(-direction)
			_update_down_ray_position()

	velocity.x = direction * SPEED
	move_and_slide()

func take_damage(_damage: int, _knockback: Vector2) -> void:
	_die_and_reward()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_weapon"):
		_die_and_reward()

func _set_direction(new_direction: int) -> void:
	direction = 1 if new_direction >= 0 else -1
	animated_sprite.flip_h = direction < 0

func _update_down_ray_position() -> void:
	ray_cast_down.position = Vector2(DOWN_RAY_X_OFFSET * direction, 10)

func _die_and_reward() -> void:
	if is_dead:
		return
	is_dead = true
	_grant_wing_point()
	queue_free()

func _grant_wing_point() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_flutter_charge"):
		player.add_flutter_charge(1)
	elif player and player.has_method("add_flutter_slot"):
		player.add_flutter_slot(1)
