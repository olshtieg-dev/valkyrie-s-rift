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
## A fresh jump / attack / dash press cancels the strike (_meteor_cancel_input),
## but not within this long of starting it, so the press that started it (or a
## bouncy double-tap) can't. Limited per airtime so dive-cancel loops can't
## hover her (the windup stalls her fall).
const METEOR_CANCEL_GRACE = 0.04
const METEOR_CANCELS_PER_AIRTIME = 1
const METEOR_SWORD_TEXTURE = preload("res://assets/sprites/swords/swords238.png")
# Pivot-local sword placement: overhead at the start, under her feet in the plunge.
const METEOR_SWORD_UP = Vector2(0, -15)
const METEOR_SWORD_DOWN = Vector2(0, 19)
const SWORD_ART_ANGLE = -PI / 4.0   # the sword art points up-right

# --- Directional slashes: hold up to slash overhead ---
const RECOIL_SPEED = 150.0

# --- Attack flow & attack movement ---
# Attack presses are buffered briefly so mashing never drops a swing.
# Switching swords mid-swing cancels it: rotating through her swords is the
# fastest way to keep slashing, and each hit with a *different* sword than the
# last (within ROTATION_WINDOW) builds the rotation chain: +25% / +50% damage.
const ATTACK_BUFFER_TIME = 0.15
const ATTACK_RECOVERY = 0.06       # after the swing, divided by attack_speed
const ROTATION_WINDOW = 0.8
const ROTATION_STEP = 0.25
const ROTATION_MAX_STEPS = 2
const LUNGE_TIME = 0.14
const AIR_HIT_HOVER = -70.0        # landing a hit in the air holds her up
const LUNGE_TINT = Color(0.7, 0.9, 1.0, 0.5)
const RISE_TINT = Color(1.0, 0.95, 0.7, 0.5)
## How much running momentum adds to jump height (0 = none, 1 = fully).
const JUMP_MOMENTUM_SHARE = 0.1

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
## Her wings start broken: no flutter at all (even holding a sword) until she
## has found WINGS_FEATHERS wing feathers (WingFeather; the first two lie on
## hel_h08's main path, see LevelRegistry "path_find"). From then on, flutters
## per airtime = the active sword's base (1-3) + each feather past those two
## + the armor's bonus_feathers. The cap is on that total, never the feathers
## alone: swords keep their flutter difference until she nears the cap, and
## she can't truly fly.
const FLUTTER_CAP = 8
const WINGS_FEATHERS = 2
var max_flutter_charges = 2
var flutter_charges_left = 2
## Wing feathers found, all of them (saved as player_state "feathers").
var flutter_bonus = WINGS_FEATHERS
signal wings_updated(count)
signal health_updated(count)
signal weapon_switched(is_sword_1) # kept for the old HUD button
signal weapon_changed(data: WeaponData, slot: int)
signal armor_changed(data: ArmorData)

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
# --- ELEMENT STATUS (from ice/thunder hits; armor resistance shortens them) ---
## Ice hits chill her: slower running for a moment, frosted blue.
const CHILL_TIME := 1.6
const CHILL_SPEED := 0.6
const CHILL_TINT := Color(0.7, 0.85, 1.15)
## Thunder hits jolt her broken wings: one flutter charge lost (unless her
## armor resists thunder by half or more) and a slightly longer stun.
const JOLT_STUN := 0.15
var chill_timer := 0.0
var _chill_fx := 0.0
var attack_lock_timer = 0.0     # meteor landing lag
var meteor_windup_timer = 0.0
var meteor_trail_timer = 0.0
var meteor_sword: Sprite2D
var meteor_cancel_grace = 0.0
var meteor_cancels_left = METEOR_CANCELS_PER_AIRTIME
var _meteor_tween: Tween
var weapon_anchor_base := Vector2.ZERO
var attack_buffer := 0.0
var attack_cooldown := 0.0
var air_lift_ready := true      # rising slash, once per airtime
var air_lunge_ready := true     # air lunge, once per airtime
var lunge_timer := 0.0
var _trail_timer := 0.0
var rotation_chain := 0
var _last_hit_weapon: WeaponData
var _last_hit_time := -10.0
var _sfx_on_floor := true       # for the landing sound

const HEART := 2                            # health is in half-hearts
const HURT_GLOW := Color(2.4, 0.55, 0.5)   # overbright red flash on hit
const BLINK_INTERVAL := 0.07                # i-frame flicker

@export_group("Visuals")
@export var dive_attack_animation: StringName = &"dive_attack"

@export_group("Stats")
## Health is counted in HALF-hearts: 2 = one heart. Enemy contact and most
## hazards deal 2. Heart containers (add_heart_container) raise
## base_max_health; max_health = that + the armor's bonus hearts.
@export var max_health: int = 6
@export var starting_health: int = 6
## What she wears. Purely defensive: resistances, bonus hearts and feathers.
@export var armor: ArmorData = preload("res://data/armor/valkyrie_plate.tres")
var base_max_health := 6
## Fractions of a half-heart that resistance shaved off, carried to the next
## hit so 25% off a 2-damage blow really averages 1.5.
var _damage_carry := 0.0
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
## She carries up to MAX_LOADOUT swords; the switch button cycles them in this order.
## Each sword (data/weapons/*.tres) also sets her movement and flutter.
## MAX_LOADOUT is the single source of truth for how many swords she carries:
## pickups, shrines, the HUD and saved state all read it, so change it only here.
## Separate slots for other kinds of items are planned; give them their own
## constant beside this one rather than sharing the sword count.
const MAX_LOADOUT: int = 4
## A new climb starts with none (unarmed: GameManager.new_climb_state); the
## blade lies on hel_02's main path (LevelRegistry "path_find"), the rest are
## side-route finds ("find") or bought at shrines. This default is what she
## carries when there's no carried state (a room run on its own, debug warps).
@export var loadout: Array[WeaponData] = [
	preload("res://data/weapons/valkyrie_blade.tres"),
]
var loadout_instances: Array[Node2D] = []
var active_slot := 0
var weapon_data: WeaponData
var active_weapon: Node2D
# Slots 0 and 1, for the old HUD switch button.
var weapon_1_instance: Node2D
var weapon_2_instance: Node2D
## The scene's own SpriteFrames (original skin); skins are copies of it.
var _base_frames: SpriteFrames

