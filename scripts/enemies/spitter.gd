class_name Spitter
extends Enemy
## Rooted turret. Swells up (telegraph), then spits a slow glob at the player.
## Swing at a glob to bat it back: reflected globs hurt enemies.

enum State { IDLE, WINDUP, COOLDOWN }

@export var sight: float = 220.0
@export var windup_time: float = 0.5
@export var fire_interval: float = 1.8
@export var projectile_speed: float = 120.0
@export var projectile_damage: int = 2 # half-hearts

var _state := State.IDLE


func _ai(delta: float) -> void:
	apply_gravity(delta)
	velocity.x = 0.0
	match _state:
		State.IDLE:
			play_row(1)
			sprite.scale = Vector2.ONE
			if can_see_player(sight):
				face_player()
				_go(State.WINDUP)
		State.WINDUP:
			play_row(0)
			face_player()
			var swell := 1.0 + 0.25 * (state_time / windup_time)
			sprite.scale = Vector2(swell, swell)
			if state_time >= windup_time:
				_fire()
				sprite.scale = Vector2.ONE
				_go(State.COOLDOWN)
		State.COOLDOWN:
			play_row(1)
			if state_time >= fire_interval:
				_go(State.IDLE)


func _fire() -> void:
	var glob := EnemyProjectile.new()
	glob.velocity = to_player().normalized() * projectile_speed
	glob.damage = projectile_damage
	glob.position = position + Vector2(0, 2)
	get_parent().add_child(glob)


func _go(s: State) -> void:
	_state = s
	enter_state()
