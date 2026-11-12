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
## What it spits. AUTO = the realm's element (fire in Hel, ice in the sky,
## thunder in Valhalla, plain bile in Yggdrasil).
@export_enum("Auto:-1", "Plain:0", "Ice:1", "Fire:2", "Thunder:3") var projectile_element: int = -1

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
				play_sfx(&"enemy_swell", 0.9)
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
	glob.element = _spit_element()
	glob.position = position + Vector2(0, 2)
	get_parent().add_child(glob)
	play_sfx(&"enemy_spit")


func _spit_element() -> Hit.Element:
	if projectile_element >= 0:
		return projectile_element as Hit.Element
	var level := _level()
	return level.realm_element() if level else Hit.Element.NONE


func _go(s: State) -> void:
	_state = s
	enter_state()