func _ready() -> void:
	add_to_group("player") # Vital for enemies to find you

	var state: Dictionary = GameManager.player_state
	base_max_health = state.get("max_health", max_health)
	if state.get("armor", "") != "":
		var worn := load(state["armor"]) as ArmorData
		if worn:
			armor = worn
	_apply_armor_stats()
	current_health = clampi(state.get("health", max_health), 1, max_health)
	flutter_bonus = _feathers_from(state)
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
	animated_sprite.frame_changed.connect(_sfx_footstep)
	meteor_sword = Sprite2D.new()
	meteor_sword.name = "MeteorSword"
	meteor_sword.texture = METEOR_SWORD_TEXTURE
	meteor_sword.scale = Vector2(0.53125, 0.5625) # same as the hand-held swords
	meteor_sword.visible = false
	meteor_sword.z_index = -1 # hilt tucked behind her
	pivot.add_child(meteor_sword)

	# --- LOADOUT SETUP ---
	# A carried empty loadout means unarmed (a new climb, GameManager.
	# new_climb_state). No carried state at all (a room run on its own, a debug
	# warp) keeps the exported blade.
	var start_loadout := loadout
	if state.has("loadout"):
		var carried: Array[WeaponData] = []
		for path: String in state["loadout"]:
			var data := load(path) as WeaponData
			if data:
				carried.append(data)
		if not carried.is_empty() or (state["loadout"] as Array).is_empty():
			start_loadout = carried
	set_loadout(start_loadout, state.get("weapon_slot", 0))
	for data in loadout:
		GameManager.own_weapon(data)
	GameManager.own_armor(armor)
	animated_sprite.self_modulate = armor.tint if armor else Color.WHITE
	_base_frames = animated_sprite.sprite_frames
	apply_skin()


## Wing feathers in carried state. Saves from before the unarmed opening kept
## only the side-route feathers ("flutter_bonus") on top of the blade's two
## flutters, so those count the two that mend her wings as found. No state =
## a room run on its own or a debug warp: wings already mended.
static func _feathers_from(state: Dictionary) -> int:
	if state.has("feathers"):
		return int(state["feathers"])
	return int(state.get("flutter_bonus", 0)) + WINGS_FEATHERS


## Re-skins her sprite to the chosen PlayerSkins skin, keeping the current
## animation and frame. Called on spawn and whenever the skin is changed.
func apply_skin() -> void:
	if _base_frames == null:
		return
	var anim: StringName = animated_sprite.animation
	var frame: int = animated_sprite.frame
	var playing: bool = animated_sprite.is_playing()
	animated_sprite.sprite_frames = PlayerSkins.skinned(_base_frames, PlayerSkins.current())
	animated_sprite.animation = anim
	animated_sprite.frame = frame
	if playing:
		animated_sprite.play()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if damage_invulnerability_timer > 0.0:
		damage_invulnerability_timer = max(0.0, damage_invulnerability_timer - delta)
	if hurt_stun_timer > 0.0:
		hurt_stun_timer = max(0.0, hurt_stun_timer - delta)
	if chill_timer > 0.0:
		_update_chill(delta)
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
		switch_sword(1)
	if InputMap.has_action("switch_weapon_prev") and Input.is_action_just_pressed("switch_weapon_prev"):
		switch_sword(-1)

	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var dive_cancel := _meteor_cancel_input(delta) if is_dive_attacking else &""
	if Input.is_action_just_pressed("attack") and dive_cancel != &"attack":
		attack_buffer = ATTACK_BUFFER_TIME
	elif attack_buffer > 0.0:
		attack_buffer = maxf(0.0, attack_buffer - delta)
	if attack_buffer > 0.0 and _can_attack():
		attack_buffer = 0.0
		if can_start_dive_attack():
			start_dive_attack()
		else:
			execute_attack(_attack_direction())

	_dash_input(delta) # DASH STRIKE

	# --- 1. Gravity & Air Logic ---
	if dash_timer > 0.0:
		_dash_step(delta) # DASH STRIKE: gravity suspended
	elif not is_on_floor() and lunge_timer > 0.0:
		_lunge_step(delta)
	elif not is_on_floor():
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
			if Input.is_action_just_pressed("jump") and velocity.y > 10 and hurt_stun_timer <= 0.0 \
					and (flutter_charges_left > 0 or DebugMenu.infinite_flutter):
				start_flutter()
	else:
		# RESET ON FLOOR
		if is_dive_attacking:
			_land_dive_attack()
			
		is_dive_attacking = false
		is_fluttering = false
		is_jumping = false
		lunge_timer = 0.0
		air_lift_ready = true
		air_lunge_ready = true
		meteor_cancels_left = METEOR_CANCELS_PER_AIRTIME
		
		if flutter_charges_left < max_flutter_charges:
			flutter_charges_left = max_flutter_charges 
			wings_updated.emit(flutter_charges_left)

	# --- 2. Horizontal Movement ---
	var direction := Input.get_axis("move_left", "move_right")

	if hurt_stun_timer > 0.0:
		# Knocked back: no steering, just a little air drag.
		velocity.x = move_toward(velocity.x, 0, FRICTION * weapon_data.traction * 0.25 * delta)
	elif dash_timer > 0.0:
		pass # DASH STRIKE carries her; no steering
	elif is_dive_attacking:
		velocity.x = 0.0 # the meteor falls straight
	elif lunge_timer > 0.0:
		pass # the lunge carries her; no steering
	elif attack_lock_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0, FRICTION * weapon_data.traction * delta)
	elif direction != 0:
		if is_on_floor():
			if signf(velocity.x) != signf(direction) and absf(velocity.x) > 20.0:
				current_momentum = 1.0 # turning around loses the run-up
			else:
				current_momentum = move_toward(current_momentum, MAX_MOMENTUM_BONUS, delta * MOMENTUM_GAIN_RATE * weapon_data.momentum_gain)

		var target_speed = min(BASE_SPEED * weapon_data.top_speed * current_momentum, MAX_SPEED * weapon_data.top_speed)
		if chill_timer > 0.0:
			target_speed *= CHILL_SPEED
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
		if is_on_floor():
			current_momentum = move_toward(current_momentum, 1.0, delta * 3.0)

	# --- 3. Initial Jump / Drop-through ---
	if Input.is_action_just_pressed("jump") and is_on_floor() and hurt_stun_timer <= 0.0 and attack_lock_timer <= 0.0:
		if Input.is_action_pressed("move_down") and _is_standing_on_one_way():
			_start_drop_through()
		else:
			# Height comes from the sword; a full run-up adds a little.
			velocity.y = BASE_JUMP_VELOCITY * weapon_data.jump_height \
					* (1.0 + (current_momentum - 1.0) * JUMP_MOMENTUM_SHARE)
			jump_hold_timer = MAX_JUMP_TIME
			is_jumping = true
			Sfx.play(&"jump")

	# --- 4. Animation ---
	_handle_animations()
	var sfx_fall_speed: float = velocity.y
	_try_step_up(direction, delta) # STEP-UP: small lips don't stop her
	move_and_slide()
	_sfx_landing(sfx_fall_speed)
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


## Unarmed she can still attack: the meteor strike (a bare power stomp) needs
## no sword, and execute_attack() does nothing without one.
func _can_attack() -> bool:
	return hurt_stun_timer <= 0.0 and attack_lock_timer <= 0.0 and attack_cooldown <= 0.0 \
			and not is_dive_attacking \
			and not (active_weapon and active_weapon.has_method("is_swinging") and active_weapon.is_swinging())


