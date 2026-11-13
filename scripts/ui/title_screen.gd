class_name TitleScreen
extends Control
## Title: Yggdrasil on its hill in a dusk valley ringed by peaks (TitleBackdrop), the game's
## name, and the main menu: Continue / Select File / Options / Debug.
##   Continue     resumes the last file played (SaveGame), greyed out without one
##   Select File  opens the three-file select (FileSelect): new climb, continue,
##                copy, erase
##   Options   music / sfx volume, fullscreen, armor skin
##   Debug     opens the developer menu (debug builds only; warp anywhere)

const STAGE := Vector2(384, 216)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const MUSIC_SLIDER := preload("res://scenes/ui/music_volume_slider.tscn")
const SFX_SLIDER := preload("res://scenes/ui/sfx_volume_slider.tscn")

const GOLD := Color(1.0, 0.84, 0.4)
const PALE := Color(0.86, 0.84, 0.92)
const DIM := Color(0.46, 0.44, 0.56)
const INK := Color(0.08, 0.05, 0.1)

var _menu: VBoxContainer
var _options: VBoxContainer
var _hint: Label
var _continue: Button
var _select_file: Button
var _files: FileSelect
var _fullscreen: Button
## Options: her armor skin (PlayerSkins), cycled with left/right or a press,
## with a little preview of her standing beside the menu.
var _armor: Button
var _armor_preview: TextureRect
var _preview_t := 0.0
var _leaving := false


func _ready() -> void:
	size = STAGE
	theme = _make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(TitleBackdrop.new())

	var title := _label("Valkyrie's Rift", 16, FONT_BOLD, GOLD, Vector2(18, 26))
	title.add_theme_constant_override("outline_size", 4)
	var subtitle := _label("Einherjer's Rising", 8, FONT, PALE, Vector2(20, 46))
	subtitle.add_theme_constant_override("outline_size", 3)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.6)
	rule.position = Vector2(20, 58)
	rule.size = Vector2(92, 1)
	add_child(rule)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(22, 86)
	_menu.add_theme_constant_override("separation", 3)
	add_child(_menu)
	_continue = _item(_menu, "Continue", _on_continue)
	_select_file = _item(_menu, "Select File", _show_files.bind(true))
	_item(_menu, "Options", _show_options.bind(true))
	if OS.is_debug_build():
		_item(_menu, "Debug", _on_debug)

	_options = VBoxContainer.new()
	_options.position = Vector2(22, 86)
	_options.add_theme_constant_override("separation", 4)
	_options.visible = false
	add_child(_options)
	_options.add_child(_heading("Options"))
	_options.add_child(MUSIC_SLIDER.instantiate())
	_options.add_child(SFX_SLIDER.instantiate())
	_fullscreen = _item(_options, "", _toggle_fullscreen)
	_armor = _item(_options, "", _cycle_armor.bind(1))
	_armor.gui_input.connect(_on_armor_input)
	_item(_options, "Back", _show_options.bind(false))
	_update_fullscreen_text()
	_armor_preview = _make_armor_preview()
	_update_armor_text()

	_hint = _label("", 8, FONT, DIM, Vector2(22, 152))
	_hint.add_theme_constant_override("outline_size", 2)
	_refresh_continue()

	var footer := _label("olshtieg-dev  *  made with Claude AI & Godot", 8, FONT, Color(PALE, 0.8), Vector2(0, STAGE.y - 12))
	footer.size.x = STAGE.x - 6
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_constant_override("outline_size", 4)

	_files = FileSelect.new()
	_files.visible = false
	_files.closed.connect(_show_files.bind(false))
	_files.started.connect(func() -> void: _leaving = true)
	add_child(_files)

	# Come up from black.
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.size = STAGE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.2)
	tween.tween_callback(fade.queue_free)

	(_select_file if _continue.disabled else _continue).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel") and _options.visible:
		get_viewport().set_input_as_handled()
		_show_options(false)


# --------------------------------------------------------------------------- actions

func _on_continue() -> void:
	if _leaving:
		return
	_leaving = true
	if not SaveGame.load_slot(SaveGame.last_slot()):
		_leaving = false


func _show_files(show_it: bool) -> void:
	_menu.visible = not show_it
	_hint.visible = not show_it
	if show_it:
		_files.open()
	else:
		_refresh_continue() # a copy or erase may have changed the last file
		_select_file.grab_focus()


