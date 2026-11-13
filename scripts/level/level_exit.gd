class_name LevelExit
extends Area2D
## Doorway to another level. Edge exits trigger on touch; portals
## (requires_interact) wait for an up press (`interact`: W / Up / E, D-pad or
## stick up), when the player's can_interact() agrees.
##
## If `anchor` names a generator opening ("west", "east", "north", "south"),
## the Level snaps this exit onto that opening at load time.

@export var target_level: String = ""
## Spawn id in the target level. Generator openings are named after their
## side, so leaving through "east" usually targets "west" on the other end.
@export var target_spawn: String = ""
@export var anchor: String = ""
@export var size: Vector2 = Vector2(16, 48):
	set(value):
		size = value
		_apply_size()
		queue_redraw()
@export var requires_interact: bool = false

@export_group("Visuals")
@export var show_frame: bool = false
@export var frame_color: Color = Color(0.8, 0.8, 1.0)
@export var label_text: String = ""

## Ignore the player briefly after load so arriving next to an exit can't bounce you back.
const ARM_DELAY_MS := 400
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

var _shape: CollisionShape2D
var _armed_at_ms := 0
var _player_inside: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player
	monitorable = false
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_apply_size()
	if label_text != "":
		_add_label()
	_armed_at_ms = Time.get_ticks_msec() + ARM_DELAY_MS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func set_rect(rect: Rect2) -> void:
	position = rect.get_center()
	size = rect.size


func _apply_size() -> void:
	if _shape:
		(_shape.shape as RectangleShape2D).size = size


func _add_label() -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", frame_color.lightened(0.3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(96, 10)
	label.position = Vector2(-48, -size.y / 2.0 - 12.0)
	add_child(label)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = body
	if not requires_interact:
		_travel()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null


func _physics_process(_delta: float) -> void:
	if requires_interact and _player_inside and Input.is_action_just_pressed("interact") \
			and (not _player_inside.has_method("can_interact") or _player_inside.call("can_interact")):
		_travel()


func _travel() -> void:
	if Time.get_ticks_msec() < _armed_at_ms:
		return
	if target_level == "":
		push_warning("LevelExit '%s' has no target_level" % name)
		return
	LevelManager.go_to(target_level, target_spawn)


func _draw() -> void:
	if not show_frame:
		return
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, Color(frame_color, 0.22))
	draw_rect(rect, frame_color, false, 1.0)
