class_name SwordPedestal
extends Interactable
## A sword resting on a stone slab: the first-pickup reward at the end of a
## side route. Taking it adds it to her loadout (and her armory collection);
## with every slot full (MAX_LOADOUT in player.gd) she swaps it for the sword in hand, which stays here,
## so nothing is ever lost. What it holds persists across reloads.
## Set `armor` instead of `weapon` and it holds a suit of armor: taking it
## puts it on (the old suit goes to the shrine wardrobe, nothing is left here).

const SLAB := preload("res://assets/sprites/kenney_pixel_platformer/tilemap_packed.png")
const SLAB_REGION := Rect2(7 * 18, 7 * 18, 18, 10) # the slab art is the top 10px of its tile
## Same scale the swords use in her hand (see scenes/sword*.tscn).
const ICON_SCALE := Vector2(0.53125, 0.5625)

@export var weapon: WeaponData
@export var armor: ArmorData

var _icon: Sprite2D
var _t := 0.0


func _build() -> void:
	var key := _key()
	if GameManager.pedestal_contents.has(key):
		var path: String = GameManager.pedestal_contents[key]
		var stored: Resource = load(path) if path != "" else null
		weapon = stored as WeaponData
		armor = stored as ArmorData
	var slab := Sprite2D.new()
	slab.texture = SLAB
	slab.region_enabled = true
	slab.region_rect = SLAB_REGION
	slab.position = Vector2(0, -5) # bottom edge on the floor
	add_child(slab)
	_icon = Sprite2D.new()
	_icon.z_index = 1
	add_child(_icon)
	_show_weapon()


func _process(delta: float) -> void:
	_t += delta
	if _icon.visible:
		# Whole-pixel hover above the slab.
		_icon.position = Vector2(0, -22 - _hover())
	if armor:
		queue_redraw()


func _hover() -> float:
	return 1.0 if fmod(_t, 1.0) < 0.5 else 0.0


## Code-drawn breastplate for armor (no icon art yet).
func _draw() -> void:
	if armor == null:
		return
	var c := armor.icon_color
	var dark := c.darkened(0.45)
	var o := Vector2(-6, -27 - _hover())
	draw_rect(Rect2(o + Vector2(0, 0), Vector2(4, 3)), dark)      # shoulders,
	draw_rect(Rect2(o + Vector2(8, 0), Vector2(4, 3)), dark)      # gap for the neck
	draw_rect(Rect2(o + Vector2(1, 2), Vector2(10, 8)), dark)
	draw_rect(Rect2(o + Vector2(2, 10), Vector2(8, 2)), dark)
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(2, 1)), c)
	draw_rect(Rect2(o + Vector2(9, 1), Vector2(2, 1)), c)
	draw_rect(Rect2(o + Vector2(2, 3), Vector2(8, 6)), c)
	draw_rect(Rect2(o + Vector2(3, 9), Vector2(6, 2)), c)
	draw_rect(Rect2(o + Vector2(5, 4), Vector2(2, 5)), dark)              # center ridge
	draw_rect(Rect2(o + Vector2(3, 4), Vector2(1, 2)), c.lightened(0.5))   # glint


func prompt_text() -> String:
	if armor:
		return "wear %s" % armor.display_name
	return "take %s" % weapon.display_name if weapon else ""


func _interact(who: Node2D) -> void:
	if armor and who.has_method("set_armor"):
		var found := not GameManager.owns_armor(armor)
		var suit := armor
		who.set_armor(suit)
		armor = null
		GameManager.pedestal_contents[_key()] = ""
		GameManager.commit_player_state(who) # a death reload keeps it on
		CombatFX.burst(self, global_position + Vector2(0, -24), 16.0, Color(1, 0.95, 0.7), 1.0, 8, 0.35)
		if found:
			_announce("Found: %s" % suit.display_name)
		queue_redraw()
		return
	if weapon == null or not who.has_method("take_weapon"):
		return
	var first_find := not GameManager.owns_weapon(weapon)
	var taken := weapon
	weapon = who.take_weapon(taken)
	GameManager.pedestal_contents[_key()] = weapon.resource_path if weapon else ""
	GameManager.commit_player_state(who) # loadout matches the pedestal after a death reload
	CombatFX.burst(self, global_position + Vector2(0, -30), 16.0, Color(1, 0.95, 0.7), 1.0, 8, 0.35)
	if first_find:
		_announce("Found: %s" % taken.display_name)
	_show_weapon()


func _announce(text: String) -> void:
	var level := LevelManager.current_level
	if level and level.get("hud") and level.hud.has_method("show_title"):
		level.hud.show_title(text)


func _show_weapon() -> void:
	_icon.visible = weapon != null and weapon.icon != null
	if _icon.visible:
		_icon.texture = weapon.icon
		_icon.modulate = weapon.tint
		if weapon.icon.get_width() <= 16:
			# 1:1 blade-up art (see WeaponData.swing_texture): just plant it point down.
			_icon.scale = Vector2.ONE
			_icon.rotation = PI
		else:
			# The 32px sword art is drawn diagonally; stand it upright, point down.
			_icon.scale = ICON_SCALE
			_icon.rotation = PI * 0.75


## Identifies this pedestal across reloads: its level's scene file + its name.
## (Walks up to the level root; current_scene isn't set yet while a level loads.)
func _key() -> String:
	var node: Node = get_parent()
	while node and node.scene_file_path == "":
		node = node.get_parent()
	return "%s:%s" % [node.scene_file_path if node else "", name]