## Whether an `interact` press (up) should use what she's standing at. Up is
## also aim-up for attacks and dashes, so it only interacts when she's
## standing still enough to mean it: on the floor, not hurt, dashing or
## swinging, and not holding attack or dash (up + attack is an up-slash).
func can_interact() -> bool:
	if is_dead or not is_on_floor() or hurt_stun_timer > 0.0 or dash_timer > 0.0 or is_dive_attacking:
		return false
	if Input.is_action_pressed("attack") or (InputMap.has_action("dash") and Input.is_action_pressed("dash")):
		return false
	return not (active_weapon and active_weapon.has_method("is_swinging") and active_weapon.is_swinging())


func execute_attack(dir: Vector2 = Vector2.RIGHT):
	if not active_weapon or not active_weapon.has_method("swing"):
		return
	if active_weapon.has_method("is_swinging") and active_weapon.is_swinging():
		return
	_aim_weapon(dir)
	var speed: float = weapon_data.attack_speed
	if "damage_mult" in active_weapon:
		active_weapon.damage_mult = _rotation_mult()
	if not active_weapon.swing(speed):
		return
	if active_weapon.has_method("swing_duration"):
		attack_cooldown = active_weapon.swing_duration(speed) + ATTACK_RECOVERY / speed
	if dir == Vector2.UP:
		_rising_slash()
	elif not is_on_floor() and weapon_data.lunge_speed > 0.0 and air_lunge_ready:
		_start_lunge()
	elif dir == Vector2.RIGHT and active_weapon.has_method("get_attack_thrust"):
		# Forward step of a thrusting sword's ground attack.
		velocity += active_weapon.get_attack_thrust(pivot.scale.x)


## Up + attack: a launcher on the ground, an air boost once per airtime.
func _rising_slash() -> void:
	if weapon_data.rising_lift <= 0.0:
		return
	if not is_on_floor():
		if not air_lift_ready:
			return
		air_lift_ready = false
	velocity.y = minf(velocity.y, -weapon_data.rising_lift)
	is_jumping = false
	is_fluttering = false
	_trail_timer = 0.0
	CombatFX.afterimage(animated_sprite, RISE_TINT)


## Side attack in the air with a thrusting sword: a short gravity-free dash.
func _start_lunge() -> void:
	air_lunge_ready = false
	lunge_timer = LUNGE_TIME
	is_jumping = false
	is_fluttering = false
	velocity = Vector2(signf(pivot.scale.x) * weapon_data.lunge_speed, 0.0)
	_trail_timer = 0.0


func _lunge_step(delta: float) -> void:
	lunge_timer -= delta
	velocity.y = 0.0
	if is_on_wall():
		lunge_timer = 0.0
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.03
		CombatFX.afterimage(animated_sprite, LUNGE_TINT)
	if lunge_timer <= 0.0:
		lunge_timer = 0.0
		velocity.x *= 0.6 # keep some carry, then air steering takes over


## Damage multiplier for the swing about to start: bonus only when this sword
## differs from the one that landed the previous hit, inside the window.
func _rotation_mult() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if _last_hit_weapon and _last_hit_weapon != weapon_data and now - _last_hit_time < ROTATION_WINDOW:
		return 1.0 + ROTATION_STEP * mini(rotation_chain + 1, ROTATION_MAX_STEPS)
	return 1.0


