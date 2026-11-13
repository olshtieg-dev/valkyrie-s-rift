class_name MagigonneShot
extends Node2D
## One Magigonne shot: a seidr orb in the sword's element color. Flies
## straight, ricochets off walls up to BOUNCES times, and pops on the first
## thing it can hit (enemy hurtboxes, element obstacles, spitter globs, which
## it bats back). Armor clinks it away harmlessly unless the shot is heavy
## (the hammer's). Spawned by Magigonne._fire().
##
## Uses shape and ray queries rather than an Area2D, so it can't be caught by
## anything scanning for weapons, and nothing fast slips between frames.

const BOUNCES := 2
const LIFE := 1.6
const RADIUS := 3.0
const KNOCKBACK := 170.0
## What swords scan: enemy hurtboxes, obstacles and the world (layer 1).
const HIT_MASK := 1
const TRAIL := 4

var velocity := Vector2.ZERO
var damage := 15
var element: Hit.Element = Hit.Element.NONE
var heavy := false
var color := Color(0.72, 0.58, 1.0)
## Excluded from hits.
var shooter: Node2D

var _life := LIFE
var _bounces := BOUNCES
var _t := 0.0
var _trail: Array[Vector2] = []
var _shape: RectangleShape2D
var _done := false


func _ready() -> void:
	z_index = 6


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_life -= delta
	if _life <= 0.0:
		_pop(false)
		return
	_trail.push_front(global_position)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	var step := velocity * delta
	if _strike(step):
		return
	var wall := _wall(step)
	if wall.is_empty():
		global_position += step
	elif _bounces > 0:
		_bounces -= 1
		var normal: Vector2 = wall["normal"]
		global_position = wall["position"] + normal * (RADIUS + 0.5)
		velocity = velocity.bounce(normal)
		Sfx.play_at(&"magigonne_bounce", global_position)
		CombatFX.burst(self, global_position, 4.0, color, 1.0, 2, 0.1)
	else:
		global_position = wall["position"]
		_pop(true)
		return
	queue_redraw()


## Hits the first target along this step. True if the shot is spent.
func _strike(step: Vector2) -> bool:
	if _shape == null:
		_shape = RectangleShape2D.new()
	var length := step.length() + RADIUS * 2.0
	_shape.size = Vector2(length, RADIUS * 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(step.angle(), global_position + step / 2.0)
	query.collision_mask = HIT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		query.exclude = [(shooter as CollisionObject2D).get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider: Object = result["collider"]
		var targets: Array = [collider]
		if collider is Area2D and (collider as Node).get_parent() is Node2D:
			targets.append((collider as Node).get_parent())
		for target: Object in targets:
			if not is_instance_valid(target) or target == shooter:
				continue
			if target is Node and ((target as Node).is_in_group("player") or (target as Node).is_in_group("pickup")):
				continue
			if not (target.has_method("take_hit") or target.has_method("take_damage")):
				continue
			if target.get("is_dying") == true:
				continue
			if target.get("armored") == true and not heavy:
				# Clinks off. (Delivering it would recoil her from afar.)
				Sfx.play_at(&"deflect", global_position)
				_pop(true)
				return true
			var hit := Hit.make(damage, velocity.normalized() * KNOCKBACK, element, heavy, self)
			hit.ranged = true
			if Hit.deliver(target, hit):
				Sfx.play_at(&"magigonne_hit", global_position)
				_pop(true)
				return true
	return false


## The first solid world body along this step (bodies only: hurtboxes and
## one-way platforms don't stop it), as a ray result, or {}.
func _wall(step: Vector2) -> Dictionary:
	var dir := step.normalized()
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step + dir * RADIUS, HIT_MASK)
	query.collide_with_areas = false
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		query.exclude = [(shooter as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


func _pop(burst: bool) -> void:
	_done = true
	if burst:
		CombatFX.burst(self, global_position, 8.0, color.lerp(Color.WHITE, 0.3), 1.0, 5, 0.18)
	else:
		CombatFX.burst(self, global_position, 4.0, Color(color, 0.6), 1.0, 2, 0.15) # fizzles out
	queue_free()


func _draw() -> void:
	# Trail: fading pixels where it was, then a soft glow, the orb and a
	# flickering white heart. All whole pixels.
	for i in _trail.size():
		var p := (_trail[i] - global_position).round()
		var a := 0.55 * (1.0 - float(i + 1) / float(TRAIL + 1))
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color(color, a))
	for y in range(-4, 4):
		for x in range(-4, 4):
			var d := Vector2(x + 0.5, y + 0.5).length()
			if d <= 2.2:
				draw_rect(Rect2(x, y, 1, 1), color.lerp(Color.WHITE, 0.15))
			elif d <= 3.2:
				draw_rect(Rect2(x, y, 1, 1), Color(0.1, 0.06, 0.16, 0.9))
			elif d <= 4.0:
				draw_rect(Rect2(x, y, 1, 1), Color(color, 0.3))
	var lit := fmod(_t, 0.12) < 0.06
	draw_rect(Rect2(-1, -1, 2, 2) if lit else Rect2(-1, -1, 1, 1), Color.WHITE)
