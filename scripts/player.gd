extends CharacterBody2D

# --- Movement Settings ---
const BASE_SPEED = 150.0        
const MAX_SPEED = 250.0         
const ACCELERATION = 800.0      
const FRICTION = 1000.0         

# --- Jump Settings ---
const BASE_JUMP_VELOCITY = -300.0 # Tweaked for better feel
const JUMP_ADD_FORCE = -1200.0 
const MAX_JUMP_TIME = 0.2

# --- Momentum Settings ---
const MOMENTUM_GAIN_RATE = 1.5  
const MAX_MOMENTUM_BONUS = 1.8  
var current_momentum = 1.0       

# --- Floaty Physics Settings ---
const TERMINAL_VELOCITY = 400.0 # Increased so you don't float too much
const GRAVITY_SCALE = 1.0
const FALL_GRAVITY_SCALE = 1.5

# --- Fast Fall Settings ---
const FAST_FALL_GRAVITY_SCALE = 3.0
const FAST_FALL_MAX_SPEED = 500.0

# --- Meteor Strike (down + attack in the air) ---
# Brief hang while the sword flips overhead-to-down, then a straight plunge.
# A direct hit is a heavy hit (shatters armor) and bounces her back up; hitting
# the ground sends out a shockwave.
const DIVE_ATTACK_DAMAGE = 40
const DIVE_ATTACK_KNOCKBACK = 300.0
const METEOR_WINDUP = 0.13
const METEOR_SPEED = 560.0
const METEOR_BOUNCE = -270.0
const METEOR_LAND_LAG = 0.14
const METEOR_SHOCK_RADIUS = 34.0
const METEOR_SHOCK_DAMAGE = 15
const METEOR_TRAIL_INTERVAL = 0.03
const METEOR_TRAIL_TINT = Color(1.0, 0.82, 0.45, 0.55)
const METEOR_SWORD_TEXTURE = preload("res://assets/sprites/swords/swords238.png")
# Pivot-local sword placement: overhead at the start, under her feet in the plunge.
const METEOR_SWORD_UP = Vector2(0, -15)
const METEOR_SWORD_DOWN = Vector2(0, 19)
const SWORD_ART_ANGLE = -PI / 4.0   # the sword art points up-right

# --- Directional slashes: hold up to slash overhead ---
const RECOIL_SPEED = 150.0

# --- Flutter Settings ---
const FLUTTER_KICK = -150.0
const FLUTTER_DURATION = 0.4
const FLUTTER_GRAVITY_SCALE = 0.1

# --- Collision layers (see project.godot [layer_names]) ---
const HAZARD_LAYER = 16      # layer 5: lava / poison tiles
const ONE_WAY_LAYER = 32     # layer 6: drop-through platforms
const DROP_THROUGH_TIME = 0.25
const NOCLIP_SPEED = 320.0

# --- PROGRESSION VARIABLES ---
## Flutters per airtime = the active sword's base + flutter_bonus (wings
## pickups, later armor), never above this, so she can't truly fly.
const FLUTTER_CAP = 4
var max_flutter_charges = 2
var flutter_charges_left = 2
var flutter_bonus = 0
signal wings_updated(count)
signal health_updated(count)
signal weapon_switched(is_sword_1) # kept for the old HUD button
signal weapon_changed(data: WeaponData, slot: int)

var jump_hold_timer = 0.0
var is_jumping = false
var is_fluttering = false
var is_dive_attacking = false
var flutter_timer = 0.0
var current_health = 0
var damage_invulnerability_timer = 0.0
var is_dead = false
var last_safe_position := Vector2.ZERO
var drop_through_timer = 0.0
var hazard_cooldown = 0.0
var hazard_sensor: Area2D
var hurt_stun_timer = 0.0
var _hurt_glow: Tween
var attack_lock_timer = 0.0     # meteor landing lag
var meteor_windup_timer = 0.0
var meteor_trail_timer = 0.0
var meteor_sword: Sprite2D
var weapon_anchor_base := Vector2.ZERO

