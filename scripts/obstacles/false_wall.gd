class_name FalseWall
extends Node2D
## Fake rock over a secret pocket. It's drawn with the room's own wall tiles
## (the very tiles that were carved away), but nothing is solid: she walks
## straight through. While she's inside, it fades so she can see the pocket;
## when she leaves, it fades back. LevelGenerator places these (secrets).
##
## Origin = the room's tile origin (same as the ground layer). `cells` are tile
## coordinates; `tiles` are their atlas coordinates in `tile_set`.

const TILE := 16
## Opacity while she's inside the pocket.
const REVEALED_ALPHA := 0.25
const FADE_TIME := 0.2
## The tell: fake rock is a hair darker and cooler than the real thing, so a
## sharp eye can spot it against the surrounding wall.
const TELL := Color(0.86, 0.84, 0.9)
const PLAYER_LAYER := 2

@export var tile_set: TileSet
@export var source_id: int = 0
@export var cells: Array[Vector2i] = []
@export var tiles: Array[Vector2i] = []

var _layer: TileMapLayer
var _tween: Tween


func _ready() -> void:
	z_index = 20 # over her: she walks behind it
	_layer = TileMapLayer.new()
	_layer.tile_set = tile_set
	_layer.collision_enabled = false
	_layer.navigation_enabled = false
	_layer.modulate = TELL
	for i in mini(cells.size(), tiles.size()):
		_layer.set_cell(cells[i], source_id, tiles[i])
	add_child(_layer)
	if cells.is_empty():
		return
	var box := Rect2i(cells[0], Vector2i.ONE)
	for c in cells:
		box = box.expand(c).expand(c + Vector2i.ONE)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = PLAYER_LAYER
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(box.size * TILE) - Vector2(4, 4)
	shape.shape = rect
	shape.position = Vector2(box.position * TILE) + Vector2(box.size * TILE) / 2.0
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body.bind(true))
	area.body_exited.connect(_on_body.bind(false))


func _on_body(body: Node, entered: bool) -> void:
	if not body.is_in_group("player"):
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_layer, "modulate:a", REVEALED_ALPHA if entered else 1.0, FADE_TIME)