## Continue follows the last file played; the hint names where it stands.
func _refresh_continue() -> void:
	var slot := SaveGame.last_slot()
	_continue.disabled = slot == 0
	var save := SaveGame.summary(slot) if slot > 0 else {}
	_hint.text = "File %d  %s - %s" % [slot, save["realm"], save["name"]] if not save.is_empty() else ""


func _on_debug() -> void:
	# The developer overlay is an autoload; it pauses the tree while open and
	# its level list warps straight in through LevelManager.
	DebugMenu.call("_set_menu_open", true)


func _show_options(show_it: bool) -> void:
	_options.visible = show_it
	_armor_preview.visible = show_it
	_menu.visible = not show_it
	_hint.visible = not show_it
	if show_it:
		(_options.get_child(1).get("slider") as Control).grab_focus()
	else:
		_menu.get_child(2).grab_focus()


func _toggle_fullscreen() -> void:
	SaveGame.set_fullscreen(not SaveGame.is_fullscreen())
	_update_fullscreen_text()


func _cycle_armor(step: int) -> void:
	PlayerSkins.cycle(step, get_tree())
	_update_armor_text()


func _on_armor_input(event: InputEvent) -> void:
	for dir in [[&"ui_left", -1], [&"ui_right", 1]]:
		if event.is_action_pressed(dir[0]):
			_armor.accept_event()
			Sfx.play(&"switch_sword")
			_cycle_armor(dir[1])


func _update_armor_text() -> void:
	_armor.text = "Armor: < %s >" % PlayerSkins.current_name()
	_armor_preview.texture = _preview_frame(0)


## Her idle frame (0..3) in the current skin, from the knight sheet layout.
func _preview_frame(i: int) -> AtlasTexture:
	var id := PlayerSkins.current()
	var tex := AtlasTexture.new()
	tex.atlas = PlayerSkins.ORIGINAL_KNIGHT if id == "original" else load(PlayerSkins.SKIN_DIR + id + ".png")
	tex.region = Rect2(i * 32, 0, 32, 32)
	return tex


func _make_armor_preview() -> TextureRect:
	var rect := TextureRect.new()
	rect.position = Vector2(176, 112)
	rect.scale = Vector2(2, 2)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)
	return rect


func _process(delta: float) -> void:
	if _armor_preview and _armor_preview.visible:
		_preview_t += delta
		(_armor_preview.texture as AtlasTexture).region.position.x = (int(_preview_t * 6.0) % 4) * 32


func _update_fullscreen_text() -> void:
	_fullscreen.text = "Fullscreen: %s" % ("On" if SaveGame.is_fullscreen() else "Off")


# --------------------------------------------------------------------------- building

func _item(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void:
		Sfx.play(&"switch_sword")
		action.call())
	button.focus_entered.connect(func() -> void:
		Sfx.play(&"switch_sword", 0.05, -8.0, 1.4))
	button.mouse_entered.connect(button.grab_focus)
	# A pointer that slides in next to the focused item.
	var cursor := Label.new()
	cursor.text = ">"
	cursor.position = Vector2(-9, 0)
	cursor.visible = false
	cursor.add_theme_color_override("font_color", GOLD)
	button.add_child(cursor)
	button.focus_entered.connect(cursor.show)
	button.focus_exited.connect(cursor.hide)
	parent.add_child(button)
	return button


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _label(text: String, font_size: int, font: Font, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


## Flat pixel styling for the stage: 8px font, no button frames, a tiny
## gold slider grabber (the default icons are far too big at this scale).
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 8
	t.set_color("font_outline_color", "Label", INK)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		t.set_stylebox(state, "Button", empty)
	t.set_color("font_color", "Button", PALE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.7))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 2)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.17, 0.28)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(GOLD, 0.8)
	fill.content_margin_top = 1
	fill.content_margin_bottom = 1
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _block_icon(PALE))
	t.set_icon("grabber_highlight", "HSlider", _block_icon(GOLD))
	t.set_icon("grabber_disabled", "HSlider", _block_icon(DIM))
	return t


static func _block_icon(color: Color) -> ImageTexture:
	var img := Image.create(3, 7, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
