class_name MusicVolumeSlider
extends HBoxContainer
## Self-contained "Music" volume control. Drop it into any menu: it reads and
## writes `MusicPlayer`'s volume, which is saved to `user://settings.cfg`.
## Works with the mouse and with ui_left/ui_right when focused.

## Text shown to the left of the slider.
@export var label_text: String = "Music"

var slider: HSlider
var _value_label: Label


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
	slider.set_value_no_signal(round(MusicPlayer.get_music_volume() * 100.0))
	_update_label()
	slider.value_changed.connect(_on_value_changed)
	MusicPlayer.volume_changed.connect(_on_external_change)


func _on_value_changed(value: float) -> void:
	MusicPlayer.set_music_volume(value / 100.0)
	_update_label()


func _on_external_change(linear: float) -> void:
	slider.set_value_no_signal(round(linear * 100.0))
	_update_label()


func _update_label() -> void:
	_value_label.text = "%d%%" % int(slider.value)
