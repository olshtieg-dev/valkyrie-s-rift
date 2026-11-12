extends Node

signal score_changed

## Coins: barter currency (expendables, swords and armor at shrines/shops).
## Stored in `score` for the existing ScoreLabel/signal; use the coin API.
var score := 0
var coins: int:
	get: return score

## Carried across level transitions: health, flutter bonus, sword loadout
## (resource paths), the active slot and found abilities.
## Cleared of "health" on death so the player respawns at full starting health.
var player_state: Dictionary = {}

## Every sword she has found or bought (resource paths). Shrines let her swap
## any of these into her loadout (MAX_LOADOUT in player.gd). Survives death and level changes.
var owned_weapons: Array[String] = []
## Which sword each pedestal currently holds, so a swap (or an emptied
## pedestal) persists when the level reloads. Key: scene path + node name.
var pedestal_contents: Dictionary = {}
## Every suit of armor she has found or bought (resource paths).
var owned_armor: Array[String] = []

## Abilities she has found (ids such as "dash"), kept in player_state["abilities"]
## so they ride along with the rest of her carried state. Written the moment
## she finds one, so a death reload never takes it back.
func has_ability(id: StringName) -> bool:
	return String(id) in player_state.get("abilities", [])

func grant_ability(id: StringName) -> void:
	var list: Array = player_state.get("abilities", []).duplicate()
	if not String(id) in list:
		list.append(String(id))
	player_state["abilities"] = list

func revoke_ability(id: StringName) -> void:
	var list: Array = player_state.get("abilities", []).duplicate()
	list.erase(String(id))
	player_state["abilities"] = list

func own_armor(data: Resource) -> bool:
	if data == null or data.resource_path == "" or data.resource_path in owned_armor:
		return false
	owned_armor.append(data.resource_path)
	return true

func owns_armor(data: Resource) -> bool:
	return data != null and data.resource_path in owned_armor

func own_weapon(data: Resource) -> bool:
	# Only saved sword files can be remembered (the save stores their paths).
	if data == null or data.resource_path == "" or data.resource_path in owned_weapons:
		return false
	owned_weapons.append(data.resource_path)
	return true

func owns_weapon(data: Resource) -> bool:
	return data != null and data.resource_path in owned_weapons

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
		"max_health": player.base_max_health, # heart containers, without armor
		"armor": player.armor.resource_path if player.armor else "",
		"flutter_bonus": player.flutter_bonus,
		"loadout": loadout_paths,
		"weapon_slot": player.active_slot,
		"abilities": player_state.get("abilities", []),
	}
