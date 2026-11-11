extends Label
## Health as a row of hearts (full / half / empty). The player's health is in
## half-hearts, so max_health 6 = three hearts. Drawn from the Kenney sheet at
## an exact 2x (the HUD isn't zoomed like the world), so pixels stay crisp.

const SHEET := preload("res://assets/sprites/kenney_pixel_platformer/tilemap_packed.png")
const FULL := Rect2(4 * 18, 2 * 18, 18, 18)
const HALF := Rect2(5 * 18, 2 * 18, 18, 18)
const EMPTY := Rect2(6 * 18, 2 * 18, 18, 18)
const SCALE := 2.0
const SPACING := 19.0 * SCALE

var _player: Node
var _health := 0
var _max := 0


func _ready() -> void:
	text = ""
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_updated.connect(_on_health_updated)
		_on_health_updated(_player.current_health)


func _on_health_updated(count: int) -> void:
	var gained := count > _health and _max > 0
	_health = count
	_max = _player.max_health if is_instance_valid(_player) else count
	queue_redraw()
	if gained:
		var tween := create_tween()
		modulate = Color(1.6, 1.6, 1.6)
		tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _draw() -> void:
	var hearts := ceili(_max / 2.0)
	for i in hearts:
		var left := _health - i * 2 # half-hearts left for this slot
		var region := FULL if left >= 2 else HALF if left == 1 else EMPTY
		draw_texture_rect_region(SHEET, Rect2(Vector2(i * SPACING, 0), region.size * SCALE), region)
