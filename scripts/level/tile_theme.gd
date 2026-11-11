@tool
class_name TileTheme
extends Resource
## Which atlas tiles the LevelGenerator paints for a realm.
## Coordinates refer to res://tilesets/world_tileset.tres (16px grid).

## Solid tile with open air above it (grass, brimstone crust, snow).
@export var surface: Vector2i = Vector2i(0, 0)
## Solid interior tiles, picked at random for variety.
@export var fill: Array[Vector2i] = [Vector2i(0, 1)]
## One-way drop-through platform.
@export var platform: Vector2i = Vector2i(10, 0)

@export_group("Hazard")
## (-1, -1) disables hazard pools for this theme.
@export var hazard_top: Vector2i = Vector2i(-1, -1)
@export var hazard_fill: Vector2i = Vector2i(-1, -1)

@export_group("Background")
## Painted behind enclosed levels (caverns, shafts, arenas), then tinted dark.
@export var background: Vector2i = Vector2i(0, 1)
@export var background_tint: Color = Color(0.3, 0.3, 0.3)

@export_group("Decor")
## Non-colliding props placed on top of floor tiles.
@export var decor: Array[Vector2i] = []
@export_range(0.0, 1.0) var decor_chance: float = 0.06


func has_hazard() -> bool:
	return hazard_top.x >= 0 and hazard_fill.x >= 0


func pick_fill(rng: RandomNumberGenerator) -> Vector2i:
	if fill.is_empty():
		return surface
	return fill[rng.randi() % fill.size()]
