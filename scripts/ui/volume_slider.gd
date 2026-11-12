class_name VolumeSlider
extends HBoxContainer
## Self-contained volume control for one audio channel. Drop it into any menu:
## it reads and writes the volume of `MusicPlayer` or `Sfx`, both saved to
## `user://settings.cfg`. Works with the mouse and with ui_left/ui_right when
## focused. See `scenes/ui/sfx_volume_slider.tscn`.

## Which volume the slider drives.
enum Channel { MUSIC, SFX }

## Which volume the slider drives.
@export var channel: Channel = Channel.SFX
## Text shown to the left of the slider.
@export var label_text: String = "SFX"
## `Sfx` id played when a drag ends (or a key nudges the slider), so the level
## can be heard. Empty for none.
@export var preview_sound: StringName = &""

var slider: HSlider
var _value_label: Label
var _dragging: bool = false


func _ready() -> void:
	var label := Label.new()
	label.text = label_text
	add_child(label)
	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.custom_minimum_size = Vector2(120, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	add_child(slider)
	_value_label = Label.new()
	_value_label.custom_minimum_size = Vector2(40, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_value_label)
	slider.set_value_no_signal(round(_get_volume() * 100.0))
	_update_label()
	slider.value_changed.connect(_on_value_changed)
	slider.drag_started.connect(func() -> void: _dragging = true)
	slider.drag_ended.connect(_on_drag_ended)
	_source().connect(&"volume_changed", _on_external_change)


## The autoload that owns this channel's volume.
func _source() -> Node:
	return MusicPlayer if channel == Channel.MUSIC else Sfx


func _get_volume() -> float:
	return MusicPlayer.get_music_volume() if channel == Channel.MUSIC else Sfx.get_sfx_volume()


func _set_volume(linear: float) -> void:
	if channel == Channel.MUSIC:
		MusicPlayer.set_music_volume(linear)
	else:
		Sfx.set_sfx_volume(linear)


func _on_value_changed(value: float) -> void:
	_set_volume(value / 100.0)
	_update_label()
	if not _dragging:
		_preview()


func _on_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	_preview()


func _preview() -> void:
	if preview_sound != &"":
		Sfx.play(preview_sound)


func _on_external_change(linear: float) -> void:
	slider.set_value_no_signal(round(linear * 100.0))
	_update_label()


func _update_label() -> void:
	_value_label.text = "%d%%" % int(slider.value)
