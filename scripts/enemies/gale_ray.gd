class_name GaleRay
extends Enemy
## A wide, flat ray of the sky realm that glides back and forth on the wind
## along a level lane, gently rising and falling. Its back is broad and calm:
## she can land on it and ride it (it's a one-way platform) across gaps her
## broken wings can't cross. Its underside and wingtips sting, so it's also a
## hazard for anyone fluttering up beneath it. Never attacks on purpose.
## Ride it, or cut it down from above (a meteor strike from its back works).

@export var glide_speed: float = 40.0
## How far it glides each way from where it was placed, in pixels.
@export var lane_half_width: float = 96.0
@export var bob_height: float = 3.0
@export var bob_speed: float = 1.6

const ONE_WAY_LAYER := 32

var _home := Vector2.ZERO
var _clock := 0.0
var _rider: CharacterBody2D


func _on_ready() -> void:
	uses_gravity = false
	_home = global_position
	collision_layer = 4 | ONE_WAY_LAYER # enemy + one-way platform: she can stand on it
	_clock = randf() * TAU


func _ai(delta: float) -> void:
	_clock += delta
	# A rider is carried by CharacterBody2D's own platform velocity; we only
	# track her so our back doesn't sting her.
	_rider = _standing_rider()

	play_row(1)
	anim_fps = 2.0
	var past_lane := (global_position.x - _home.x) * facing > lane_half_width
	if is_on_wall() or past_lane:
		facing = -facing
	velocity.x = facing * glide_speed
	var target_y := _home.y + sin(_clock * bob_speed) * bob_height
	velocity.y = clampf((target_y - global_position.y) * 3.0, -40.0, 40.0)


## The player, if she's standing on our back right now.
func _standing_rider() -> CharacterBody2D:
	var p := player() as CharacterBody2D
	if not p or not p.is_on_floor():
		return null
	for i in p.get_slide_collision_count():
		if p.get_slide_collision(i).get_collider() == self:
			return p
	return null


## The back is safe; only the underside and edges sting.
func _deal_contact_damage() -> void:
	var p := player()
	if p and (p == _rider or p.global_position.y < global_position.y - 4.0):
		return
	super()
