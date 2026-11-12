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
## Damage type of touching it (armor resists by type). NONE = physical.
@export var contact_element: Hit.Element = Hit.Element.NONE
## Touch carries the realm's element (LevelManager.current_level.realm_element()):
## fire in Hel, ice in the sky, thunder in Valhalla. Overrides contact_element
## when the realm has one, and shows motes around it.
@export var elemental_touch: bool = false
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

@export_group("Elements")
## ICE hits encase it in ice: it stops, deals no contact damage, falls like a
## block and can be stood on. Slashes still hurt it (a kill shatters the ice);
## a heavy hit (meteor, hammer) shatters it outright for a stylish kill
## (guaranteed heart); FIRE thaws it at once.
@export var freezable: bool = true
@export var freeze_time: float = 3.0
## FIRE hits set it burning: damage over time. Armor doesn't catch fire.
@export var burnable: bool = true

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
const THAW_WARNING := 0.8      # last seconds of a freeze: cracks + shiver
const THAW_STAGGER := 0.35
const FROZEN_TINT := Color(0.7, 0.88, 1.25)
const BURN_TIME := 2.5
const BURN_TICK := 0.5
const BURN_DAMAGE := 3
const BURN_TINT := Color(1.35, 0.8, 0.55)
const SHOCK_STUN := 0.5
const SOLID_LAYER := 1         # frozen: solid to her, like the world
const BIG_BODY_HALF_SIZE := 8.0 # body bigger than a tile: dies with the big cry

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

var frozen := false
var burning := false
var _freeze_timer := 0.0
## Collision layer the enemy had when freeze() made it solid; thaw() restores
## exactly this, so subclasses with extra layers (e.g. a one-way back) keep them.
var _prefreeze_layer: int = 4
var _ice: IceBlock
var _burn_timer := 0.0
var _burn_tick := 0.0
var _flames: Flames


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
	if touch_element() != Hit.Element.NONE:
		var aura := ElementAura.new()
		aura.element = touch_element()
		add_child(aura)


## Damage type of touching it right now.
func touch_element() -> Hit.Element:
	if elemental_touch:
		var level := _level()
		if level and level.realm_element() != Hit.Element.NONE:
			return level.realm_element()
	return contact_element


## The Level this enemy lives in. Walks up the tree rather than asking
## LevelManager, which only learns the new level after its children are ready.
func _level() -> Level:
	var node := get_parent()
	while node and not (node is Level):
		node = node.get_parent()
	return node as Level


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
	if frozen:
		_frozen_step(delta)
		return
	if burning:
		_burn_step(delta)
		if is_dying:
			return
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

## Entry point for Hit (see scripts/combat/hit.gd): damage first, then the
## sword's element (ICE freezes, FIRE burns, THUNDER stuns) if it survived.
func take_hit(hit: Hit) -> void:
	last_hit_element = hit.element
	if is_dying:
		return
	if frozen:
		_hit_while_frozen(hit)
		return
	if _iframes > 0.0 and not (hit.heavy and armored):
		return
	if hit.heavy:
		take_heavy_hit(hit.damage, hit.knockback)
	else:
		take_damage(hit.damage, hit.knockback)
	if is_dying:
		return
	match hit.element:
		Hit.Element.ICE:
			if freezable:
				freeze()
		Hit.Element.FIRE:
			if burnable and not armored:
				ignite()
		Hit.Element.THUNDER:
			_shock()


# --------------------------------------------------------------------------
# Elements
# --------------------------------------------------------------------------

func freeze() -> void:
	if frozen or is_dying:
		return
	_extinguish()
	frozen = true
	_freeze_timer = freeze_time
	stagger_timer = 0.0
	velocity = Vector2.ZERO
	_prefreeze_layer = collision_layer
	collision_layer = _prefreeze_layer | SOLID_LAYER
	_ice = IceBlock.new()
	_ice.rect = _body_rect().grow(2)
	add_child(_ice)
	_ice.freeze_over()
	play_sfx(&"enemy_freeze")
	if sprite:
		sprite.self_modulate = FROZEN_TINT


