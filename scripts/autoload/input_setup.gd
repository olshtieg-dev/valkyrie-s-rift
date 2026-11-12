extends Node
## Gamepad setup, applied at startup before any input is read.
##
## Every action in project.godot is bound to Godot's *standard* layout
## (Xbox names / PlayStation names):
##   A / Cross     jump              X / Square    attack
##   B / Circle    dash (and menu back)   (keyboard: C dash)
##   RT / R2       next sword        LT / L2       previous sword
##                                   (keyboard: Q next, R previous)
##   left stick / D-pad  move        D-pad up      interact
##   Back / Select debug menu (debug builds)
##   RB / R1, LB / L1, Y / Triangle  deliberately unbound in gameplay: reserved
##                 for future abilities and an ultimate (see RESERVED_BUTTONS)
##
## Any of these can be changed per player in F1 > Controller setup (see the
## bottom of this file); that also picks which pad drives the game.
##
## Godot translates each controller's raw buttons into that layout with a
## built-in database (SDL's gamecontrollerdb). Some third-party pads are in
## it with the wrong button order, so Square jumps and Cross does nothing.
## MAPPING_FIXES overrides those entries. To add a pad: find its GUID with
## Input.get_joy_guid(), log the raw button numbers, and add an SDL mapping
## string here (format: https://github.com/mdqinc/SDL_GameControllerDB).

const MAPPING_FIXES := [
	# PDP "Afterglow Gamepad for PS3" (USB 0e6f:0111). Generic HID pad whose raw
	# order is Square, Cross, Circle, Triangle, L1, R1, L2, R2, Select, Start,
	# L3, R3, PS; L2/R2 are digital. Godot's built-in entry swaps Square/Cross.
	# Listed with and without SDL3's CRC field in the GUID so either matches.
	"0300d3b76f0e00001101000011010000,Afterglow Gamepad for PS3,a:b1,b:b2,x:b0,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,back:b8,start:b9,leftstick:b10,rightstick:b11,guide:b12,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,",
	"030000006f0e00001101000011010000,Afterglow Gamepad for PS3,a:b1,b:b2,x:b0,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,back:b8,start:b9,leftstick:b10,rightstick:b11,guide:b12,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,",
]


## Pad buttons kept free of every gameplay action: R1 / L1 are reserved for
## future abilities, Triangle for an ultimate. Don't bind them by default.
const RESERVED_BUTTONS: Array[JoyButton] = [
	JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_Y,
]


func _enter_tree() -> void:
	for mapping: String in MAPPING_FIXES:
		# true = also re-map a pad that is already plugged in.
		Input.add_joy_mapping(mapping, true)
	_add_sword_rotation_actions()
	_add_dash_action()
	_add_menu_back_button()
	_init_controls()


## Sword rotation is on the triggers only: R2 next, L2 previous. Added here
## rather than in project.godot so an open editor can't save over it.
func _add_sword_rotation_actions() -> void:
	if not InputMap.has_action("switch_weapon_prev"):
		InputMap.add_action("switch_weapon_prev", 0.5)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event("switch_weapon_prev", key)
	# project.godot binds Triangle to next sword; it's reserved (RESERVED_BUTTONS).
	for action: String in ["switch_weapon", "switch_weapon_prev"]:
		if not InputMap.has_action(action):
			continue
		for button: JoyButton in RESERVED_BUTTONS:
			var reserved := InputEventJoypadButton.new()
			reserved.button_index = button
			if InputMap.action_has_event(action, reserved):
				InputMap.action_erase_event(action, reserved)
	# project.godot binds axis 4 (the LEFT trigger) to next sword, so R2 did
	# nothing; fix it here.
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	if InputMap.has_action("switch_weapon"):
		if InputMap.action_has_event("switch_weapon", lt):
			InputMap.action_erase_event("switch_weapon", lt)
		if not InputMap.action_has_event("switch_weapon", rt):
			InputMap.action_add_event("switch_weapon", rt)
	if InputMap.has_action("switch_weapon_prev") and not InputMap.action_has_event("switch_weapon_prev", lt):
		InputMap.action_add_event("switch_weapon_prev", lt)


## `dash`: pad O / B and keyboard C (Shift is attack). Added at runtime, like
## switch_weapon_prev, so an open editor can't save over it.
## O is also ui_cancel, which closes the paused menus. Godot still reports that
## press as is_action_just_pressed("dash") on the first unpaused physics frame
## (even if released in the same frame), so whatever reads `dash` must ignore
## it on the frame the tree resumes.
func _add_dash_action() -> void:
	if InputMap.has_action("dash"):
		return
	InputMap.add_action("dash", 0.5)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	InputMap.action_add_event("dash", key)
	var circle := InputEventJoypadButton.new()
	circle.button_index = JOY_BUTTON_B
	InputMap.action_add_event("dash", circle)


