class_name Npc
extends Interactable
## Someone she can talk to. Interact shows the next line of `lines` in a
## speech label over their head; after the last line the talk ends, and the
## next interact starts again from the top.
##
## Drawn from a horizontal strip of idle frames in `sheet` (frame i at
## `first_frame` + i * frame width). Set `near_spawn` to stand beside one of
## the level's spawns, so the NPC lands on generated floor wherever it is.

const LINE_WIDTH := 180.0
const SPEECH_BOX := 64.0 # text sits at the bottom of a box this tall

@export var npc_name: String = ""
@export_multiline var lines: PackedStringArray = []

@export_group("Sprite")
@export var sheet: Texture2D
@export var first_frame := Rect2(0, 0, 16, 16)
@export_range(1, 16) var frame_count: int = 1
@export var fps: float = 6.0
@export var tint := Color.WHITE
@export var face_left := false

@export_group("Placement")
## Spawn id in the parent Level to stand beside (e.g. "west"). Empty = stay put.
@export var near_spawn: String = ""
## Horizontal distances from that spawn to try, in order; the first with
## floor under it and headroom wins (the level's shrine sits within 32 px).
@export var spawn_offsets: PackedFloat32Array = [80.0, -80.0, 112.0, -112.0, 56.0]

var _line := -1
var _sprite: Sprite2D
var _speech: Label
var _time := 0.0


func _build() -> void:
	if reach.y < first_frame.size.y:
		reach = Vector2(maxf(reach.x, first_frame.size.x + 16), first_frame.size.y)
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.region_enabled = true
	_sprite.region_rect = first_frame
	_sprite.centered = true
	_sprite.offset = Vector2(0, -first_frame.size.y / 2.0)
	_sprite.flip_h = face_left
	_sprite.modulate = tint
	add_child(_sprite)
	_speech = Label.new()
	_speech.add_theme_font_override("font", FONT)
	_speech.add_theme_font_size_override("font_size", 8)
	_speech.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_speech.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_speech.add_theme_constant_override("outline_size", 3)
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.size = Vector2(LINE_WIDTH, SPEECH_BOX)
	_speech.position = Vector2(-LINE_WIDTH / 2.0, -first_frame.size.y - 10 - SPEECH_BOX)
	_speech.z_index = 20
	_speech.visible = false
	add_child(_speech)
	if near_spawn != "":
		visible = false # until placed on the first physics frame


func _physics_process(delta: float) -> void:
	if not _settled and near_spawn != "":
		_place_near_spawn()
		visible = true
	super(delta)
	if frame_count > 1:
		_time += delta
		var i := int(_time * fps) % frame_count
		_sprite.region_rect = Rect2(first_frame.position + Vector2(first_frame.size.x * i, 0), first_frame.size)
	if _line >= 0 and _player == null:
		_end_talk()


func _place_near_spawn() -> void:
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	var level := node as Level
	if level == null or not level.spawns.has(near_spawn):
		push_warning("Npc %s: no spawn '%s' to stand beside." % [npc_name, near_spawn])
		return
	var base: Vector2 = level.spawns[near_spawn]
	var feet := base + Vector2(spawn_offsets[0] if not spawn_offsets.is_empty() else 0.0, 0)
	for dx in spawn_offsets:
		if level._standable(base + Vector2(dx, 0)):
			feet = base + Vector2(dx, 0)
			break
	global_position = level.to_global(feet)


func _interact(_who: Node2D) -> void:
	if lines.is_empty():
		return
	_line += 1
	if _line >= lines.size():
		_end_talk()
		return
	var who := npc_name + ": " if npc_name != "" else ""
	_speech.text = who + lines[_line]
	_speech.visible = true
	_prompt.visible = false


func _end_talk() -> void:
	_line = -1
	_speech.visible = false


func prompt_text() -> String:
	return "" if _line >= 0 else "Talk"


func _refresh_prompt() -> void:
	super()
	if _line >= 0:
		_prompt.visible = false
