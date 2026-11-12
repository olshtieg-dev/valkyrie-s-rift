class_name Shrine
extends Interactable
## Valkyrie shrine along the main climb: the armory. Lets her swap any sword
## she has already found into her sword slots (MAX_LOADOUT in player.gd), and barter coins for swords and
## expendables. It never hands out a sword she hasn't found or bought (first
## pickups live at the end of side routes; see SwordPedestal).

const STATUE := preload("res://assets/sprites/tiny_creatures/tilemap_packed.png")
const STATUE_REGION := Rect2(3 * 16, 8 * 16, 16, 16) # golden statue

var _t := 0.0


func _build() -> void:
	var statue := Sprite2D.new()
	statue.texture = STATUE
	statue.region_enabled = true
	statue.region_rect = STATUE_REGION
	statue.position = Vector2(0, -8)
	statue.z_index = 1
	add_child(statue)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Soft pulsing glow behind the statue, in whole-pixel rings.
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	for i in 3:
		var r := 10.0 + i * 4.0 + roundf(pulse * 2.0)
		draw_circle(Vector2(0, -9), r, Color(1.0, 0.85, 0.45, 0.07 + 0.03 * (2 - i)))


func prompt_text() -> String:
	return "Shrine"


func _interact(who: Node2D) -> void:
	ShrineMenu.open(who)
