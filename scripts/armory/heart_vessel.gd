class_name HeartVessel
extends Area2D
## A heart container: a side-route find that adds one heart for good (and
## fills her up). Hovers in a golden reliquary glow; touch to take it.
## Taken vessels stay taken across reloads, keyed like sword pedestals
## (level scene file + node name) in GameManager.pedestal_contents.
## Origin = feet position on the floor; the heart floats above it.

const SHEET := preload("res://assets/sprites/kenney_pixel_platformer/tilemap_packed.png")
const HEART_REGION := Rect2(4 * 18, 2 * 18, 18, 18) # same heart as the HUD
const GOLD := Color(1.0, 0.85, 0.35)
const PLAYER_LAYER := 2
const FLOAT := 14.0

var _sprite: Sprite2D
var _t := 0.0
var _taken := false


func _ready() -> void:
	if GameManager.pedestal_contents.get(_key(), "full") == "":
		queue_free()
		return
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -FLOAT)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.region_rect = HEART_REGION
	_sprite.z_index = 1
	add_child(_sprite)
	z_index = 3
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if _sprite:
		# Whole-pixel bob.
		_sprite.position = Vector2(0, -FLOAT - (1.0 if fmod(_t, 1.2) < 0.6 else 0.0))
	queue_redraw()


func _draw() -> void:
	if _taken:
		return
	# Pulsing gold halo of pixels behind the heart, and a few rising sparkles.
	var c := Vector2(0, -FLOAT)
	var pulse := 10.0 + (1.0 if fmod(_t, 0.8) < 0.4 else 0.0)
	for i in 12:
		var a := i * TAU / 12.0 + _t * 0.6
		draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * pulse).round(), Vector2(1, 1)), Color(GOLD, 0.8))
	for i in 3:
		var y := fmod(_t * 10.0 + i * 7.0, 20.0)
		draw_rect(Rect2(Vector2(-6 + i * 6, -y).round(), Vector2(1, 1)), Color(1, 0.95, 0.7, 1.0 - y / 20.0))


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player") or not body.has_method("add_heart_container"):
		return
	_taken = true
	body.add_heart_container(1)
	GameManager.pedestal_contents[_key()] = ""
	GameManager.commit_player_state(body) # a death reload keeps the heart
	CombatFX.burst(self, global_position + Vector2(0, -FLOAT), 18.0, GOLD, 1.0, 10, 0.4)
	var level := LevelManager.current_level
	if level and level.get("hud") and level.hud.has_method("show_title"):
		level.hud.show_title("Heart Container: +1 heart")
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 10.0, 0.4)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _key() -> String:
	var node: Node = get_parent()
	while node and node.scene_file_path == "":
		node = node.get_parent()
	return "%s:%s" % [node.scene_file_path if node else "", name]
