extends Node
## Plays one looping soundtrack per realm (autoload `MusicPlayer`).
##
## Watches scene changes, maps the current scene's path to a realm through
## `LevelRegistry`, and crossfades when the realm changes. A level in the same
## realm (or a reload after death) keeps the current track running without a
## restart. Only one track is ever audible at a time.
##
## Music plays on the "Music" bus (see `default_bus_layout.tres`). The user's
## volume lives on that bus and is saved to `user://settings.cfg`; ducking is
## layered on top of it, and crossfades happen on the two internal players.
##
## Public API: `set_music_volume()` / `get_music_volume()`, `duck()` / `unduck()`,
## `stop_music()`, `play_realm()`, and `play_override()` / `clear_override()` for
## boss moments. The player's death ducks the music automatically (via its
## `health_updated` signal); the next scene load unducks it.

## Emitted when the user's music volume changes (linear 0..1).
signal volume_changed(linear: float)

## Realm id -> looping track, from the realm's "music" key in
## LevelRegistry.REALMS. Empty for realms without music.
## ("debug" covers the debug room and the prototype scene.)
static func track_for(realm: String) -> String:
	return LevelRegistry.realm(realm).get("music", "")

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const SETTINGS_KEY := "music_volume"
const SILENT_DB := -60.0
const OVERRIDE_KEY := "<override>"

## Seconds a crossfade between realms (or a fade to silence) takes.
@export var fade_time: float = 1.2
## Playback level of the tracks before the user's volume. Mastered to about -18 LUFS.
@export var volume_db: float = -4.0
## Audio bus the music plays on (falls back to Master if it doesn't exist).
@export var bus: StringName = &"Music"
## How far the music dips while the player's death plays out.
@export var death_duck_db: float = -14.0

## Realm the current scene belongs to ("" outside registered levels).
var current_realm: String = ""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _tweens: Array[Tween] = [null, null]
## What's audible: a realm id, OVERRIDE_KEY, or "" for silence.
var _playing_key: String = ""
var _override: AudioStream = null
var _user_linear: float = 1.0
var _duck_db: float = 0.0
var _duck_tween: Tween
var _bus_index: int = 0


## Release the streams before the engine tears down, so quitting mid-track
## doesn't report leaked resources.
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	_override = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus_index = AudioServer.get_bus_index(bus)
	if _bus_index < 0:
		push_warning("MusicPlayer: no '%s' audio bus, using Master" % bus)
		_bus_index = 0
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Track%d" % i
		player.bus = AudioServer.get_bus_name(_bus_index)
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	_load_settings()
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	_on_scene_changed.call_deferred()


# --- Volume -------------------------------------------------------------------

## User music volume, linear 0..1 (0 mutes). Saved to `user://settings.cfg`.
func set_music_volume(linear: float, save: bool = true) -> void:
	_user_linear = clampf(linear, 0.0, 1.0)
	_apply_bus()
	if save:
		_save_settings()
	volume_changed.emit(_user_linear)


## User music volume, linear 0..1.
func get_music_volume() -> float:
	return _user_linear


# --- Ducking --------------------------------------------------------------------

## Dip the music by `amount_db` (negative) over `time` seconds, e.g. under a cutscene.
func duck(amount_db: float = -12.0, time: float = 0.4) -> void:
	_tween_duck(minf(amount_db, 0.0), time)


## Bring the music back to full level over `time` seconds.
func unduck(time: float = 0.8) -> void:
	_tween_duck(0.0, time)


# --- Tracks ---------------------------------------------------------------------

## Fade the music out and stop (`fade` < 0 uses `fade_time`). The next scene load
## or `play_realm()` starts it again.
func stop_music(fade: float = -1.0) -> void:
	_override = null
	_switch("", null, fade)


