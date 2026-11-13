class_name ShrineMenu
extends CanvasLayer
## The shrine's armory + barter screen. Pauses the game while open and works
## with keyboard, mouse or controller (D-pad / stick to move, Cross / A to
## pick, Circle / B / Esc to leave).
##
##   CARRIED  her sword slots (MAX_LOADOUT), in switch order. Pick a slot first...
##   ARMORY   ...then a sword she owns to put in it (or put the slot away).
##   ARMOR    every suit she owns; pick one to wear.
##   BARTER   swords, armor and expendables for coins.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const GOLD := Color(1.0, 0.85, 0.45)
const DIM := Color(1, 1, 1, 0.45)

var _player: Node
var _slot := 0
var _info: Label
var _coins: CoinLabel
var _columns: HBoxContainer
var _focus_key := ""
var _closing := false


static func open(player: Node) -> ShrineMenu:
	var menu := ShrineMenu.new()
	menu._player = player
	player.get_tree().root.add_child(menu)
	return menu


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_slot = _player.active_slot
	_build_frame()
	_rebuild("slot%d" % _slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


# --------------------------------------------------------------------------

func _build_frame() -> void:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 14
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := MarginContainer.new()
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 48)
	add_child(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(pad)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	pad.add_child(body)

	var header := HBoxContainer.new()
	body.add_child(header)
	var title := _label("VALKYRIE SHRINE", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# Her balance is the headline number: a 2x coin, like the in-level HUD.
	_coins = CoinLabel.make(GameManager.coins, GOLD, 2)
	header.add_child(_coins)

	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 24)
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_columns)

	_info = _label("", Color(1, 1, 1, 0.85))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 64)
	body.add_child(_info)
	body.add_child(_label("Pick a slot, then a sword for it. Pick armor to wear it.   Esc / B: leave", DIM))


## Rebuilds the three columns from current state, then refocuses `focus_key`.
func _rebuild(focus_key: String = "") -> void:
	for child in _columns.get_children():
		child.queue_free()
	_coins.amount = GameManager.coins
	var to_focus: Control
	var keyed := {}

	# CARRIED
	var carried := _column("CARRIED")
	for i in _player.MAX_LOADOUT:
		var data: WeaponData = _player.loadout[i] if i < _player.loadout.size() else null
		var text := "%d  %s" % [i + 1, data.display_name if data else "- empty -"]
		if i == _slot:
			text = "> " + text
		var b := _button(carried, text, _on_slot.bind(i))
		if i == _slot:
			b.add_theme_color_override("font_color", GOLD)
		b.focus_entered.connect(_show_weapon_info.bind(data, "Slot %d" % (i + 1)))
		keyed["slot%d" % i] = b

	# ARMORY
	var armory := _column("ARMORY")
	var spare: Array[WeaponData] = []
	for path: String in GameManager.owned_weapons:
		var data := load(path) as WeaponData
		if data and not data in _player.loadout:
			spare.append(data)
	for data in spare:
		var b := _button(armory, data.display_name, _on_choose.bind(data))
		b.focus_entered.connect(_show_weapon_info.bind(data, ""))
		keyed["own:" + data.resource_path] = b
	if _slot < _player.loadout.size() and _player.loadout.size() > 1:
		var b := _button(armory, "(put this slot away)", _on_put_away)
		b.focus_entered.connect(func() -> void: _info.text = "Empty this slot. She always carries at least one sword.")
		keyed["putaway"] = b
	if armory.get_child_count() == 1:
		armory.add_child(_label("Nothing spare yet.\nSwords are found at the\nend of side routes.", DIM))

	# ARMOR
	var wardrobe := _column("ARMOR")
	for path: String in GameManager.owned_armor:
		var suit := load(path) as ArmorData
		if suit == null:
			continue
		var worn: bool = suit == _player.armor
		var b := _button(wardrobe, ("* " if worn else "") + suit.display_name, _on_wear.bind(suit))
		if worn:
			b.add_theme_color_override("font_color", GOLD)
		b.focus_entered.connect(_show_armor_info.bind(suit, "Wearing" if worn else ""))
		keyed["wear:" + path] = b

	# BARTER
	var barter := _column("BARTER")
	for data in ShopCatalog.weapons_for_sale():
		var b := _button(barter, data.display_name, _on_buy_weapon.bind(data))
		b.disabled = GameManager.coins < data.price
		_add_price(b, data.price)
		b.focus_entered.connect(_show_weapon_info.bind(data, "%d coins" % data.price))
		keyed["buy:" + data.resource_path] = b
	for suit in ShopCatalog.armor_for_sale():
		var b := _button(barter, suit.display_name, _on_buy_armor.bind(suit))
		b.disabled = GameManager.coins < suit.price
		_add_price(b, suit.price)
		b.focus_entered.connect(_show_armor_info.bind(suit, "%d coins" % suit.price))
		keyed["buyarmor:" + suit.resource_path] = b
	for item: Dictionary in ShopCatalog.EXPENDABLES:
		var b := _button(barter, item["name"], _on_buy_item.bind(item))
		b.disabled = GameManager.coins < item["price"] or not ShopCatalog.expendable_useful(item["id"], _player)
		_add_price(b, item["price"])
		b.focus_entered.connect(func() -> void: _info.text = "%s (%d coins): %s" % [item["name"], item["price"], item["description"]])
		keyed["item:" + item["id"]] = b
	var leave := _button(barter, "Leave", _close)
	leave.focus_entered.connect(func() -> void: _info.text = "")
	keyed["leave"] = leave

	to_focus = keyed.get(focus_key, keyed.get("slot%d" % _slot))
	if to_focus and to_focus.disabled:
		to_focus = keyed["leave"]
	if to_focus:
		to_focus.call_deferred("grab_focus")


