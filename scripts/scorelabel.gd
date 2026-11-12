extends Label
## Coin count, shown as a coin icon followed by the number. The icon is the
## coin pickup's first frame, cropped to its visible 10x10 and drawn at an
## exact 2x (the HUD isn't zoomed like the world), so pixels stay crisp.

const COIN_SHEET := preload("res://assets/sprites/coin.png")
const COIN_REGION := Rect2(3, 3, 10, 10)
const SCALE := 2.0
## Gap between the icon and the number, in screen pixels.
const GAP := 4.0


func _ready() -> void:
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = COIN_REGION.size.x * SCALE + GAP
	add_theme_stylebox_override("normal", pad)
	GameManager.score_changed.connect(update_text)
	update_text()


func update_text() -> void:
	text = str(GameManager.coins)


func _draw() -> void:
	var icon_size := COIN_REGION.size * SCALE
	var y := roundf((size.y - icon_size.y) / 2.0)
	draw_texture_rect_region(COIN_SHEET, Rect2(Vector2(0, y), icon_size), COIN_REGION)