func thaw() -> void:
	if not frozen:
		return
	frozen = false
	collision_layer = _prefreeze_layer
	if _ice:
		_ice.melt()
		_ice = null
	if sprite:
		sprite.self_modulate = Color.WHITE
	_iframes = 0.0
	stagger_timer = THAW_STAGGER
	CombatFX.burst(self, global_position + _body_rect().get_center(), 10.0, IceBlock.EDGE, 1.0, 5, 0.2)


## Heavy hit on the ice: it shatters with the enemy inside. Stylish kill.
func shatter() -> void:
	frozen = false
	if _ice:
		_ice.shatter()
		_ice = null
	CombatFX.shake(self, 2.5, 0.15)
	play_sfx(&"enemy_shatter")
	_killed_stylishly = true
	health = 0
	modulate.a = 0.0
	die()


func ignite() -> void:
	if is_dying:
		return
	if frozen:
		thaw() # fire melts the ice instead
		return
	if not burning:
		play_sfx(&"enemy_ignite")
	burning = true
	_burn_timer = BURN_TIME
	_burn_tick = BURN_TICK
	if not is_instance_valid(_flames):
		_flames = Flames.new()
		_flames.rect = _body_rect().grow(1)
		_flames.rate = 110.0
		add_child(_flames)


func _hit_while_frozen(hit: Hit) -> void:
	if hit.heavy:
		shatter()
		return
	if hit.element == Hit.Element.FIRE:
		thaw()
		take_damage(hit.damage, hit.knockback)
		return
	if _iframes > 0.0:
		return
	if hit.element == Hit.Element.ICE:
		_freeze_timer = freeze_time # keep it frozen (keep your platform)
	var dir := signf(_player_pos().x - global_position.x)
	CombatFX.burst(self, global_position + _body_rect().get_center() + Vector2(dir * 5.0, 0), 6.0, Color(0.9, 0.97, 1.0), 1.0, 3, 0.12)
	# Held fast in the ice: damage, but no knockback.
	take_damage(hit.damage, Vector2.ZERO)


## Subclass hook: does the ice block fall while frozen? True by default (even
## fliers drop like a block of ice). Mobs anchored to a ceiling or wall return
## false so the ice stays stuck where they cling.
func _frozen_falls() -> bool:
	return true


func _frozen_step(delta: float) -> void:
	_freeze_timer -= delta
	if _ice:
		_ice.thawing = _freeze_timer < THAW_WARNING
	if _frozen_falls():
		velocity.x = 0.0
		apply_gravity(delta)
		move_and_slide()
	else:
		velocity = Vector2.ZERO # frozen to its surface: stays put
	if _freeze_timer <= 0.0:
		thaw()


func _burn_step(delta: float) -> void:
	_burn_timer -= delta
	_burn_tick -= delta
	if sprite:
		sprite.self_modulate = BURN_TINT if int(_burn_timer * 12.0) % 2 == 0 else Color.WHITE
	if _burn_tick <= 0.0:
		_burn_tick += BURN_TICK
		health -= BURN_DAMAGE
		if health <= 0:
			_killed_stylishly = true
			_extinguish()
			die()
			return
	if _burn_timer <= 0.0:
		_extinguish()


func _extinguish() -> void:
	burning = false
	if is_instance_valid(_flames):
		_flames.active = false
	_flames = null
	if sprite and not frozen:
		sprite.self_modulate = Color.WHITE


## THUNDER: a jolt that stuns briefly.
func _shock() -> void:
	stagger_timer = maxf(stagger_timer, SHOCK_STUN)
	play_sfx(&"enemy_shock")
	CombatFX.burst(self, global_position + _body_rect().get_center(), 9.0, Color(1.0, 0.95, 0.5), 1.0, 6, 0.15)


## The body's rect in local space (the hurtbox).
func _body_rect() -> Rect2:
	return Rect2((hurtbox_offset - hurtbox_size / 2.0).round(), hurtbox_size)


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
	var half := body_half_extents()
	play_sfx(&"enemy_die_big" if maxf(half.x, half.y) > BIG_BODY_HALF_SIZE else &"enemy_die")
	if _ice:
		_ice.shatter() # dying inside the ice breaks it
		_ice = null
		frozen = false
	_extinguish()
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
			var open := _can_hurt(body)
			body.take_damage(contact_damage, Vector2(signf(body.global_position.x - global_position.x), -0.5), touch_element())
			_bite_if_landed(body, open)


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
	play_sfx(&"enemy_armor_break")
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