const HEART := 2                            # health is in half-hearts
const HURT_GLOW := Color(2.4, 0.55, 0.5)   # overbright red flash on hit
const BLINK_INTERVAL := 0.07                # i-frame flicker

@export_group("Visuals")
@export var dive_attack_animation: StringName = &"dive_attack"

@export_group("Stats")
## Health is counted in HALF-hearts: 2 = one heart. Enemy contact and most
## hazards deal 2. Heart containers (add_heart_container) raise max_health.
@export var max_health: int = 6
@export var starting_health: int = 6
@export var damage_invulnerability_time: float = 1.0
## Hit reaction: launched away from the source, steering locked briefly.
@export var hurt_knockback: Vector2 = Vector2(190, -210)
@export var hurt_stun_time: float = 0.28
@export var hurt_hitstop: float = 0.07
@export var death_reload_delay: float = 1.0

@onready var animated_sprite = $Pivot/AnimatedSprite2D
@onready var pivot = $Pivot
@onready var weapon_anchor = $Pivot/WeaponAnchor
@onready var dive_attack_hitbox = $DiveAttackHitbox
@onready var dive_attack_shape = $DiveAttackHitbox/CollisionShape2D

# --- SWORD LOADOUT ---
## She carries up to 3 swords; the switch button cycles them in this order.
## Each sword (data/weapons/*.tres) also sets her movement and flutter.
const MAX_LOADOUT = 3
@export var loadout: Array[WeaponData] = [
	preload("res://data/weapons/valkyrie_blade.tres"),
	preload("res://data/weapons/ice_rapier.tres"),
]
var loadout_instances: Array[Node2D] = []
var active_slot := 0
var weapon_data: WeaponData
var active_weapon: Node2D
# Slots 0 and 1, for the old HUD switch button.
var weapon_1_instance: Node2D
var weapon_2_instance: Node2D

