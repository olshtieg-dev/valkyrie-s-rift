class_name BootSplash
extends Control
## Studio cards before the intro: the olshtieg-dev badge (name typed out with
## a blinking cursor), then the "made with Claude AI" and "made with Godot"
## cards. Driven by one
## clock in _process so a skip can end it at any moment.

signal finished

const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const STUDIO_MARK := preload("res://assets/sprites/title/studio_mark.png")
const CLAUDE_MARK := preload("res://assets/sprites/title/claude_mark.png")
## The Godot logo by Andrea Calabro (CC BY 4.0), pixelated from res://icon.svg.
const GODOT_MARK := preload("res://assets/sprites/title/godot_mark.png")

## Seconds per card, including its fades.
const CARD_TIME := 2.7
const FADE := 0.4
## Seconds per typed character of the studio name.
const TYPE_RATE := 0.06

const STUDIO_NAME := "olshtieg-dev"
const STAGE := Vector2(384, 216)

var _t := 0.0
var _done := false
var _cards: Array[Control] = []
var _studio_label: Label
var _claude_mark: TextureRect


func _ready() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = size
	add_child(bg)

	# Card 1: studio badge + typed name.
	var studio := _card()
	_add_mark(studio, STUDIO_MARK, Vector2(size.x / 2.0, 82))
	_studio_label = _label(studio, "", 16, FONT_BOLD, 104, Color(0.96, 0.96, 0.99))
	_label(studio, "presents", 8, null, 126, Color(0.55, 0.6, 0.75))

	# Card 2: made with Claude AI.
	var claude := _card()
	_label(claude, "made with", 8, null, 66, Color(0.6, 0.6, 0.66))
	_claude_mark = _add_mark(claude, CLAUDE_MARK, Vector2(size.x / 2.0, 92))
	_label(claude, "Claude AI", 16, FONT_BOLD, 108, Color(0.93, 0.6, 0.47))

	# Card 3: made with Godot.
	var godot := _card()
	_label(godot, "made with", 8, null, 56, Color(0.6, 0.6, 0.66))
	_add_mark(godot, GODOT_MARK, Vector2(size.x / 2.0, 90))
	_label(godot, "Godot Engine", 16, FONT_BOLD, 112, Color(0.55, 0.78, 0.96))


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var index := int(_t / CARD_TIME)
	if index >= _cards.size():
		_finish()
		return
	var u := fmod(_t, CARD_TIME)
	for i in _cards.size():
		_cards[i].visible = i == index
	var card := _cards[index]
	card.modulate.a = clampf(minf(u / FADE, (CARD_TIME - u) / FADE), 0.0, 1.0)
	# The mark drops in a few pixels (whole pixels only).
	var mark: TextureRect = card.get_meta("mark")
	var drop := 1.0 - clampf(u / 0.35, 0.0, 1.0)
	mark.position.y = mark.get_meta("rest_y") - roundf(6.0 * drop * drop)
	if index == 0:
		var typed := clampi(int((u - 0.35) / TYPE_RATE), 0, STUDIO_NAME.length())
		var cursor := "_" if typed < STUDIO_NAME.length() or fmod(u, 0.5) < 0.25 else " "
		_studio_label.text = STUDIO_NAME.substr(0, typed) + cursor
		if typed > 0 and typed < STUDIO_NAME.length() and int((u - delta - 0.35) / TYPE_RATE) < typed:
			Sfx.play(&"switch_sword", 0.1, -6.0)
	else:
		# A warm pulse through the mark once it lands.
		var pulse := clampf(1.0 - absf(u - 0.6) / 0.3, 0.0, 1.0)
		mark.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.6, 1.4) if index == 1 else Color(1.4, 1.6, 1.8), pulse)


func _unhandled_input(event: InputEvent) -> void:
	if _done or _t < 0.3:
		return
	if _is_skip(event):
		get_viewport().set_input_as_handled()
		_finish()


static func _is_skip(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	for action in [&"jump", &"attack", &"ui_accept", &"ui_cancel"]:
		if event.is_action_pressed(action):
			return true
	return false


func _finish() -> void:
	_done = true
	finished.emit()


func _card() -> Control:
	var card := Control.new()
	card.size = size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	add_child(card)
	_cards.append(card)
	return card


func _add_mark(card: Control, tex: Texture2D, center: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = (center - tex.get_size() / 2.0).floor()
	rect.set_meta("rest_y", rect.position.y)
	card.add_child(rect)
	card.set_meta("mark", rect)
	return rect


func _label(card: Control, text: String, font_size: int, font: Font, y: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y)
	label.size = Vector2(size.x, font_size + 4)
	label.add_theme_font_size_override("font_size", font_size)
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)
	return label
