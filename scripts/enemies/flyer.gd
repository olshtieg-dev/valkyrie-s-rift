class_name Flyer
extends Enemy
## Hovers around its spawn point. When the player comes into view it pulls back
## (telegraph), swoops at where the player was, then drifts home. Ignores
## gravity, so it guards open shafts where the player is fluttering.

enum State { HOVER, WINDUP, SWOOP, RETURN }

@export var sight: float = 150.0
@export var swoop_speed: float = 210.0
@export var swoop_time: float = 0.6
@export var windup_time: float = 0.35
@export var return_speed: float = 70.0
@export var cooldown: float = 0.8
@export var bob_height: float = 6.0

var _state := State.HOVER
var _home := Vector2.ZERO
var _swoop_dir := Vector2.ZERO
var _clock := 0.0


func _init() -> void:
	# Flyers are the realm's elemental creatures (frost wisps in the sky,
	# storm bats in Valhalla, fire bats in Hel). Untick per scene/instance.
	elemental_touch = true


func _on_ready() -> void:
	_home = global_position


func _ai(delta: float) -> void:
	_clock += delta
	anim_fps = 16.0 if _state == State.SWOOP else 7.0
	match _state:
		State.HOVER:
			play_row(1)
			var target := _home + Vector2(0, sin(_clock * 2.5) * bob_height)
			velocity = (target - global_position) * 4.0
			if state_time >= cooldown and can_see_player(sight):
				face_player()
				_swoop_dir = to_player().normalized()
				_go(State.WINDUP)
		State.WINDUP:
			play_row(0)
			velocity = -_swoop_dir * 25.0
			if state_time >= windup_time:
				_swoop_dir = to_player().normalized()
				play_sfx(&"enemy_swoop")
				_go(State.SWOOP)
		State.SWOOP:
			velocity = _swoop_dir * swoop_speed
			if get_slide_collision_count() > 0 or state_time >= swoop_time:
				_go(State.RETURN)
		State.RETURN:
			play_row(1)
			var to_home := _home - global_position
			if to_home.length() < 4.0:
				_go(State.HOVER)
			else:
				velocity = to_home.normalized() * return_speed
				facing = 1 if to_home.x > 0.0 else -1


func _go(s: State) -> void:
	_state = s
	enter_state()
