class_name FileSelect
extends Control
## Zelda-style file select, opened from the title (TitleScreen) on its
## 384x216 stage and drawn with its theme. Three framed file cards show each
## save's room (in its realm's colour), hearts, coins, feathers, swords and
## play time; an empty file reads "New Climb".
##   pick a file   empty: start a new climb in it; used: continue it
##   Copy          pick a source, then a destination (asks before overwriting)
##   Erase         pick a file, then confirm
##   Back / ui_cancel steps back one stage, and closes from the top.

## The title gets its menu back (copies/erases may have changed Continue).
signal closed
## A file was picked and its room is loading; the title stops taking input.
signal started

enum Mode { PLAY, COPY_FROM, COPY_TO, ERASE, CONFIRM }

const STAGE := TitleScreen.STAGE
const CARD_SIZE := Vector2(280, 38)
const WARN := Color(1.0, 0.55, 0.45)

var _mode := Mode.PLAY
## What a Yes on the confirm row does (copy over / erase), and where No goes.
var _confirm_action := Callable()
var _confirm_back := Mode.PLAY
var _source := 0
var _cards: Array[FileCard] = []
var _actions: HBoxContainer
var _copy: Button
var _erase: Button
var _confirm: HBoxContainer
var _no: Button
var _header: Label
var _hint: Label
var _leaving := false


func _ready() -> void:
	size = STAGE
	var shade := ColorRect.new()
	shade.color = Color(TitleScreen.INK, 0.9)
	shade.size = STAGE
	add_child(shade)

	_header = _label("Select a File", TitleScreen.FONT_BOLD, TitleScreen.GOLD, 14)
	var rule := ColorRect.new()
	rule.color = Color(TitleScreen.GOLD, 0.5)
	rule.position = Vector2((STAGE.x - 120) / 2.0, 27)
	rule.size = Vector2(120, 1)
	add_child(rule)

	var list := VBoxContainer.new()
	list.position = Vector2((STAGE.x - CARD_SIZE.x) / 2.0, 34)
	list.add_theme_constant_override("separation", 5)
	add_child(list)
	for slot in range(1, SaveGame.SLOTS + 1):
		var card := FileCard.new()
		card.slot = slot
		card.custom_minimum_size = CARD_SIZE
		card.pressed.connect(_on_card.bind(slot))
		_wire(card)
		list.add_child(card)
		_cards.append(card)

	_actions = _row(166)
	_copy = _button(_actions, "Copy", _start_copy)
	_erase = _button(_actions, "Erase", _start_erase)
	_button(_actions, "Back", _back)
	_confirm = _row(166)
	_confirm.visible = false
	_button(_confirm, "Yes", func() -> void: _confirm_action.call())
	_no = _button(_confirm, "No", _back)

	_hint = _label("", TitleScreen.FONT, TitleScreen.DIM, 184)
	_set_mode(Mode.PLAY)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play(&"switch_sword", 0.05, -6.0, 0.8)
		_back()


## Called by the title each time it shows the panel.
func open() -> void:
	visible = true
	_leaving = false
	_set_mode(Mode.PLAY)


# --------------------------------------------------------------------------- flow

func _on_card(slot: int) -> void:
	if _leaving:
		return
	var used := SaveGame.has_save(slot)
	match _mode:
		Mode.PLAY:
			_leaving = true
			started.emit()
			if used:
				SaveGame.load_slot(slot)
			else:
				NewGameIntro.play(get_tree()) # the cherub scene, over the first room's load
				SaveGame.new_game(slot)
		Mode.COPY_FROM:
			_source = slot
			_set_mode(Mode.COPY_TO)
		Mode.COPY_TO:
			if used:
				_ask("Copy over File %d?" % slot, _do_copy.bind(slot), Mode.COPY_TO, slot)
			else:
				_do_copy(slot)
		Mode.ERASE:
			_ask("Erase File %d? It's gone for good." % slot, _do_erase.bind(slot), Mode.ERASE, slot)


func _start_copy() -> void:
	if _used_slots().is_empty():
		_flash("No file to copy.")
	else:
		_set_mode(Mode.COPY_FROM)


func _start_erase() -> void:
	if _used_slots().is_empty():
		_flash("No file to erase.")
	else:
		_set_mode(Mode.ERASE)


func _do_copy(to: int) -> void:
	var ok := SaveGame.copy_slot(_source, to)
	_set_mode(Mode.PLAY, _cards[to - 1])
	_flash("File %d copied to File %d." % [_source, to] if ok else "Couldn't copy the file.", not ok)


func _do_erase(slot: int) -> void:
	SaveGame.erase_slot(slot)
	Sfx.play(&"deflect", 0.04, -6.0)
	_set_mode(Mode.PLAY, _cards[slot - 1])
	_flash("File %d erased." % slot)


