extends Node
## Moves the player between levels: fade out, loading card (LoadingScreen)
## while the scene loads on a thread, swap, fade in. The tree stays paused and
## input is swallowed for the whole transition.
## Reloads (death, F4) skip the card: the room just fades in from black.
## Remembers which spawn the player arrived at so death reloads put them back
## at the room entrance, and holds debug seed overrides for generated rooms.

## Seconds to fade the old room to black.
const FADE_OUT := 0.18
## Seconds to fade the new room in from black.
const FADE_IN := 0.25
## Least time the loading card stays up, so fast loads don't flicker...
const CARD_MIN := 0.5
## ...and a little longer when she enters a new realm, so its name lands.
const CARD_MIN_NEW_REALM := 1.1
## Seconds a reloaded room (death, F4, game start) fades in from black.
const RELOAD_FADE_IN := 0.3

var current_level: Node = null
var current_level_id: String = ""
## Spawn id used for the current room; reused when the room reloads after death.
var spawn_id: String = ""
## level_id -> seed. Set by the debug menu's "Reroll seed".
var seed_overrides: Dictionary = {}

var _busy := false
var _announce := false
var _fade: ColorRect
var _fade_tween: Tween
var _card: LoadingScreen


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
	_card = LoadingScreen.new()
	_card.name = "LoadingScreen"
	layer.add_child(_card)


## Swallow every input event while a transition runs, so presses on the
## loading card don't reach the menus or leak into the new level.
func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


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
	await _fade_to(1.0, FADE_OUT)

	var from_realm: String = LevelRegistry.find(current_level_id).get("realm", "")
	var new_realm: bool = info["realm"] != from_realm
	_card.show_for(info)
	if new_realm:
		# Start the realm crossfade under the card. MusicPlayer ignores the
		# repeat request it makes itself on scene_changed (same track key).
		MusicPlayer.play_realm(info["realm"])
	var packed := await _load_scene(info["path"], CARD_MIN_NEW_REALM if new_realm else CARD_MIN)
	var err := FAILED
	if packed:
		spawn_id = target_spawn
		current_level_id = level_id
		current_level = null
		_announce = true
		err = get_tree().change_scene_to_packed(packed)
	if err == OK:
		await get_tree().scene_changed
		await get_tree().process_frame
		if current_level == null:
			# Not a Level (e.g. the prototype scene): restore the default backdrop.
			RenderingServer.set_default_clear_color(
					ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
	else:
		push_error("LevelManager: failed to load %s (error %d)" % [info["path"], err])
		_announce = false
		if new_realm:
			MusicPlayer.play_realm(from_realm)
	await _card.hide_card()
	await _fade_to(0.0, FADE_IN)
	get_tree().paused = false
	_busy = false


## Threaded load of `path` behind the card, feeding its pip row. Holds until
## at least `min_time` has passed; the pips fill over that time even when the
## scene is already cached, so the bar never jumps. Null if the load fails.
func _load_scene(path: String, min_time: float) -> PackedScene:
	if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		return null
	var start := Time.get_ticks_msec()
	var progress := []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		var loaded := status == ResourceLoader.THREAD_LOAD_LOADED
		var real := 1.0 if loaded else (float(progress[0]) if not progress.is_empty() else 0.0)
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		_card.progress = minf(real, elapsed / min_time)
		if loaded and elapsed >= min_time:
			break
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene


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
	if not _busy:
		# A reload (death, F4) or the first room: no card, just come up from
		# black. The death sequence already ended on black, so this is seamless.
		_fade.modulate.a = 1.0
		_fade_to(0.0, RELOAD_FADE_IN)


func _fade_to(alpha: float, time: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", alpha, time)
	await _fade_tween.finished
