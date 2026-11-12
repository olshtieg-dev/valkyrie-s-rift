class_name EnemyProjectile
extends Area2D
## Glob fired by a Spitter. Hurts the player. A sword hit reflects it
## (the weapons call take_damage on anything they touch), after which it
## flies back faster and damages enemies instead.

const REFLECT_DAMAGE := 20
const ELEMENT_COLORS := [Color(0.95, 0.35, 0.55), Color(0.6, 0.9, 1.0), Color(1.0, 0.5, 0.15), Color(1.0, 0.95, 0.4)]

var velocity := Vector2.ZERO
var damage := 2 # half-hearts
## Damage type (armor resists by type); also colors the glob.
var element: Hit.Element = Hit.Element.NONE
var reflected := false
var _life := 4.0


func _ready() -> void:
	collision_layer = 1 # weapons scan layer 1
	collision_mask = 1 | 2 # world, player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	z_index = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func take_damage(_amount: int, _knockback: Vector2 = Vector2.ZERO) -> void:
	if reflected:
		return
	reflected = true
	velocity = -velocity * 1.8
	collision_mask = 1 | 4 # world, enemies
	_life = 2.0
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not reflected and body.has_method("take_damage"):
			body.take_damage(damage, velocity, element)
			_splat()
	elif body.is_in_group("enemy"):
		if reflected and body.has_method("take_damage"):
			body.take_damage(REFLECT_DAMAGE, velocity.normalized() * 150.0)
			_splat()
	else:
		_splat() # hit the world


func _splat() -> void:
	Sfx.play_at(&"enemy_splat", global_position)
	queue_free()


func _draw() -> void:
	var core: Color = Color(1.0, 0.85, 0.3) if reflected else ELEMENT_COLORS[element]
	draw_circle(Vector2.ZERO, 3.5, Color(0.1, 0.02, 0.05))
	draw_circle(Vector2.ZERO, 2.5, core)
