

extends Label


func _ready():
	print("ScoreLabel ready")
	GameManager.score_changed.connect(update_text)
	update_text()

func update_text():
	print("Updating text")
	text = "Score: " + str(GameManager.score)
