extends Node
## Sound effects (autoload `Sfx`).
##
## Every sound has an id in `SOUNDS`: its clip(s), level, pitch jitter and
## cooldown. Swapping a sound is a one-line change there. A sound with several
## clips picks one at random (never the same twice in a row).
##
##   Sfx.play(&"jump")                         # non-positional (the player's own sounds)
##   Sfx.play(&"hurt", -1.0, -3.0, 0.9)        # default jitter, 3 dB quieter, pitched down
##   Sfx.play_at(&"hit", enemy.global_position) # positional, panned by the camera
##
## Helpers pick ids from game state: `footstep_id()` (by the current realm),
## `swing_id()` / `hit_id()` (by the sword's element, or its own override).
##
## Plays on the "SFX" bus (see `default_bus_layout.tres`); falls back to Master.
## Runs while the tree is paused (the death sequence pauses it).

## Emitted whenever a sound actually starts (after cooldown). Handy for tests.
signal played(id: StringName)
## Emitted when the user's SFX volume changes (linear 0..1).
signal volume_changed(linear: float)

## id -> {files: Array[String], db: float, jitter: float (pitch +-), cooldown: float (s)}
const SOUNDS := {
	# --- Moving ---
	&"step_stone": {"files": [
		"res://assets/sounds/juhani_junkala_moves/step_stone_1.wav",
		"res://assets/sounds/juhani_junkala_moves/step_stone_2.wav",
		"res://assets/sounds/juhani_junkala_moves/step_stone_3.wav"], "db": -15.0, "jitter": 0.08, "cooldown": 0.09},
	&"step_bark": {"files": [
		"res://assets/sounds/juhani_junkala_moves/step_bark_1.wav",
		"res://assets/sounds/juhani_junkala_moves/step_bark_2.wav"], "db": -17.0, "jitter": 0.1, "cooldown": 0.09},
	&"step_cloud": {"files": [
		"res://assets/sounds/juhani_junkala_moves/step_cloud_1.wav",
		"res://assets/sounds/juhani_junkala_moves/step_cloud_2.wav"], "db": -12.0, "jitter": 0.1, "cooldown": 0.09},
	&"step_metal": {"files": [
		"res://assets/sounds/juhani_junkala_moves/step_metal_1.wav",
		"res://assets/sounds/juhani_junkala_moves/step_metal_2.wav"], "db": -17.0, "jitter": 0.06, "cooldown": 0.09},
	&"jump": {"files": ["res://assets/sounds/jump.wav"], "db": -8.0, "jitter": 0.05, "cooldown": 0.05},
	&"land": {"files": [
		"res://assets/sounds/juhani_junkala_moves/land_soft_1.wav",
		"res://assets/sounds/juhani_junkala_moves/land_soft_2.wav"], "db": -8.0, "jitter": 0.08, "cooldown": 0.1},
	&"land_heavy": {"files": [
		"res://assets/sounds/juhani_junkala_moves/land_heavy_1.wav",
		"res://assets/sounds/juhani_junkala_moves/land_heavy_2.wav"], "db": -4.0, "jitter": 0.06, "cooldown": 0.1},
	&"drop_through": {"files": ["res://assets/sounds/tap.wav"], "db": -14.0, "jitter": 0.1, "cooldown": 0.1},
	## Broken wings: small, strained flaps (pitched up as the charges run out).
	&"flutter": {"files": [
		"res://assets/sounds/antumdeluge_wings_flap/wing_flutter_1.wav",
		"res://assets/sounds/antumdeluge_wings_flap/wing_flutter_2.wav",
		"res://assets/sounds/antumdeluge_wings_flap/wing_flutter_3.wav"], "db": -3.0, "jitter": 0.06, "cooldown": 0.08},
	&"spring": {"files": ["res://assets/sounds/yo_frankie/projectile_splat.wav"], "db": -2.0, "jitter": 0.08, "cooldown": 0.15},
	# --- Meteor Strike ---
	&"meteor_windup": {"files": ["res://assets/sounds/artisticdude/swing_heavy.wav"], "db": -6.0, "jitter": 0.03, "cooldown": 0.1},
	&"meteor_fall": {"files": ["res://assets/sounds/juhani_junkala_retro_512/comet_fall.wav"], "db": -10.0, "jitter": 0.0, "cooldown": 0.1},
	&"meteor_impact": {"files": ["res://assets/sounds/juhani_junkala_retro_512/comet_impact.wav"], "db": -4.0, "jitter": 0.05, "cooldown": 0.1},
	&"meteor_impact_big": {"files": ["res://assets/sounds/juhani_junkala_retro_512/comet_impact_big.wav"], "db": -3.0, "jitter": 0.04, "cooldown": 0.1},
	&"meteor_slam": {"files": ["res://assets/sounds/rubberduck/comet_impact_slam.ogg"], "db": -8.0, "jitter": 0.04, "cooldown": 0.1},
	&"meteor_hit": {"files": ["res://assets/sounds/juhani_junkala_retro_512/hammer_impact.wav"], "db": -4.0, "jitter": 0.05, "cooldown": 0.1},
	# --- Dash Strike ---
	## The burst itself: a short whoosh (pitched up by the player).
	&"dash": {"files": ["res://assets/sounds/rubberduck/comet_fall_whoosh.ogg"], "db": -5.0, "jitter": 0.06, "cooldown": 0.08},
	## The dash cutting through something on the way.
	&"dash_hit": {"files": [
		"res://assets/sounds/juhani_junkala_retro_512/hit_flesh_1.wav",
		"res://assets/sounds/juhani_junkala_retro_512/hit_flesh_2.wav"], "db": -4.0, "jitter": 0.08, "cooldown": 0.05},
	# --- Swords ---
	&"swing_blade": {"files": [
		"res://assets/sounds/juhani_junkala_retro_512/swing_blade_1.wav",
		"res://assets/sounds/juhani_junkala_retro_512/swing_blade_2.wav",
		"res://assets/sounds/juhani_junkala_retro_512/swing_blade_3.wav"], "db": -8.0, "jitter": 0.07, "cooldown": 0.04},
	&"swing_rapier": {"files": ["res://assets/sounds/artisticdude/swing_rapier.wav"], "db": -9.0, "jitter": 0.08, "cooldown": 0.04},
	&"swing_flame": {"files": ["res://assets/sounds/rubberduck/swing_flame.ogg"], "db": 4.0, "jitter": 0.06, "cooldown": 0.04},
	&"swing_heavy": {"files": ["res://assets/sounds/artisticdude/swing_heavy.wav"], "db": -6.0, "jitter": 0.05, "cooldown": 0.04},
	&"hit": {"files": [
		"res://assets/sounds/juhani_junkala_retro_512/hit_flesh_1.wav",
		"res://assets/sounds/juhani_junkala_retro_512/hit_flesh_2.wav"], "db": -6.0, "jitter": 0.08, "cooldown": 0.05},
	&"hit_heavy": {"files": ["res://assets/sounds/juhani_junkala_retro_512/hammer_impact.wav"], "db": -5.0, "jitter": 0.05, "cooldown": 0.05},
	## Her blade glancing off armor (she recoils).
	&"deflect": {"files": ["res://assets/sounds/rubberduck/hit_armor_deflect.ogg"], "db": 0.0, "jitter": 0.06, "cooldown": 0.1},
	&"switch_sword": {"files": ["res://assets/sounds/tap.wav"], "db": -10.0, "jitter": 0.05, "cooldown": 0.05},
	# --- Harm ---
	&"hurt": {"files": ["res://assets/sounds/hurt.wav"], "db": -5.0, "jitter": 0.05, "cooldown": 0.15},
	## Fully absorbed by her armor: a clank, no harm.
	&"block": {"files": ["res://assets/sounds/rubberduck/hit_armor_deflect.ogg"], "db": -2.0, "jitter": 0.06, "cooldown": 0.15},
	&"chill": {"files": ["res://assets/sounds/rubberduck/ice_hit_small.ogg"], "db": -6.0, "jitter": 0.05, "cooldown": 0.3},
	&"jolt": {"files": ["res://assets/sounds/rubberduck/thunder_crack.ogg"], "db": -10.0, "jitter": 0.05, "cooldown": 0.3},
	&"death": {"files": ["res://assets/sounds/hurt.wav"], "db": -3.0, "jitter": 0.0, "cooldown": 0.5},
	## Her armor bursting apart in the death sequence.
	&"armor_burst": {"files": ["res://assets/sounds/rubberduck/hit_armor_break.ogg"], "db": 0.0, "jitter": 0.0, "cooldown": 0.5},
	# --- Gains ---
	&"heal": {"files": ["res://assets/sounds/juhani_junkala_retro_512/heal.wav"], "db": -6.0, "jitter": 0.03, "cooldown": 0.1},
	## Coin grabbed. Pickup.play_coin_sound() raises the pitch through a quick combo.
	&"coin": {"files": ["res://assets/sounds/coin.wav"], "db": -9.0, "jitter": 0.02, "cooldown": 0.04},
	&"power_up": {"files": ["res://assets/sounds/power_up.wav"], "db": -4.0, "jitter": 0.0, "cooldown": 0.2},
	## A mana drop, or the trickle refilling a shot (played lower).
	&"mana": {"files": ["res://assets/sounds/juhani_junkala_retro_512/heal.wav"], "db": -9.0, "jitter": 0.03, "cooldown": 0.05},
	# --- Magigonne (scripts/combat/magigonne.gd) ---
	## The hand cannon's boom: the explosion, pitched up into a short crack.
	&"magigonne_fire": {"files": ["res://assets/sounds/explosion.wav"], "db": -11.0, "jitter": 0.06, "cooldown": 0.05},
	## Trigger pulled on an empty bar.
	&"magigonne_empty": {"files": ["res://assets/sounds/tap.wav"], "db": -8.0, "jitter": 0.0, "cooldown": 0.15},
	&"magigonne_bounce": {"files": ["res://assets/sounds/tap.wav"], "db": -12.0, "jitter": 0.1, "cooldown": 0.04},
	&"magigonne_hit": {"files": ["res://assets/sounds/yo_frankie/projectile_splat.wav"], "db": -6.0, "jitter": 0.08, "cooldown": 0.04},
	# --- enemies ---
	# Positional (Sfx.play_at via Enemy.play_sfx), a few dB under her sounds.
	# Short cooldowns so a swarm (cinder mites) or a pair of shockwaves sounds once.
	# Her sword's hit and her recoil's "deflect" already cover slashes landing
	# and clinking off armor, so enemies add no hurt/clink of their own.
	## A wind-up telegraph: something swelling (spitter, hopper crouch, leech rearing).
	&"enemy_swell": {"files": ["res://assets/sounds/juhani_junkala_enemies/swell.wav"], "db": -9.0, "jitter": 0.06, "cooldown": 0.1},
	## Low growl telegraph (charger shudder, draugr rearing, einherjar drawing back).
	&"enemy_growl": {"files": ["res://assets/sounds/juhani_junkala_enemies/growl.wav"], "db": -6.0, "jitter": 0.06, "cooldown": 0.15},
	## Rumble in the wood (root serpent's dust spill).
	&"enemy_rumble": {"files": ["res://assets/sounds/juhani_junkala_enemies/rumble.wav"], "db": -7.0, "jitter": 0.06, "cooldown": 0.15},
	## Screech telegraphs: gale hawk rising, dropper shaking loose (small).
	&"enemy_screech": {"files": ["res://assets/sounds/juhani_junkala_enemies/screech.wav"], "db": -11.0, "jitter": 0.05, "cooldown": 0.2},
	&"enemy_screech_small": {"files": ["res://assets/sounds/juhani_junkala_enemies/screech_small.wav"], "db": -14.0, "jitter": 0.08, "cooldown": 0.15},
	&"enemy_hop": {"files": ["res://assets/sounds/juhani_junkala_enemies/hop.wav"], "db": -10.0, "jitter": 0.08, "cooldown": 0.08},
	## Cinder mite skitter-hop: tiny and quiet, with a cooldown so the swarm doesn't stack.
	&"enemy_hop_small": {"files": ["res://assets/sounds/juhani_junkala_enemies/hop_small.wav"], "db": -17.0, "jitter": 0.12, "cooldown": 0.15},
	## A quick lunge or lash (climber, sap leech).
	&"enemy_lunge": {"files": ["res://assets/sounds/juhani_junkala_enemies/lunge.wav"], "db": -8.0, "jitter": 0.08, "cooldown": 0.08},
	&"enemy_dash": {"files": ["res://assets/sounds/rubberduck/comet_fall_whoosh.ogg"], "db": -12.0, "jitter": 0.06, "cooldown": 0.15},
	&"enemy_swoop": {"files": ["res://assets/sounds/rubberduck/flyer_swoop.ogg"], "db": -8.0, "jitter": 0.08, "cooldown": 0.1},
	&"enemy_dive": {"files": ["res://assets/sounds/juhani_junkala_enemies/dive.wav"], "db": -10.0, "jitter": 0.04, "cooldown": 0.2},
	&"enemy_fall": {"files": ["res://assets/sounds/juhani_junkala_enemies/fall.wav"], "db": -11.0, "jitter": 0.06, "cooldown": 0.15},
	&"enemy_roll": {"files": ["res://assets/sounds/juhani_junkala_enemies/roll.wav"], "db": -11.0, "jitter": 0.05, "cooldown": 0.2},
	## Body hitting the world: charger into a wall, beetle bounce, hawk beak-first, dropper landing.
	&"enemy_thud": {"files": ["res://assets/sounds/juhani_junkala_enemies/thud.wav"], "db": -7.0, "jitter": 0.08, "cooldown": 0.08},
	&"enemy_slam": {"files": ["res://assets/sounds/juhani_junkala_enemies/slam.wav"], "db": -4.0, "jitter": 0.04, "cooldown": 0.2},
	## A draugr shockwave crumbling away at a wall or ledge.
	&"enemy_crumble": {"files": ["res://assets/sounds/juhani_junkala_enemies/crumble.wav"], "db": -14.0, "jitter": 0.1, "cooldown": 0.1},
	&"enemy_blade": {"files": ["res://assets/sounds/artisticdude/swing_heavy.wav"], "db": -8.0, "jitter": 0.05, "cooldown": 0.08},
	&"enemy_spit": {"files": ["res://assets/sounds/rubberduck/enemy_spit.ogg"], "db": -7.0, "jitter": 0.08, "cooldown": 0.08},
	&"enemy_splat": {"files": ["res://assets/sounds/yo_frankie/projectile_splat.wav"], "db": -9.0, "jitter": 0.1, "cooldown": 0.06},
	## Contact damage that landed (physical touch only; elemental touch uses her chill/jolt).
	&"enemy_bite": {"files": [
		"res://assets/sounds/artisticdude/enemy_bite_1.wav",
		"res://assets/sounds/artisticdude/enemy_bite_2.wav"], "db": -8.0, "jitter": 0.06, "cooldown": 0.2},
	&"enemy_armor_break": {"files": ["res://assets/sounds/rubberduck/hit_armor_break.ogg"], "db": -3.0, "jitter": 0.05, "cooldown": 0.1},
	&"enemy_freeze": {"files": ["res://assets/sounds/rubberduck/ice_hit_small.ogg"], "db": -6.0, "jitter": 0.06, "cooldown": 0.08},
	&"enemy_shatter": {"files": ["res://assets/sounds/rubberduck/ice_shatter.ogg"], "db": -4.0, "jitter": 0.05, "cooldown": 0.08},
	&"enemy_ignite": {"files": ["res://assets/sounds/rubberduck/fire_burst.ogg"], "db": -9.0, "jitter": 0.06, "cooldown": 0.12},
	&"enemy_shock": {"files": ["res://assets/sounds/rubberduck/thunder_crack.ogg"], "db": -16.0, "jitter": 0.06, "cooldown": 0.2},
	&"enemy_die": {"files": [
		"res://assets/sounds/juhani_junkala_enemies/poof_1.wav",
		"res://assets/sounds/juhani_junkala_enemies/poof_2.wav"], "db": -8.0, "jitter": 0.1, "cooldown": 0.06},
	## Death cry of the big mobs (wider than a tile: draugr, einherjar, gale ray).
	&"enemy_die_big": {"files": ["res://assets/sounds/juhani_junkala_enemies/die_big.wav"], "db": -9.0, "jitter": 0.04, "cooldown": 0.2},
}

