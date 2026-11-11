class_name Hopper
extends Enemy
## Sits still until the player is near, crouches (telegraph), then leaps at them.
## Lands, rests, repeats. Good at punishing players who linger on ledges.

enum State { IDLE, WINDUP, AIR, REST }

@export var trigger_range: float = 130.0
@export var max_hop_x: float = 150.0
@export var hop_y: float = -290.0
@export var windup_time: float = 0.35
@export var rest_time: float = 0.55

var _state := State.IDLE


func _ai(delta: float) -> void:
	apply_gravity(delta)
	match _state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play_row(1)
			if is_on_floor() and state_time > 0.2 and can_see_player(trigger_range):
				face_player()
				_go(State.WINDUP)
		State.WINDUP:
			velocity.x = 0.0
			play_row(0)
			sprite.scale = Vector2(1.25, 0.75)
			if state_time >= windup_time:
				velocity = Vector2(clampf(to_player().x * 1.8, -max_hop_x, max_hop_x), hop_y)
				sprite.scale = Vector2(0.85, 1.15)
				_go(State.AIR)
		State.AIR:
			if is_on_floor() and velocity.y >= 0.0 and state_time > 0.1:
				velocity.x = 0.0
				sprite.scale = Vector2.ONE
				_go(State.REST)
		State.REST:
			velocity.x = 0.0
			if state_time >= rest_time:
				_go(State.IDLE)


func _go(s: State) -> void:
	_state = s
	enter_state()
