class_name BarkBeetle
extends Enemy
## A Yggdrasil beetle with a shell like bark. It ambles along branches; when
## the player is on its level it tucks in (telegraph) and rolls at her. Rolling,
## the shell is armor: slashes clink off, and it doesn't stop at ledges, so it
## bounces down shafts onto whoever is climbing below. When it unrolls it's
## dizzy for a moment and takes double damage. A meteor strike cracks it open
## mid-roll.

enum State { PATROL, CURL, ROLL, DIZZY }

@export var patrol_speed: float = 28.0
@export var roll_speed: float = 150.0
@export var sight: float = 140.0
@export var curl_time: float = 0.4
@export var roll_time: float = 2.2
@export var dizzy_time: float = 1.1
## Wall bounces before it gives up rolling early.
@export var max_bounces: int = 2

var _state := State.PATROL
var _bounces := 0
var _spin := 0.0


func damage_taken_multiplier() -> float:
	return 2.0 if _state == State.DIZZY else 1.0


func _ai(delta: float) -> void:
	sprite.position.x = 0.0
	match _state:
		State.PATROL:
			crawl(delta, patrol_speed)
			play_row(1)
			var d := to_player()
			if state_time > 0.6 and is_on_floor() and absf(d.y) < 24.0 and can_see_player(sight):
				face_player()
				play_sfx(&"enemy_swell", 0.75)
				_go(State.CURL)
		State.CURL:
			apply_gravity(delta)
			velocity.x = 0.0
			sprite.scale = Vector2(1.0, 0.85) if int(state_time * 20.0) % 2 == 0 else Vector2.ONE
			sprite.position.x = roundf(sin(state_time * 70.0))
			if state_time >= curl_time:
				sprite.scale = Vector2.ONE
				_set_shell(true)
				_bounces = 0
				play_sfx(&"enemy_roll")
				_go(State.ROLL)
		State.ROLL:
			if not armored: # a heavy hit cracked the shell
				_unroll()
				return
			apply_gravity(delta)
			if is_on_wall() or wall_ahead(7.0):
				_bounces += 1
				facing = -facing
				play_sfx(&"enemy_thud")
				CombatFX.shake(self, 1.0, 0.08)
			velocity.x = facing * roll_speed
			# Quarter-turn steps keep the pixels square.
			_spin += facing * roll_speed / 8.0 * delta
			sprite.rotation = roundf(_spin / (PI / 2.0)) * (PI / 2.0)
			if (state_time >= roll_time and is_on_floor()) or _bounces > max_bounces:
				_unroll()
		State.DIZZY:
			apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			play_row(2)
			sprite.position.x = roundf(sin(state_time * 12.0) * 1.5)
			if state_time >= dizzy_time:
				_go(State.PATROL)


func _unroll() -> void:
	Sfx.stop(&"enemy_roll")
	_set_shell(false)
	sprite.rotation = 0.0
	_spin = 0.0
	_go(State.DIZZY)


## Rolling shell = armor (see Enemy.armored), with the same steel outline.
func _set_shell(on: bool) -> void:
	armored = on
	if not sprite:
		return
	if on:
		var mat := ShaderMaterial.new()
		mat.shader = ARMOR_SHADER
		mat.set_shader_parameter("steel", armor_tint)
		sprite.material = mat
	else:
		sprite.material = null


func _go(s: State) -> void:
	_state = s
	enter_state()
