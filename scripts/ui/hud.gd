extends CanvasLayer
## In-level HUD: score, wings, lives, sword switch, and the room title card.

@onready var title_label: Label = $TitleLabel

var _title_tween: Tween


func show_title(text: String) -> void:
	title_label.text = text
	title_label.modulate.a = 0.0
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween()
	_title_tween.tween_property(title_label, "modulate:a", 1.0, 0.4)
	_title_tween.tween_interval(1.8)
	_title_tween.tween_property(title_label, "modulate:a", 0.0, 0.6)
