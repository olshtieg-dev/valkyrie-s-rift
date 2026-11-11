extends Node
## Moves the player between levels: fade out, swap scene, fade in.
## Remembers which spawn the player arrived at so death reloads put them back
## at the room entrance, and holds debug seed overrides for generated rooms.

var current_level: Node = null
var current_level_id: String = ""
## Spawn id used for the current room; reused when the room reloads after death.
var spawn_id: String = ""
## level_id -> seed. Set by the debug menu's "Reroll seed".
var seed_overrides: Dictionary = {}

var _busy := false
var _announce := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func go_to(level_id: String, target_spawn: String = "") -> void:
	if _busy:
		return
	var info := LevelRegistry.find(level_id)
	if info.is_empty():
		push_error("LevelManager: unknown level '%s' (add it to LevelRegistry)" % level_id)
		return
	_busy = true
	var player := get_tree().get_first_node_in_group("player")
	if player:
		GameManager.store_player_state(player)

	get_tree().paused = true
	await _fade_to(1.0)
	spawn_id = target_spawn
	current_level_id = level_id
	current_level = null
	_announce = true
	var err := get_tree().change_scene_to_file(info["path"])
	if err != OK:
		push_error("LevelManager: failed to load %s (error %d)" % [info["path"], err])
	await get_tree().process_frame
	await get_tree().process_frame
	if current_level == null:
		# Not a Level (e.g. the prototype scene): restore the default backdrop.
		RenderingServer.set_default_clear_color(
				ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
	get_tree().paused = false
	await _fade_to(0.0)
	_busy = false


## Reload the current room in place, keeping health/wings/weapon.
func reload_level() -> void:
	if _busy:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		GameManager.store_player_state(player)
	get_tree().paused = false
	get_tree().reload_current_scene()


## Debug: regenerate the current generated room with a fresh random seed.
func reroll_current() -> int:
	if current_level == null or current_level.get("generator") == null:
		return -1
	var new_seed := randi()
	seed_overrides[current_level_id] = new_seed
	reload_level()
	return new_seed


## Called by Level._ready.
func register_level(level: Node) -> void:
	current_level = level
	current_level_id = level.level_id
	if _announce:
		_announce = false
		level.announce()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, 0.18)
	await tween.finished