func _ready() -> void:
	add_to_group("player") # Vital for enemies to find you

	var state: Dictionary = GameManager.player_state
	max_health = state.get("max_health", max_health)
	current_health = clampi(state.get("health", starting_health), 1, max_health)
	flutter_bonus = state.get("flutter_bonus", 0)
	last_safe_position = global_position
	_setup_hazard_sensor()

	health_updated.emit(current_health)
	
	# Dive Attack Safety
	if dive_attack_hitbox:
		dive_attack_hitbox.body_entered.connect(_on_dive_attack_body_entered)
		dive_attack_hitbox.area_entered.connect(_on_dive_attack_area_entered)
		_set_dive_attack_hitbox_enabled(false)

	# --- ROBUST BUTTON CONNECTION ---
	# Instead of a hard path, we look for the group "sword_button"
	# Make sure to add your SwitchSwordButton to this group!
	var sword_switcher = get_tree().get_first_node_in_group("sword_button")
	if sword_switcher:
		sword_switcher.pressed.connect(_on_sword_switch_requested)
	
	weapon_anchor_base = weapon_anchor.position
	meteor_sword = Sprite2D.new()
	meteor_sword.name = "MeteorSword"
	meteor_sword.texture = METEOR_SWORD_TEXTURE
	meteor_sword.scale = Vector2(0.53125, 0.5625) # same as the hand-held swords
	meteor_sword.visible = false
	meteor_sword.z_index = -1 # hilt tucked behind her
	pivot.add_child(meteor_sword)

	# --- LOADOUT SETUP ---
	if state.has("loadout"):
		var carried: Array[WeaponData] = []
		for path: String in state["loadout"]:
			var data := load(path) as WeaponData
			if data:
				carried.append(data)
		if not carried.is_empty():
			loadout = carried
	loadout = loadout.slice(0, MAX_LOADOUT)
	for data in loadout:
		var inst: Node2D = data.scene.instantiate()
		if "data" in inst:
			inst.data = data
		weapon_anchor.add_child(inst)
		_disable_weapon(inst)
		loadout_instances.append(inst)
	weapon_1_instance = loadout_instances[0] if loadout_instances.size() > 0 else null
	weapon_2_instance = loadout_instances[1] if loadout_instances.size() > 1 else null
	_equip(clampi(state.get("weapon_slot", 0), 0, loadout.size() - 1), true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if damage_invulnerability_timer > 0.0:
		damage_invulnerability_timer = max(0.0, damage_invulnerability_timer - delta)
	if hurt_stun_timer > 0.0:
		hurt_stun_timer = max(0.0, hurt_stun_timer - delta)
	if attack_lock_timer > 0.0:
		attack_lock_timer = max(0.0, attack_lock_timer - delta)
	_update_iframe_blink()
	if hazard_cooldown > 0.0:
		hazard_cooldown = max(0.0, hazard_cooldown - delta)
	if drop_through_timer > 0.0:
		drop_through_timer -= delta
		if drop_through_timer <= 0.0:
			collision_mask |= ONE_WAY_LAYER

	if DebugMenu.noclip:
		_noclip_move(delta)
		return

	# --- 0. Attack Input & Weapon Switching ---
	if Input.is_action_just_pressed("switch_weapon"):
		_on_sword_switch_requested()

	if Input.is_action_just_pressed("attack") and hurt_stun_timer <= 0.0 and attack_lock_timer <= 0.0:
		if can_start_dive_attack():
			start_dive_attack()
		elif not is_dive_attacking:
			execute_attack(_attack_direction())

	# --- 1. Gravity & Air Logic ---
	if not is_on_floor():
		if is_dive_attacking:
			is_fluttering = false
			is_jumping = false
			_meteor_step(delta)
			
		elif is_fluttering:
			velocity += get_gravity() * FLUTTER_GRAVITY_SCALE * delta
			velocity.y = move_toward(velocity.y, FLUTTER_KICK * weapon_data.flutter_height, 15)
			flutter_timer -= delta
			
			if flutter_timer <= 0 or Input.is_action_just_released("jump"):
				is_fluttering = false
		else:
			var gravity_scale := GRAVITY_SCALE if velocity.y < 0 else FALL_GRAVITY_SCALE
			
			# Fast Fall Logic
			if velocity.y > 0 and Input.is_action_pressed("move_down"):
				gravity_scale = FAST_FALL_GRAVITY_SCALE
				is_fluttering = false

			velocity += get_gravity() * gravity_scale * delta

			var max_fall_speed = FAST_FALL_MAX_SPEED if Input.is_action_pressed("move_down") else TERMINAL_VELOCITY
			velocity.y = min(velocity.y, max_fall_speed)

			# Jump Hold Logic
			if is_jumping and Input.is_action_pressed("jump"):
				if jump_hold_timer > 0:
					velocity.y += JUMP_ADD_FORCE * delta
					jump_hold_timer -= delta
				else:
					is_jumping = false

			if Input.is_action_just_released("jump"):
				is_jumping = false

			# Trigger Flutter
			if Input.is_action_just_pressed("jump") and velocity.y > 10 and flutter_charges_left > 0 and hurt_stun_timer <= 0.0:
				start_flutter()
	else:
		# RESET ON FLOOR
		if is_dive_attacking:
			_land_dive_attack()
			
		is_dive_attacking = false
		is_fluttering = false
		is_jumping = false
		current_momentum = move_toward(current_momentum, 1.0, delta * 3.0)
		
		if flutter_charges_left < max_flutter_charges:
			flutter_charges_left = max_flutter_charges 
			wings_updated.emit(flutter_charges_left)

	# --- 2. Horizontal Movement ---
	var direction := Input.get_axis("move_left", "move_right")

	if hurt_stun_timer > 0.0:
		# Knocked back: no steering, just a little air drag.
		velocity.x = move_toward(velocity.x, 0, FRICTION * weapon_data.traction * 0.25 * delta)
	elif is_dive_attacking:
		velocity.x = 0.0 # the meteor falls straight
	elif attack_lock_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0, FRICTION * weapon_data.traction * delta)
	elif direction != 0:
		if is_on_floor():
			current_momentum = move_toward(current_momentum, MAX_MOMENTUM_BONUS, delta * MOMENTUM_GAIN_RATE * weapon_data.momentum_gain)

		var target_speed = min(BASE_SPEED * weapon_data.top_speed * current_momentum, MAX_SPEED * weapon_data.top_speed)
		var accel: float = ACCELERATION * weapon_data.acceleration
		# Reversing against current speed is a matter of grip: low traction slides.
		if signf(velocity.x) != signf(direction) and absf(velocity.x) > 20.0:
			accel = maxf(accel, FRICTION) * weapon_data.traction
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
		
		# VISUAL FLIP
		if direction > 0:
			pivot.scale.x = 1
		elif direction < 0:
			pivot.scale.x = -1
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * weapon_data.traction * delta)

	# --- 3. Initial Jump / Drop-through ---
	if Input.is_action_just_pressed("jump") and is_on_floor() and hurt_stun_timer <= 0.0 and attack_lock_timer <= 0.0:
		if Input.is_action_pressed("move_down") and _is_standing_on_one_way():
			_start_drop_through()
		else:
			velocity.y = BASE_JUMP_VELOCITY * current_momentum
			jump_hold_timer = MAX_JUMP_TIME
			is_jumping = true

	# --- 4. Animation ---
	_handle_animations()
	move_and_slide()
	_update_last_safe_position()

