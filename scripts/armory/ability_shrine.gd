class_name AbilityShrine
extends Area2D
## A side-route find that teaches her an ability (registry find "ability:<id>").
## A small rune stone on a plinth, with the ability's sigil hovering over it;
## touch to take it. The ability goes into GameManager's carried player state
## (GameManager.grant_ability), so it lasts across levels and deaths.
## Taken shrines stay empty across reloads, keyed like sword pedestals and
## heart vessels (level scene file + node name) in GameManager.pedestal_contents.
## Origin = feet position on the floor.

const PLAYER_LAYER := 2
const FLOAT := 15.0
const STONE := Color(0.36, 0.33, 0.38)
const STONE_LIT := Color(0.52, 0.48, 0.55)
const STONE_DARK := Color(0.2, 0.18, 0.22)

## Name, hint and sigil color per ability id. The hint names the action;
## "%s" becomes the keyboard key bound to it (if any).
const INFO := {
	&"dash": {"name": "Dash Strike", "hint": "O / %s: dash any way you hold (8-way), or where you face. In the air, or upward, it spends a feather.",
			"color": Color(0.8, 1.15, 1.4)}, # overbright: reads through realm tints
}

@export var ability: StringName = &"dash"

var _t := 0.0
var _taken := false


func _ready() -> void:
	if GameManager.pedestal_contents.get(_key(), "full") == "":
		queue_free()
		return
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 26)
	shape.shape = rect
	shape.position = Vector2(0, -13)
	add_child(shape)
	z_index = 3
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _color() -> Color:
	return INFO.get(ability, {}).get("color", Color.WHITE)


func _draw() -> void:
	# Plinth: a squat stone block with a lit top edge.
	draw_rect(Rect2(-6, -4, 12, 4), STONE)
	draw_rect(Rect2(-6, -4, 12, 1), STONE_LIT)
	draw_rect(Rect2(-5, -1, 10, 1), STONE_DARK)
	if _taken:
		return
	var c := _color()
	var bob := 1.0 if fmod(_t, 1.2) < 0.6 else 0.0 # whole-pixel bob
	var o := Vector2(0, -FLOAT - bob)
	# Soft halo behind the stone.
	draw_rect(Rect2(o + Vector2(-6, -8), Vector2(12, 15)), Color(c, 0.18))
	draw_rect(Rect2(o + Vector2(-5, -7), Vector2(10, 13)), Color(c, 0.22))
	# Rune stone: a little upright slab.
	draw_rect(Rect2(o + Vector2(-4, -6), Vector2(8, 11)), STONE)
	draw_rect(Rect2(o + Vector2(-4, -6), Vector2(8, 1)), STONE_LIT)
	draw_rect(Rect2(o + Vector2(3, -5), Vector2(1, 10)), STONE_DARK)
	# Sigil: two chevrons pointing ahead (>>), glowing.
	var glow := Color(c, 0.85 + 0.15 * sin(_t * 5.0))
	for chevron in [-2, 1]:
		for i in 3:
			draw_rect(Rect2(o + Vector2(chevron + i - 1, -3 + i), Vector2(1, 1)), glow)
			draw_rect(Rect2(o + Vector2(chevron + i - 1, 1 - i), Vector2(1, 1)), glow)
	# Speed streaks sliding through it, left to right.
	for i in 3:
		var x := fmod(_t * 28.0 + i * 9.0, 26.0) - 13.0
		var y := -FLOAT - 4.0 + i * 4.0
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(4, 1)), Color(c, 0.55 * (1.0 - absf(x) / 13.0)))
	# Pulsing ring of light pixels around the stone.
	var pulse := 10.0 + (1.0 if fmod(_t, 0.8) < 0.4 else 0.0)
	for i in 10:
		var a := i * TAU / 10.0 + _t * 0.7
		draw_rect(Rect2((o + Vector2(cos(a), sin(a)) * pulse).round(), Vector2(1, 1)), Color(c, 0.7))


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	GameManager.grant_ability(ability)
	GameManager.pedestal_contents[_key()] = ""
	Sfx.play(&"power_up")
	CombatFX.burst(self, global_position + Vector2(0, -FLOAT), 18.0, _color(), 1.0, 10, 0.4)
	var level := LevelManager.current_level
	if level and level.get("hud") and level.hud.has_method("show_title"):
		level.hud.show_title(title_text(ability))
	set_deferred("monitoring", false)


## "Dash Strike: O / Shift: dash where you face..." for the HUD banner.
static func title_text(id: StringName) -> String:
	var info: Dictionary = INFO.get(id, {"name": String(id).capitalize(), "hint": ""})
	var hint: String = info["hint"]
	if hint.contains("%s"):
		hint = hint % _key_name(id)
	return "%s: %s" % [info["name"], hint] if hint != "" else String(info["name"])


## Keyboard key bound to the action of the same name, for the hint.
static func _key_name(action: StringName) -> String:
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key := event as InputEventKey
				var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
				return OS.get_keycode_string(code)
	return "key"


func _key() -> String:
	var node: Node = get_parent()
	while node and node.scene_file_path == "":
		node = node.get_parent()
	return "%s:%s" % [node.scene_file_path if node else "", name]
