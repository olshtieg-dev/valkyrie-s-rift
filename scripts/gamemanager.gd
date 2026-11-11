extends Node

signal score_changed

## Coins: barter currency (expendables, swords and armor at shrines/shops).
## Stored in `score` for the existing ScoreLabel/signal; use the coin API.
var score := 0
var coins: int:
	get: return score

## Carried across level transitions: health, flutter bonus, sword loadout
## (resource paths) and the active slot.
## Cleared of "health" on death so the player respawns at full starting health.
var player_state: Dictionary = {}

func add_point(amount := 1):
	score += amount
	score_changed.emit()

func add_coins(amount := 1) -> void:
	add_point(amount)


## Spends coins if there are enough. Returns false (and spends nothing) if not.
func spend_coins(amount: int) -> bool:
	if amount > score:
		return false
	score -= amount
	score_changed.emit()
	return true

func reset_score():
	score = 0
	score_changed.emit()

func store_player_state(player: Node) -> void:
	var loadout_paths: Array[String] = []
	for data: Resource in player.loadout:
		loadout_paths.append(data.resource_path)
	player_state = {
		"health": player.current_health,
		"max_health": player.max_health,
		"flutter_bonus": player.flutter_bonus,
		"loadout": loadout_paths,
		"weapon_slot": player.active_slot,
	}
