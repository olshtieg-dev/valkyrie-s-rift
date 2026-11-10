extends Label

@export var tick_symbol: String = "|"

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_updated.connect(_on_health_updated)
		_on_health_updated(player.current_health)

func _on_health_updated(count: int) -> void:
	var ticks := ""
	for i in range(count):
		ticks += tick_symbol
	text = "Lives: " + ticks