## A swing connected with an enemy: track the rotation chain, and in the air
## hold her up and refresh the rising slash and lunge (keep the combo airborne).
func _on_weapon_landed(target: Node, weapon: Node) -> void:
	if weapon != active_weapon or not target.is_in_group("enemy"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _last_hit_weapon and _last_hit_weapon != weapon_data and now - _last_hit_time < ROTATION_WINDOW:
		rotation_chain = mini(rotation_chain + 1, ROTATION_MAX_STEPS)
		CombatFX.burst(self, (target as Node2D).global_position, 8.0 + 4.0 * rotation_chain,
				weapon_data.tint.lerp(Color(1, 0.85, 0.4), 0.5), 1.0, 3 + 2 * rotation_chain, 0.18)
	else:
		rotation_chain = 0
	_last_hit_weapon = weapon_data
	_last_hit_time = now
	if not is_on_floor():
		air_lift_ready = true
		air_lunge_ready = true
		meteor_cancels_left = METEOR_CANCELS_PER_AIRTIME
		if lunge_timer <= 0.0:
			velocity.y = minf(velocity.y, AIR_HIT_HOVER)


## Rotates the whole swing (sword, arc and hitbox) about her center. The pivot
## is mirrored when facing left, so "right" here always means "in front".
func _aim_weapon(dir: Vector2) -> void:
	var angle := 0.0 if dir == Vector2.RIGHT else -PI / 2.0 if dir == Vector2.UP else PI / 2.0
	weapon_anchor.rotation = angle
	weapon_anchor.position = weapon_anchor_base.rotated(angle)
	if dir == Vector2.UP and weapon_data:
		# Overhead swings turn above her helmet, not at her face (per sword).
		weapon_anchor.position += weapon_data.up_offset / pivot.scale.abs()


## Bounce back off something hard (armor). `dir` is the push direction.
func recoil(dir: float) -> void:
	if is_dead:
		return
	_end_dash(0.0) # DASH STRIKE: bounced off armor
	velocity.x = dir * RECOIL_SPEED
	Sfx.play(&"deflect")
	if not is_on_floor():
		velocity.y = minf(velocity.y, -60.0)
	attack_lock_timer = maxf(attack_lock_timer, 0.12)


## Launched by something springy (a soft slime boulder): like a landing,
## it refreshes flutters and air moves.
func spring(vy: float) -> void:
	if is_dead:
		return
	_end_meteor()
	_end_dash(0.0) # DASH STRIKE
	velocity.y = vy
	Sfx.play(&"spring")
	is_jumping = false
	is_fluttering = false
	lunge_timer = 0.0
	air_lift_ready = true
	air_lunge_ready = true
	meteor_cancels_left = METEOR_CANCELS_PER_AIRTIME
	flutter_charges_left = max_flutter_charges
	wings_updated.emit(flutter_charges_left)


func can_start_dive_attack() -> bool:
	return not is_on_floor() and not is_dive_attacking and Input.is_action_pressed("move_down")

func start_dive_attack():
	is_dive_attacking = true
	is_fluttering = false
	is_jumping = false
	meteor_windup_timer = METEOR_WINDUP
	meteor_trail_timer = 0.0
	meteor_cancel_grace = METEOR_CANCEL_GRACE
	velocity = Vector2(0, -50) # a little hitch upward sells the windup
	Sfx.play(&"meteor_windup", -1.0, 0.0, 0.75)
	_set_dive_attack_hitbox_enabled(false)
	dive_attack_shape.scale = Vector2.ONE * weapon_data.reach # the sword's reach
	if _meteor_tween:
		_meteor_tween.kill()
		_meteor_tween = null
	if active_weapon == null:
		# Unarmed: a power stomp. No sword to flip, she tucks and drops
		# boots first (her dive frames); the trail and landing do the rest.
		meteor_sword.visible = false
		return
	# Sword flips from overhead to straight down during the windup.
	meteor_sword.visible = true
	meteor_sword.position = METEOR_SWORD_UP
	meteor_sword.rotation = -PI / 2.0 - SWORD_ART_ANGLE
	if _meteor_tween:
		_meteor_tween.kill()
	var tween := meteor_sword.create_tween().set_parallel()
	_meteor_tween = tween
	tween.tween_property(meteor_sword, "position", METEOR_SWORD_DOWN, METEOR_WINDUP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(meteor_sword, "rotation", PI / 2.0 - SWORD_ART_ANGLE, METEOR_WINDUP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _meteor_step(delta: float) -> void:
	if meteor_windup_timer > 0.0:
		meteor_windup_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		if meteor_windup_timer <= 0.0:
			velocity = Vector2(0, METEOR_SPEED)
			_set_dive_attack_hitbox_enabled(true)
			Sfx.play(&"meteor_fall")
			CombatFX.burst(self, global_position + Vector2(0, -6), 10.0, Color(1, 0.9, 0.6), 1.0, 0, 0.12)
		return
	velocity = Vector2(0, METEOR_SPEED)
	meteor_trail_timer -= delta
	if meteor_trail_timer <= 0.0:
		meteor_trail_timer = METEOR_TRAIL_INTERVAL
		CombatFX.afterimage(animated_sprite, METEOR_TRAIL_TINT)
		if meteor_sword.visible:
			CombatFX.afterimage(meteor_sword, METEOR_TRAIL_TINT)


func _end_meteor() -> void:
	is_dive_attacking = false
	meteor_windup_timer = 0.0
	_set_dive_attack_hitbox_enabled(false)
	Sfx.stop(&"meteor_fall")
	if _meteor_tween:
		_meteor_tween.kill()
		_meteor_tween = null
	if meteor_sword:
		meteor_sword.visible = false


## Comet strike cancel. A press of dash, attack or jump made after the strike
## started (and after METEOR_CANCEL_GRACE, so the press that started it, a
## held button or a bouncy double-tap can't) drops the strike, windup or
## plunge, and hands control straight back, METEOR_CANCELS_PER_AIRTIME times
## per airtime (refreshed like the other air moves). One press, one move:
##   dash   -> a dash in the held direction, only if can_dash() would allow it
##             (otherwise the press is ignored and she keeps plunging)
##   attack -> an air swing in the held direction (up = rising slash)
##   jump   -> a flutter if she has a feather, else a plain fall from a standstill
## Returns the action that cancelled it, or &"".
func _meteor_cancel_input(delta: float) -> StringName:
	meteor_cancel_grace = maxf(0.0, meteor_cancel_grace - delta)
	if meteor_cancel_grace > 0.0 or meteor_cancels_left <= 0 or hurt_stun_timer > 0.0:
		return &""
	# Ignore the press that closed a menu, the same frames _dash_input does.
	if _dash_resume_block > 0 or (_last_physics_frame >= 0 and Engine.get_physics_frames() - _last_physics_frame > 1):
		return &""
	var action := &""
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash") and _can_dash_out_of_meteor():
		action = &"dash"
	elif Input.is_action_just_pressed("attack"):
		action = &"attack"
	elif Input.is_action_just_pressed("jump"):
		action = &"jump"
	else:
		return &""
	cancel_dive_attack()
	match action:
		&"dash":
			start_dash()
		&"attack":
			var held := Input.get_axis("move_left", "move_right")
			if held != 0.0:
				pivot.scale.x = signf(held)
			attack_buffer = 0.0
			if _can_attack():
				execute_attack(_attack_direction())
		&"jump":
			if flutter_charges_left > 0:
				start_flutter()
	return action


## Ends the strike with no landing: no shockwave, no landing lag. Her plunge
## speed is dropped so whatever she cancels into starts from a standstill.
func cancel_dive_attack() -> void:
	if not is_dive_attacking:
		return
	_end_meteor()
	Sfx.stop(&"meteor_windup")
	meteor_cancels_left -= 1
	velocity.y = minf(velocity.y, 0.0)


## can_dash() as if the strike were already over (it refuses mid-strike).
func _can_dash_out_of_meteor() -> bool:
	is_dive_attacking = false
	var ok := can_dash()
	is_dive_attacking = true
	return ok


func _land_dive_attack():
	var was_plunging: bool = meteor_windup_timer <= 0.0
	_end_meteor()
	if not was_plunging:
		return
	attack_lock_timer = METEOR_LAND_LAG
	_sfx_meteor_impact()
	var radius := METEOR_SHOCK_RADIUS * weapon_data.meteor_power
	CombatFX.burst(self, global_position, radius, Color(1, 0.85, 0.55), 0.3, 10, 0.3)
	CombatFX.shake(self, 3.0 * weapon_data.meteor_power, 0.2)
	# Shockwave: hurts grounded enemies nearby. Armor ignores it; only a direct
	# meteor hit breaks armor.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D or enemy.get("is_dying") or enemy.get("armored"):
			continue
		var d: Vector2 = (enemy as Node2D).global_position - global_position
		if absf(d.x) <= radius and absf(d.y) <= 20.0 and enemy.has_method("take_damage"):
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
	Sfx.play(&"meteor_hit")
	velocity.y = METEOR_BOUNCE * weapon_data.meteor_power
	air_lift_ready = true
	air_lunge_ready = true
	meteor_cancels_left = METEOR_CANCELS_PER_AIRTIME
	CombatFX.burst(self, global_position + Vector2(0, 6), 14.0, Color(1, 0.95, 0.75), 1.0, 6, 0.2)
	CombatFX.shake(self, 2.0, 0.12)

# --- HEALTH & DAMAGE ---
func take_hit(hit: Hit) -> void:
	take_damage(hit.damage, hit.knockback, hit.element)


## `knockback` gives the push direction (only its x sign matters); with no
## direction the player is pushed backwards from where she faces. `element`
## picks which of the armor's resistances applies (NONE = physical).
func take_damage(amount: int = HEART, knockback: Vector2 = Vector2.ZERO, element: Hit.Element = Hit.Element.NONE) -> void:
	if is_dead or amount <= 0: return
	if DebugMenu.god_mode: return
	if damage_invulnerability_timer > 0.0: return
	if dash_guard_timer > 0.0: return # DASH STRIKE: cutting through what she struck

	var dealt := _resisted(amount, element)
	if dealt <= 0:
		# Fully absorbed: still knocked back (no standing in lava), no harm.
		damage_invulnerability_timer = damage_invulnerability_time * 0.5
		_apply_hurt_knockback(knockback)
		CombatFX.burst(self, global_position + Vector2(0, -6), 9.0, armor.icon_color.lightened(0.4), 1.0, 4, 0.15)
		Sfx.play(&"block")
		return
	current_health = max(0, current_health - dealt)
	health_updated.emit(current_health)

	if current_health <= 0:
		_die()
		return
	damage_invulnerability_timer = damage_invulnerability_time
	_apply_hurt_knockback(knockback)
	_play_hurt_feedback()
	Sfx.play(&"hurt")
	_element_status(element)


## Ice chills, thunder jolts; both scale down with the armor's resistance.
func _element_status(element: Hit.Element) -> void:
	var resist := armor.resistance(element) if armor else 0.0
	match element:
		Hit.Element.ICE:
			chill_timer = maxf(chill_timer, CHILL_TIME * (1.0 - resist))
			if chill_timer > 0.0:
				pivot.modulate = Color(CHILL_TINT, pivot.modulate.a)
				Sfx.play(&"chill")
		Hit.Element.THUNDER:
			hurt_stun_timer += JOLT_STUN * (1.0 - resist)
			Sfx.play(&"jolt")
			CombatFX.burst(self, global_position + Vector2(0, -8), 10.0, Color(1.0, 0.95, 0.4), 1.0, 6, 0.2)
			if resist < 0.5 and flutter_charges_left > 0:
				flutter_charges_left -= 1
				wings_updated.emit(flutter_charges_left)


func _update_chill(delta: float) -> void:
	chill_timer = maxf(0.0, chill_timer - delta)
	_chill_fx -= delta
	if _chill_fx <= 0.0 and chill_timer > 0.0:
		_chill_fx = 0.18
		CombatFX.burst(self, global_position + Vector2(randf_range(-5, 5), -10), 4.0, Color(0.85, 0.95, 1.0), 1.0, 2, 0.25)
	if chill_timer <= 0.0:
		pivot.modulate = Color(1, 1, 1, pivot.modulate.a)


func _apply_hurt_knockback(knockback: Vector2) -> void:
	var dir_x := signf(knockback.x)
	if dir_x == 0.0:
		dir_x = -signf(pivot.scale.x) if pivot.scale.x != 0 else -1.0
	var steady := 1.0 - (armor.stagger_resist if armor else 0.0)
	_end_dash(0.0) # DASH STRIKE
	velocity = Vector2(dir_x * hurt_knockback.x, hurt_knockback.y) * steady
	hurt_stun_timer = hurt_stun_time * steady
	lunge_timer = 0.0
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
	
	_end_dash(0.0) # DASH STRIKE: puts the brandished sword away
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
	Sfx.play(&"death", 0.0, 0.0, 0.7)
	Sfx.play_after(&"armor_burst", DeathSequence.SHAKE_TIME)

	# Armor shakes apart into feathers, then the level reloads.
	# (death_reload_delay is unused now; the sequence sets the pace.)
	var sequence := DeathSequence.play(self)
	sequence.finished.connect(func() -> void:
		get_tree().reload_current_scene())

func _heal(amount: int = HEART) -> void:
	current_health = min(max_health, current_health + amount)
	health_updated.emit(current_health)
	Sfx.play(&"heal")


## Permanent: one more heart (2 half-hearts) of max health, and a full heal.
func add_heart_container(count: int = 1) -> void:
	base_max_health += HEART * count
	Sfx.play(&"power_up")
	_apply_armor_stats()
	current_health = max_health
	health_updated.emit(current_health)


## Damage after the armor's resistance to `element`, in whole half-hearts.
func _resisted(amount: int, element: Hit.Element) -> int:
	var resist := armor.resistance(element) if armor else 0.0
	if resist <= 0.0:
		return amount
	var exact := amount * (1.0 - resist) + _damage_carry
	var dealt := floori(exact + 0.001)
	_damage_carry = exact - dealt
	return dealt


## Puts on `data` (shrines, pedestals). Bonus hearts come as empty containers
## (no heal from swapping); taking them off trims health to the new max.
func set_armor(data: ArmorData) -> void:
	if data == null:
		return
	armor = data
	_damage_carry = 0.0
	GameManager.own_armor(data)
	_apply_armor_stats()
	animated_sprite.self_modulate = data.tint
	armor_changed.emit(data)


func _apply_armor_stats() -> void:
	max_health = base_max_health + (armor.bonus_hearts * HEART if armor else 0)
	current_health = mini(current_health, max_health)
	health_updated.emit(current_health)
	if weapon_data:
		max_flutter_charges = _max_flutter()
		flutter_charges_left = mini(flutter_charges_left, max_flutter_charges)
		wings_updated.emit(flutter_charges_left)

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
	# Broken wings strain harder (higher) with each flap used this airtime.
	Sfx.play(&"flutter", -1.0, 0.0, 1.0 + 0.08 * maxi(0, max_flutter_charges - flutter_charges_left - 1))

func add_flutter_charge(amount: int = 1):
	flutter_charges_left = min(flutter_charges_left + amount, max_flutter_charges)
	wings_updated.emit(flutter_charges_left)

## Permanent upgrade (WingFeather, scripts/wings.gd): one more feather. The
## first WINGS_FEATHERS mend her wings (the sword's own flutters); each one
## after is one more flutter per airtime (the total stays <= FLUTTER_CAP).
func add_flutter_slot(amount: int = 1):
	flutter_bonus += amount
	Sfx.play(&"power_up")
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
	hazard_sensor.body_entered.connect(func(_body: Node2D) -> void: respawn_from_hazard(HEART, _hazard_element()))

func _update_last_safe_position() -> void:
	if not is_on_floor() or not get_platform_velocity().is_zero_approx():
		return
	if hazard_sensor and hazard_sensor.has_overlapping_bodies():
		return
	last_safe_position = global_position

## Lava, poison, bottomless pits: hurt (ignoring i-frames) and return to safe ground.
func respawn_from_hazard(amount: int = HEART, element: Hit.Element = Hit.Element.NONE) -> void:
	if is_dead or hazard_cooldown > 0.0:
		return
	hazard_cooldown = 0.3
	damage_invulnerability_timer = 0.0
	take_damage(amount, Vector2.ZERO, element)
	if is_dead:
		return
	global_position = last_safe_position
	_end_dash(0.0) # DASH STRIKE
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
	Sfx.play(&"drop_through")

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
	switch_sword(1)


## Next (+1) or previous (-1) sword. Cancels a swing in progress so the new
## sword can strike right away (the buffered attack fires on the next frame).
func switch_sword(step: int) -> void:
	if loadout.size() < 2 or is_dead:
		return
	if active_weapon and active_weapon.has_method("cancel_swing"):
		active_weapon.cancel_swing()
	attack_cooldown = 0.0
	_equip(posmod(active_slot + step, loadout.size()), false)
	Sfx.play(&"switch_sword")
	CombatFX.afterimage(animated_sprite, Color(weapon_data.tint.r, weapon_data.tint.g, weapon_data.tint.b, 0.45), 0.12)


## Replaces the carried swords (1 to MAX_LOADOUT) and equips `slot`. Used at
## start, by shrines (armory) and pedestals. Flutters are kept, not refilled.
## An empty loadout leaves her unarmed (WeaponData.unarmed()): the start of
## the climb, before the Valkyrie Blade in hel_02.
func set_loadout(new_loadout: Array, slot: int = 0) -> void:
	var swords: Array[WeaponData] = []
	for data in new_loadout:
		if data is WeaponData and data.scene and not data in swords and swords.size() < MAX_LOADOUT:
			swords.append(data)
	var first_time := weapon_data == null
	for inst in loadout_instances:
		inst.queue_free()
	loadout_instances.clear()
	active_weapon = null
	loadout = swords
	for data in loadout:
		var inst: Node2D = data.scene.instantiate()
		if "data" in inst:
			inst.data = data
		inst.modulate = data.tint
		if inst.has_signal("landed"):
			inst.landed.connect(_on_weapon_landed.bind(inst))
		weapon_anchor.add_child(inst)
		_disable_weapon(inst)
		loadout_instances.append(inst)
	weapon_1_instance = loadout_instances[0] if loadout_instances.size() > 0 else null
	weapon_2_instance = loadout_instances[1] if loadout_instances.size() > 1 else null
	_equip(clampi(slot, 0, loadout.size() - 1), first_time)


## Pedestal pickup: adds the sword if there's a free slot (and switches to it),
## otherwise swaps it for the sword in hand. Returns the sword left behind on
## the pedestal (null if none).
func take_weapon(data: WeaponData) -> WeaponData:
	GameManager.own_weapon(data)
	var swords := loadout.duplicate()
	if swords.size() < MAX_LOADOUT:
		swords.append(data)
		set_loadout(swords, swords.size() - 1)
		return null
	var left_behind: WeaponData = swords[active_slot]
	swords[active_slot] = data
	set_loadout(swords, active_slot)
	return left_behind


func _equip(slot: int, refill_flutter: bool) -> void:
	if active_weapon:
		if active_weapon.has_method("cancel_swing"):
			active_weapon.cancel_swing()
		_disable_weapon(active_weapon)
	active_slot = slot
	if loadout.is_empty():
		# Unarmed: bare movement, no swing (active_weapon stays null).
		active_slot = 0
		weapon_data = WeaponData.unarmed()
		active_weapon = null
	else:
		weapon_data = loadout[slot]
		active_weapon = loadout_instances[slot]
		_enable_weapon(active_weapon)
	max_flutter_charges = _max_flutter()
	if refill_flutter:
		flutter_charges_left = max_flutter_charges
	else:
		flutter_charges_left = mini(flutter_charges_left, max_flutter_charges)
	wings_updated.emit(flutter_charges_left)
	if meteor_sword:
		meteor_sword.modulate = weapon_data.tint
	weapon_switched.emit(slot == 0)
	weapon_changed.emit(weapon_data, slot)


func _max_flutter() -> int:
	if flutter_bonus < WINGS_FEATHERS:
		return 0 # wings still broken: no flutter from sword or armor
	var feathers := armor.bonus_feathers if armor else 0
	return mini(weapon_data.flutter_charges + flutter_bonus - WINGS_FEATHERS + feathers, FLUTTER_CAP)


## Element of the level's hazard tiles (lava burns; poison pools don't).
func _hazard_element() -> Hit.Element:
	var level := LevelManager.current_level
	if level and level.has_method("hazard_element"):
		return level.hazard_element()
	return Hit.Element.NONE


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
	

# --- DASH STRIKE ---
## A side-route ability (AbilityShrine "ability:dash"; GameManager.has_ability).
## The `dash` action bursts her in the direction held on the stick / arrows,
## 8-way (up, down, diagonals), or straight ahead where she faces if nothing
## is held. Gravity is suspended for the burst only. It stops at walls,
## ceilings and floors and cuts through enemies in its path with the sword's
## element. A level ground dash is free (short cooldown); in the air, or any
## dash with an upward part (even from the ground), it spends one flutter
## feather and is refused with none left, so dashes can't replace feathers
## on the climb. On the ground, down is ignored (it dashes level). A dash into armor (or a
## shield from the front) clinks off and bounces her back, like a slash. She
## is not invulnerable: only after landing a hit does she get a brief guard
## while she passes through what she struck. Jumping out of a ground dash
## leaves with a full run-up's speed (no more).
const DASH_SPEED := 500.0          # px/s: 5 tiles in DASH_TIME
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.3         # from the end of one dash to the next
const DASH_BUFFER := 0.1           # an early press still dashes when allowed
const DASH_DAMAGE_MULT := 0.75     # of the sword's damage
const DASH_KNOCKBACK := 220.0
const DASH_HIT_GUARD := 0.2        # no contact harm right after a landed dash hit
const DASH_REACH := 12.0           # hitbox reaches this far ahead of her center
const DASH_HITBOX_HEIGHT := 14.0
const DASH_HIT_MASK := 1           # what swords scan: enemy hurtboxes, obstacles
const DASH_TRAIL_INTERVAL := 0.03
const DASH_CARRY_Y := 0.33         # share of vertical dash speed kept after
const DASH_SWORD_HOLD := 4.0       # px from her body centre to the brandished grip
const DASH_SWORD_THRUST := 3.0     # px the brandish shoots forward as she sets off
const DASH_SWORD_THRUST_TIME := 0.05
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_buffer := 0.0
var dash_guard_timer := 0.0
var _dash_dir := 1.0               # facing sign (-1 / 1), for flips and FX
var _dash_vec := Vector2.RIGHT     # unit direction of this dash
var _dash_grounded := false
var _dash_hit: Dictionary = {}     # instance ids already struck this dash
var _dash_trail: DashTrail
var _dash_ghost_timer := 0.0
var _dash_shape: RectangleShape2D
var _dash_sword: Sprite2D          # the equipped sword held out (brandish, no hitbox)
var _last_physics_frame := -1
var _dash_resume_block := 0        # physics frames to ignore dash after a resume


func has_dash() -> bool:
	return GameManager.has_ability(&"dash")


## Reads the `dash` action (buffered) and starts a dash when allowed. Ignores
## the press that closed a menu (O is also "menu back"): physics frames keep
## counting while the tree is paused, so a gap since our last frame means the
## game just resumed. The stale press can show up on the first or second
## frame after, depending on when the menu unpaused, so both are skipped.
func _dash_input(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	var resumed := _last_physics_frame >= 0 and frame - _last_physics_frame > 1
	_last_physics_frame = frame
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_guard_timer = maxf(0.0, dash_guard_timer - delta)
	dash_buffer = maxf(0.0, dash_buffer - delta)
	if resumed:
		_dash_resume_block = 2
	if _dash_resume_block > 0:
		_dash_resume_block -= 1
		dash_buffer = 0.0
		return
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		dash_buffer = DASH_BUFFER
	if dash_buffer > 0.0 and dash_timer <= 0.0 and can_dash():
		dash_buffer = 0.0
		start_dash()


func can_dash() -> bool:
	if not has_dash() or is_dead or dash_timer > 0.0 or dash_cooldown > 0.0:
		return false
	if hurt_stun_timer > 0.0 or attack_lock_timer > 0.0 or is_dive_attacking:
		return false
	return not _dash_costs_feather(_dash_direction()) or flutter_charges_left > 0 \
			or DebugMenu.infinite_flutter


## Unit direction for a dash started now: the held direction, 8-way (down
## dropped on the ground), else straight ahead where she faces.
func _dash_direction() -> Vector2:
	var held := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	held = Vector2(signf(roundf(held.x)), signf(roundf(held.y))) # snap the stick to 8 ways
	if is_on_floor() and held.y > 0.0:
		held.y = 0.0
	if held == Vector2.ZERO:
		held.x = signf(pivot.scale.x) if pivot.scale.x != 0.0 else 1.0
	return held.normalized()


## A feather pays for any dash in the air, and for one that rises.
func _dash_costs_feather(dir: Vector2) -> bool:
	return not is_on_floor() or dir.y < 0.0


## Starts the burst. A feather (in the air, or rising) is spent through the
## same path as a flutter (wings_updated), which the HUD feathers show.
func start_dash() -> void:
	_dash_vec = _dash_direction()
	if _dash_vec.x != 0.0:
		pivot.scale.x = signf(_dash_vec.x)
	_dash_dir = signf(pivot.scale.x) if pivot.scale.x != 0.0 else 1.0
	_dash_grounded = is_on_floor() and _dash_vec.y == 0.0
	if _dash_costs_feather(_dash_vec):
		if not DebugMenu.infinite_flutter:
			flutter_charges_left -= 1
		wings_updated.emit(flutter_charges_left)
		_dash_feather_fx()
	dash_timer = DASH_TIME
	is_jumping = false
	is_fluttering = false
	lunge_timer = 0.0
	_dash_hit.clear()
	velocity = _dash_vec * DASH_SPEED
	_dash_ghost_timer = 0.0
	var tint: Color = weapon_data.tint.lerp(Color.WHITE, 0.5) if weapon_data else Color.WHITE
	_dash_trail = DashTrail.spawn(self, _dash_vec, Color(tint, 0.8))
	_pose_dash_sword()
	Sfx.play(&"dash", -1.0, 0.0, 1.25)


func _dash_step(delta: float) -> void:
	if is_dive_attacking:
		_end_dash(0.0)
		return
	# Jump out of a ground dash: leaves with a full run-up, no extra.
	if _dash_grounded and is_on_floor() and Input.is_action_just_pressed("jump"):
		current_momentum = MAX_MOMENTUM_BONUS
		_end_dash(_dash_dir * MAX_SPEED * weapon_data.top_speed)
		return
	if is_on_wall() and get_wall_normal().x * _dash_vec.x < 0.0:
		_end_dash(0.0)
		return
	if (_dash_vec.y < 0.0 and is_on_ceiling()) or (_dash_vec.y > 0.0 and is_on_floor()):
		_end_dash(_dash_vec.x * BASE_SPEED * weapon_data.top_speed)
		return
	velocity = _dash_vec * DASH_SPEED
	_dash_strike(delta)
	if dash_timer <= 0.0:
		return # clinked off armor (recoil ended it)
	_pose_dash_sword()
	_dash_ghost_timer -= delta
	if _dash_ghost_timer <= 0.0:
		_dash_ghost_timer = DASH_TRAIL_INTERVAL
		CombatFX.afterimage(animated_sprite, LUNGE_TINT)
		if _dash_sword.visible:
			CombatFX.afterimage(_dash_sword, LUNGE_TINT)
	if dash_timer - delta <= 0.0:
		# Back to her run speed; steering, gravity and friction take over.
		_end_dash(_dash_vec.x * BASE_SPEED * weapon_data.top_speed)
	else:
		dash_timer -= delta


## Ends a dash in progress (no-op otherwise); `carry_x` is her speed after.
## A vertical part eases off to a third of dash speed, so an up-dash floats
## to a stop rather than launching her, and a down-dash keeps falling.
func _end_dash(carry_x: float) -> void:
	if dash_timer <= 0.0:
		return
	dash_timer = 0.0
	dash_cooldown = DASH_COOLDOWN
	velocity.x = carry_x
	velocity.y = _dash_vec.y * DASH_SPEED * DASH_CARRY_Y if not is_on_floor() else 0.0
	if _dash_trail and is_instance_valid(_dash_trail):
		_dash_trail.stop()
	_dash_trail = null
	if _dash_sword:
		_dash_sword.visible = false


## Brandish: the equipped sword's own art and tint held out along the dash
## from her body, shooting forward a few pixels as she sets off. Looks only:
## the dash's query (_dash_strike) is its one damage source. Hidden while a
## swing shows the sword instead.
func _pose_dash_sword() -> void:
	if _dash_sword == null:
		_dash_sword = Sprite2D.new()
		_dash_sword.name = "DashSword"
		pivot.add_child(_dash_sword) # after her sprite: drawn over her
	var weapon := active_weapon
	if weapon == null or not weapon.has_method("pose_held_art") \
			or (weapon.has_method("is_swinging") and weapon.is_swinging()):
		_dash_sword.visible = false
		return
	weapon.pose_held_art(_dash_sword)
	_dash_sword.modulate = weapon_data.tint
	# Pivot space: mirrored when facing left and scaled, so convert from world.
	var dir := Vector2(_dash_vec.x * signf(pivot.scale.x), _dash_vec.y)
	var k := clampf((DASH_TIME - dash_timer) / DASH_SWORD_THRUST_TIME, 0.0, 1.0)
	var hold := DASH_SWORD_HOLD + DASH_SWORD_THRUST * (ease(k, 0.4) - 1.0)
	_dash_sword.position = (Vector2(0.0, 1.0) + dir * hold) / pivot.scale.abs()
	_dash_sword.rotation += dir.angle()
	_dash_sword.visible = true


## The dash's hitbox: a box from her center to DASH_REACH ahead along the
## dash, stretched by this frame's travel, queried directly so a fast pass
## can't skip a target.
## Each target is struck once per dash.
func _dash_strike(delta: float) -> void:
	if _dash_shape == null:
		_dash_shape = RectangleShape2D.new()
	var length := DASH_REACH + DASH_SPEED * delta
	_dash_shape.size = Vector2(length, DASH_HITBOX_HEIGHT)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _dash_shape
	query.transform = Transform2D(_dash_vec.angle(), global_position + Vector2(0.0, -7.0) + _dash_vec * length / 2.0)
	query.collision_mask = DASH_HIT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider: Object = result["collider"]
		var targets: Array = [collider]
		if collider is Area2D and (collider as Node).get_parent() is Node2D:
			targets.append((collider as Node).get_parent())
		for target: Object in targets:
			if not is_instance_valid(target) or target == self or _dash_hit.has(target.get_instance_id()):
				continue
			if target is Node and (target as Node).is_in_group("player"):
				continue
			if not (target.has_method("take_hit") or target.has_method("take_damage")):
				continue
			_dash_hit[target.get_instance_id()] = true
			var hit := Hit.make(maxi(1, roundi(weapon_data.damage * DASH_DAMAGE_MULT)),
					_dash_vec * DASH_KNOCKBACK, weapon_data.element, weapon_data.heavy_hits, self)
			if not Hit.deliver(target, hit):
				continue
			if dash_timer <= 0.0:
				return # armor: the target called recoil(), which ended the dash
			_dash_landed(target)


func _dash_landed(target: Object) -> void:
	dash_guard_timer = DASH_HIT_GUARD
	Sfx.play(&"dash_hit")
	var at: Vector2 = (target as Node2D).global_position if target is Node2D else global_position
	CombatFX.burst(self, at + Vector2(0, -4), 9.0, weapon_data.tint.lerp(Color.WHITE, 0.4), 1.0, 5, 0.15)


## A feather or two shaken loose: the air dash's cost, made visible.
func _dash_feather_fx() -> void:
	var feathers := FeatherBurst.new()
	feathers.count = 3
	feathers.life = 0.9
	feathers.fade_time = 0.4
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(feathers)
	feathers.global_position = global_position + Vector2(0.0, -8.0) - _dash_vec * 4.0


# --- SOUND (see scripts/audio/sfx.gd) ---
## A footstep on each foot contact of the run cycle (every 4th frame), on the
## current realm's surface.
func _sfx_footstep() -> void:
	if animated_sprite.animation == &"run" and animated_sprite.frame % 4 == 0 and is_on_floor():
		Sfx.play(Sfx.footstep_id())


## Landing thud, louder with fall speed; a full-speed fall lands heavy. The
## meteor strike has its own impact instead.
func _sfx_landing(fall_speed: float) -> void:
	var grounded := is_on_floor()
	if grounded and not _sfx_on_floor and not is_dead and not is_dive_attacking and fall_speed > 80.0:
		var heavy := fall_speed >= TERMINAL_VELOCITY * 0.95
		Sfx.play(&"land_heavy" if heavy else &"land", -1.0, remap(minf(fall_speed, TERMINAL_VELOCITY), 80.0, TERMINAL_VELOCITY, -10.0, 0.0))
	_sfx_on_floor = grounded


## Meteor landing boom; stronger swords (meteor_power) get the big one.
func _sfx_meteor_impact() -> void:
	if weapon_data.meteor_power >= 1.2:
		Sfx.play(&"meteor_impact_big")
		Sfx.play(&"meteor_slam")
	else:
		Sfx.play(&"meteor_impact", -1.0, 0.0, 1.0 / maxf(weapon_data.meteor_power, 0.5))


# --- STEP-UP ---
## Walking into a lip no taller than STEP_HEIGHT (a seam between bodies, or a
## one-way platform tile whose top sits 2px below the solid ground beside it)
## lifts her onto it with no jump and no lost speed. Her rounded capsule only
## rides over ~1px by itself. STEP_HEIGHT stays well under half a tile, so every
## real 16px ledge still needs a jump; and it only works from the floor (or a
## few frames after walking off it) while not rising, so it never adds height
## to a jump or a flutter.
const STEP_HEIGHT := 6.0
const STEP_COYOTE_FRAMES := 3
var _step_air_frames := 0


## Called right before move_and_slide(): if this frame's run would hit a low
## lip, raise her by its height so the slide carries her on at full speed.
func _try_step_up(direction: float, delta: float) -> void:
	_step_air_frames = 0 if is_on_floor() else _step_air_frames + 1
	if direction == 0.0 or signf(velocity.x) != signf(direction) or velocity.y < 0.0:
		return # not pushing forward into it, or rising (jump / flutter)
	if _step_air_frames > STEP_COYOTE_FRAMES or dash_timer > 0.0 or lunge_timer > 0.0 \
			or hurt_stun_timer > 0.0 or is_dive_attacking:
		return
	var from := global_transform
	var ahead := Vector2(maxf(absf(velocity.x) * delta, 1.0) * direction, 0.0)
	var wall := _step_test(from, ahead)
	if wall == null or wall.get_collision_normal().x * direction > -0.3 \
			or absf(wall.get_collision_normal().angle_to(up_direction)) <= floor_max_angle:
		return # nothing ahead, or a slope she walks up anyway
	# How far up she can go without hitting a ceiling.
	var rise := _step_test(from, Vector2(0.0, -STEP_HEIGHT))
	var headroom := STEP_HEIGHT if rise == null else -rise.get_travel().y
	if headroom < 0.5:
		return
	# Probe at least one foot-radius ahead, so her flat bottom (not the round
	# of the capsule grazing the corner) is what lands on the lip's top.
	var probe := ahead.normalized() * maxf(absf(ahead.x), _step_foot_radius())
	var raised := from.translated(Vector2(0.0, -headroom))
	if _step_test(raised, probe) != null:
		return # still blocked up there: a real wall or ledge
	# Drop back down past the lip to find its top.
	var over := raised.translated(probe)
	var land := _step_test(over, Vector2(0.0, headroom))
	if land == null or absf(land.get_collision_normal().angle_to(up_direction)) > floor_max_angle:
		return
	var step := headroom - land.get_travel().y
	if step <= 0.0 or _step_hazard_at(over.origin + land.get_travel()):
		return
	# A hair over the lip, and shifted so this frame's slide ends right where
	# the probe landed (fully on top, not snapped back onto the corner).
	global_position += Vector2(probe.x - ahead.x, -minf(step + 0.25, headroom))


## Radius of the round bottom of her collider (1 px for a box).
func _step_foot_radius() -> float:
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CapsuleShape2D:
		return (shape_node.shape as CapsuleShape2D).radius
	return 1.0


## Motion test of her body from `from` along `motion`; null if it's free.
func _step_test(from: Transform2D, motion: Vector2) -> PhysicsTestMotionResult2D:
	var params := PhysicsTestMotionParameters2D.new()
	params.from = from
	params.motion = motion
	params.margin = safe_margin
	var result := PhysicsTestMotionResult2D.new()
	return result if PhysicsServer2D.body_test_motion(get_rid(), params, result) else null


## True if her hazard sensor would touch lava / poison standing at `pos`.
func _step_hazard_at(pos: Vector2) -> bool:
	if hazard_sensor == null:
		return false
	var shape_node := hazard_sensor.get_child(0) as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = Transform2D(0.0, pos + shape_node.position)
	query.collision_mask = HAZARD_LAYER
	query.collide_with_areas = true
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
