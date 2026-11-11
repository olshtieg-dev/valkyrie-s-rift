extends Area2D

## Half-hearts (2 = one heart).
@export var damage: int = 2
## Pits and world-bottom killzones: send the player back to the last safe ground
## instead of only chipping health while they keep falling.
@export var respawn_player: bool = false

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if respawn_player and body.has_method("respawn_from_hazard"):
		body.respawn_from_hazard(damage)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