# ---------------------------------------------------------------------------
# Controller setup: which pad drives the game, and each action's pad bindings.
# Edited from the F1 menu (scripts/ui/controller_setup.gd), saved to
# CONFIG_PATH and applied at startup in every build. Works with any pad Godot
# can see, known to its database or not: you bind whatever it reports.
# Keyboard bindings are never touched.

## Emitted after the chosen pad or any binding changes.
signal controls_changed

const CONFIG_PATH := "user://controls.cfg"
## Saved as [meta] version. Files without it (version 1) predate the R2/L2-only
## sword layout; see LEGACY_DEFAULTS.
const CONFIG_VERSION := 2
## Version-1 default pad bindings (as saved by _encode) that are now obsolete:
## swords were also on Triangle / R1 / L1. A version-1 file whose binding for
## one of these actions is exactly this set was never customised, so it's
## dropped in favour of the new default. Any other saved set is kept as is.
const LEGACY_DEFAULTS := {
	"switch_weapon": ["b3", "b10", "a5+"],
	"switch_weapon_prev": ["b9", "a4+"],
}
## Actions shown in the controller setup, in menu order: [action, label].
const REBINDABLE := [
	["jump", "Jump"],
	["attack", "Attack"],
	["dash", "Dash"],
	["switch_weapon", "Next sword"],
	["switch_weapon_prev", "Prev sword"],
	["interact", "Interact"],
	["move_up", "Up / aim up"],
	["move_down", "Down / drop"],
	["move_left", "Left"],
	["move_right", "Right"],
	["ui_cancel", "Menu back"],
]
## Menu actions that copy a gameplay action's pad bindings, so a remapped pad
## can also drive menus (confirm = Jump). Keyboard keys are untouched.
const MENU_MIRRORS := {
	"ui_accept": "jump",
	"ui_up": "move_up",
	"ui_down": "move_down",
	"ui_left": "move_left",
	"ui_right": "move_right",
}

## How set_binding treats the action's existing pad bindings.
enum BindMode {
	ADD, ## keep them
	REPLACE_ALL, ## drop them all
	REPLACE_SAME_KIND, ## drop buttons if binding a button, axes if an axis (a D-pad press keeps the stick)
}
const BUTTON_NAMES := [
	"A/Cross", "B/Circle", "X/Square", "Y/Triangle", "Back/Select", "Home/PS",
	"Start", "L3", "R3", "LB/L1", "RB/R1", "D-pad up", "D-pad down",
	"D-pad left", "D-pad right", "Misc", "Paddle 1", "Paddle 2", "Paddle 3",
	"Paddle 4", "Touchpad",
]

## GUID of the chosen pad ("" = any controller) and its name, for display
## while it is unplugged.
var selected_guid := ""
var selected_name := ""

var _defaults: Dictionary = {} # action -> Array of joypad InputEvents


func _init_controls() -> void:
	for row: Array in REBINDABLE:
		_defaults[row[0]] = get_bindings(row[0]).map(func(e: InputEvent) -> InputEvent: return e.duplicate())
	_load()
	Input.joy_connection_changed.connect(func(_id: int, _connected: bool) -> void:
		_apply_device()
		_sync_menus()
		controls_changed.emit())
	_apply_device()
	_sync_menus()


## The device id the game listens to: the chosen pad if plugged in, else -1 (any).
func active_device() -> int:
	if selected_guid != "":
		for id in Input.get_connected_joypads():
			if Input.get_joy_guid(id) == selected_guid:
				return id
	return -1


## `guid` "" means any controller.
func select_device(guid: String, pad_name: String) -> void:
	selected_guid = guid
	selected_name = pad_name
	_apply_device()
	_commit()


## The joypad events bound to `action` (keyboard events left out).
func get_bindings(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if is_joy_event(e):
				out.append(e)
	return out


## Binds a pad button/axis to `action`; `mode` says what happens to its other pad bindings.
func set_binding(action: StringName, event: InputEvent, mode: BindMode) -> void:
	var clean := _clean(event)
	if clean == null or not InputMap.has_action(action):
		return
	for e in get_bindings(action):
		var same_kind := (e is InputEventJoypadButton) == (clean is InputEventJoypadButton)
		if mode == BindMode.REPLACE_ALL or (mode == BindMode.REPLACE_SAME_KIND and same_kind) or _same_input(e, clean):
			InputMap.action_erase_event(action, e)
	clean.device = active_device()
	InputMap.action_add_event(action, clean)
	_commit()


func clear_bindings(action: StringName) -> void:
	for e in get_bindings(action):
		InputMap.action_erase_event(action, e)
	_commit()


## Restores every action's pad bindings from project.godot (keeps the chosen pad).
func reset_bindings() -> void:
	for action: String in _defaults:
		for e in get_bindings(action):
			InputMap.action_erase_event(action, e)
		for e: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, e.duplicate())
	_apply_device()
	_commit()


## Other rebindable actions that share an input with `event`.
func actions_using(event: InputEvent) -> PackedStringArray:
	var out := PackedStringArray()
	for row: Array in REBINDABLE:
		for e in get_bindings(row[0]):
			if _same_input(e, event):
				out.append(row[1])
				break
	return out