## Realm id (LevelRegistry) -> footstep id. Anything else walks on stone.
const FOOTSTEPS := {
	"hel": &"step_stone",
	"yggdrasil": &"step_bark",
	"sky": &"step_cloud",
	"valhalla": &"step_metal",
}

## Sword element (Hit.Element) -> swing / hit ids, unless the sword names its own.
const SWINGS := {
	Hit.Element.NONE: &"swing_blade",
	Hit.Element.ICE: &"swing_rapier",
	Hit.Element.FIRE: &"swing_flame",
	Hit.Element.THUNDER: &"swing_heavy",
}
const HITS := {
	Hit.Element.THUNDER: &"hit_heavy",
}

## Non-positional voices (the player's sounds); the oldest is stolen when full.
@export var voices: int = 12
## Positional voices for `play_at`.
@export var voices_2d: int = 6
## Audio bus the effects play on (falls back to Master if it doesn't exist).
@export var bus: StringName = &"SFX"

var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []
var _next := 0
var _next_2d := 0
var _streams := {}      # id -> Array[AudioStream] (loaded lazily)
var _last_time := {}    # id -> seconds of the last start
var _last_variant := {} # id -> index of the last clip
var _by_id := {}        # id -> the player that last played it (for stop())
var _audible := false
var _realm_scene: Node
var _realm := ""
## User SFX volume, linear 0..1 (applied to the SFX bus).
var _user_linear: float = 1.0

