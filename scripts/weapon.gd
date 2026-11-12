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
	var delivered := Hit.deliver(target, make_hit())
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
			if enemy is Node2D and enemy.global_position.distance_to(global_position) <= fallback_hit_radius:
				_apply_hit(enemy)

func _on_animation_finished(_anim_name: StringName) -> void:
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