static func is_joy_event(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


## Short human name for a pad button or axis direction, in Godot's standard layout.
static func describe(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		var b: int = e.button_index
		return BUTTON_NAMES[b] if b >= 0 and b < BUTTON_NAMES.size() else "Button %d" % b
	if e is InputEventJoypadMotion:
		var plus: bool = e.axis_value > 0.0
		match e.axis:
			JOY_AXIS_LEFT_X: return "L-stick right" if plus else "L-stick left"
			JOY_AXIS_LEFT_Y: return "L-stick down" if plus else "L-stick up"
			JOY_AXIS_RIGHT_X: return "R-stick right" if plus else "R-stick left"
			JOY_AXIS_RIGHT_Y: return "R-stick down" if plus else "R-stick up"
			JOY_AXIS_TRIGGER_LEFT: return "LT/L2"
			JOY_AXIS_TRIGGER_RIGHT: return "RT/R2"
		return "Axis %d%s" % [e.axis, "+" if plus else "-"]
	return "?"


func _commit() -> void:
	_sync_menus()
	_save()
	controls_changed.emit()


## Pad B goes back in menus. Godot's default ui_cancel has no pad button, so
## the F1 menu couldn't be backed out of with a controller.
func _add_menu_back_button() -> void:
	if InputMap.has_action("ui_cancel") and get_bindings("ui_cancel").is_empty():
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_B
		InputMap.action_add_event("ui_cancel", b)


func _sync_menus() -> void:
	for menu_action: String in MENU_MIRRORS:
		if not InputMap.has_action(menu_action):
			continue
		for e in get_bindings(menu_action):
			InputMap.action_erase_event(menu_action, e)
		for e in get_bindings(MENU_MIRRORS[menu_action]):
			InputMap.action_add_event(menu_action, e.duplicate())


func _apply_device() -> void:
	var device := active_device()
	for action in InputMap.get_actions():
		for e in InputMap.action_get_events(action):
			if is_joy_event(e) and e.device != device:
				InputMap.action_erase_event(action, e)
				e.device = device
				InputMap.action_add_event(action, e)


## A device-free copy of a pad press: a button, or an axis pushed one way.
static func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventJoypadButton:
		var b := InputEventJoypadButton.new()
		b.button_index = event.button_index
		return b
	if event is InputEventJoypadMotion:
		var m := InputEventJoypadMotion.new()
		m.axis = event.axis
		m.axis_value = 1.0 if event.axis_value > 0.0 else -1.0
		return m
	return null


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func _encode(e: InputEvent) -> String:
	if e is InputEventJoypadButton:
		return "b%d" % e.button_index
	return "a%d%s" % [e.axis, "+" if e.axis_value > 0.0 else "-"]


static func _decode(s: String) -> InputEvent:
	if s.begins_with("b") and s.substr(1).is_valid_int():
		var b := InputEventJoypadButton.new()
		b.button_index = s.substr(1).to_int() as JoyButton
		return b
	if s.begins_with("a") and s.length() >= 3 and s.substr(1, s.length() - 2).is_valid_int():
		var m := InputEventJoypadMotion.new()
		m.axis = s.substr(1, s.length() - 2).to_int() as JoyAxis
		m.axis_value = 1.0 if s.ends_with("+") else -1.0
		return m
	return null


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", CONFIG_VERSION)
	cfg.set_value("device", "guid", selected_guid)
	cfg.set_value("device", "name", selected_name)
	for row: Array in REBINDABLE:
		var codes := PackedStringArray()
		for e in get_bindings(row[0]):
			codes.append(_encode(e))
		cfg.set_value("bindings", row[0], codes)
	cfg.save(CONFIG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	selected_guid = cfg.get_value("device", "guid", "")
	selected_name = cfg.get_value("device", "name", "")
	var legacy: bool = cfg.get_value("meta", "version", 1) < CONFIG_VERSION
	for row: Array in REBINDABLE:
		var action: StringName = row[0]
		if not cfg.has_section_key("bindings", action) or not InputMap.has_action(action):
			continue
		var codes: PackedStringArray = cfg.get_value("bindings", action, PackedStringArray())
		if legacy and _is_legacy_default(action, codes):
			continue # keep the new default set up in _add_sword_rotation_actions
		for e in get_bindings(action):
			InputMap.action_erase_event(action, e)
		for code: String in codes:
			var e := _decode(code)
			if e:
				InputMap.action_add_event(action, e)
	if legacy:
		_save() # stamp the version so the migration runs once


## True if `codes` is exactly the old default for `action` (any order).
static func _is_legacy_default(action: StringName, codes: PackedStringArray) -> bool:
	if not LEGACY_DEFAULTS.has(action):
		return false
	var old: Array = LEGACY_DEFAULTS[action]
	if codes.size() != old.size():
		return false
	for code: String in codes:
		if not old.has(code):
			return false
	return true