func _back() -> void:
	match _mode:
		Mode.PLAY:
			visible = false
			closed.emit()
		Mode.COPY_FROM:
			_set_mode(Mode.PLAY, _copy)
		Mode.COPY_TO:
			_set_mode(Mode.COPY_FROM, _cards[_source - 1])
		Mode.ERASE:
			_set_mode(Mode.PLAY, _erase)
		Mode.CONFIRM:
			_set_mode(_confirm_back, _cards[_marked_slot() - 1])


## Shows the Yes / No row for a question about `slot` (No is focused: safe).
func _ask(question: String, action: Callable, back_to: Mode, slot: int) -> void:
	_confirm_action = action
	_confirm_back = back_to
	_mode = Mode.CONFIRM
	for card in _cards:
		card.marked = card.slot == slot or (back_to == Mode.COPY_TO and card.slot == _source)
		card.danger = card.slot == slot
		card.focus_mode = Control.FOCUS_NONE
		card.restyle()
	_actions.visible = false
	_confirm.visible = true
	_header.text = "Erase File" if back_to == Mode.ERASE else "Copy File"
	_set_hint(question, WARN)
	_no.grab_focus()


func _set_mode(mode: Mode, focus: Control = null) -> void:
	_mode = mode
	_actions.visible = true
	_confirm.visible = false
	var used := _used_slots()
	for card in _cards:
		card.refresh()
		var pickable: bool
		match mode:
			Mode.PLAY: pickable = true
			Mode.COPY_FROM, Mode.ERASE: pickable = card.slot in used
			Mode.COPY_TO: pickable = card.slot != _source
		card.focus_mode = Control.FOCUS_ALL if pickable else Control.FOCUS_NONE
		card.dimmed = not pickable
		card.marked = mode == Mode.COPY_TO and card.slot == _source
		card.danger = false
		card.restyle()
	match mode:
		Mode.PLAY:
			_header.text = "Select a File"
			_set_hint("Pick a file to climb.", TitleScreen.DIM)
		Mode.COPY_FROM:
			_header.text = "Copy File"
			_set_hint("Copy which file?", TitleScreen.PALE)
		Mode.COPY_TO:
			_header.text = "Copy File"
			_set_hint("Copy File %d to which file?" % _source, TitleScreen.PALE)
		Mode.ERASE:
			_header.text = "Erase File"
			_set_hint("Erase which file?", WARN)
	if focus == null or focus.focus_mode == Control.FOCUS_NONE:
		focus = _first_pickable()
	focus.grab_focus()


func _first_pickable() -> Control:
	for card in _cards:
		if card.focus_mode != Control.FOCUS_NONE:
			return card
	return _copy


func _marked_slot() -> int:
	for card in _cards:
		if card.danger:
			return card.slot
	return 1


func _used_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in range(1, SaveGame.SLOTS + 1):
		if SaveGame.has_save(slot):
			out.append(slot)
	return out


func _flash(text: String, warn := false) -> void:
	_set_hint(text, WARN if warn else TitleScreen.GOLD)


func _set_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)


# --------------------------------------------------------------------------- building

func _wire(button: Button) -> void:
	button.focus_entered.connect(func() -> void: Sfx.play(&"switch_sword", 0.05, -8.0, 1.4))
	button.mouse_entered.connect(func() -> void:
		if button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus())


func _row(y: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, y)
	row.size = Vector2(STAGE.x, 10)
	add_child(row)
	return row


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void:
		if _leaving:
			return
		Sfx.play(&"switch_sword")
		action.call())
	_wire(button)
	var cursor := Label.new()
	cursor.text = ">"
	cursor.position = Vector2(-9, 0)
	cursor.visible = false
	cursor.add_theme_color_override("font_color", TitleScreen.GOLD)
	button.add_child(cursor)
	button.focus_entered.connect(cursor.show)
	button.focus_exited.connect(cursor.hide)
	parent.add_child(button)
	return button


