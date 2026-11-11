class_name Enemy
extends CharacterBody2D
## Base for every mob. Enemy scenes are self-contained: drop one into a level,
## or list it in a LevelGenerator's enemy_scenes, and it works with no wiring.
##
## Subclasses implement _ai(delta), which sets `velocity`. The base handles
## health, hit flash, knockback stagger, hit-stop, contact damage, death and
## rewards. Killing an enemy refunds flutter charges, so fighting mid-air
## keeps the climb going.
##
## Sprites: any Sprite2D works. Multi-frame sheets use rows as row 0
## windup, row 1 idle/move, row 2 hurt (missing rows fall back to the last
## one). A single-frame sprite gets a whole-pixel bob instead, so pixels stay
## crisp (no scaling).

enum Placement { FLOOR, CEILING, WALL, AIR }

signal died(enemy: Enemy)
signal armor_broken(enemy: Enemy)

@export_group("Stats")
@export var max_health: int = 15
## In half-hearts (2 = one heart), like all damage to the player.
@export var contact_damage: int = 2
@export_range(0.0, 1.0) var knockback_resist: float = 0.0
## Flutter charges refunded to the player on kill.
@export var flutter_reward: int = 1
@export var score_reward: int = 0
## Optional pickup spawned where the enemy dies.
@export var drop_scene: PackedScene

@export_group("Drops")
## Chance of a heart on an ordinary kill.
@export_range(0.0, 1.0) var heart_drop_chance: float = 0.15
## Stylish kills always drop a heart: finishing it with a heavy hit (the
## meteor strike, later the hammer); the element system adds shatter/burn.
@export var heart_on_stylish_kill: bool = true
@export_range(0.0, 1.0) var coin_drop_chance: float = 0.5
@export var coin_drop_amount: int = 1

@export_group("Armor")
## Armored enemies shrug off sword slashes (clink + the player bounces off).
## A heavy hit (the player's meteor strike) shatters the armor; after that
## they take normal damage.
@export var armored: bool = false
## Steel color for the plating (outline) and the shards when it breaks.
@export var armor_tint: Color = Color(0.62, 0.7, 0.86)
## Stagger applied when the armor shatters, a window for follow-up slashes.
@export var armor_break_stagger: float = 0.7

@export_group("Placement")
## Where the generator puts this enemy.
@export var spawn_placement: Placement = Placement.FLOOR
## Distance from the origin to the collider edge that touches the spawn surface
## (bottom for FLOOR, top for CEILING, side for WALL).
@export var surface_offset: float = 11.0

@export_group("Body")
@export var uses_gravity: bool = true
@export var hurtbox_size: Vector2 = Vector2(12, 12)
@export var hurtbox_offset: Vector2 = Vector2(0, 5)

@export_group("Visuals")
@export var sprite: Sprite2D
@export var anim_fps: float = 8.0
## Set when the source art faces left, so flipping matches movement.
@export var art_faces_left: bool = false
## Whole-pixel bob for single-frame sprites (0 disables).
@export var bob_pixels: int = 1

const MAX_FALL_SPEED := 500.0
const HIT_IFRAMES := 0.12
const STAGGER_TIME := 0.2
const WORLD_MASK := 1
const FLOOR_MASK := 1 | 32 # world + one-way
const HITSTOP_SCALE := 0.05
const ARMOR_SHADER := preload("res://scripts/fx/armor.gdshader")

var health: int
var facing: int = 1
var stagger_timer := 0.0
var last_hit_element: Hit.Element = Hit.Element.NONE
var _heavy_hit_pending := false
var _killed_stylishly := false
var is_dying := false
var state_time := 0.0 # seconds since entering the current state (subclasses use it)

var _iframes := 0.0
var _anim_row := 1
var _anim_time := 0.0
var _hurtbox: Area2D
var _player: Node2D
var _sprite_offset := Vector2.ZERO


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	collision_layer = 4 # enemy
	z_index = 4
	_build_hurtbox()
	if sprite:
		_sprite_offset = sprite.offset
		if armored:
			var mat := ShaderMaterial.new()
			mat.shader = ARMOR_SHADER
			mat.set_shader_parameter("steel", armor_tint)
			sprite.material = mat
	_on_ready()


## Subclass hook, called at the end of _ready.
func _on_ready() -> void:
	pass


## Subclass hook: set velocity (and state) for this physics frame.
func _ai(_delta: float) -> void:
	if uses_gravity:
		apply_gravity(_delta)


