class_name Pickup
extends Area2D
## Dropped heart or coin. Pops out of whatever dropped it, falls to the
## ground (hearts drift down swaying, coins drop straight), sits there, then
## blinks and expires. Spawn with Pickup.spawn().
##
## Hearts heal one heart (2 half-hearts). Coins are barter currency.

enum Kind { HEART, COIN }

const SHEET := preload("res://assets/sprites/kenney_pixel_platformer/tilemap_packed.png")
const REGIONS := {
	Kind.HEART: Rect2(4 * 18, 2 * 18, 18, 18),
	Kind.COIN: Rect2(11 * 18, 7 * 18, 18, 18),
}
const PLAYER_LAYER := 2
const GROUND_MASK := 1 | 32 # world + one-way
const LIFETIME := 10.0
const BLINK_AT := 7.0
const PICKUP_DELAY := 0.25 # let it pop out before it can be grabbed
const HEART_HEAL := 2
## Coin combo: grabs within COMBO_WINDOW seconds of the last climb these
## semitones (a major pentatonic run), so a spill rings out instead of clattering.
const COIN_COMBO_STEPS: Array[int] = [0, 2, 4, 7, 9, 12]
const COIN_COMBO_WINDOW := 0.6

static var _coin_combo := 0
static var _coin_combo_time := -100.0

var kind: Kind = Kind.HEART
var amount := 1

var _velocity := Vector2.ZERO
var _landed := false
var _age := 0.0
var _sway := 0.0
var _sprite: Sprite2D


## Plays the coin sound, pitched up one step per coin grabbed in quick
## succession (resets after COIN_COMBO_WINDOW). Used by every coin source.
static func play_coin_sound() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _coin_combo_time > COIN_COMBO_WINDOW:
		_coin_combo = 0
	var semitones: int = COIN_COMBO_STEPS[mini(_coin_combo, COIN_COMBO_STEPS.size() - 1)]
	# Only advance the combo when the sound actually played (not on cooldown).
	if Sfx.play(&"coin", -1.0, 0.0, pow(2.0, semitones / 12.0)):
		_coin_combo += 1
		_coin_combo_time = now


## Drops a pickup at `at`, popping out in a small arc.
static func spawn(context: Node, at: Vector2, p_kind: Kind, p_amount: int = 1) -> Pickup:
	var p := Pickup.new()
	p.kind = p_kind
	p.amount = p_amount
	p._velocity = Vector2(randf_range(-40.0, 40.0), -110.0 if p_kind == Kind.COIN else -70.0)
	p._sway = randf() * TAU
	var host := context.get_tree().current_scene if context.get_tree().current_scene else context.get_parent()
	host.add_child.call_deferred(p)
	p.position = at
	return p


func _ready() -> void:
	add_to_group("pickup")
	z_index = 4
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitoring = false # switched on after PICKUP_DELAY; catches a player already standing here
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.region_rect = REGIONS[kind]
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _age > BLINK_AT:
		_sprite.visible = fmod(_age, 0.2) < 0.12
	if _age > PICKUP_DELAY and not monitoring:
		set_deferred("monitoring", true)
	if _landed:
		return
	if kind == Kind.HEART and _velocity.y > 0.0:
		# Drift down like a feather.
		_sway += delta * 5.0
		_velocity.y = minf(_velocity.y + 200.0 * delta, 40.0)
		_velocity.x = sin(_sway) * 30.0
	else:
		_velocity.y = minf(_velocity.y + 500.0 * delta, 300.0)
		_velocity.x = move_toward(_velocity.x, 0.0, 30.0 * delta)
	var step := _velocity * delta
	# Land on whatever is below (world or one-way platforms).
	if step.y > 0.0:
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 8.0 + step.y), GROUND_MASK)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position = Vector2(global_position.x + step.x, hit["position"].y - 8.0).round()
			_landed = true
			return
	global_position += step


func _on_body_entered(body: Node2D) -> void:
	if _age < PICKUP_DELAY or not body.is_in_group("player"):
		return
	match kind:
		Kind.HEART:
			if body.has_method("_heal"):
				body._heal(HEART_HEAL * amount)
			CombatFX.burst(self, global_position, 10.0, Color(1, 0.45, 0.4), 1.0, 5, 0.25)
		Kind.COIN:
			GameManager.add_coins(amount)
			Pickup.play_coin_sound()
			CombatFX.burst(self, global_position, 8.0, Color(1, 0.85, 0.3), 1.0, 3, 0.2)
	queue_free()