func _label(text: String, font: Font, color: Color, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(0, y)
	label.size = Vector2(STAGE.x, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label


# --------------------------------------------------------------------------- card

## One framed file: number, room, hearts, coins / feathers / swords, time.
## Drawn in code at whole stage pixels.
class FileCard extends Button:
	const HEART := [
		".##.##.",
		"#######",
		"#######",
		".#####.",
		"..###..",
		"...#...",
	]
	const COIN := [
		".###.",
		"#h##d",
		"#h##d",
		"####d",
		".ddd.",
	]
	const FEATHER := [
		"...#",
		"..##",
		".##s",
		".#qs",
		"#q#.",
		"q#..",
		"q...",
	]
	const SWORD := [
		"......#",
		".....#s",
		"....#s.",
		".g.#s..",
		"..g....",
		".h.g...",
		"h......",
	]
	const FILL := Color(0.09, 0.06, 0.13, 0.95)
	const FRAME := Color(0.3, 0.26, 0.4)
	const RED := Color(0.9, 0.2, 0.24)
	const RED_HI := Color(1.0, 0.6, 0.6)
	const HOLLOW := Color(0.28, 0.18, 0.26)

	var slot := 1
	## Not pickable in the current mode: drawn faded.
	var dimmed := false
	## The copy source / the file a question is about: framed in gold.
	var marked := false
	## The file a question would overwrite or erase: framed in red.
	var danger := false
	var _info: Dictionary = {}

	func _ready() -> void:
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func refresh() -> void:
		_info = SaveGame.summary(slot)

	func restyle() -> void:
		modulate.a = 0.4 if dimmed and not marked else 1.0
		queue_redraw()

	func _draw() -> void:
		var font: Font = TitleScreen.FONT
		var bold: Font = TitleScreen.FONT_BOLD
		var w := size.x
		var h := size.y
		var lit := has_focus()
		var frame := RED if danger else TitleScreen.GOLD if lit or marked else FRAME

		draw_rect(Rect2(1, 1, w - 2, h - 2), FILL)
		# 1px frame with clipped corners, doubled on the focused card.
		draw_rect(Rect2(2, 0, w - 4, 1), frame)
		draw_rect(Rect2(2, h - 1, w - 4, 1), frame)
		draw_rect(Rect2(0, 2, 1, h - 4), frame)
		draw_rect(Rect2(w - 1, 2, 1, h - 4), frame)
		draw_rect(Rect2(1, 1, 1, 1), frame)
		draw_rect(Rect2(w - 2, 1, 1, 1), frame)
		draw_rect(Rect2(1, h - 2, 1, 1), frame)
		draw_rect(Rect2(w - 2, h - 2, 1, 1), frame)
		if lit:
			draw_rect(Rect2(2, 2, w - 4, h - 4), Color(frame, 0.35), false, 1.0)

		# File number, in its own column.
		var num_color := TitleScreen.GOLD if lit or marked else TitleScreen.PALE
		var nw := bold.get_string_size(str(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(bold, Vector2(roundf(13 - nw / 2.0), 26), str(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, num_color)
		draw_rect(Rect2(24, 5, 1, h - 10), Color(frame, 0.6))

		if _info.is_empty():
			var empty_color := TitleScreen.GOLD if lit else TitleScreen.DIM
			draw_string(font, Vector2(32, 22), "- New Climb -", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, empty_color)
			return

		# Row 1: realm (its colour) and room, play time on the right.
		var realm: String = _info["realm"]
		var x := 32.0
		draw_string(bold, Vector2(x, 13), realm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, _info["realm_color"])
		x += bold.get_string_size(realm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6
		draw_string(font, Vector2(x, 13), _info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TitleScreen.PALE)
		var time := SaveGame.format_time(_info["play_time"])
		draw_string(font, Vector2(w - 70, 13), time, HORIZONTAL_ALIGNMENT_RIGHT, 64, 8, TitleScreen.DIM)

		# Row 2: hearts (health in half-hearts), then coins / feathers / swords.
		var max_hearts := ceili(int(_info["max_health"]) / 2.0)
		var health := int(_info["health"])
		for i in max_hearts:
			var left := health - i * 2
			_heart(Vector2(32 + i * 8, 22), left)
		var right := w - 6
		right = _counter(right, SWORD, str(_info["swords"]), {"#": Color(0.92, 0.94, 1.0), "s": Color(0.58, 0.62, 0.74), "g": TitleScreen.GOLD, "h": Color(0.62, 0.4, 0.26)})
		right = _counter(right, FEATHER, str(_info["wings"]), {"#": Color.WHITE, "s": Color(0.78, 0.84, 0.95), "q": Color(0.62, 0.66, 0.78)})
		_counter(right, COIN, str(_info["coins"]), {"#": TitleScreen.GOLD, "h": Color(1.0, 0.96, 0.78), "d": Color(0.74, 0.5, 0.2)})

	## A heart with `left` half-hearts (2 full, 1 half, 0 empty).
	func _heart(origin: Vector2, left: int) -> void:
		for row in HEART.size():
			var line: String = HEART[row]
			for col in line.length():
				if line[col] != "#":
					continue
				var c := RED if left >= 2 or (left == 1 and col < 4) else HOLLOW
				if c == RED and row == 1 and col == 1:
					c = RED_HI
				draw_rect(Rect2(origin + Vector2(col, row), Vector2.ONE), c)

	## Draws "icon count" ending at x = `right` on row 2; returns where the
	## next counter to its left should end.
	func _counter(right: float, icon: Array, text: String, colors: Dictionary) -> float:
		var font: Font = TitleScreen.FONT
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(font, Vector2(right - tw, 29), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TitleScreen.PALE)
		var iw: int = (icon[0] as String).length()
		var origin := Vector2(right - tw - 2 - iw, 28 - icon.size())
		for row in icon.size():
			var line: String = icon[row]
			for col in line.length():
				if colors.has(line[col]):
					draw_rect(Rect2(origin + Vector2(col, row), Vector2.ONE), colors[line[col]])
		return right - tw - 2 - iw - 8
