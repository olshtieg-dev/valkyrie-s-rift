extends TextureButton

@export var icon_sword_1: Texture2D
@export var icon_sword_2: Texture2D

var player: CharacterBody2D

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Connect to the player's signal
		player.weapon_switched.connect(_on_player_weapon_switched)
		# Connect to the button's own click
		pressed.connect(_on_self_pressed)
		# Set initial state
		update_icon(player.active_weapon == player.weapon_1_instance)
	else:
		print("UI Error: Button could not find player!")

func _on_player_weapon_switched(is_sword_1: bool):
	update_icon(is_sword_1)
	_play_bounce_animation()

func _on_self_pressed():
	if player and player.has_method("_on_sword_switch_requested"):
		player._on_sword_switch_requested()

func update_icon(is_weapon_1_active: bool):
	if is_weapon_1_active:
		texture_normal = icon_sword_1
	else:
		texture_normal = icon_sword_2

func _play_bounce_animation():
	var tween = create_tween()
	scale = Vector2.ONE
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
