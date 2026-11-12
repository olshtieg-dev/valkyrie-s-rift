class_name DebugLoadoutPage
extends PanelContainer
## Loadout page for the F1 debug menu: tick the swords she carries (up to the
## player's MAX_LOADOUT), pick the one in hand, the armor she wears, her found
## abilities, heart containers and wing bonus.
## Every change applies to the live player at once and is written to
## GameManager's carried player state, so it survives level changes, reloads
## and deaths, and the HUD (sword icon, feathers, hearts) follows.
## Swords and armor come from scanning data/weapons/ and data/armor/, so new
## .tres files show up here on their own. Abilities come from AbilityShrine.INFO.

## The player chose Back.
signal closed

const WEAPON_DIR := "res://data/weapons/"
const ARMOR_DIR := "res://data/armor/"
## Icons are scaled by a whole number to fit this box (pixel art stays crisp).
const ICON_BOX := 32
## Most heart containers the stepper allows.
const MAX_HEART_CONTAINERS := 12
const GOLD := Color(1.0, 0.85, 0.35)
const DIM := Color(1, 1, 1, 0.55)

var _body: VBoxContainer
## Focusable controls of the current build, by key, so focus survives a rebuild.
var _focus: Dictionary = {}
var _first_focus: Control
## Description of the focused sword or armor.
var _info: Label


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true # keep the pad's selection on screen
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(pad)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	pad.add_child(_body)


## Call when the page is shown: rebuilds it from her current state and focuses
## the first control, so a pad can drive it straight away.
func focus_first() -> void:
	_rebuild("")


## All WeaponData (or ArmorData) files in `dir`, by file name. Uses
## ResourceLoader.list_directory, which also sees remapped files in exports.
static func scan(dir: String) -> Array[Resource]:
	var found: Array[Resource] = []
	var files := Array(ResourceLoader.list_directory(dir))
	files.sort()
	for file: String in files:
		if file.ends_with("/") or not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(dir + file)
		if res is WeaponData or res is ArmorData:
			found.append(res)
	return found


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


# --------------------------------------------------------------------------

