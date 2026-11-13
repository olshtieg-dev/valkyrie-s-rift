extends Node
## Three save files, Zelda style (autoload `SaveGame`).
##
## Files live at `user://save_1.dat` .. `save_3.dat`. The title's file select
## picks one: an empty file starts a new climb in it, a used one continues it.
## That file becomes the current slot, and every time a playable room finishes
## loading (level change or death reload) the run is written to it, so
## continuing drops her back at the entrance of the last room she reached with
## what she carried into it. Debug-realm rooms, and runs started without a
## file (debug warps from the title), are never saved.
##
## Play time counts while a room is running and the tree isn't paused; it is
## written with each room save and topped up (time only) when the game quits.
## Also holds the video setting the title Options page edits.

const SLOTS := 3
const VERSION := 1
## Where a new climb starts.
const FIRST_LEVEL := "hel_h01"
## The single save of earlier builds; moved into slot 1 once (see _migrate).
const LEGACY_PATH := "user://save.dat"

const SETTINGS_PATH := "user://settings.cfg"
const VIDEO_SECTION := "video"
const SAVE_SECTION := "save"

## The file auto-save writes to (1..SLOTS), 0 = none (not playing a file).
var current_slot := 0
## Seconds played on the current file, including this session.
var play_time := 0.0


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.get_value(VIDEO_SECTION, "fullscreen", false):
		set_fullscreen(true, false)
	_migrate()


func _process(delta: float) -> void:
	# Autoloads inherit pausing, so pause menus and level fades don't count.
	if current_slot > 0 and LevelManager.current_level != null:
		play_time += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_store_play_time()


# --------------------------------------------------------------------------- slots

static func slot_path(slot: int) -> String:
	return "user://save_%d.dat" % slot


func has_save(slot: int) -> bool:
	return not _read(slot).is_empty()


## The file Continue resumes: the last one played, if it still holds a save.
func last_slot() -> int:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var slot := int(cfg.get_value(SAVE_SECTION, "last_slot", 0))
	return slot if slot >= 1 and slot <= SLOTS and has_save(slot) else 0


## What the file select shows for a file, or {} when it's empty:
## level_id, name (room), realm (name), realm_color, health / max_health (in
## half-hearts, max without armor), coins, wings (feathers found), swords
## (owned), abilities (ids), play_time (seconds), saved_at (unix time).
func summary(slot: int) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {}
	var info := LevelRegistry.find(data["level_id"])
	var realm := LevelRegistry.realm(info.get("realm", ""))
	var state: Dictionary = data.get("player_state", {})
	var max_health := int(state.get("max_health", 6))
	return {
		"level_id": data["level_id"],
		"name": info.get("name", data["level_id"]),
		"realm": realm.get("name", ""),
		"realm_color": realm.get("color", Color.WHITE),
		"health": clampi(int(state.get("health", max_health)), 0, max_health),
		"max_health": max_health,
		"coins": int(data.get("score", 0)),
		"wings": int(state.get("flutter_bonus", 0)),
		"swords": maxi(1, (data.get("owned_weapons", []) as Array).size()),
		"abilities": state.get("abilities", []),
		"play_time": float(data.get("play_time", 0.0)),
		"saved_at": int(data.get("saved_at", 0)),
	}


## Restores a file into GameManager, makes it current and loads its room.
func load_slot(slot: int) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	GameManager.score = int(data.get("score", 0))
	GameManager.player_state = data.get("player_state", {})
	GameManager.owned_weapons.assign(data.get("owned_weapons", []))
	GameManager.owned_armor.assign(data.get("owned_armor", []))
	GameManager.pedestal_contents = data.get("pedestal_contents", {})
	GameManager.score_changed.emit()
	_select(slot, float(data.get("play_time", 0.0)))
	LevelManager.go_to(data["level_id"], data.get("spawn_id", ""))
	return true