## Moves the hurtbox (and the body rect used for FX and stomps) to `offset`
## in local space. Safe to call before the hurtbox is built: the offset is
## stored and applied when `_build_hurtbox()` runs.
func set_hurtbox_offset(offset: Vector2) -> void:
	hurtbox_offset = offset
	if _hurtbox:
		(_hurtbox.get_child(0) as CollisionShape2D).position = offset


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


## Plays a Sfx id at this enemy (positional: off-screen mobs stay quiet).
func play_sfx(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	Sfx.play_at(id, global_position, -1.0, volume_db, pitch)


## True if `body` (the player) can take damage right now (not in her i-frames).
func _can_hurt(body: Node) -> bool:
	var t: Variant = body.get("damage_invulnerability_timer")
	return t == null or float(t) <= 0.0


## Bite sound when a touch just landed on her (`was_open` = _can_hurt before
## the touch). Physical touch only: elemental touch plays her chill/jolt.
func _bite_if_landed(body: Node, was_open: bool) -> void:
	if was_open and not _can_hurt(body) and touch_element() == Hit.Element.NONE:
		play_sfx(&"enemy_bite")


func face_player() -> void:
	var dx := to_player().x
	if absf(dx) > 1.0:
		facing = 1 if dx > 0.0 else -1


func apply_gravity(delta: float, scale_factor: float = 1.0) -> void:
	velocity += get_gravity() * scale_factor * delta
	velocity.y = minf(velocity.y, MAX_FALL_SPEED)


# Patrol probes are sized from the body collider, so big mobs (Draugr,
# Einherjar) turn at the same gap from a wall or edge as a 16px crawler.
# Every collider that fits one 16px tile probes as the stock 10x12 body
# (half 5x6), which reproduces the old fixed probes exactly: wall ray 8px
# out at 6px above the feet, ledge ray 7px out, 2px up, 10px deep.
const WALL_PROBE_REACH := 3.0  # px past the collider's front edge
const LEDGE_PROBE_REACH := 2.0 # px past the collider's front edge
const LEDGE_PROBE_RISE := 2.0  # ledge ray starts this far above the feet
const LEDGE_PROBE_DEPTH := 10.0
const DEFAULT_HALF_EXTENTS := Vector2(5, 6) # the stock 10x12 crawler body
const TILE_BODY := Vector2(16, 16) # colliders this size or smaller use the default

var _half_extents := Vector2(-1, -1)


## Half-size used to place patrol probes, from the body collider (first
## CollisionShape2D child), cached on first use. Bodies that fit one 16px
## tile (and enemies without a collider) get DEFAULT_HALF_EXTENTS.
func body_half_extents() -> Vector2:
	if _half_extents.x < 0.0:
		_half_extents = DEFAULT_HALF_EXTENTS
		for child in get_children():
			var col := child as CollisionShape2D
			if col and col.shape:
				var size := col.shape.get_rect().size * col.scale.abs()
				if size.x > TILE_BODY.x or size.y > TILE_BODY.y:
					_half_extents = size / 2.0
				break
	return _half_extents


## Wall within `distance` px of the origin, along facing. Negative distance
## (default) reaches WALL_PROBE_REACH past the collider's front edge.
func wall_ahead(distance: float = -1.0) -> bool:
	var half := body_half_extents()
	if distance < 0.0:
		distance = half.x + WALL_PROBE_REACH
	var from := global_position + Vector2(0, surface_offset - half.y)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(facing * distance, 0), WORLD_MASK)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## No floor `lookahead` px ahead of the origin. Negative lookahead (default)
## probes LEDGE_PROBE_REACH past the collider's front edge.
func ledge_ahead(lookahead: float = -1.0) -> bool:
	if lookahead < 0.0:
		lookahead = body_half_extents().x + LEDGE_PROBE_REACH
	var from := global_position + Vector2(facing * lookahead, surface_offset - LEDGE_PROBE_RISE)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, LEDGE_PROBE_DEPTH), FLOOR_MASK)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Ground patrol: walk, turn at walls and ledges.
func crawl(delta: float, speed: float) -> void:
	apply_gravity(delta)
	patrol_step(speed)


## crawl() without the gravity, for mobs whose _ai already applied it.
func patrol_step(speed: float) -> void:
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