func _handle_animations() -> void:
	if is_on_floor():
		if abs(velocity.x) < 5.0:
			animated_sprite.play("idle")
			animated_sprite.speed_scale = 1.0
		else:
			animated_sprite.play("run")
			animated_sprite.speed_scale = max(0.8, abs(velocity.x) / (BASE_SPEED * weapon_data.top_speed))
	else:
		animated_sprite.speed_scale = 1.0
		if is_fluttering:
			if animated_sprite.sprite_frames.has_animation("flutter"):
				animated_sprite.play("flutter")
			else:
				animated_sprite.play("jump") # Fallback
		elif is_dive_attacking:
			play_fall_animation(dive_attack_animation, "fall")
		else:
			if velocity.y < 0:
				animated_sprite.play("jump")
			else:
				animated_sprite.play("fall")

func play_fall_animation(primary: StringName, fallback: StringName) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(primary):
		animated_sprite.play(primary)
	else:
		animated_sprite.play(fallback)

# --- ATTACK SYSTEM ---
## Up held = overhead slash, otherwise a slash in front. (Down in the air is
## the meteor strike, handled before this.)
func _attack_direction() -> Vector2:
	return Vector2.UP if Input.is_action_pressed("move_up") else Vector2.RIGHT


func execute_attack(dir: Vector2 = Vector2.RIGHT):
	if not active_weapon or not active_weapon.has_method("swing"):
		return
	if active_weapon.has_method("is_swinging") and active_weapon.is_swinging():
		return
	_aim_weapon(dir)
	if active_weapon.swing():
		# Forward lunge (sword 2's thrust) only applies to slashes in front.
		if dir == Vector2.RIGHT and active_weapon.has_method("get_attack_thrust"):
			velocity += active_weapon.get_attack_thrust(pivot.scale.x)


## Rotates the whole swing (sword, arc and hitbox) about her center. The pivot
## is mirrored when facing left, so "right" here always means "in front".
func _aim_weapon(dir: Vector2) -> void:
	var angle := 0.0 if dir == Vector2.RIGHT else -PI / 2.0 if dir == Vector2.UP else PI / 2.0
	weapon_anchor.rotation = angle
	weapon_anchor.position = weapon_anchor_base.rotated(angle)


## Bounce back off something hard (armor). `dir` is the push direction.
func recoil(dir: float) -> void:
	if is_dead:
		return
	velocity.x = dir * RECOIL_SPEED
	if not is_on_floor():
		velocity.y = minf(velocity.y, -60.0)
	attack_lock_timer = maxf(attack_lock_timer, 0.12)


func can_start_dive_attack() -> bool:
	return not is_on_floor() and not is_dive_attacking and Input.is_action_pressed("move_down")

