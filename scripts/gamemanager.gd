extends Node

signal score_changed

var score := 0

func add_point(amount := 1):
	score += amount
	score_changed.emit()
	print(score) # debug
	
func reset_score():
	score = 0
	score_changed.emit()