func _column(heading: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label(heading, Color.WHITE))
	_columns.add_child(col)
	return col


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Puts a `[coin] N` price tag on the right end of a barter button (dimmed
## with the button when she can't buy it), and widens the button so the name
## and the price never overlap. Call after setting `b.disabled`.
func _add_price(b: Button, price: int) -> void:
	var tag := CoinLabel.make(price, GOLD)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if b.disabled:
		tag.modulate = Color(1, 1, 1, 0.5)
	b.add_child(tag)
	# Room for two digits, numbers right-aligned, so the coins line up in a column.
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var digits := tag.get_theme_font("font").get_string_size("00", HORIZONTAL_ALIGNMENT_LEFT, -1, tag.get_theme_font_size("font_size")).x
	tag.custom_minimum_size.x = CoinLabel.COIN_REGION.size.x * tag.icon_scale + tag.gap + digits
	tag.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	tag.offset_right = -8.0
	tag.offset_left = tag.offset_right - tag.get_combined_minimum_size().x
	b.custom_minimum_size.x = b.get_combined_minimum_size().x + tag.get_combined_minimum_size().x + 16.0


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	return l


# --------------------------------------------------------------------------

func _on_slot(i: int) -> void:
	_slot = i
	var first_spare := ""
	for path: String in GameManager.owned_weapons:
		var data := load(path) as WeaponData
		if data and not data in _player.loadout:
			first_spare = "own:" + path
			break
	_rebuild(first_spare if first_spare != "" else "slot%d" % i)


func _on_choose(data: WeaponData) -> void:
	var swords: Array[WeaponData] = _player.loadout.duplicate()
	var carried_at := swords.find(data)
	if carried_at != -1 and _slot < swords.size():
		# Already carried: swap the two slots (reorders the switch cycle).
		swords[carried_at] = swords[_slot]
		swords[_slot] = data
	elif carried_at != -1:
		return
	elif _slot < swords.size():
		swords[_slot] = data
	else:
		swords.append(data)
		_slot = swords.size() - 1
	_player.set_loadout(swords, mini(_player.active_slot, swords.size() - 1))
	_rebuild("slot%d" % _slot)


func _on_put_away() -> void:
	var swords: Array[WeaponData] = _player.loadout.duplicate()
	if swords.size() <= 1 or _slot >= swords.size():
		return
	swords.remove_at(_slot)
	_player.set_loadout(swords, mini(_player.active_slot, swords.size() - 1))
	_slot = mini(_slot, swords.size())
	_rebuild("slot%d" % _slot)


func _on_buy_weapon(data: WeaponData) -> void:
	if not GameManager.spend_coins(data.price):
		return
	GameManager.own_weapon(data)
	# Straight into a free slot if there is one; otherwise it waits in the armory.
	if _player.loadout.size() < _player.MAX_LOADOUT:
		var swords: Array[WeaponData] = _player.loadout.duplicate()
		swords.append(data)
		_player.set_loadout(swords, _player.active_slot)
	_info.text = "Bought %s." % data.display_name
	_rebuild("leave")


func _on_wear(suit: ArmorData) -> void:
	_player.set_armor(suit)
	_rebuild("wear:" + suit.resource_path)


## Bought armor is put on straight away (the old suit stays in the wardrobe).
func _on_buy_armor(suit: ArmorData) -> void:
	if not GameManager.spend_coins(suit.price):
		return
	_player.set_armor(suit)
	_rebuild("wear:" + suit.resource_path)
	_info.text = "Bought and put on %s." % suit.display_name


func _show_armor_info(suit: ArmorData, prefix: String) -> void:
	_info.text = "%s%s\n%s\n%s" % [prefix + ": " if prefix != "" else "", suit.display_name, suit.description, suit.summary()]


func _on_buy_item(item: Dictionary) -> void:
	if not ShopCatalog.expendable_useful(item["id"], _player):
		return
	if not GameManager.spend_coins(item["price"]):
		return
	ShopCatalog.apply_expendable(item["id"], _player)
	_rebuild("item:" + item["id"])


func _show_weapon_info(data: WeaponData, prefix: String) -> void:
	if data == null:
		_info.text = "%s: empty. Pick a sword from the armory to fill it." % prefix
		return
	var element: String = ["", "  Ice", "  Fire", "  Thunder"][data.element]
	var heavy := "  Heavy hits" if data.heavy_hits else ""
	_info.text = "%s%s\n%s\nDamage %d%s%s   Swing x%.2f   Run x%.2f   Jump x%.2f   Grip x%.2f   Flutters %d" % [
		prefix + ": " if prefix != "" else "", data.display_name, data.description,
		data.damage, element, heavy, data.attack_speed, data.top_speed, data.jump_height,
		data.traction, data.flutter_charges]


func _close() -> void:
	if _closing:
		return
	_closing = true
	visible = false
	# Keep what she bought or changed here through a death in this level
	# (coins are already spent for good).
	if is_instance_valid(_player):
		GameManager.commit_player_state(_player)
	# Unpause a frame later so the button press that closed the menu doesn't
	# also register as a jump or attack.
	await get_tree().process_frame
	get_tree().paused = false
	queue_free()
