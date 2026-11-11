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

	_disable_hitbox()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

func swing() -> bool:
	if not anim_player or anim_player.is_playing():
		return false
	
	# Fix: Make the sword visible when the swing starts
	if sword_sprite:
		sword_sprite.visible = true
	
	_enable_hitbox()
	call_deferred("_apply_hits_from_overlaps")
	
	var animation_to_play: StringName = attack_animation if anim_player.has_animation(attack_animation) else anim_player.get_animation_list()[0]
	anim_player.play(animation_to_play)
	return true

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
	return Hit.deliver(target, make_hit())


func make_hit() -> Hit:
	var knockback := global_transform.x.normalized() * knockback_force
	if data:
		return Hit.make(data.damage, knockback, data.element, data.heavy_hits, self)
	return Hit.make(damage, knockback, Hit.Element.NONE, false, self)

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
	
	
	
	
	
