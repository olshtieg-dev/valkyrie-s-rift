class_name CombatFX
extends RefCounted
## Small, code-only combat effects shared by the player and enemies.
## Everything is spawned into the current scene so it outlives the caller.


## A fading copy of a sprite's current frame: speed trails for the meteor strike.
static func afterimage(source: Node2D, tint: Color, life: float = 0.18) -> void:
	var tex: Texture2D
	var ghost := Sprite2D.new()
	if source is AnimatedSprite2D:
		var anim := source as AnimatedSprite2D
		tex = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		ghost.flip_h = anim.flip_h
		ghost.offset = anim.offset
		ghost.centered = anim.centered
	elif source is Sprite2D:
		var spr := source as Sprite2D
		tex = spr.texture
		ghost.flip_h = spr.flip_h
		ghost.offset = spr.offset
		ghost.centered = spr.centered
	if tex == null or not source.is_inside_tree():
		ghost.free()
		return
	ghost.texture = tex
	ghost.modulate = tint
	ghost.z_index = source.z_index + 3
	_scene(source).add_child(ghost)
	ghost.global_transform = source.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, life)
	tween.tween_callback(ghost.queue_free)


## Expanding ring + debris. `flatten` < 1 squashes it into a ground shockwave.
static func burst(context: Node, at: Vector2, radius: float, color: Color,
		flatten: float = 1.0, debris: int = 6, duration: float = 0.25) -> void:
	var b := Burst.new()
	b.radius = radius
	b.color = color
	b.flatten = flatten
	b.debris = debris
	b.duration = duration
	b.debris_up_only = flatten < 1.0
	_scene(context).add_child(b)
	b.global_position = at


## Metal shards flying off when armor breaks.
static func shards(context: Node, at: Vector2, color: Color) -> void:
	var b := Burst.new()
	b.radius = 14.0
	b.color = color
	b.debris = 12
	b.debris_speed = 140.0
	b.duration = 0.4
	b.ring_width = 1.0
	_scene(context).add_child(b)
	b.global_position = at


## Whole-pixel camera shake that decays over `duration` (real time).
static func shake(context: Node, strength: float, duration: float) -> void:
	var cam := context.get_viewport().get_camera_2d() if context.is_inside_tree() else null
	if cam == null:
		return
	var tween := context.get_tree().create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_method(func(k: float) -> void:
		if is_instance_valid(cam):
			var s := strength * (1.0 - k)
			cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s)).round(), 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		if is_instance_valid(cam):
			cam.offset = Vector2.ZERO)


static func _scene(context: Node) -> Node:
	var tree := context.get_tree()
	return tree.current_scene if tree and tree.current_scene else context.get_parent()