## Shared with MusicPlayer: one file, one key per bus.
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const SETTINGS_KEY := "sfx_volume"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs (CI, agents' checks) have no audio out; bookkeeping still runs.
	_audible = DisplayServer.get_name() != "headless"
	var bus_name := bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	if bus_name != bus:
		push_warning("Sfx: no '%s' audio bus, using Master" % bus)
	for i in voices:
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		add_child(p)
		_players.append(p)
	for i in voices_2d:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = bus_name
		p2.max_distance = 600.0
		add_child(p2)
		_players_2d.append(p2)
	_load_volume()


## Release the streams before the engine tears down, so quitting doesn't
## report leaked playbacks.
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	for p2: AudioStreamPlayer2D in _players_2d:
		p2.stop()
		p2.stream = null
	_streams.clear()


# --- Volume ------------------------------------------------------------------------

## User SFX volume, linear 0..1 (0 mutes). Saved to `user://settings.cfg` as
## `[audio] sfx_volume`, next to MusicPlayer's `music_volume`.
func set_sfx_volume(linear: float, save: bool = true) -> void:
	_user_linear = clampf(linear, 0.0, 1.0)
	_apply_volume()
	if save:
		_save_volume()
	volume_changed.emit(_user_linear)


## User SFX volume, linear 0..1.
func get_sfx_volume() -> float:
	return _user_linear


func _apply_volume() -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return  # never turn Master down for it: that would take the music too
	AudioServer.set_bus_mute(index, _user_linear <= 0.0)
	if _user_linear > 0.0:
		AudioServer.set_bus_volume_db(index, linear_to_db(_user_linear))


func _load_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_user_linear = clampf(float(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, 1.0)), 0.0, 1.0)
	_apply_volume()


