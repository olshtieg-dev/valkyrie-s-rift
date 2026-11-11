class_name SpawnPoint
extends Marker2D
## Hand-placed arrival point. Place it where the player's feet should be.
## LevelExits elsewhere target it by spawn_id. Overrides a generator anchor
## with the same name.

@export var spawn_id: StringName = &"default"
