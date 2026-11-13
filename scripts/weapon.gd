extends Area2D
class_name Weapon
@export var damage: int = 15
@export var anim_player: AnimationPlayer 
@export var sword_sprite: Sprite2D
@export var hitbox: CollisionShape2D
@export_group("Stats")
@export var knockback_force: float = 250.0
@export var fallback_hit_radius: float = 20.0
@export_group("Visuals")
@export var attack_animation: StringName = &"attack_slash"
@export_group("Movement")
@export var thrust_speed: float = 0.0
@export var thrust_vertical_speed: float = 0.0

## Set by the player when equipped. Supplies damage, element and heavy hits;
## without it the exported `damage` is used and hits are plain.
var data: WeaponData
## Set per swing by the player (sword-rotation combo bonus).
var damage_mult := 1.0

## First thing this swing actually hit (once per swing).
signal landed(target: Node)
var _landed_this_swing := false

## The swing art's own scale and offset, before reach (see _apply_reach).
var _art_scale := Vector2.ONE
var _art_offset := Vector2.ZERO
## Turns the art so its blade points along +x: the 32px scene art leans
## up-right (45 degrees), a swing_texture stands blade-up (90).
var _art_held_rotation := PI / 4.0

## Fast swings carry the hitbox a long way between physics frames (the
## rapier's thrust crosses ~50px in under three), so overlap signals alone
## skip what it passes over. Each physics frame of a swing also sweeps the
## hitbox from its last pose to this one in steps of about SWEEP_STEP px,
## striking what it crosses. Every target is struck at most once per swing.
const SWEEP_STEP := 3.0
const SWEEP_MAX_STEPS := 24
var _sweeping := false
var _from_rot := 0.0
var _from_pos := Vector2.ZERO
var _from_hitbox_pos := Vector2.ZERO
var _struck := {}

func _ready() -> void:
	# Safety check in case you forget to assign the node in Inspector
	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer")
		if not anim_player:
			# If it still can't find it, try finding by type
			for child in get_children():
				if child is AnimationPlayer:
					anim_player = child
	
	add_to_group("player_weapon")
	monitoring = true
	monitorable = true
	
	if sword_sprite:
		sword_sprite.visible = false
		_apply_swing_texture()
		_art_scale = sword_sprite.scale
		_art_offset = sword_sprite.offset
	_apply_reach()

	_disable_hitbox()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

## `speed` = playback rate (the sword's attack_speed).
func swing(speed: float = 1.0) -> bool:
	if not anim_player or anim_player.is_playing():
		return false
	_landed_this_swing = false
	
	# Fix: Make the sword visible when the swing starts
	if sword_sprite:
		sword_sprite.visible = true
	
	_enable_hitbox()
	call_deferred("_apply_hits_from_overlaps")
	
	var animation_to_play: StringName = attack_animation if anim_player.has_animation(attack_animation) else anim_player.get_animation_list()[0]
	anim_player.play(animation_to_play, -1, speed)
	anim_player.advance(0.0) # pose the first frame now, so the sweep starts there
	_struck.clear()
	_sweeping = hitbox != null and hitbox.shape != null
	_mark_sweep_pose()
	Sfx.play(Sfx.swing_id(data), -1.0, 0.0, lerpf(1.0, speed, 0.3))
	return true


## Seconds the current swing animation lasts at `speed`.
func swing_duration(speed: float = 1.0) -> float:
	if not anim_player:
		return 0.0
	var anim_name: StringName = attack_animation if anim_player.has_animation(attack_animation) else anim_player.get_animation_list()[0]
	return anim_player.get_animation(anim_name).length / maxf(speed, 0.01)


## Ends the swing at once (switching swords mid-swing).
func cancel_swing() -> void:
	if anim_player and anim_player.is_playing():
		anim_player.stop()
	_on_animation_finished(&"")

func is_swinging() -> bool:
	return anim_player != null and anim_player.is_playing()

func get_attack_thrust(facing_direction: float) -> Vector2:
	var horizontal_sign: float = -1.0 if facing_direction < 0 else 1.0
	return Vector2(horizontal_sign * thrust_speed, thrust_vertical_speed)

func _on_body_entered(body: Node2D) -> void:
	_apply_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_apply_hit(area)
	var parent: Node = area.get_parent()
	if parent and parent is Node2D:
		_apply_hit(parent as Node2D)

func _apply_hit(target: Node2D) -> bool:
	if target == owner or target.is_in_group("player"): return false # Don't hit yourself
	if _struck.has(target.get_instance_id()): return false # once per swing
	var delivered := Hit.deliver(target, make_hit())
	if delivered:
		_struck[target.get_instance_id()] = true
	if delivered and not _landed_this_swing:
		_landed_this_swing = true
		Sfx.play(Sfx.hit_id(data))
		landed.emit(target)
	return delivered


func make_hit() -> Hit:
	var knockback := global_transform.x.normalized() * knockback_force
	if data:
		return Hit.make(roundi(data.damage * damage_mult), knockback * damage_mult, data.element, data.heavy_hits, self)
	return Hit.make(roundi(damage * damage_mult), knockback, Hit.Element.NONE, false, self)

