class_name Climber
extends Enemy
## Clings to a wall and crawls up and down it. When the player is level with it
## on the open side, it lunges off the wall, then keeps crawling on the floor.
## Lives in the shaft walls the player climbs past.

enum State { CLING, LUNGE, CRAWL }

@export var climb_speed: float = 40.0
@export var lunge_range: float = 110.0
@export var lunge_velocity: Vector2 = Vector2(170, -120)
@export var crawl_speed: float = 40.0

var _state := State.CLING
var _wall_side := -1 # -1 = wall on the left, 1 = on the right
var _climb_dir := -1.0
var _found_wall := false


func _on_ready() -> void:
	uses_gravity = false


## Runs on the first physics frame: tile collision doesn't exist yet in _ready.
func _find_wall() -> void:
	_found_wall = true
	if _ray(Vector2(-12, 0)):
		_wall_side = -1
	elif _ray(Vector2(12, 0)):
		_wall_side = 1
	else:
		# Dropped somewhere without a wall: just be a ground crawler.
		uses_gravity = true
		_go(State.CRAWL)
		return
	_orient()


func _ai(delta: float) -> void:
	if not _found_wall:
		_find_wall()
		velocity = Vector2.ZERO
		return
	match _state:
		State.CLING:
			play_row(1)
			velocity = Vector2(_wall_side * 20.0, _climb_dir * climb_speed)
			var blocked := _ray(Vector2(0, _climb_dir * 9.0))
			var wall_continues := _ray(Vector2(_wall_side * 12.0, 0), Vector2(0, _climb_dir * 8.0))
			if blocked or not wall_continues:
				_climb_dir = -_climb_dir
			var d := to_player()
			if absf(d.y) < 20.0 and signf(d.x) == -_wall_side and can_see_player(lunge_range):
				uses_gravity = true
				facing = -_wall_side
				velocity = Vector2(facing * lunge_velocity.x, lunge_velocity.y)
				sprite.rotation = 0.0
				play_sfx(&"enemy_lunge", 1.1)
				_go(State.LUNGE)
		State.LUNGE:
			apply_gravity(delta)
			if is_on_floor() and state_time > 0.1:
				_go(State.CRAWL)
		State.CRAWL:
			crawl(delta, crawl_speed)
			play_row(1)


func _orient() -> void:
	# Belly against the wall: the sheet's "down" (+y) points toward the wall.
	sprite.rotation = -_wall_side * PI / 2.0


func _ray(offset: Vector2, from_offset: Vector2 = Vector2.ZERO) -> bool:
	var from := global_position + from_offset
	var query := PhysicsRayQueryParameters2D.create(from, from + offset, WORLD_MASK)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Frozen while clinging, the ice stays stuck to the wall.
func _frozen_falls() -> bool:
	return uses_gravity


func _go(s: State) -> void:
	_state = s
	enter_state()
