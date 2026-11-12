extends CanvasLayer
## Developer overlay, debug builds only.
##   F1 / gamepad Select (Back)
##                      open the menu (pauses the game): warp to any level, toggles,
##                      actions, and Controller setup (pick a pad, rebind its buttons)
##   F2                 noclip (fly with move keys, through walls)
##   F3                 god mode
##   F4                 reload the current level
## A small readout in the bottom-left shows level, position, tile cell, velocity and FPS.

var god_mode := false
var infinite_flutter := false
var noclip := false
var show_info := true

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

var _enabled := false
var _menu: Control
var _info: Label
var _first_focus: Control
var _toggle_buttons: Dictionary = {}
var _main_page: Control
var _controls_page: Control
var _controller_setup: ControllerSetup
var _loadout_page: DebugLoadoutPage


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = OS.is_debug_build()
	if not _enabled:
		set_process(false)
		set_process_unhandled_input(false)
		return
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	# Checked first: Esc is a key, and the key branch below swallows every key.
	if _menu.visible and event.is_action_pressed("ui_cancel"):
		if _controls_page.visible:
			_show_controller_setup(false)
		elif _loadout_page.visible:
			_show_loadout(false)
		else:
			_set_menu_open(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				_set_menu_open(not _menu.visible)
			KEY_F2:
				_set_flag("noclip", not noclip)
			KEY_F3:
				_set_flag("god_mode", not god_mode)
			KEY_F4:
				_close_and(LevelManager.reload_level)
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		_set_menu_open(not _menu.visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_info.visible = show_info
	if not show_info:
		return
	var lines := PackedStringArray()
	var level_id := LevelManager.current_level_id
	lines.append("level  %s" % (level_id if level_id != "" else get_tree().current_scene.scene_file_path if get_tree().current_scene else "-"))
	var level := LevelManager.current_level
	if level and level.get("generator"):
		lines.append("seed   %d" % level.generator.level_seed)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		var p := player.global_position
		lines.append("pos    %d, %d   cell %d, %d" % [p.x, p.y, floori(p.x / 16.0), floori(p.y / 16.0)])
		lines.append("vel    %d, %d" % [player.velocity.x, player.velocity.y])
	lines.append("fps    %d" % Engine.get_frames_per_second())
	var flags := PackedStringArray()
	if god_mode: flags.append("GOD")
	if noclip: flags.append("NOCLIP")
	if infinite_flutter: flags.append("INF-FLUTTER")
	if GameManager.has_ability(&"dash"): flags.append("DASH")
	if not flags.is_empty():
		lines.append(" ".join(flags))
	_info.text = "\n".join(lines)


# --------------------------------------------------------------------------

func _set_menu_open(open: bool) -> void:
	_menu.visible = open
	_main_page.visible = true
	_controls_page.visible = false
	_loadout_page.visible = false
	get_tree().paused = open
	if open and _first_focus:
		_first_focus.grab_focus()


func _close_and(action: Callable) -> void:
	_set_menu_open(false)
	action.call()


func _set_flag(flag: String, value: bool) -> void:
	set(flag, value)
	if _toggle_buttons.has(flag):
		(_toggle_buttons[flag] as CheckButton).set_pressed_no_signal(value)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _spawn_enemy(path: String) -> void:
	var p := _player() as Node2D
	var scene := get_tree().current_scene
	if not p or not scene:
		return
	var facing: float = p.get_node("Pivot").scale.x if p.has_node("Pivot") else 1.0
	var mob: Node2D = load(path).instantiate()
	mob.global_position = p.global_position + Vector2(facing * 56.0, -20.0)
	scene.add_child(mob)
	_set_menu_open(false)


# --------------------------------------------------------------------------

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16

	_info = Label.new()
	_info.theme = ui_theme
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("shadow_offset_x", 1)
	_info.add_theme_constant_override("shadow_offset_y", 1)
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)

	_menu = MarginContainer.new()
	_menu.theme = ui_theme
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_menu.add_theme_constant_override("margin_" + side, 64)
	_menu.hide()
	add_child(_menu)

	var panel := PanelContainer.new()
	_main_page = panel
	_menu.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true # keep the pad's selection on screen
	panel.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(pad)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	pad.add_child(columns)

	# Left column: levels grouped by realm.
	var levels := VBoxContainer.new()
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(levels)
	levels.add_child(_heading("WARP", Color.WHITE))
	for realm: Dictionary in LevelRegistry.REALMS:
		var in_realm := LevelRegistry.in_realm(realm["id"])
		if in_realm.is_empty():
			continue
		levels.add_child(_heading(realm["name"], realm["color"]))
		for level: Dictionary in in_realm:
			var button := Button.new()
			button.text = "  %s" % level["name"]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_close_and.bind(LevelManager.go_to.bind(level["id"], "")))
			levels.add_child(button)
			if _first_focus == null:
				_first_focus = button

	# Right column: toggles and actions.
	var tools := VBoxContainer.new()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(tools)
	tools.add_child(_heading("CONTROLLER", Color.WHITE))
	_add_action(tools, "Controller setup", _show_controller_setup.bind(true))
	tools.add_child(preload("res://scenes/ui/music_volume_slider.tscn").instantiate())
	tools.add_child(preload("res://scenes/ui/sfx_volume_slider.tscn").instantiate())
	tools.add_child(_heading("CHEATS", Color.WHITE))
	_add_toggle(tools, "god_mode", "God mode  [F3]")
	_add_toggle(tools, "infinite_flutter", "Infinite flutter")
	_add_toggle(tools, "noclip", "Noclip  [F2]")
	_add_toggle(tools, "show_info", "Info readout")
	var shapes := CheckButton.new()
	shapes.text = "Collision shapes"
	shapes.button_pressed = get_tree().debug_collisions_hint
	shapes.toggled.connect(func(on: bool) -> void:
		get_tree().debug_collisions_hint = on
		_close_and(LevelManager.reload_level))
	tools.add_child(shapes)

	tools.add_child(_heading("ACTIONS", Color.WHITE))
	_add_action(tools, "Loadout (swords, armor, abilities)", _show_loadout.bind(true))
	_add_action(tools, "Reload level  [F4]", func() -> void: _close_and(LevelManager.reload_level))
	_add_action(tools, "Reroll seed", func() -> void: _close_and(LevelManager.reroll_current))
	_add_action(tools, "Heal to full", func() -> void:
		var p := _player()
		if p: p._heal(p.max_health))
	_add_action(tools, "+1 heart container", func() -> void:
		var p := _player()
		if p: p.add_heart_container(1))
	_add_action(tools, "+10 coins", func() -> void: GameManager.add_coins(10))
	_add_action(tools, "+1 wing (max flutter)", func() -> void:
		var p := _player()
		if p: p.add_flutter_slot(1))
	_add_action(tools, "Dash strike: grant / revoke", func() -> void:
		if GameManager.has_ability(&"dash"):
			GameManager.revoke_ability(&"dash")
		else:
			GameManager.grant_ability(&"dash"))
	_add_action(tools, "Debug room", func() -> void: _close_and(LevelManager.go_to.bind("debug_room", "")))

	tools.add_child(_heading("SPAWN  (in front of you)", Color.WHITE))
	for enemy: Dictionary in EnemyCatalog.ENEMIES:
		var button := Button.new()
		button.text = enemy["name"]
		button.tooltip_text = enemy["move"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_spawn_enemy.bind(enemy["path"]))
		tools.add_child(button)

	var hint := Label.new()
	hint.text = "\nF1 / Esc / pad Select or B to close"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	tools.add_child(hint)

	# Controller setup: a separate page in the same frame, swapped in for the columns.
	_controls_page = PanelContainer.new()
	_controls_page.hide()
	_menu.add_child(_controls_page)
	var controls_scroll := ScrollContainer.new()
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.follow_focus = true
	_controls_page.add_child(controls_scroll)
	var controls_pad := MarginContainer.new()
	controls_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		controls_pad.add_theme_constant_override("margin_" + side, 16)
	controls_scroll.add_child(controls_pad)
	_controller_setup = ControllerSetup.new()
	_controller_setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controller_setup.closed.connect(_show_controller_setup.bind(false))
	controls_pad.add_child(_controller_setup)

	# Loadout: another page swapped in the same way (scripts/ui/debug_loadout_page.gd).
	_loadout_page = DebugLoadoutPage.new()
	_loadout_page.hide()
	_loadout_page.closed.connect(_show_loadout.bind(false))
	_menu.add_child(_loadout_page)


func _show_loadout(show_it: bool) -> void:
	_main_page.visible = not show_it
	_loadout_page.visible = show_it
	if show_it:
		_loadout_page.focus_first()
	elif _first_focus:
		_first_focus.grab_focus()


func _show_controller_setup(show_it: bool) -> void:
	_main_page.visible = not show_it
	_controls_page.visible = show_it
	if show_it:
		_controller_setup.focus_first()
	elif _first_focus:
		_first_focus.grab_focus()


func _heading(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _add_toggle(parent: Control, flag: String, text: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = get(flag)
	toggle.toggled.connect(func(on: bool) -> void: set(flag, on))
	parent.add_child(toggle)
	_toggle_buttons[flag] = toggle


func _add_action(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	parent.add_child(button)