## Starts a fresh climb in a file: clears every carried thing and loads the
## first room (whose arrival writes the file).
func new_game(slot: int) -> void:
	GameManager.score = 0
	GameManager.player_state = {}
	GameManager.owned_weapons.clear()
	GameManager.owned_armor.clear()
	GameManager.pedestal_contents = {}
	GameManager.score_changed.emit()
	_select(slot, 0.0)
	LevelManager.go_to(FIRST_LEVEL, "")


## Copies one file over another. False if the source is empty or the write fails.
func copy_slot(from: int, to: int) -> bool:
	if from == to:
		return false
	var data := _read(from)
	return not data.is_empty() and _write(to, data)


func erase_slot(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if slot == current_slot:
		current_slot = 0


## Play time as hours:minutes ("0:07", "12:45").
static func format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%02d" % [floori(minutes / 60.0), minutes % 60]


# --------------------------------------------------------------------------- settings

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(on: bool, save: bool = true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if save:
		_set_setting(VIDEO_SECTION, "fullscreen", on)


func _set_setting(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # keep the other sections (audio, video)
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS_PATH)


# --------------------------------------------------------------------------- internals

func _select(slot: int, time: float) -> void:
	current_slot = slot
	play_time = time
	_set_setting(SAVE_SECTION, "last_slot", slot)


func _on_scene_changed() -> void:
	if current_slot <= 0:
		return
	var level := LevelManager.current_level
	if level == null or level != get_tree().current_scene:
		return
	var info := LevelRegistry.find(LevelManager.current_level_id)
	if info.is_empty() or info.get("realm", "") == "debug":
		return
	_write(current_slot, {
		"version": VERSION,
		"level_id": LevelManager.current_level_id,
		"spawn_id": LevelManager.spawn_id,
		"score": GameManager.score,
		"player_state": GameManager.player_state.duplicate(true),
		"owned_weapons": Array(GameManager.owned_weapons),
		"owned_armor": Array(GameManager.owned_armor),
		"pedestal_contents": GameManager.pedestal_contents.duplicate(),
		"play_time": play_time,
		"saved_at": Time.get_unix_time_from_system(),
	})


## On quit: keep the time played since the last room save, and nothing else
## (coins picked up mid-room would come back with the room).
func _store_play_time() -> void:
	if current_slot <= 0:
		return
	var data := _read(current_slot)
	if data.is_empty():
		return
	data["play_time"] = play_time
	_write(current_slot, data)


func _write(slot: int, data: Dictionary) -> bool:
	var path := slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: couldn't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_var(data)
	return true


## A file's run, or {} when it's empty, unreadable or stale.
func _read(slot: int) -> Dictionary:
	return _read_path(slot_path(slot)) if slot >= 1 and slot <= SLOTS else {}


func _read_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var() # no objects allowed
	if not data is Dictionary or data.get("version", 0) != VERSION:
		return {}
	if LevelRegistry.find(str(data.get("level_id", ""))).is_empty():
		return {}
	return data


## Earlier builds kept one save at user://save.dat. Move it into slot 1 once,
## if slot 1 is free: write the copy, read it back, and only then rename the
## old file to save.dat.migrated (kept, never deleted). Any failure leaves
## save.dat where it was, to try again next launch.
func _migrate() -> void:
	if not FileAccess.file_exists(LEGACY_PATH) or FileAccess.file_exists(slot_path(1)):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.get_value(SAVE_SECTION, "legacy_migrated", false):
		return
	var data := _read_path(LEGACY_PATH)
	if data.is_empty():
		return # unreadable or stale: leave it alone
	if not data.has("play_time"):
		data["play_time"] = 0.0
	if not _write(1, data) or _read(1).get("level_id", "") != data["level_id"]:
		push_warning("SaveGame: couldn't move %s into file 1; kept it" % LEGACY_PATH)
		return
	if DirAccess.rename_absolute(LEGACY_PATH, LEGACY_PATH + ".migrated") != OK:
		# The copy is good; just don't migrate again over a file 1 the player erased.
		_set_setting(SAVE_SECTION, "legacy_migrated", true)
	_set_setting(SAVE_SECTION, "last_slot", 1)
