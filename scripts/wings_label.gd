
extends Label

func _ready():
	# Find the player in the scene. Adjust the path if your player is named differently.
	var player = get_tree().get_first_node_in_group("player") 
	if player:
		player.wings_updated.connect(_on_wings_updated)
		# Set initial display
		_on_wings_updated(player.max_flutter_charges)

func _on_wings_updated(count):
	# This creates a string of icons like "🪶"
	var icons = ""
	for i in range(count):
		icons += "O" # Or use a Wing Emoji if your font supports it
	text = "Wings: " + icons
