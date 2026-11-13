extends CanvasLayer
## In-level HUD: score, wings, lives, sword switch, the title card (finds,
## pickups) and the small room-name tag.

const ROOM_FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## The room-name tag is a quiet "you are here", not a reveal: the grand realm
## card (LoadingScreen) is for new realms and loading a save. Kept small,
## see-through and quick so ordinary rooms don't promise more than they are.
const ROOM_ALPHA := 0.7
const ROOM_FADE_IN := 0.2
const ROOM_HOLD := 1.1
const ROOM_FADE_OUT := 0.45

@onready var title_label: Label = $TitleLabel

var _title_tween: Tween
var _room_label: Label
var _room_tween: Tween


func _ready() -> void:
	_room_label = Label.new()
	_room_label.name = "RoomNameLabel"
	_room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_room_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room_label.offset_top = 8.0
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_override("font", ROOM_FONT)
	_room_label.add_theme_font_size_override("font_size", 16)
	_room_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	_room_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_room_label.add_theme_constant_override("shadow_offset_x", 1)
	_room_label.add_theme_constant_override("shadow_offset_y", 1)
	_room_label.modulate.a = 0.0
	add_child(_room_label)


## Small, translucent room name at the top of the screen, gone in ~2 s.
func show_room_name(text: String) -> void:
	_room_label.text = text
	_room_label.modulate.a = 0.0
	if _room_tween:
		_room_tween.kill()
	_room_tween = create_tween()
	_room_tween.tween_property(_room_label, "modulate:a", ROOM_ALPHA, ROOM_FADE_IN)
	_room_tween.tween_interval(ROOM_HOLD)
	_room_tween.tween_property(_room_label, "modulate:a", 0.0, ROOM_FADE_OUT)


func show_title(text: String) -> void:
	title_label.text = text
	title_label.modulate.a = 0.0
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween()
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 0.4)
	_title_tween.tween_interval(1.8)
	_title_tween.tween_property(title_label, "modulate:a", 0.0, 0.6)
