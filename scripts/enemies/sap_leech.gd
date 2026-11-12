class_name SapLeech
extends Enemy
## A fat leech glued to Yggdrasil's bark with sap. It inches along the wall to
## keep level with the player, then rears back (telegraph) and lashes out from
## the wall, reaching across the shaft. It never lets go: it guards a stretch of
## wall the player has to climb or wall-jump past. Hit it while it's stretched
## out, or from the side as you pass. Dropped somewhere with no wall, it just
## crawls.

enum State { CLING, WINDUP, LASH, RETRACT, CRAWL }

@export var inch_speed: float = 22.0
@export var sight: float = 120.0
## How close (vertically) she must be before it lashes.
@export var lash_band: float = 18.0
## How far the body stretches out from the wall, in pixels.
@export var reach: float = 22.0
@export var windup_time: float = 0.45
@export var lash_hold: float = 0.3
@export var retract_time: float = 0.35
@export var cooldown: float = 0.9
@export var crawl_speed: float = 25.0

var _state := State.CLING
var _wall_side := -1 # -1 = wall on the left, 1 = on the right
var _found_wall := false
var _rest_sprite := Vector2.ZERO
var _rest_hurtbox := Vector2.ZERO
var _stretch := 0.0 # 0 = resting on the wall, 1 = fully out


func _on_ready() -> void:
	uses_gravity = false


## Runs on the first physics frame: tile collision doesn't exist yet in _ready.
func _find_wall() -> void:
	_found_wall = true
	if _ray(Vector2(-12, 0)):
		_wall_side = -1
	elif _ray(Vector2(12, 0)):
		_wall_side = 1
	else:
		_let_go()
		return
	# Belly against the wall, head pointing out into the shaft.
	sprite.rotation = -_wall_side * PI / 2.0
	_rest_sprite = Vector2(-_wall_side * 6.0, 0)
	_rest_hurtbox = Vector2(-_wall_side * 5.0, 0)
	_apply_stretch()


func _ai(delta: float) -> void:
	if not _found_wall:
		_find_wall()
		velocity = Vector2.ZERO
		return
	if _state == State.CRAWL:
		crawl(delta, crawl_speed)
		play_row(1)
		return
	if not _ray(Vector2(_wall_side * 12.0, 0)):
		_let_go() # knocked or thawed off its wall
		return
	match _state:
		State.CLING:
			play_row(1)
			var d := to_player()
			var dir := 0.0
			if can_see_player(sight):
				if absf(d.y) > 4.0:
					dir = signf(d.y)
				if absf(d.y) < lash_band and state_time > cooldown:
					play_sfx(&"enemy_swell", 0.8)
					_go(State.WINDUP)
			# Keep to the wall: stop where it ends or something blocks the way.
			if dir != 0.0 and (_ray(Vector2(0, dir * 10.0)) or not _ray(Vector2(_wall_side * 12.0, 0), Vector2(0, dir * 9.0))):
				dir = 0.0
			velocity = Vector2(_wall_side * 20.0, dir * inch_speed)
		State.WINDUP:
			velocity = Vector2(_wall_side * 20.0, 0)
			_stretch = -0.15 # rears back into the bark
			_apply_stretch()
			sprite.position.y += roundf(sin(state_time * 60.0))
			if state_time >= windup_time:
				play_sfx(&"enemy_lunge", 0.8)
				_go(State.LASH)
		State.LASH:
			velocity = Vector2(_wall_side * 20.0, 0)
			_stretch = minf(1.0, state_time / 0.1)
			_apply_stretch()
			if state_time >= 0.1 + lash_hold:
				_go(State.RETRACT)
		State.RETRACT:
			velocity = Vector2(_wall_side * 20.0, 0)
			_stretch = maxf(0.0, 1.0 - state_time / retract_time)
			_apply_stretch()
			if _stretch <= 0.0:
				_go(State.CLING)


## Moves the sprite and the hurtbox out from the wall by `_stretch`.
func _apply_stretch() -> void:
	var out := Vector2(-_wall_side * roundf(_stretch * reach), 0)
	sprite.position = _rest_sprite + out
	set_hurtbox_offset(_rest_hurtbox + out)


func _let_go() -> void:
	_found_wall = true
	uses_gravity = true
	_stretch = 0.0
	sprite.rotation = 0.0
	_rest_sprite = Vector2(0, -6) # upright: the slug's frame is 23px tall
	_rest_hurtbox = Vector2(0, -1)
	_apply_stretch()
	_go(State.CRAWL)


func _ray(offset: Vector2, from_offset: Vector2 = Vector2.ZERO) -> bool:
	var from := global_position + from_offset
	var query := PhysicsRayQueryParameters2D.create(from, from + offset, WORLD_MASK)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Frozen while glued to the bark, the ice stays stuck to the wall.
func _frozen_falls() -> bool:
	return uses_gravity


func _go(s: State) -> void:
	_state = s
	enter_state()
