class_name ControllerSetup
extends VBoxContainer
## Controller setup page for the F1 menu: pick which pad drives the game,
## test it (shows the last thing pressed), and rebind each action by pressing
## the button you want. Changes save immediately (InputSetup → user://controls.cfg).
##   Set    replace the action's pad bindings with the next press
##   Add    keep them and add the next press
##   Clear  remove the action's pad bindings
##   Quick setup  asks for every action in turn; press its button, or wait
##                to skip (keeps the old binding). Esc stops.

## The player chose Back.
signal closed

const LISTEN_TIMEOUT := 6.0
## Quick setup: seconds to wait on each action before skipping it.
const WIZARD_STEP_TIME := 6.0
## Ignore presses this soon after "Set"/"Add", so the press that chose it
## (A/Cross on a pad) isn't captured as the new binding.
const LISTEN_GRACE := 0.25
const AXIS_THRESHOLD := 0.6

var _device_picker: OptionButton
var _device_guids: PackedStringArray = []
var _last_input: Label
var _status: Label
var _binding_labels: Dictionary = {} # action -> Label
var _first_focus: Control

var _listen_action := ""
var _listen_mode: InputSetup.BindMode = InputSetup.BindMode.REPLACE_ALL
var _wizard := false
var _wizard_index := 0
var _wizard_skipped := PackedStringArray()
var _axis_held: Dictionary = {} # "device:axis" -> true while pushed past the threshold
var _listen_time := 0.0
var _listen_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build()
	InputSetup.controls_changed.connect(_refresh)
	_refresh()


## Call when the page is shown, so a pad can drive it straight away.
func focus_first() -> void:
	_cancel_listen()
	_refresh()
	if _first_focus:
		_first_focus.grab_focus()