## Switch to `realm`'s track (crossfading), or fade out if it has none.
## Does nothing when that track is already playing. Ignored during an override.
func play_realm(realm: String) -> void:
	current_realm = realm
	if _override != null:
		return
	if track_for(realm) == "":
		_switch("", null)
		return
	if _playing_key == realm:
		return
	var stream := load(track_for(realm)) as AudioStream
	if stream == null:
		push_error("MusicPlayer: can't load %s" % track_for(realm))
		return
	_switch(realm, stream)


## Boss moments: crossfade to `stream` (looped if it supports it) until
## `clear_override()` or the next scene change.
func play_override(stream: AudioStream, fade: float = -1.0) -> void:
	if stream == null:
		clear_override(fade)
		return
	_override = stream
	_playing_key = ""  # force the switch even if the same stream plays again
	_switch(OVERRIDE_KEY, stream, fade)


## End an override and crossfade back to the current realm's track.
func clear_override(fade: float = -1.0) -> void:
	if _override == null:
		return
	_override = null
	if track_for(current_realm) != "":
		var stream := load(track_for(current_realm)) as AudioStream
		_switch(current_realm, stream, fade)
	else:
		_switch("", null, fade)


## Realm id for a scene path, or "" if the path isn't a registered level.
static func realm_for_path(path: String) -> String:
	var info := LevelRegistry.find_by_path(path)
	return info.get("realm", "") if not info.is_empty() else ""


# --- Internals --------------------------------------------------------------------

func _switch(key: String, stream: AudioStream, fade: float = -1.0) -> void:
	if key == _playing_key:
		return
	var time := fade_time if fade < 0.0 else fade
	_playing_key = key
	var old := _active
	_fade(old, SILENT_DB, true, time)
	if stream == null:
		return
	if "loop" in stream:
		stream.set("loop", true)
	_active = 1 - old
	var incoming := _players[_active]
	if _tweens[_active] and _tweens[_active].is_valid():
		_tweens[_active].kill()
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	# Headless runs (CI, agents' checks) have no audio out, and quitting mid-track
	# there leaks the Ogg playback. Track bookkeeping still runs.
	if DisplayServer.get_name() != "headless":
		incoming.play()
	_fade(_active, volume_db, false, time)


func _fade(index: int, to_db: float, stop_after: bool, time: float) -> void:
	var player := _players[index]
	if _tweens[index] and _tweens[index].is_valid():
		_tweens[index].kill()
	if not player.playing:
		return
	if time <= 0.0:
		player.volume_db = to_db
		if stop_after:
			player.stop()
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "volume_db", to_db, time)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[index] = tween


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_override = null
	unduck(0.6)
	play_realm(realm_for_path(scene.scene_file_path))


## Hook the player's death without touching player.gd: she emits
## `health_updated(0)` right before `_die()` starts the death sequence.
func _on_node_added(node: Node) -> void:
	if not (node is CharacterBody2D and node.has_signal("health_updated")):
		return
	if node.has_method("add_heart_container") or node.scene_file_path.ends_with("player.tscn"):
		var cb := _on_player_health
		if not node.is_connected("health_updated", cb):
			node.connect("health_updated", cb)


func _on_player_health(count: int) -> void:
	if count <= 0:
		duck(death_duck_db, 0.5)


func _tween_duck(target_db: float, time: float) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	if time <= 0.0:
		_set_duck(target_db)
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck_db, target_db, time)


func _set_duck(db: float) -> void:
	_duck_db = db
	_apply_bus()


func _apply_bus() -> void:
	if _user_linear <= 0.0:
		AudioServer.set_bus_mute(_bus_index, true)
		return
	AudioServer.set_bus_mute(_bus_index, false)
	AudioServer.set_bus_volume_db(_bus_index, linear_to_db(_user_linear) + _duck_db)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_user_linear = clampf(float(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, 1.0)), 0.0, 1.0)
	_apply_bus()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep any other sections other code stores here
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, _user_linear)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("MusicPlayer: couldn't save %s (error %d)" % [SETTINGS_PATH, err])
