class_name Interactable
extends Area2D
## Base for things she uses with the interact button (W / Up / E / D-pad up):
## shrines and sword pedestals. Shows a small prompt while she's in range,
## and settles onto the floor below it on the first physics frame (tile
## collision doesn't exist yet in _ready), so it can be placed loosely.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const PLAYER_LAYER := 2
const GROUND_MASK := 1 | 32

## Size of the area she has to stand in, centered above the origin (feet).
@export var reach := Vector2(28, 28)
@export var snap_to_floor := true

var _player: Node2D
var _prompt: Label
var _settled := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = reach
	shape.shape = rect
	shape.position = Vector2(0, -reach.y / 2.0)
	add_child(shape)
	_prompt = Label.new()
	_prompt.add_theme_font_override("font", FONT)
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(140, 10)
	_prompt.position = Vector2(-70, -reach.y - 22)
	_prompt.z_index = 20
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_player = b
			_refresh_prompt())
	body_exited.connect(func(b: Node2D) -> void:
		if b == _player:
			_player = null
			_refresh_prompt())
	_build()


func _physics_process(_delta: float) -> void:
	if not _settled:
		_settled = true
		if snap_to_floor:
			_snap_down()
	if _player and not _player.get("is_dead") and Input.is_action_just_pressed("interact"):
		_interact(_player)
		_refresh_prompt()


## Subclass hooks.
func _build() -> void:
	pass


func _interact(_who: Node2D) -> void:
	pass


func prompt_text() -> String:
	return ""


func _refresh_prompt() -> void:
	var text := prompt_text()
	_prompt.text = "[UP] " + text if text != "" else ""
	_prompt.visible = _player != null and text != ""


func _snap_down() -> void:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0, -8)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 96), GROUND_MASK)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = roundf(hit["position"].y)
