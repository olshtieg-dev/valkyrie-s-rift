class_name GaleHawk
extends Enemy
## A sky-realm hawk that patrols high on the wind. When the player is below it
## in a shaft, it screeches and rises (telegraph), then stoops straight down
## like a falling spear. If it misses it hits the ground beak-first, sticks
## there dazed (double damage), then flaps back up to its perch. It punishes
## climbing straight up an open shaft: watch the sky, sidestep the dive, then
## punish it on the ground.

enum State { PATROL, WINDUP, DIVE, STUCK, RISE }

@export var patrol_speed: float = 35.0
@export var patrol_half_width: float = 40.0
## Horizontal window below it that triggers a dive.
@export var trigger_width: float = 36.0
@export var trigger_depth: float = 240.0
@export var windup_time: float = 0.45
@export var dive_speed: float = 320.0
@export var max_dive: float = 280.0
@export var stuck_time: float = 1.2
@export var rise_speed: float = 80.0

var _state := State.PATROL
var _home := Vector2.ZERO
var _clock := 0.0


func _on_ready() -> void:
	uses_gravity = false
	_home = global_position


func damage_taken_multiplier() -> float:
	return 2.0 if _state == State.STUCK else 1.0


func _ai(delta: float) -> void:
	_clock += delta
	sprite.position.x = 0.0
	match _state:
		State.PATROL:
			play_row(1)
			anim_fps = 6.0
			if is_on_wall() or (global_position.x - _home.x) * facing > patrol_half_width:
				facing = -facing
			velocity = Vector2(facing * patrol_speed, (_home.y + sin(_clock * 2.0) * 3.0 - global_position.y) * 3.0)
			var d := to_player()
			if state_time > 0.8 and absf(d.x) < trigger_width and d.y > 12.0 and d.y < trigger_depth and can_see_player(trigger_depth + 20.0):
				face_player()
				play_sfx(&"enemy_screech")
				_go(State.WINDUP)
		State.WINDUP:
			play_row(0)
			# Rises, wings beating, sliding over her; the dive line is set
			# when the windup ends, so a late sidestep dodges it.
			velocity = Vector2(clampf((_player_pos().x - global_position.x) * 5.0, -90.0, 90.0), -30.0)
			sprite.position.x = roundf(sin(state_time * 80.0))
			if state_time >= windup_time:
				play_sfx(&"enemy_dive")
				_go(State.DIVE)
		State.DIVE:
			velocity = Vector2(0, dive_speed)
			if is_on_floor() or get_slide_collision_count() > 0:
				velocity = Vector2.ZERO
				CombatFX.shake(self, 1.5, 0.1)
				CombatFX.burst(self, global_position + Vector2(0, 6), 7.0, Color(0.9, 0.9, 1.0), 0.5, 4, 0.15)
				Sfx.stop(&"enemy_dive")
				play_sfx(&"enemy_thud", 1.1)
				_go(State.STUCK)
			elif global_position.y - _home.y > max_dive:
				_go(State.RISE)
		State.STUCK:
			play_row(2)
			velocity = Vector2.ZERO
			sprite.position.x = roundf(sin(state_time * 9.0))
			if state_time >= stuck_time:
				_go(State.RISE)
		State.RISE:
			play_row(1)
			anim_fps = 10.0
			var to_home := _home - global_position
			if to_home.length() < 4.0:
				_go(State.PATROL)
			else:
				velocity = to_home.normalized() * rise_speed
				facing = 1 if to_home.x > 0.0 else -1


func _go(s: State) -> void:
	_state = s
	enter_state()
