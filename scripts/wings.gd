class_name WingFeather
extends Area2D
## Wing feather: a side-route find ("wings" in the level registry), or one of
## the two on the main path that mend her broken wings ("path_find"). Each is
## one more feather for good (Player.add_flutter_slot): the first two give
## her the sword's own flutters, every later one +1 flutter per airtime (up
## to Player.FLUTTER_CAP). The HUD's feather, drawn in code at whole world
## pixels, hovers in a pale sky-blue glow; touch to take it. Taken feathers
## stay taken across reloads (keyed like heart vessels: level scene file +
## node name, in GameManager.pedestal_contents), and the upgrade is saved at
## once so a death in the same level can't take it back.
## Origin = feet position on the floor; the feather floats above it.

const FEATHER: Array = preload("res://scripts/wings_label.gd").FEATHER
const VANE := Color(1, 1, 1)
const SHADE := Color(0.78, 0.84, 0.95)
const QUILL := Color(0.62, 0.66, 0.78)
const OUTLINE := Color(0.08, 0.08, 0.14)
const GLOW := Color(0.62, 0.82, 1.0)
const PLAYER_LAYER := 2
const FLOAT := 14.0

var _t := 0.0
var _rise := 0.0
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
	z_index = 3
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Whole-pixel bob, a soft pixel glow, a pulsing ring and rising motes.
	var c := Vector2(0, -FLOAT - (1.0 if fmod(_t, 1.2) < 0.6 else 0.0) - roundf(_rise))
	if not _taken:
		var glow := 0.34 + (0.08 if fmod(_t, 0.8) < 0.4 else 0.0)
		for y in range(-8, 9):
			for x in range(-8, 9):
				var d := Vector2(x, y).length()
				if d <= 8.0:
					# Three flat bands, brightest at the middle.
					var band := 3.0 - floorf(d / 3.0)
					draw_rect(Rect2(c + Vector2(x, y), Vector2.ONE), Color(GLOW, glow * band / 3.0))
		var pulse := 10.0 + (1.0 if fmod(_t, 0.8) < 0.4 else 0.0)
		for i in 12:
			var a := i * TAU / 12.0 - _t * 0.6
			draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * pulse).round(), Vector2.ONE), Color(0.88, 0.96, 1.0, 0.9))
		for i in 3:
			var y := fmod(_t * 9.0 + i * 7.0, 20.0)
			draw_rect(Rect2(Vector2(-6 + i * 6, -y).round(), Vector2.ONE), Color(0.85, 0.93, 1.0, 1.0 - y / 20.0))
	_draw_feather((c - Vector2(FEATHER[0].length(), FEATHER.size()) / 2.0).round())


## The HUD feather bitmap (wings_label.gd) at 1 world pixel per cell, outlined.
func _draw_feather(origin: Vector2) -> void:
	for row in FEATHER.size():
		var line: String = FEATHER[row]
		for col in line.length():
			if line[col] == ".":
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(col, row) + d
				if not _filled(n):
					draw_rect(Rect2(origin + Vector2(n), Vector2.ONE), OUTLINE)
	for row in FEATHER.size():
		var line: String = FEATHER[row]
		for col in line.length():
			var ch := line[col]
			if ch == ".":
				continue
			var color := QUILL if ch == "q" else SHADE if ch == "s" else VANE
			draw_rect(Rect2(origin + Vector2(col, row), Vector2.ONE), color)


func _filled(p: Vector2i) -> bool:
	if p.y < 0 or p.y >= FEATHER.size():
		return false
	var line: String = FEATHER[p.y]
	return p.x >= 0 and p.x < line.length() and line[p.x] != "."


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player") or not body.has_method("add_flutter_slot"):
		return
	_taken = true
	body.add_flutter_slot(1)
	GameManager.pedestal_contents[_key()] = ""
	GameManager.commit_player_state(body) # a death reload keeps the feather
	CombatFX.burst(self, global_position + Vector2(0, -FLOAT), 18.0, GLOW, 1.0, 10, 0.4)
	var level := LevelManager.current_level
	if level and level.get("hud") and level.hud.has_method("show_title"):
		level.hud.show_title(_title_for(body))
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "_rise", 10.0, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## Her wings start broken (Player.WINGS_FEATHERS): the first feathers mend
## them rather than adding a flutter.
func _title_for(player: Variant) -> String:
	var found: int = player.flutter_bonus
	var needed: int = player.WINGS_FEATHERS
	if found < needed:
		var left := needed - found
		return "Wing Feather: %d more and her wings will hold" % left
	if found == needed:
		return "Her wings hold again: jump in the air to flutter"
	return "Wing Feather: +1 flutter"


func _key() -> String:
	var node: Node = get_parent()
	while node and node.scene_file_path == "":
		node = node.get_parent()
	return "%s:%s" % [node.scene_file_path if node else "", name]
