class_name Draugr
extends Enemy
## A hulking dead thing of Hel, twice her height. It plods toward the player.
## Close enough, it rears up (a long, shuddering telegraph) and slams the
## ground: the screen shakes and a crest of rubble runs along the floor both
## ways. Jump the crests. After a slam it stands winded, the moment to hit it.
## Barely moved by knockback; takes many hits. Guards wide ledges and the
## floors at the bottom of shafts.

enum State { WALK, WINDUP, SLAM, WINDED }

@export var walk_speed: float = 18.0
@export var sight: float = 170.0
## Horizontal distance at which it starts a slam.
@export var slam_range: float = 64.0
@export var windup_time: float = 0.75
@export var winded_time: float = 1.0
@export var shockwave_speed: float = 150.0
@export var shockwave_life: float = 0.9
@export var shockwave_damage: int = 2 # half-hearts
@export var slam_cooldown: float = 1.4

var _state := State.WALK
var _rest_sprite := Vector2.ZERO


func _on_ready() -> void:
	_rest_sprite = sprite.position


func _ai(delta: float) -> void:
	apply_gravity(delta)
	sprite.position = _rest_sprite
	match _state:
		State.WALK:
			play_row(1)
			anim_fps = 5.0
			if can_see_player(sight):
				face_player()
				var d := to_player()
				if state_time >= slam_cooldown and is_on_floor() and absf(d.x) < slam_range and absf(d.y) < 60.0:
					play_sfx(&"enemy_growl", 0.7, 2.0)
					_go(State.WINDUP)
					return
				velocity.x = 0.0 if (wall_ahead() or ledge_ahead()) else facing * walk_speed
			else:
				patrol_step(walk_speed * 0.6) # crawl() minus gravity, applied above
		State.WINDUP:
			velocity.x = 0.0
			anim_fps = 0.0
			# Rears up a little higher each moment, shuddering.
			var lift := roundf(4.0 * minf(1.0, state_time / (windup_time * 0.7)))
			sprite.position = _rest_sprite + Vector2(roundf(sin(state_time * 70.0)), -lift)
			if state_time >= windup_time:
				_slam()
				_go(State.SLAM)
		State.SLAM:
			velocity.x = 0.0
			sprite.position = _rest_sprite + Vector2(0, 1)
			if state_time >= 0.12:
				_go(State.WINDED)
		State.WINDED:
			velocity.x = 0.0
			anim_fps = 2.0
			if state_time >= winded_time:
				_go(State.WALK)


func _slam() -> void:
	CombatFX.shake(self, 3.0, 0.25)
	play_sfx(&"enemy_slam")
	var feet := global_position + Vector2(0, surface_offset)
	CombatFX.burst(self, feet, 14.0, GroundShockwave.DUST, 0.4, 8, 0.25)
	if not is_on_floor():
		return
	for dir in [-1.0, 1.0]:
		var wave := GroundShockwave.new()
		wave.speed = dir * shockwave_speed
		wave.life = shockwave_life
		wave.damage = shockwave_damage
		wave.position = position + Vector2(dir * 10.0, surface_offset)
		get_parent().add_child(wave)


func _go(s: State) -> void:
	_state = s
	enter_state()