func start_dive_attack():
	is_dive_attacking = true
	is_fluttering = false
	is_jumping = false
	meteor_windup_timer = METEOR_WINDUP
	meteor_trail_timer = 0.0
	velocity = Vector2(0, -50) # a little hitch upward sells the windup
	_set_dive_attack_hitbox_enabled(false)
	# Sword flips from overhead to straight down during the windup.
	meteor_sword.visible = true
	meteor_sword.position = METEOR_SWORD_UP
	meteor_sword.rotation = -PI / 2.0 - SWORD_ART_ANGLE
	var tween := meteor_sword.create_tween().set_parallel()
	tween.tween_property(meteor_sword, "position", METEOR_SWORD_DOWN, METEOR_WINDUP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(meteor_sword, "rotation", PI / 2.0 - SWORD_ART_ANGLE, METEOR_WINDUP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _meteor_step(delta: float) -> void:
	if meteor_windup_timer > 0.0:
		meteor_windup_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		if meteor_windup_timer <= 0.0:
			velocity = Vector2(0, METEOR_SPEED)
			_set_dive_attack_hitbox_enabled(true)
			CombatFX.burst(self, global_position + Vector2(0, -6), 10.0, Color(1, 0.9, 0.6), 1.0, 0, 0.12)
		return
	velocity = Vector2(0, METEOR_SPEED)
	meteor_trail_timer -= delta
	if meteor_trail_timer <= 0.0:
		meteor_trail_timer = METEOR_TRAIL_INTERVAL
		CombatFX.afterimage(animated_sprite, METEOR_TRAIL_TINT)
		CombatFX.afterimage(meteor_sword, METEOR_TRAIL_TINT)


func _end_meteor() -> void:
	is_dive_attacking = false
	meteor_windup_timer = 0.0
	_set_dive_attack_hitbox_enabled(false)
	if meteor_sword:
		meteor_sword.visible = false


func _land_dive_attack():
	var was_plunging: bool = meteor_windup_timer <= 0.0
	_end_meteor()
	if not was_plunging:
		return
	attack_lock_timer = METEOR_LAND_LAG
	CombatFX.burst(self, global_position, METEOR_SHOCK_RADIUS, Color(1, 0.85, 0.55), 0.3, 10, 0.3)
	CombatFX.shake(self, 3.0, 0.2)
	# Shockwave: hurts grounded enemies nearby. Armor ignores it; only a direct
	# meteor hit breaks armor.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D or enemy.get("is_dying") or enemy.get("armored"):
			continue
		var d: Vector2 = (enemy as Node2D).global_position - global_position
		if absf(d.x) <= METEOR_SHOCK_RADIUS and absf(d.y) <= 20.0 and enemy.has_method("take_damage"):
			Hit.deliver(enemy, Hit.make(METEOR_SHOCK_DAMAGE, Vector2(signf(d.x), -1.0) * 200.0, weapon_data.element, false, self))


func _set_dive_attack_hitbox_enabled(enabled: bool) -> void:
	if not dive_attack_hitbox: return
	dive_attack_hitbox.set_deferred("monitoring", enabled)
	if dive_attack_shape:
		dive_attack_shape.set_deferred("disabled", not enabled)

# --- COLLISION LOGIC ---
func _on_dive_attack_body_entered(body: Node2D) -> void:
	_apply_dive_attack_hit(body)

func _on_dive_attack_area_entered(area: Area2D) -> void:
	_apply_dive_attack_hit(area)
	var parent = area.get_parent()
	if parent and parent is Node2D:
		_apply_dive_attack_hit(parent)

func _apply_dive_attack_hit(target: Node) -> void:
	if target == self or not is_dive_attacking or meteor_windup_timer > 0.0: return
	# Always heavy (shatters armor), carrying the sword's element.
	var hit := Hit.make(DIVE_ATTACK_DAMAGE, Vector2.DOWN * DIVE_ATTACK_KNOCKBACK, weapon_data.element, true, self)
	if not Hit.deliver(target, hit): return
	_end_meteor()
	velocity.y = METEOR_BOUNCE
	CombatFX.burst(self, global_position + Vector2(0, 6), 14.0, Color(1, 0.95, 0.75), 1.0, 6, 0.2)
	CombatFX.shake(self, 2.0, 0.12)

# --- HEALTH & DAMAGE ---
func take_hit(hit: Hit) -> void:
	take_damage(hit.damage, hit.knockback)


## `knockback` gives the push direction (only its x sign matters); with no
## direction the player is pushed backwards from where she faces.
func take_damage(amount: int = HEART, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0: return
	if DebugMenu.god_mode: return
	if damage_invulnerability_timer > 0.0: return

	current_health = max(0, current_health - amount)
	health_updated.emit(current_health)

	if current_health <= 0:
		_die()
		return
	damage_invulnerability_timer = damage_invulnerability_time
	_apply_hurt_knockback(knockback)
	_play_hurt_feedback()


func _apply_hurt_knockback(knockback: Vector2) -> void:
	var dir_x := signf(knockback.x)
	if dir_x == 0.0:
		dir_x = -signf(pivot.scale.x) if pivot.scale.x != 0 else -1.0
	velocity = Vector2(dir_x * hurt_knockback.x, hurt_knockback.y)
	hurt_stun_timer = hurt_stun_time
	_end_meteor()
	is_fluttering = false
	is_jumping = false
	current_momentum = 1.0
	_set_dive_attack_hitbox_enabled(false)


func _play_hurt_feedback() -> void:
	# Overbright red glow that fades out over the stun.
	if _hurt_glow:
		_hurt_glow.kill()
	animated_sprite.modulate = HURT_GLOW
	_hurt_glow = create_tween()
	_hurt_glow.tween_property(animated_sprite, "modulate", Color.WHITE, hurt_stun_time).set_ease(Tween.EASE_IN)
	# Brief hitstop so the hit lands, on real time so it always ends.
	if hurt_hitstop > 0.0 and Engine.time_scale == 1.0:
		Engine.time_scale = 0.05
		get_tree().create_timer(hurt_hitstop, true, false, true).timeout.connect(func() -> void:
			if Engine.time_scale == 0.05:
				Engine.time_scale = 1.0)


## Flicker while invulnerable (after the glow), so the window is readable.
func _update_iframe_blink() -> void:
	var blinking: bool = damage_invulnerability_timer > 0.0 and hurt_stun_timer <= 0.0
	var a := 1.0
	if blinking and int(damage_invulnerability_timer / BLINK_INTERVAL) % 2 == 0:
		a = 0.3
	pivot.modulate.a = a

func _die() -> void:
	if is_dead: return
	is_dead = true
	
	# Disable physics
	velocity = Vector2.ZERO
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", true)
	
	_end_meteor()
	if _hurt_glow:
		_hurt_glow.kill()
	animated_sprite.modulate = Color.WHITE
	pivot.modulate.a = 1.0

	# Respawn at the level entrance with fresh health; keep wings/weapon.
	GameManager.player_state.erase("health")

	# Armor shakes apart into feathers, then the level reloads.
	# (death_reload_delay is unused now; the sequence sets the pace.)
	var sequence := DeathSequence.play(self)
	sequence.finished.connect(func() -> void:
		get_tree().reload_current_scene())

func _heal(amount: int = HEART) -> void:
	current_health = min(max_health, current_health + amount)
	health_updated.emit(current_health)


## Permanent: one more heart (2 half-hearts) of max health, and a full heal.
func add_heart_container(count: int = 1) -> void:
	max_health += HEART * count
	current_health = max_health
	health_updated.emit(current_health)

# --- ABILITIES ---
func start_flutter():
	is_fluttering = true
	_end_meteor()
	_set_dive_attack_hitbox_enabled(false)
	is_jumping = false
	flutter_timer = FLUTTER_DURATION
	if not DebugMenu.infinite_flutter:
		flutter_charges_left -= 1
	velocity.y = FLUTTER_KICK * weapon_data.flutter_height # Instant kick up
	wings_updated.emit(flutter_charges_left)

func add_flutter_charge(amount: int = 1):
	flutter_charges_left = min(flutter_charges_left + amount, max_flutter_charges)
	wings_updated.emit(flutter_charges_left)

## Permanent upgrade (Wings pickup): one more flutter per airtime, on top of
## the sword's base (up to FLUTTER_CAP).
func add_flutter_slot(amount: int = 1):
	flutter_bonus += amount
	max_flutter_charges = _max_flutter()
	flutter_charges_left = max_flutter_charges
	wings_updated.emit(flutter_charges_left)

# --- HAZARDS & SAFE GROUND ---
func _setup_hazard_sensor() -> void:
	hazard_sensor = Area2D.new()
	hazard_sensor.name = "HazardSensor"
	hazard_sensor.collision_layer = 0
	hazard_sensor.collision_mask = HAZARD_LAYER
	# Must stay monitorable: a non-monitorable Area2D is treated as static by the
	# broadphase and never pairs with static tile bodies, so lava would go unnoticed.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 10)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	hazard_sensor.add_child(shape)
	add_child(hazard_sensor)
	hazard_sensor.body_entered.connect(func(_body: Node2D) -> void: respawn_from_hazard(HEART))

func _update_last_safe_position() -> void:
	if not is_on_floor() or not get_platform_velocity().is_zero_approx():
		return
	if hazard_sensor and hazard_sensor.has_overlapping_bodies():
		return
	last_safe_position = global_position

## Lava, poison, bottomless pits: hurt (ignoring i-frames) and return to safe ground.
func respawn_from_hazard(amount: int = HEART) -> void:
	if is_dead or hazard_cooldown > 0.0:
		return
	hazard_cooldown = 0.3
	damage_invulnerability_timer = 0.0
	take_damage(amount)
	if is_dead:
		return
	global_position = last_safe_position
	velocity = Vector2.ZERO
	_end_meteor()
	is_fluttering = false
	is_jumping = false
	_set_dive_attack_hitbox_enabled(false)

# --- ONE-WAY PLATFORMS ---
func _is_standing_on_one_way() -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y > -0.7:
			continue
		var layer := PhysicsServer2D.body_get_collision_layer(collision.get_collider_rid())
		if layer & ONE_WAY_LAYER:
			return true
	return false

func _start_drop_through() -> void:
	collision_mask &= ~ONE_WAY_LAYER
	drop_through_timer = DROP_THROUGH_TIME
	position.y += 2.0

# --- DEBUG ---
func _noclip_move(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	global_position += dir * NOCLIP_SPEED * delta
	velocity = Vector2.ZERO
	if dir.x != 0.0:
		pivot.scale.x = signf(dir.x)

# --- WEAPON SWITCHING ---
## Cycles the loadout. Instant and allowed mid-air (for freeze-then-shatter
## combos), but never refills flutters: charges left are capped to the new
## sword's maximum.
func _on_sword_switch_requested():
	if loadout.size() < 2:
		return
	_equip((active_slot + 1) % loadout.size(), false)


func _equip(slot: int, refill_flutter: bool) -> void:
	if active_weapon:
		_disable_weapon(active_weapon)
	active_slot = slot
	weapon_data = loadout[slot]
	active_weapon = loadout_instances[slot]
	_enable_weapon(active_weapon)
	max_flutter_charges = _max_flutter()
	if refill_flutter:
		flutter_charges_left = max_flutter_charges
	else:
		flutter_charges_left = mini(flutter_charges_left, max_flutter_charges)
	wings_updated.emit(flutter_charges_left)
	weapon_switched.emit(slot == 0)
	weapon_changed.emit(weapon_data, slot)


func _max_flutter() -> int:
	return mini(weapon_data.flutter_charges + flutter_bonus, FLUTTER_CAP)


func _disable_weapon(weapon: Node2D):
	if not weapon: return
	weapon.hide()
	weapon.process_mode = Node.PROCESS_MODE_DISABLED
	if weapon.has_node("AnimationPlayer"):
		weapon.get_node("AnimationPlayer").stop()

func _enable_weapon(weapon: Node2D):
	if not weapon: return
	weapon.show()
	weapon.process_mode = Node.PROCESS_MODE_INHERIT
	# Remove the emit from here to keep things clean!
	