## Subclass hook: multiplier on incoming damage (e.g. a stunned charger takes double).
func damage_taken_multiplier() -> float:
	return 1.0


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_iframes = maxf(0.0, _iframes - delta)
	state_time += delta
	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		if uses_gravity:
			apply_gravity(delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
	else:
		_ai(delta)
	move_and_slide()
	_deal_contact_damage()
	_animate(delta)


# --------------------------------------------------------------------------
# Damage
# --------------------------------------------------------------------------

## Entry point for Hit (see scripts/combat/hit.gd). Elements are recorded for
## the element system (freeze/burn) that builds on this.
func take_hit(hit: Hit) -> void:
	last_hit_element = hit.element
	if hit.heavy:
		take_heavy_hit(hit.damage, hit.knockback)
	else:
		take_damage(hit.damage, hit.knockback)


## A hit that breaks armor (the meteor strike). Plain take_damage otherwise.
func take_heavy_hit(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return
	var broke := armored
	if broke:
		_break_armor()
		_iframes = 0.0
	_heavy_hit_pending = true
	take_damage(amount, knockback)
	_heavy_hit_pending = false
	if broke and not is_dying:
		stagger_timer = maxf(stagger_timer, armor_break_stagger)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dying or _iframes > 0.0 or amount <= 0:
		return
	if armored:
		_deflect()
		return
	_iframes = HIT_IFRAMES
	health -= maxi(1, roundi(amount * damage_taken_multiplier()))
	_flash()
	if health <= 0:
		_killed_stylishly = _heavy_hit_pending
		die()
		return
	# Knock away from the player regardless of the weapon's own rotation.
	var strength := knockback.length() * (1.0 - knockback_resist)
	if strength > 0.0:
		var away := Vector2(signf(global_position.x - _player_pos().x), 0.0)
		if away.x == 0.0:
			away.x = -facing
		velocity = Vector2(away.x * strength, -strength * 0.35)
		if knockback.y > 0.0: # dive attacks hammer downward
			velocity.y = strength * 0.5
		stagger_timer = STAGGER_TIME * (1.0 - knockback_resist)
	_hitstop(0.035)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	var p := player()
	if p and flutter_reward > 0 and p.has_method("add_flutter_charge"):
		p.add_flutter_charge(flutter_reward)
	if score_reward > 0:
		GameManager.add_point(score_reward)
	if drop_scene:
		var drop := drop_scene.instantiate()
		drop.position = position
		get_parent().add_child.call_deferred(drop)
	_drop_loot()
	_hitstop(0.06)
	play_row(2)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.4, 0.6), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _drop_loot() -> void:
	var at := global_position + Vector2(0, -4)
	if (_killed_stylishly and heart_on_stylish_kill) or randf() < heart_drop_chance:
		Pickup.spawn(self, at, Pickup.Kind.HEART)
	if coin_drop_amount > 0 and randf() < coin_drop_chance:
		Pickup.spawn(self, at, Pickup.Kind.COIN, coin_drop_amount)


func _deal_contact_damage() -> void:
	if contact_damage <= 0:
		return
	for body in _hurtbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage, Vector2(signf(body.global_position.x - global_position.x), -0.5))


func _deflect() -> void:
	_iframes = HIT_IFRAMES
	var p := player()
	var dir := signf(_player_pos().x - global_position.x)
	if dir == 0.0:
		dir = -facing
	CombatFX.burst(self, global_position + Vector2(dir * 6.0, 2.0), 7.0, Color(1, 1, 0.85), 1.0, 4, 0.15)
	modulate = Color(1.8, 1.8, 2.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.1)
	if p and p.has_method("recoil"):
		p.recoil(dir)
	_hitstop(0.03)


func _break_armor() -> void:
	armored = false
	if sprite:
		sprite.material = null
	CombatFX.shards(self, global_position + Vector2(0, 3), armor_tint.lightened(0.3))
	armor_broken.emit(self)


func _flash() -> void:
	modulate = Color(4, 4, 4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)


## Brief global freeze on impact. The restore runs on a SceneTree tween so it
## still fires if this enemy is freed mid-freeze.
func _hitstop(duration: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = HITSTOP_SCALE
	var tween := get_tree().create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_interval(duration)
	tween.tween_callback(Engine.set_time_scale.bind(1.0))


func _build_hurtbox() -> void:
	# Layer 1 because the existing weapons and dive hitbox scan layer 1 for
	# anything with take_damage(). Mask 2 = player, for contact damage.
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hurtbox_size
	shape.shape = rect
	shape.position = hurtbox_offset
	_hurtbox.add_child(shape)
	add_child(_hurtbox)


# --------------------------------------------------------------------------
# Helpers for subclasses
# --------------------------------------------------------------------------

func player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _player_pos() -> Vector2:
	var p := player()
	return p.global_position if p else global_position


## Vector from this enemy to the player's chest.
func to_player() -> Vector2:
	return _player_pos() + Vector2(0, -6) - global_position


func can_see_player(max_range: float) -> bool:
	var p := player()
	if not p or p.get("is_dead"):
		return false
	var d := to_player()
	if d.length() > max_range:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + d, WORLD_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func face_player() -> void:
	var dx := to_player().x
	if absf(dx) > 1.0:
		facing = 1 if dx > 0.0 else -1


func apply_gravity(delta: float, scale_factor: float = 1.0) -> void:
	velocity += get_gravity() * scale_factor * delta
	velocity.y = minf(velocity.y, MAX_FALL_SPEED)


func wall_ahead(distance: float = 8.0) -> bool:
	var from := global_position + Vector2(0, surface_offset - 6.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(facing * distance, 0), WORLD_MASK)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func ledge_ahead(lookahead: float = 7.0) -> bool:
	var from := global_position + Vector2(facing * lookahead, surface_offset - 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 10), FLOOR_MASK)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Ground patrol: walk, turn at walls and ledges.
func crawl(delta: float, speed: float) -> void:
	apply_gravity(delta)
	if is_on_floor() and (wall_ahead() or ledge_ahead()):
		facing = -facing
	velocity.x = facing * speed


func enter_state() -> void:
	state_time = 0.0


func play_row(row: int) -> void:
	if row != _anim_row:
		_anim_row = row
		_anim_time = 0.0


func _animate(delta: float) -> void:
	if not sprite:
		return
	_anim_time += delta
	var row := mini(_anim_row, sprite.vframes - 1)
	var step := int(_anim_time * anim_fps)
	sprite.frame = row * sprite.hframes + step % sprite.hframes
	if sprite.hframes == 1 and bob_pixels > 0:
		sprite.offset = _sprite_offset + Vector2(0, -bob_pixels if (step / 2) % 2 == 0 else 0)
	sprite.flip_h = (facing < 0) != art_faces_left
