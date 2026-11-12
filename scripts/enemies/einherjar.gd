class_name Einherjar
extends Enemy
## One of Valhalla's chosen dead, a warrior with a round shield, guarding the
## halls she breaks into. It advances on her shield-first: slashes from the
## front clink off the shield (and bounce her back). It turns slowly, so jump
## over it and strike its back, or come down on it with a meteor strike, which
## goes over the shield. A heavy hit from the front smashes the shield, and
## then it's open from every side. Close in, it draws back (telegraph) and
## lunges with its blade. Holds its ledge: it won't walk off an edge.

enum State { PATROL, ADVANCE, WINDUP, LUNGE, RECOVER }

@export var patrol_speed: float = 20.0
@export var advance_speed: float = 34.0
@export var sight: float = 170.0
@export var lunge_range: float = 30.0
@export var windup_time: float = 0.4
@export var lunge_speed: float = 190.0
@export var lunge_time: float = 0.16
@export var recover_time: float = 0.6
## Seconds it takes to turn around once she's behind it: the opening.
@export var turn_delay: float = 0.5
@export var shield_sprite: Sprite2D
## Steel color of the shield shards.
@export var shield_tint: Color = Color(0.996, 0.682, 0.204)

var shield_intact := true
var _state := State.PATROL
var _turn_timer := 0.0
var _rest_sprite := Vector2.ZERO


func _on_ready() -> void:
	_rest_sprite = sprite.position
	_place_shield()


func take_hit(hit: Hit) -> void:
	if shield_intact and not is_dying and not frozen and _from_front(hit):
		if hit.heavy:
			_break_shield()
		else:
			_deflect()
			return
	super(hit)


## Blows from in front, roughly level (not from above, like the meteor strike).
func _from_front(hit: Hit) -> bool:
	if stagger_timer > 0.0:
		return false
	var from := _player_pos()
	if hit.source is Node2D and not (hit.source as Node).is_in_group("player_weapon"):
		from = (hit.source as Node2D).global_position
	var d := from - global_position
	if d.y < -8.0 and absf(d.x) < 14.0:
		return false # coming down on its head
	return signf(d.x) == float(facing) and absf(d.x) > 2.0


func _break_shield() -> void:
	shield_intact = false
	play_sfx(&"enemy_armor_break", 0.85)
	if shield_sprite:
		CombatFX.shards(self, shield_sprite.global_position, shield_tint)
		shield_sprite.visible = false
	CombatFX.shake(self, 1.5, 0.1)
	stagger_timer = maxf(stagger_timer, 0.6)


func _ai(delta: float) -> void:
	apply_gravity(delta)
	sprite.position = _rest_sprite
	var sees := can_see_player(sight) and absf(to_player().y) < 40.0
	match _state:
		State.PATROL:
			play_row(1)
			anim_fps = 6.0
			patrol_step(patrol_speed) # crawl() minus gravity, applied above
			if sees:
				_go(State.ADVANCE)
		State.ADVANCE:
			play_row(1)
			anim_fps = 9.0
			_turn_slowly(delta)
			var d := to_player()
			var blocked := wall_ahead() or ledge_ahead()
			velocity.x = 0.0 if blocked or signf(d.x) != float(facing) else facing * advance_speed
			if signf(d.x) == float(facing) and absf(d.x) < lunge_range:
				play_sfx(&"enemy_growl", 1.0, -2.0)
				_go(State.WINDUP)
			elif not sees and state_time > 1.0:
				_go(State.PATROL)
		State.WINDUP:
			play_row(0)
			velocity.x = 0.0
			sprite.position = _rest_sprite + Vector2(-facing * 2.0, 0)
			if state_time >= windup_time:
				play_sfx(&"enemy_blade", 0.85)
				_go(State.LUNGE)
		State.LUNGE:
			play_row(1)
			anim_fps = 14.0
			velocity.x = 0.0 if ledge_ahead(9.0) else facing * lunge_speed
			if state_time >= lunge_time:
				_go(State.RECOVER)
		State.RECOVER:
			play_row(0)
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= recover_time:
				_go(State.ADVANCE if sees else State.PATROL)
	_place_shield()


## Turns to face her only after she's been behind it for `turn_delay`.
func _turn_slowly(delta: float) -> void:
	var dx := to_player().x
	if absf(dx) > 2.0 and signf(dx) != float(facing):
		_turn_timer += delta
		if _turn_timer >= turn_delay:
			facing = -facing
			_turn_timer = 0.0
	else:
		_turn_timer = 0.0


func _place_shield() -> void:
	if not shield_sprite:
		return
	var lunge := 2.0 if _state == State.LUNGE else 0.0
	shield_sprite.position = Vector2(facing * (6.0 + lunge), 1.0) + (sprite.position - _rest_sprite)
	shield_sprite.flip_h = facing < 0


func _go(s: State) -> void:
	_state = s
	enter_state()
