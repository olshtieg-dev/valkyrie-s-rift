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

# --- Dive Attack Fall Settings ---
const DIVE_ATTACK_GRAVITY_SCALE = 6.0
const DIVE_ATTACK_MAX_SPEED = 600.0
const DIVE_ATTACK_START_SPEED = 300.0
const DIVE_ATTACK_DAMAGE = 25
const DIVE_ATTACK_KNOCKBACK = 300.0

# --- Flutter Settings ---
const FLUTTER_KICK = -150.0
const FLUTTER_DURATION = 0.4
const FLUTTER_GRAVITY_SCALE = 0.1

# --- PROGRESSION VARIABLES ---
var max_flutter_charges = 2    
var flutter_charges_left = 2
signal wings_updated(count)
signal health_updated(count)
signal weapon_switched(is_sword_1)

var jump_hold_timer = 0.0
var is_jumping = false
var is_fluttering = false
var is_dive_attacking = false
var flutter_timer = 0.0
var current_health = 0
var damage_invulnerability_timer = 0.0
var is_dead = false
var coins_toward_life = 0

@export_group("Visuals")
@export var dive_attack_animation: StringName = &"dive_attack"

@export_group("Stats")
@export var max_health: int = 6
@export var starting_health: int = 3
@export var damage_invulnerability_time: float = 1.0
@export var death_reload_delay: float = 1.0
@export var coins_per_life: int = 10

@onready var animated_sprite = $Pivot/AnimatedSprite2D
@onready var pivot = $Pivot
@onready var weapon_anchor = $Pivot/WeaponAnchor
@onready var dive_attack_hitbox = $DiveAttackHitbox
@onready var dive_attack_shape = $DiveAttackHitbox/CollisionShape2D

# --- WEAPON INVENTORY SETTINGS ---
var sword1_scene = preload("res://scenes/sword.tscn")
var sword2_scene = preload("res://scenes/sword2.tscn")

var weapon_1_instance: Node2D
var weapon_2_instance: Node2D
var active_weapon: Node2D 

func _ready() -> void:
	add_to_group("player") # Vital for enemies to find you
	
	current_health = clampi(starting_health, 1, max_health)
	health_updated.emit(current_health)
	wings_updated.emit(flutter_charges_left)
	
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
	
	# --- INVENTORY SETUP ---
	if sword1_scene:
		weapon_1_instance = sword1_scene.instantiate()
		weapon_anchor.add_child(weapon_1_instance)
		active_weapon = weapon_1_instance
	
	if sword2_scene:
		weapon_2_instance = sword2_scene.instantiate()
		weapon_anchor.add_child(weapon_2_instance)
		# Disable Sword 2 by default
		_disable_weapon(weapon_2_instance)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if damage_invulnerability_timer > 0.0:
		damage_invulnerability_timer = max(0.0, damage_invulnerability_timer - delta)


	# --- 0. Attack Input & Weapon Switching ---
	if Input.is_action_just_pressed("switch_weapon"):
		print("Input detected: Switching weapon!") 
		_on_sword_switch_requested() # Ensure this is on its own line!
	
	
	# --- In _physics_process ---
# 1. Check for the Controller/Keyboard input directly
	if Input.is_action_just_pressed("switch_weapon"):
		print("Input detected: Switching weapon!") # This helps us debug in the Output window_on_sword_switch_requested()
	
	
	if Input.is_action_just_pressed("attack"):
		if can_start_dive_attack():
			start_dive_attack()
		elif not is_dive_attacking:
			execute_attack()

	# --- 1. Gravity & Air Logic ---
	if not is_on_floor():
		if is_dive_attacking:
			is_fluttering = false
			is_jumping = false
			velocity += get_gravity() * DIVE_ATTACK_GRAVITY_SCALE * delta
			velocity.y = min(velocity.y, DIVE_ATTACK_MAX_SPEED)
			
		elif is_fluttering:
			velocity += get_gravity() * FLUTTER_GRAVITY_SCALE * delta
			velocity.y = move_toward(velocity.y, FLUTTER_KICK, 15)
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
			if Input.is_action_just_pressed("jump") and velocity.y > 10 and flutter_charges_left > 0:
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
	
	if direction != 0:
		if is_on_floor():
			current_momentum = move_toward(current_momentum, MAX_MOMENTUM_BONUS, delta * MOMENTUM_GAIN_RATE)
		
		var target_speed = min(BASE_SPEED * current_momentum, MAX_SPEED)
		velocity.x = move_toward(velocity.x, direction * target_speed, ACCELERATION * delta)
		
		# VISUAL FLIP
		if direction > 0:
			pivot.scale.x = 1
		elif direction < 0:
			pivot.scale.x = -1
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# --- 3. Initial Jump ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = BASE_JUMP_VELOCITY * current_momentum
		jump_hold_timer = MAX_JUMP_TIME
		is_jumping = true

	# --- 4. Animation ---
	_handle_animations()
	move_and_slide()

