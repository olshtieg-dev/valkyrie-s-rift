extends TextureButton

@export var icon_sword_1: Texture2D
@export var icon_sword_2: Texture2D

var player: CharacterBody2D

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Show whatever is actually equipped (any sword, any slot), not just
		# "slot 1 or slot 2".
		player.weapon_changed.connect(_on_player_weapon_changed)
		# Connect to the button's own click
		pressed.connect(_on_self_pressed)
		# Set initial state
		show_weapon(player.weapon_data, player.active_slot)
	else:
		print("UI Error: Button could not find player!")

func _on_player_weapon_changed(data: WeaponData, slot: int) -> void:
	show_weapon(data, slot)
	_play_bounce_animation()

func _on_self_pressed():
	if player and player.has_method("_on_sword_switch_requested"):
		player._on_sword_switch_requested()

## Shows the equipped weapon's own icon and tint. Falls back to its swing art,
## then to the old per-slot icons for weapons with no art of their own.
func show_weapon(data: WeaponData, slot: int) -> void:
	var tex: Texture2D = null
	if data:
		tex = data.icon if data.icon else data.swing_texture
	if tex == null:
		tex = icon_sword_1 if slot == 0 else icon_sword_2
	texture_normal = tex
	modulate = data.tint if data else Color.WHITE

## Kept for old callers: picks one of the two per-slot icons.
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