func _save_volume() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep MusicPlayer's key and anything else stored here
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, _user_linear)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Sfx: couldn't save %s (error %d)" % [SETTINGS_PATH, err])


# --- Playing ---------------------------------------------------------------------

## Plays `id` (non-positional). `pitch_jitter` < 0 uses the sound's own;
## `volume_db` is added to its level; `pitch` scales it. Returns false when the
## id is unknown or still on cooldown.
func play(id: StringName, pitch_jitter: float = -1.0, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	var stream := _pick(id)
	if stream == null:
		return false
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	_start(p, id, stream, pitch_jitter, volume_db, pitch)
	return true


## Plays `id` at a world position (panned and attenuated by the camera).
func play_at(id: StringName, pos: Vector2, pitch_jitter: float = -1.0, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	var stream := _pick(id)
	if stream == null:
		return false
	var p := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _players_2d.size()
	p.global_position = pos
	_start(p, id, stream, pitch_jitter, volume_db, pitch)
	return true


## Plays `id` after `seconds` of real time (keeps going while paused).
func play_after(id: StringName, seconds: float, volume_db: float = 0.0) -> void:
	get_tree().create_timer(seconds, true, false, true).timeout.connect(play.bind(id, -1.0, volume_db))


## Stops the last playback of `id` (e.g. the meteor's fall when she lands).
func stop(id: StringName) -> void:
	var p: Node = _by_id.get(id)
	# Only if that voice hasn't been reused for another sound since.
	if p and is_instance_valid(p) and p.get("stream") in streams(id):
		p.call("stop")
	_by_id.erase(id)


# --- Picking ids from game state ----------------------------------------------------

## Footstep id for the realm of the current scene.
func footstep_id() -> StringName:
	var scene := get_tree().current_scene
	if scene != _realm_scene:
		_realm_scene = scene
		var info := LevelRegistry.find_by_path(scene.scene_file_path) if scene else {}
		_realm = info.get("realm", "")
	return FOOTSTEPS.get(_realm, &"step_stone")


## Swing id for a sword: its own `swing_sound` if set, else by element.
func swing_id(data: WeaponData) -> StringName:
	if data == null:
		return &"swing_blade"
	if data.swing_sound != &"":
		return data.swing_sound
	return SWINGS.get(data.element, &"swing_blade")


## Hit-landed id for a sword: its own `hit_sound` if set, heavy for heavy
## hitters, else by element.
func hit_id(data: WeaponData) -> StringName:
	if data == null:
		return &"hit"
	if data.hit_sound != &"":
		return data.hit_sound
	if data.heavy_hits:
		return &"hit_heavy"
	return HITS.get(data.element, &"hit")


## True if `id` is in the table.
func has(id: StringName) -> bool:
	return SOUNDS.has(id)


## Every clip of `id`, loaded (empty if unknown or unloadable).
func streams(id: StringName) -> Array:
	if not _streams.has(id):
		var list: Array[AudioStream] = []
		for path: String in SOUNDS.get(id, {}).get("files", []):
			var s := load(path) as AudioStream
			if s:
				list.append(s)
			else:
				push_error("Sfx: can't load %s for '%s'" % [path, id])
		_streams[id] = list
	return _streams[id]


# --- Internals ---------------------------------------------------------------------

func _pick(id: StringName) -> AudioStream:
	var info: Dictionary = SOUNDS.get(id, {})
	if info.is_empty():
		push_warning("Sfx: unknown sound '%s'" % id)
		return null
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_time.get(id, -100.0)) < float(info.get("cooldown", 0.0)):
		return null
	var list := streams(id)
	if list.is_empty():
		return null
	var i := randi() % list.size()
	if list.size() > 1 and i == _last_variant.get(id, -1):
		i = (i + 1) % list.size()
	_last_variant[id] = i
	_last_time[id] = now
	return list[i]


func _start(p: Node, id: StringName, stream: AudioStream, pitch_jitter: float, volume_db: float, pitch: float) -> void:
	var info: Dictionary = SOUNDS[id]
	var jitter: float = info.get("jitter", 0.0) if pitch_jitter < 0.0 else pitch_jitter
	p.set("stream", stream)
	p.set("volume_db", float(info.get("db", 0.0)) + volume_db)
	p.set("pitch_scale", maxf(0.05, pitch * (1.0 + randf_range(-jitter, jitter))))
	_by_id[id] = p
	if _audible:
		p.call("play")
	played.emit(id)