func _build() -> void:
	add_child(_heading("CONTROLLER SETUP"))

	var device_row := HBoxContainer.new()
	device_row.add_theme_constant_override("separation", 12)
	var device_label := Label.new()
	device_label.text = "Use"
	device_row.add_child(device_label)
	_device_picker = OptionButton.new()
	_device_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_device_picker.item_selected.connect(_on_device_selected)
	device_row.add_child(_device_picker)
	add_child(device_row)

	var quick := _small_button("Quick setup: press each button in turn", _start_wizard)
	quick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(quick)
	_first_focus = quick

	_last_input = Label.new()
	_last_input.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_input.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(_last_input)

	add_child(_heading("BINDINGS"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for row: Array in InputSetup.REBINDABLE:
		var action: String = row[0]
		if not InputMap.has_action(action):
			continue
		var name_label := Label.new()
		name_label.text = row[1]
		grid.add_child(name_label)
		var bound := Label.new()
		bound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bound.clip_text = true
		bound.custom_minimum_size.x = 260
		grid.add_child(bound)
		_binding_labels[action] = bound
		grid.add_child(_small_button("Set", _start_listen.bind(action, InputSetup.BindMode.REPLACE_ALL)))
		grid.add_child(_small_button("Add", _start_listen.bind(action, InputSetup.BindMode.ADD)))
		grid.add_child(_small_button("Clear", func() -> void:
			_cancel_listen()
			InputSetup.clear_bindings(action)))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	add_child(_status)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.add_child(_small_button("Reset to defaults", func() -> void:
		_cancel_listen()
		InputSetup.reset_bindings()
		_status.text = "Pad bindings reset to defaults."))
	footer.add_child(_small_button("Back", func() -> void:
		_cancel_listen()
		closed.emit()))
	add_child(footer)

	var hint := Label.new()
	hint.text = "Keyboard keys are unchanged. Esc / pad B (or your Menu back): back"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(hint)


func _refresh() -> void:
	if not is_inside_tree():
		return
	# Pad list: "Any controller" plus every connected pad (and the saved one if unplugged).
	_device_picker.clear()
	_device_guids.clear()
	_device_picker.add_item("Any controller")
	_device_guids.append("")
	var selected_index := 0
	var saved_found := false
	for id in Input.get_connected_joypads():
		var guid := Input.get_joy_guid(id)
		_device_picker.add_item("#%d  %s" % [id, Input.get_joy_name(id)])
		_device_guids.append(guid)
		if guid == InputSetup.selected_guid and not saved_found:
			selected_index = _device_guids.size() - 1
			saved_found = true
	if InputSetup.selected_guid != "" and not saved_found:
		_device_picker.add_item("%s  (unplugged)" % InputSetup.selected_name)
		_device_guids.append(InputSetup.selected_guid)
		selected_index = _device_guids.size() - 1
	_device_picker.select(selected_index)

	for action: String in _binding_labels:
		var names := PackedStringArray()
		for e in InputSetup.get_bindings(action):
			var text := InputSetup.describe(e)
			var shared := InputSetup.actions_using(e)
			if shared.size() > 1:
				text += "*"
			names.append(text)
		(_binding_labels[action] as Label).text = ", ".join(names) if not names.is_empty() else "(none)"
	if _last_input.text == "":
		_last_input.text = "Press anything on a pad to test it."


func _on_device_selected(index: int) -> void:
	var guid := _device_guids[index]
	var pad_name := ""
	if guid != "":
		pad_name = _device_picker.get_item_text(index).get_slice("  ", 1)
	InputSetup.select_device(guid, pad_name)
	_status.text = "Using %s." % ("any controller" if guid == "" else pad_name)


func _start_listen(action: String, mode: InputSetup.BindMode) -> void:
	_listen_action = action
	_listen_mode = mode
	_listen_time = 0.0
	if not _wizard:
		_listen_button = get_viewport().gui_get_focus_owner() as Button
		_status.text = "Press a pad button or push a stick for %s...  (Esc cancels)" % _label_of(action)
	else:
		_update_wizard_prompt()


func _start_wizard() -> void:
	_wizard = true
	_wizard_index = 0
	_wizard_skipped.clear()
	_listen_button = get_viewport().gui_get_focus_owner() as Button
	_start_listen(InputSetup.REBINDABLE[0][0], InputSetup.BindMode.REPLACE_SAME_KIND)


func _wizard_next() -> void:
	_wizard_index += 1
	if _wizard_index < InputSetup.REBINDABLE.size():
		_start_listen(InputSetup.REBINDABLE[_wizard_index][0], InputSetup.BindMode.REPLACE_SAME_KIND)
		return
	_wizard = false
	_listen_action = ""
	_status.text = "Quick setup done." + ("  Skipped (unchanged): " + ", ".join(_wizard_skipped) if not _wizard_skipped.is_empty() else "")
	if _listen_button:
		_listen_button.grab_focus()


func _update_wizard_prompt() -> void:
	_status.text = "QUICK SETUP %d/%d:  press the button for  %s\n(skips in %ds, keeping the old binding; Esc stops)" % [
		_wizard_index + 1, InputSetup.REBINDABLE.size(), _label_of(_listen_action).to_upper(),
		ceili(WIZARD_STEP_TIME - _listen_time)]


func _cancel_listen(message := "") -> void:
	if _listen_action != "":
		_listen_action = ""
		_wizard = false
		_status.text = message


func _process(delta: float) -> void:
	if _listen_action == "":
		return
	_listen_time += delta
	if _wizard:
		if _listen_time > WIZARD_STEP_TIME:
			_wizard_skipped.append(_label_of(_listen_action))
			_wizard_next()
		else:
			_update_wizard_prompt()
	elif _listen_time > LISTEN_TIMEOUT:
		_cancel_listen("No input. Nothing changed.")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var device_ok := InputSetup.active_device() == -1 or event.device == InputSetup.active_device()
	var press := _is_press(event)
	if press:
		_last_input.text = "Last input: %s  (pad #%d %s)%s" % [
			InputSetup.describe(event), event.device, _raw_code(event),
			"" if device_ok else "  - not the selected pad"]

	if _listen_action == "":
		return
	# While listening, the pad talks to us only (no menu navigation).
	if InputSetup.is_joy_event(event):
		get_viewport().set_input_as_handled()
		if press and device_ok and _listen_time >= LISTEN_GRACE:
			var action := _listen_action
			_listen_action = ""
			InputSetup.set_binding(action, event, _listen_mode)
			var shared := InputSetup.actions_using(event)
			shared.erase(_label_of(action))
			_status.text = "%s bound to %s.%s" % [_label_of(action), InputSetup.describe(event),
				("  * also used by " + ", ".join(shared)) if not shared.is_empty() else ""]
			if _wizard:
				_wizard_next()
			elif _listen_button:
				_listen_button.grab_focus()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel_listen("Stopped. Bindings made so far are kept." if _wizard else "Cancelled.")


func _is_press(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		# Only the moment it crosses the threshold, so a held stick counts once.
		var key := "%d:%d" % [event.device, event.axis]
		var was: bool = _axis_held.get(key, false)
		var now := absf(event.axis_value) >= AXIS_THRESHOLD
		_axis_held[key] = now
		return now and not was
	return false


func _raw_code(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "button %d" % event.button_index
	return "axis %d %s" % [event.axis, "+" if event.axis_value > 0.0 else "-"]


func _label_of(action: String) -> String:
	for row: Array in InputSetup.REBINDABLE:
		if row[0] == action:
			return row[1]
	return action


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _small_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	return button
