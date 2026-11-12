class_name ElementAura
extends Node2D
## Motes circling an enemy whose touch carries an element, so the player can
## read it at a glance: embers (fire), snowflakes (ice), sparks (thunder).
## Code-drawn whole pixels; add as a child of the enemy.

const COLORS := {
	Hit.Element.FIRE: [Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.5)],
	Hit.Element.ICE: [Color(0.7, 0.92, 1.0), Color(1.0, 1.0, 1.0)],
	Hit.Element.THUNDER: [Color(1.0, 0.95, 0.4), Color(1.0, 1.0, 0.85)],
}

var element: Hit.Element = Hit.Element.NONE
## Orbit radius in pixels and the orbit's center (relative to the enemy).
var radius := 9.0
var center := Vector2(0, -2)
var _t := 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not COLORS.has(element):
		return
	var colors: Array = COLORS[element]
	var spin := 3.0 if element == Hit.Element.THUNDER else 1.6
	for i in 3:
		var a := _t * spin + i * TAU / 3.0
		var p := center + Vector2(cos(a) * radius, sin(a) * radius * 0.5)
		var c: Color = colors[0]
		match element:
			Hit.Element.FIRE:
				p.y -= fmod(_t * 6.0 + i, 3.0) # embers drift up
			Hit.Element.THUNDER:
				if int(_t * 14.0 + i * 3) % 4 == 0:
					c = colors[1] # crackle
					p += Vector2(1, -1)
		draw_rect(Rect2(p.round(), Vector2(1, 1)), c)
		if element == Hit.Element.ICE and int(_t * 4.0 + i) % 3 == 0:
			# Tiny snowflake cross.
			draw_rect(Rect2(p.round() + Vector2(-1, 0), Vector2(3, 1)), colors[1])
			draw_rect(Rect2(p.round() + Vector2(0, -1), Vector2(1, 3)), colors[1])
