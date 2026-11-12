class_name CoinLabel
extends Label
## A coin amount drawn as `[coin icon] N`, for menus. The icon is the coin
## pickup's first frame, cropped to its visible 10x10 and drawn at an exact
## integer scale so pixels stay crisp. Same look as the HUD's coin counter
## (`scripts/scorelabel.gd`), which keeps its own copy.

const COIN_SHEET := preload("res://assets/sprites/coin.png")
const COIN_REGION := Rect2(3, 3, 10, 10)

## Whole-number scale for the icon. 1 suits ~14px menu text.
@export_range(1, 4) var icon_scale: int = 1:
	set(value):
		icon_scale = maxi(value, 1)
		_update_padding()
## Gap between the icon and the number, in pixels.
@export var gap: float = 3.0:
	set(value):
		gap = value
		_update_padding()
## The number shown after the icon.
@export var amount: int = 0:
	set(value):
		amount = value
		text = str(value)


## Convenience constructor: a coin label showing `value` in `color`.
static func make(value: int, color: Color = Color.WHITE, scale_factor: int = 1) -> CoinLabel:
	var l := CoinLabel.new()
	l.icon_scale = scale_factor
	l.amount = value
	l.add_theme_color_override("font_color", color)
	return l


func _init() -> void:
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_update_padding()


func _update_padding() -> void:
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = COIN_REGION.size.x * icon_scale + gap
	add_theme_stylebox_override("normal", pad)
	queue_redraw()


func _draw() -> void:
	var icon_size := COIN_REGION.size * icon_scale
	var y := roundf((size.y - icon_size.y) / 2.0)
	draw_texture_rect_region(COIN_SHEET, Rect2(Vector2(0, y), icon_size), COIN_REGION)
