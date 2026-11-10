extends Area2D

func _on_body_entered(body):
	if body.has_method("add_flutter_slot"):
		body.add_flutter_slot(1)
		queue_free() # Remove the item from the world
