

extends Label


func _ready():
	GameManager.score_changed.connect(update_text)
	update_text()

func update_text():
	text = "Coins: " + str(GameManager.coins)
