extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	GameManager.add_point()
	if body.has_method("on_coin_collected"):
		body.on_coin_collected(1)
	queue_free()
