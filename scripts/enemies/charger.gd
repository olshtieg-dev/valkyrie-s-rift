class_name Charger
extends Enemy
## Patrols slowly. Spotting the player ahead on its level, it shudders (telegraph)
## then dashes. Slamming into a wall stuns it; stunned, it takes double damage.
## It stops at ledges rather than running off them. Heavy: resists knockback.

enum State { PATROL, WINDUP, DASH, STUN }

@export var patrol_speed: float = 30.0
@export var dash_speed: float = 270.0
@export var sight: float = 170.0
@export var windup_time: float = 0.45
@export var dash_time: float = 0.9
@export var stun_time: float = 1.0

var _state := State.PATROL


func damage_taken_multiplier() -> float:
	return 2.0 if _state == State.STUN else 1.0


func _ai(delta: float) -> void:
	sprite.position.x = 0.0
	match _state:
		State.PATROL:
			crawl(delta, patrol_speed)
			play_row(1)
			var d := to_player()
			if state_time > 0.5 and absf(d.y) < 28.0 and signf(d.x) == facing and can_see_player(sight):
				play_sfx(&"enemy_growl", 1.15)
				_go(State.WINDUP)
		State.WINDUP:
			apply_gravity(delta)
			velocity.x = 0.0
			play_row(0)
			sprite.position.x = roundf(sin(state_time * 90.0))
			if state_time >= windup_time:
				play_sfx(&"enemy_dash")
				_go(State.DASH)
		State.DASH:
			apply_gravity(delta)
			velocity.x = facing * dash_speed
			if is_on_wall() or wall_ahead(6.0):
				velocity.x = 0.0
				play_sfx(&"enemy_thud", 0.8)
				_go(State.STUN)
			elif is_on_floor() and ledge_ahead(10.0):
				velocity.x = 0.0
				_go(State.PATROL)
			elif state_time >= dash_time:
				_go(State.PATROL)
		State.STUN:
			apply_gravity(delta)
			velocity.x = 0.0
			play_row(2)
			if state_time >= stun_time:
				_go(State.PATROL)


func _go(s: State) -> void:
	_state = s
	enter_state()