func _apply_hits_from_overlaps() -> void:
	var hit_any := false
	for body in get_overlapping_bodies():
		if body is Node2D: hit_any = _apply_hit(body as Node2D) or hit_any
	for area in get_overlapping_areas():
		if area is Node2D: hit_any = _apply_hit(area as Node2D) or hit_any

	if not hit_any:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is Node2D and enemy.global_position.distance_to(global_position) <= fallback_hit_radius * reach():
				_apply_hit(enemy)

func _physics_process(_delta: float) -> void:
	if _sweeping and is_swinging():
		_sweep()


## Sweeps the hitbox from the pose marked last frame to the current one.
func _sweep() -> void:
	var shape := hitbox.shape
	var parent_xf: Transform2D = (get_parent() as Node2D).global_transform if get_parent() is Node2D else Transform2D.IDENTITY
	var from := parent_xf * _sweep_pose(0.0)
	var to := parent_xf * _sweep_pose(1.0)
	var travel := 0.0
	for p: Vector2 in _shape_points(shape):
		travel = maxf(travel, (to * p).distance_to(from * p))
	var steps := clampi(ceili(travel / SWEEP_STEP), 1, SWEEP_MAX_STEPS)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	for i in range(1, steps + 1):
		query.transform = parent_xf * _sweep_pose(float(i) / steps)
		for result in space.intersect_shape(query, 16):
			var collider: Object = result["collider"]
			if collider is Area2D:
				_on_area_entered(collider as Area2D)
			elif collider is Node2D:
				_apply_hit(collider as Node2D)
	_mark_sweep_pose()


## The hitbox's transform in the parent's space, `t` of the way from the
## marked pose to the current one (only rotation and positions animate).
func _sweep_pose(t: float) -> Transform2D:
	var root := Transform2D(lerp_angle(_from_rot, rotation, t), scale, 0.0, _from_pos.lerp(position, t))
	return root * Transform2D(hitbox.rotation, hitbox.scale, hitbox.skew, _from_hitbox_pos.lerp(hitbox.position, t))


func _mark_sweep_pose() -> void:
	_from_rot = rotation
	_from_pos = position
	if hitbox:
		_from_hitbox_pos = hitbox.position


static func _shape_points(shape: Shape2D) -> Array[Vector2]:
	if shape is SegmentShape2D:
		return [shape.a, shape.b]
	if shape is RectangleShape2D:
		var e: Vector2 = shape.size / 2.0
		return [-e, e, Vector2(e.x, -e.y), Vector2(-e.x, e.y)]
	return [Vector2.ZERO]


func _on_animation_finished(anim_name: StringName) -> void:
	# A swing that ran to its end still covers its last stretch (cancel_swing
	# passes no name: a switched-away sword strikes nothing more).
	if _sweeping and anim_name != &"":
		_sweep()
	_sweeping = false
	_disable_hitbox()
	if sword_sprite:
		sword_sprite.visible = false

func _enable_hitbox() -> void:
	if hitbox: hitbox.set_deferred("disabled", false)

func _disable_hitbox() -> void:
	if hitbox: hitbox.set_deferred("disabled", true)
	
	
	
	
	


## The sword scenes' art is a 32px diagonal blade (grip at the sprite origin,
## pointing up-right). A sword's own `swing_texture` is drawn blade-up at 1:1,
## so stand it on its grip and lean it the same 45 degrees.
func _apply_swing_texture() -> void:
	if data == null or data.swing_texture == null:
		return
	var tex := data.swing_texture
	sword_sprite.texture = tex
	sword_sprite.scale = Vector2.ONE
	sword_sprite.offset = Vector2(0, -(tex.get_height() / 2.0 - 1.0))
	sword_sprite.rotation += PI / 4.0
	_art_held_rotation = PI / 2.0


## WeaponData.reach (1.0 without data).
func reach() -> float:
	return data.reach if data else 1.0


## Reach scales the whole swing about her hand (hitbox, animated positions).
## The art is scaled back to its own 1:1 pixels and its offset pushed out by
## the same factor, so it stays centered on the larger hitbox without
## resampling: past 1.0 the hitbox reaches a little beyond the blade.
func _apply_reach() -> void:
	var r := reach()
	if is_equal_approx(r, 1.0):
		return
	scale = Vector2(r, r)
	if sword_sprite:
		sword_sprite.scale = _art_scale / r
		sword_sprite.offset = _art_offset * r


## Puts this sword's art on `sprite` held straight out: grip at the sprite's
## origin, blade along +x, the same pixels as the swing. For poses outside a
## swing (the dash brandish); the caller sets position and tint.
func pose_held_art(sprite: Sprite2D) -> void:
	if not sword_sprite:
		return
	sprite.texture = sword_sprite.texture
	sprite.scale = _art_scale
	sprite.offset = _art_offset
	sprite.rotation = _art_held_rotation
