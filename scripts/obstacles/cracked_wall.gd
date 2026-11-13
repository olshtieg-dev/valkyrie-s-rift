class_name CrackedWall
extends StaticBody2D
## A plug of cracked rock sealing a secret pocket. It's drawn with the room's
## own wall tiles plus dark cracks (the tell), and any blow with a sword
## breaks it: no element or heavy hit needed. LevelGenerator places these
## (secrets). Origin = top-left corner; size is in tiles.

const TILE := 16
const CRACK := Color(0.05, 0.03, 0.04, 0.9)
const CRACK_LIGHT := Color(1.0, 0.85, 0.6, 0.25)
const DEBRIS := Color(0.32, 0.26, 0.24)

@export var tile_set: TileSet
@export var source_id: int = 0
## Atlas coordinates, row by row (top to bottom, left to right).
@export var tiles: Array[Vector2i] = []
@export var size_tiles := Vector2i(1, 3)

var broken := false
var _shake := 0.0
var _shape: CollisionShape2D
var _layer: TileMapLayer


func _ready() -> void:
	add_to_group("obstacle")
	collision_layer = 1
	collision_mask = 0
	var size := Vector2(size_tiles) * TILE
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)
	_layer = TileMapLayer.new()
	_layer.tile_set = tile_set
	_layer.collision_enabled = false
	_layer.navigation_enabled = false
	_layer.show_behind_parent = true # the cracks (_draw) go over the rock
	var i := 0
	for y in size_tiles.y:
		for x in size_tiles.x:
			if i < tiles.size():
				_layer.set_cell(Vector2i(x, y), source_id, tiles[i])
			i += 1
	add_child(_layer)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 4.0)
		_layer.position.x = roundf(sin(_shake * 60.0) * 2.0 * _shake)


func take_hit(hit: Hit) -> void:
	if broken or (hit.damage <= 0 and not hit.heavy):
		return
	smash()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	take_hit(Hit.make(amount, knockback))


func smash() -> void:
	if broken:
		return
	broken = true
	_shake = 0.6
	_shape.set_deferred("disabled", true)
	var size := Vector2(size_tiles) * TILE
	CombatFX.burst(self, global_position + size / 2.0, size.length() * 0.45, DEBRIS, 1.0, 14, 0.4)
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# A few jagged cracks running down the plug, fixed per wall position so
	# a baked room keeps the same look.
	var size := Vector2(size_tiles) * TILE
	var seed_base := int(position.x) * 31 + int(position.y) * 17
	for strand in maxi(2, size_tiles.x + 1):
		var x := 3.0 + _hash(seed_base, strand) * (size.x - 6.0)
		var y := 0.0
		while y < size.y:
			var step := 3.0 + _hash(seed_base + strand, int(y)) * 4.0
			var nx := clampf(x + (_hash(seed_base - strand, int(y)) - 0.5) * 6.0, 1.0, size.x - 2.0)
			draw_line(Vector2(roundf(x), roundf(y)), Vector2(roundf(nx), roundf(y + step)), CRACK, 1.0)
			if int(y) % 3 == 0:
				draw_rect(Rect2(roundf(nx) + 1.0, roundf(y + step), 1, 1), CRACK_LIGHT)
			x = nx
			y += step


func _hash(a: int, b: int) -> float:
	return float((a * 73856093 ^ b * 19349663) & 1023) / 1023.0