func _rebuild(focus_key: String) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_focus.clear()
	_first_focus = null

	_body.add_child(_heading("LOADOUT", Color.WHITE))
	var p := _player()
	if p == null:
		_body.add_child(_label("No player in this scene.", DIM))
	else:
		_body.add_child(_label("Changes apply at once and carry across levels.", DIM))
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 48)
		_body.add_child(columns)
		var left := _column(columns)
		var right := _column(columns)
		_build_swords(left, p)
		_build_stats(left, p)
		_build_armor(right, p)
		_build_abilities(right, p)

	_info = _label("", DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.y = 40
	_body.add_child(_info)

	var back := _button("Back", func() -> void: closed.emit())
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_body.add_child(_spacer())
	_body.add_child(back)
	_remember("back", back)
	_body.add_child(_label("A / Enter: toggle    O / Esc: back", DIM))

	for key: String in _focus:
		if not (key.begins_with("sword:") or key.begins_with("armor:")):
			(_focus[key] as Control).focus_entered.connect(_show_info.bind("", ""))
	var target: Control = _focus.get(focus_key, _first_focus)
	if target:
		target.grab_focus()


func _build_swords(parent: Control, p: Node) -> void:
	var carried: Array = p.loadout
	var cap: int = p.MAX_LOADOUT
	parent.add_child(_heading("SWORDS   %d / %d" % [carried.size(), cap], Color.WHITE))
	for res in scan(WEAPON_DIR):
		var data := res as WeaponData
		if data == null or data.scene == null:
			continue
		var key := data.resource_path
		var is_carried := data in carried
		var row := _row(parent)
		row.add_child(_icon(data.icon if data.icon else data.swing_texture, data.tint))
		var box := CheckBox.new()
		box.text = data.display_name
		box.tooltip_text = data.description
		box.button_pressed = is_carried
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# At least one sword stays; no more than the cap.
		box.disabled = (is_carried and carried.size() <= 1) or (not is_carried and carried.size() >= cap)
		box.toggled.connect(_on_sword_toggled.bind(data))
		box.focus_entered.connect(_show_info.bind(data.display_name, data.description))
		row.add_child(box)
		_remember("sword:" + key, box)
		var in_hand: bool = data == p.weapon_data
		var hold := _button("in hand" if in_hand else "hold", _on_hold.bind(data))
		hold.disabled = not is_carried
		hold.custom_minimum_size.x = 112
		if in_hand:
			hold.add_theme_color_override("font_color", GOLD)
			hold.add_theme_color_override("font_disabled_color", GOLD)
		row.add_child(hold)
		_remember("hold:" + key, hold)
	if carried.size() >= cap:
		parent.add_child(_label("Full: untick one to swap.", DIM))


func _build_armor(parent: Control, p: Node) -> void:
	parent.add_child(_heading("ARMOR", Color.WHITE))
	var group := ButtonGroup.new() # radio: exactly one suit
	for res in scan(ARMOR_DIR):
		var suit := res as ArmorData
		if suit == null:
			continue
		var row := _row(parent)
		row.add_child(_swatch(suit.icon_color))
		var box := CheckBox.new()
		box.button_group = group
		box.text = suit.display_name
		box.tooltip_text = "%s\n%s" % [suit.description, suit.summary()]
		box.button_pressed = suit == p.armor
		box.toggled.connect(_on_armor_toggled.bind(suit))
		box.focus_entered.connect(_show_info.bind(suit.display_name, "%s  %s" % [suit.summary(), suit.description]))
		row.add_child(box)
		_remember("armor:" + suit.resource_path, box)


func _build_abilities(parent: Control, _p: Node) -> void:
	parent.add_child(_heading("ABILITIES", Color.WHITE))
	for id: StringName in AbilityShrine.INFO:
		var box := CheckBox.new()
		box.text = AbilityShrine.INFO[id].get("name", String(id))
		box.button_pressed = GameManager.has_ability(id)
		box.toggled.connect(_on_ability_toggled.bind(id))
		parent.add_child(box)
		_remember("ability:" + id, box)


func _build_stats(parent: Control, p: Node) -> void:
	parent.add_child(_heading("UPGRADES", Color.WHITE))
	var containers: int = p.base_max_health / p.HEART
	var armor_hearts: int = p.armor.bonus_hearts if p.armor else 0
	_stepper(parent, "hearts", "Heart containers  %d%s" % [containers, "  (+%d armor)" % armor_hearts if armor_hearts > 0 else ""],
			containers > 1, containers < MAX_HEART_CONTAINERS)
	var bonus: int = p.flutter_bonus
	_stepper(parent, "wings", "Wing bonus  +%d   (flutters %d)" % [bonus, p.max_flutter_charges],
			bonus > 0, bonus < p.FLUTTER_CAP)


func _show_info(title: String, text: String) -> void:
	_info.text = "%s: %s" % [title, text] if title != "" else ""


# --------------------------------------------------------------------------

func _on_sword_toggled(on: bool, data: WeaponData) -> void:
	var p := _player()
	if p == null:
		return
	var swords: Array[WeaponData] = p.loadout.duplicate()
	var held: WeaponData = p.weapon_data
	if on and not data in swords and swords.size() < p.MAX_LOADOUT:
		swords.append(data)
		GameManager.own_weapon(data)
	elif not on and data in swords and swords.size() > 1:
		swords.erase(data)
	var slot := swords.find(held)
	if slot < 0:
		slot = mini(p.active_slot, swords.size() - 1)
	p.set_loadout(swords, slot)
	_commit("sword:" + data.resource_path)


func _on_hold(data: WeaponData) -> void:
	var p := _player()
	if p == null:
		return
	var slot: int = p.loadout.find(data)
	if slot >= 0 and slot != p.active_slot:
		p.set_loadout(p.loadout.duplicate(), slot)
	_commit("hold:" + data.resource_path)


func _on_armor_toggled(on: bool, suit: ArmorData) -> void:
	var p := _player()
	if not on or p == null:
		return
	if suit != p.armor:
		p.set_armor(suit)
	_commit("armor:" + suit.resource_path)


func _on_ability_toggled(on: bool, id: StringName) -> void:
	if on:
		GameManager.grant_ability(id)
	else:
		GameManager.revoke_ability(id)
	_commit("ability:" + id)


func _on_step(which: String, step: int) -> void:
	var p := _player()
	if p == null:
		return
	match which:
		"hearts":
			if step > 0:
				p.add_heart_container(1)
			else:
				p.base_max_health = maxi(p.HEART, p.base_max_health - p.HEART)
				p._apply_armor_stats()
		"wings":
			if step > 0:
				p.add_flutter_slot(1)
			else:
				p.flutter_bonus = maxi(0, p.flutter_bonus - 1)
				p.max_flutter_charges = p._max_flutter()
				p.flutter_charges_left = mini(p.flutter_charges_left, p.max_flutter_charges)
				p.wings_updated.emit(p.flutter_charges_left)
	_commit("%s%s" % [which, "+" if step > 0 else "-"])


## Writes her state to GameManager (so reloads, level changes and deaths keep
## it) and redraws the page with focus back on `focus_key`.
func _commit(focus_key: String) -> void:
	var p := _player()
	if p:
		GameManager.store_player_state(p)
	# Deferred: the control that fired this is about to be freed.
	_rebuild.call_deferred(focus_key)


# --------------------------------------------------------------------------

func _remember(key: String, control: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL
	_focus[key] = control
	if _first_focus == null:
		_first_focus = control


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	return column


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _stepper(parent: Control, key: String, text: String, can_down: bool, can_up: bool) -> void:
	var row := _row(parent)
	var minus := _button("-", _on_step.bind(key, -1))
	minus.disabled = not can_down
	minus.custom_minimum_size.x = 32
	row.add_child(minus)
	_remember(key + "-", minus)
	var plus := _button("+", _on_step.bind(key, 1))
	plus.disabled = not can_up
	plus.custom_minimum_size.x = 32
	row.add_child(plus)
	_remember(key + "+", plus)
	row.add_child(_label(text, Color.WHITE))


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _heading(text: String, color: Color) -> Label:
	var label := _label(text, color)
	label.custom_minimum_size.y = 28
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	return label


func _spacer() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	return gap


## The sword's sprite, scaled by a whole number to fit ICON_BOX.
func _icon(tex: Texture2D, tint: Color) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	if tex == null:
		return box
	var size := Vector2i(tex.get_width(), tex.get_height())
	var mult := maxi(1, ICON_BOX / maxi(size.x, size.y))
	var rect := TextureRect.new()
	rect.texture = tex
	rect.modulate = tint
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(size * mult)
	box.add_child(rect)
	return box


## Armor has no sprite, only a plate color: a small chip of it.
func _swatch(color: Color) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(ICON_BOX, ICON_BOX)
	var chip := ColorRect.new()
	chip.color = color
	chip.custom_minimum_size = Vector2(12, 14)
	box.add_child(chip)
	return box