func _handle_animations() -> void:
	if is_on_floor():
		if abs(velocity.x) < 5.0:
			animated_sprite.play("idle")
			animated_sprite.speed_scale = 1.0
		else:
			animated_sprite.play("run")
			animated_sprite.speed_scale = max(0.8, abs(velocity.x) / BASE_SPEED)
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
func execute_attack():
	if active_weapon and active_weapon.has_method("swing"):
		if active_weapon.swing():
			# Add thrust movement
			if active_weapon.has_method("get_attack_thrust"):
				var facing_direction: float = pivot.scale.x
				var thrust: Vector2 = active_weapon.get_attack_thrust(facing_direction)
				velocity += thrust

func can_start_dive_attack() -> bool:
	return not is_on_floor() and not is_dive_attacking and Input.is_action_pressed("move_down")

func start_dive_attack():
	is_dive_attacking = true
	is_fluttering = false
	is_jumping = false
	_set_dive_attack_hitbox_enabled(true)
	velocity.y = max(velocity.y, DIVE_ATTACK_START_SPEED)

func _land_dive_attack():
	_set_dive_attack_hitbox_enabled(false)
	# Optional: Add a screen shake or landing particle here

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
	if target == self: return
	if target.has_method("take_damage"):
		# Knockback is usually DOWN for a dive attack
		target.take_damage(DIVE_ATTACK_DAMAGE, Vector2.DOWN * DIVE_ATTACK_KNOCKBACK)
		# Optional: Bounce the player up slightly on hit
		velocity.y = -200

# --- HEALTH & DAMAGE ---
func take_damage(amount: int = 1, _knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0: return
	if damage_invulnerability_timer > 0.0: return

	current_health = max(0, current_health - amount)
	health_updated.emit(current_health)

	if current_health <= 0:
		_die()
	else:
		damage_invulnerability_timer = damage_invulnerability_time
		# Flash effect or sound here

func _die() -> void:
	if is_dead: return
	is_dead = true
	
	# Disable physics
	velocity = Vector2.ZERO
	var collider = get_node_or_null("CollisionShape2D")
	if collider: collider.set_deferred("disabled", true)
	
	# Slow motion death
	Engine.time_scale = 0.5
	
	# Create a timer to reload
	var t = get_tree().create_timer(death_reload_delay)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	)

func _heal(amount: int = 1) -> void:
	current_health = min(max_health, current_health + amount)
	health_updated.emit(current_health)

# --- ABILITIES ---
func start_flutter():
	is_fluttering = true
	is_dive_attacking = false
	_set_dive_attack_hitbox_enabled(false)
	is_jumping = false
	flutter_timer = FLUTTER_DURATION
	flutter_charges_left -= 1 
	velocity.y = FLUTTER_KICK # Instant kick up
	wings_updated.emit(flutter_charges_left)

func add_flutter_charge(amount: int = 1):
	flutter_charges_left = min(flutter_charges_left + amount, max_flutter_charges)
	wings_updated.emit(flutter_charges_left)

# --- WEAPON SWITCHING ---
func _on_sword_switch_requested():
	if active_weapon == weapon_1_instance:
		_disable_weapon(weapon_1_instance)
		_enable_weapon(weapon_2_instance)
		active_weapon = weapon_2_instance
	else:
		_disable_weapon(weapon_2_instance)
		_enable_weapon(weapon_1_instance)
		active_weapon = weapon_1_instance
	
	# MOVE THIS OUTSIDE THE IF/ELSE:
	# Now it fires every single time a switch happens
	var is_s1 = (active_weapon == weapon_1_instance)
	weapon_switched.emit(is_s1)
	print("PLAYER: Emitted weapon_switched signal. Is Sword 1: ", is_s1)

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
	
