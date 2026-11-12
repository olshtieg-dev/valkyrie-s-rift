class_name Dropper
extends Enemy
## Clings to a ceiling. When the player passes underneath it shakes loose
## (telegraph) and plummets, then crawls along whatever it lands on.
## Built for shafts: punishes climbing straight up without looking.

enum State { HANG, SHAKE, FALL, CRAWL }

@export var trigger_width: float = 28.0
@export var trigger_depth: float = 220.0
@export var shake_time: float = 0.3
@export var crawl_speed: float = 40.0
## Moves the upside-down sprite so it sits against the ceiling while hanging.
@export var hang_sprite_shift: float = 4.0

var _state := State.HANG
var _rest_position := Vector2.ZERO


func _on_ready() -> void:
	_rest_position = sprite.position
	uses_gravity = false # stuck to the ceiling until it lets go (no sag when staggered)
	sprite.flip_v = true
	sprite.position.y = _rest_position.y + hang_sprite_shift


func _ai(delta: float) -> void:
	match _state:
		State.HANG:
			velocity = Vector2.ZERO
			play_row(1)
			var d := to_player()
			if absf(d.x) < trigger_width and d.y > 0.0 and d.y < trigger_depth and can_see_player(trigger_depth + 20.0):
				play_sfx(&"enemy_screech_small", 1.3)
				_go(State.SHAKE)
		State.SHAKE:
			velocity = Vector2.ZERO
			play_row(0)
			sprite.position.x = _rest_position.x + roundf(sin(state_time * 80.0))
			if state_time >= shake_time:
				sprite.position = _rest_position
				sprite.flip_v = false
				uses_gravity = true
				play_sfx(&"enemy_fall")
				_go(State.FALL)
		State.FALL:
			apply_gravity(delta, 2.0)
			velocity.x = 0.0
			if is_on_floor():
				sprite.scale = Vector2(1.3, 0.7)
				create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.2)
				face_player()
				Sfx.stop(&"enemy_fall")
				play_sfx(&"enemy_thud", 1.2)
				_go(State.CRAWL)
		State.CRAWL:
			crawl(delta, crawl_speed)
			play_row(1)


## Frozen while still on the ceiling, the ice stays stuck up there.
func _frozen_falls() -> bool:
	return uses_gravity


func _go(s: State) -> void:
	_state = s
	enter_state()
