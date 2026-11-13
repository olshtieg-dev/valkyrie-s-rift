class_name LevelRegistry
extends RefCounted
## Single list of every playable room. The debug room and debug menu build
## their portals/buttons from this, and LevelManager resolves ids through it.
## Add a level here and it shows up everywhere.

const REALMS := [
	{"id": "debug", "name": "Debug", "color": Color(0.62, 0.64, 0.72), "music": "res://assets/music/realms/workshop.ogg"},
	{"id": "hel", "name": "Hel", "color": Color(0.92, 0.36, 0.2), "music": "res://assets/music/realms/hel.ogg"},
	{"id": "yggdrasil", "name": "Yggdrasil", "color": Color(0.45, 0.78, 0.36), "music": "res://assets/music/realms/yggdrasil.ogg"},
	{"id": "sky", "name": "Sky Realm", "color": Color(0.62, 0.8, 1.0), "music": "res://assets/music/realms/sky.ogg"},
	{"id": "valhalla", "name": "Valhalla", "color": Color(0.96, 0.82, 0.38), "music": "res://assets/music/realms/valhalla.ogg"},
]

const LEVELS := [
	{"id": "debug_room", "name": "Debug Room", "realm": "debug", "path": "res://levels/debug/debug_room.tscn"},
	{"id": "prototype", "name": "Prototype", "realm": "debug", "path": "res://game.tscn"},
	{"id": "magigonne_range", "name": "Magigonne Range", "realm": "debug", "path": "res://levels/debug/magigonne_range.tscn"},
	# Optional per level: "find" = a WeaponData/ArmorData on a pedestal at the end
	# of one side route, "heart_container" for a HeartVessel (+1 heart), "wings"
	# for a WingFeather (+1 flutter per airtime, scripts/wings.gd), or
	# "ability:<id>" for an AbilityShrine (e.g. "ability:dash"). A list of finds
	# puts each at the end of its own side route, best detour first.
	# "path_find" (same strings, one or a list) instead lies on the main path,
	# on the floor beside the room's entrance spawn: for what the climb itself
	# hands her, never for side-route rewards.
	# She starts unarmed with broken wings (GameManager.new_climb_state): the
	# Valkyrie Blade is hel_02's path_find, and hel_h08's two path_find feathers
	# mend her wings (Player.WINGS_FEATHERS: the sword's own flutters, the
	# blade's 2). Six more wing feathers in side routes (Hel 3, Yggdrasil 2,
	# Sky 1), +1 flutter each, take the blade's 2 to Player.FLUTTER_CAP (8)
	# before Valhalla.
	# "gate" = "vine" / "slime" plugs every other side room (never a find's).
	# "secrets" = how many hidden pockets to carve into the rock (coins inside),
	# "secret_style" = "false" (walk-through fake rock), "cracked" (break it with
	# a sword) or "mixed" (default), "secret_find" = finds (same strings, one or
	# a list) hidden in the first pockets instead of coins. Secrets don't change
	# the rest of the room's layout. Unarmed rooms want "false" (no sword to
	# break cracked rock).
	# Hel, in play order (docs/realms/hel.md): H01 -> hel_02 -> H08 -> H02 -> ... -> H13.
	# Detours follow the room they branch from.
	{"id": "hel_h01", "name": "Where She Fell", "realm": "hel", "path": "res://levels/hel/h01_where_she_fell.tscn",
			"secrets": 1, "secret_style": "false"},
	{"id": "hel_02", "name": "Brimstone Ascent", "realm": "hel", "path": "res://levels/hel/hel_02_brimstone_ascent.tscn",
			"find": "wings", "path_find": "res://data/weapons/valkyrie_blade.tres", "secrets": 1, "secret_style": "false"},
	{"id": "hel_h08", "name": "Brimstone Depths", "realm": "hel", "path": "res://levels/hel/h08_brimstone_ascent.tscn",
			"path_find": ["wings", "wings"], "secrets": 2},
	{"id": "hel_h09", "name": "Ember Forge", "realm": "hel", "path": "res://levels/hel/h09_ember_forge.tscn",
			"find": "res://data/weapons/flame_greatsword.tres"},
	{"id": "hel_h02", "name": "The Pit", "realm": "hel", "path": "res://levels/hel/h02_the_pit.tscn",
			"secrets": 2},
	{"id": "hel_h03", "name": "Frozen Hollow", "realm": "hel", "path": "res://levels/hel/h03_frozen_hollow.tscn",
			"find": "res://data/weapons/ice_rapier.tres"},
	{"id": "hel_h04", "name": "Ember Hub", "realm": "hel", "path": "res://levels/hel/h04_ember_hub.tscn",
			"secrets": 2},
	{"id": "hel_h05", "name": "Cinder Hall", "realm": "hel", "path": "res://levels/hel/h05_cinder_hall.tscn",
			"find": "wings", "secrets": 1},
	{"id": "hel_h06", "name": "Ash Chimney", "realm": "hel", "path": "res://levels/hel/h06_ash_chimney.tscn",
			"find": "ability:dash", "secrets": 1},
	{"id": "hel_h07", "name": "Sealed Cache", "realm": "hel", "path": "res://levels/hel/h07_sealed_cache.tscn",
			"find": "res://data/armor/ember_mail.tres"},
	{"id": "hel_h10", "name": "Draugr Hall", "realm": "hel", "path": "res://levels/hel/h10_draugr_hall.tscn",
			"find": "heart_container", "secrets": 2},
	{"id": "hel_h11", "name": "Modgud's Rest", "realm": "hel", "path": "res://levels/hel/h11_modguds_rest.tscn"},
	{"id": "hel_h12", "name": "Garmr's Den", "realm": "hel", "path": "res://levels/hel/h12_garmrs_den.tscn"},
	{"id": "hel_h13", "name": "Hel's Breach", "realm": "hel", "path": "res://levels/hel/h13_hels_breach.tscn",
			"find": "wings", "secrets": 1},
	# Off the main path: the old Pit test level (debug warp only; its exit leads into hel_02).
	{"id": "hel_01", "name": "The Pit", "realm": "hel", "path": "res://levels/hel/hel_01_the_pit.tscn",
			"find": ["res://data/weapons/ice_rapier.tres", "ability:dash"], "gate": "slime"},
	{"id": "ygg_01", "name": "Roots", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_01_roots.tscn",
			"find": "wings", "gate": "vine"},
	{"id": "ygg_02", "name": "Hollow Trunk", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_02_hollow_trunk.tscn",
			"find": "heart_container"},
	{"id": "ygg_03", "name": "Canopy", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_03_canopy.tscn",
			"find": ["res://data/armor/swan_mantle.tres", "wings"]},
	{"id": "sky_01", "name": "Cloud Steps", "realm": "sky", "path": "res://levels/sky/sky_01_cloud_steps.tscn",
			"find": ["heart_container", "wings"]},
	{"id": "val_01", "name": "Gate of Valhalla", "realm": "valhalla", "path": "res://levels/valhalla/val_01_gate.tscn"},
]


## Searches the main game's LEVELS and then every level pack.
static func find(level_id: String) -> Dictionary:
	for level: Dictionary in LEVELS + pack_levels():
		if level["id"] == level_id:
			return level
	return {}


static func find_by_path(path: String) -> Dictionary:
	for level: Dictionary in LEVELS + pack_levels():
		if level["path"] == path:
			return level
	return {}


static func realm(realm_id: String) -> Dictionary:
	for r: Dictionary in REALMS:
		if r["id"] == realm_id:
			return r
	return {}


static func in_realm(realm_id: String) -> Array:
	var out := []
	for level: Dictionary in LEVELS:
		if level["realm"] == realm_id:
			out.append(level)
	return out


## The finds of a registry entry as a list ("find" may be one or several).
static func finds_of(entry: Dictionary) -> Array:
	var f: Variant = entry.get("find", [])
	return (f as Array) if f is Array else [f]


## The main-path finds of a registry entry ("path_find"), as a list.
static func path_finds_of(entry: Dictionary) -> Array:
	var f: Variant = entry.get("path_find", [])
	return (f as Array) if f is Array else [f]


## The finds hidden in secret pockets ("secret_find"), as a list.
static func secret_finds_of(entry: Dictionary) -> Array:
	var f: Variant = entry.get("secret_find", [])
	return (f as Array) if f is Array else [f]


# --- level packs ----------------------------------------------------------------
# A pack is a folder under PACKS_DIR holding baked room scenes and a pack.json:
#   {"name": "...", "description": "...", "start": "<level id>",
#    "levels": [{"id": "...", "name": "...", "realm": "hel", "file": "room.tscn"}, ...]}
# "file" is relative to the pack folder. Pack rooms are baked (tiles, mobs and
# finds saved in the scene), so entries carry no "find"/"gate". Their ids must
# be unique across the game; exits inside a pack target the pack's own ids.
# Pack rooms resolve through find()/find_by_path() but stay out of LEVELS and
# in_realm(), so they don't crowd the debug room or the realm warp lists.
# First step toward loadable map packs (folders from user:// too, later).

const PACKS_DIR := "res://levels/packs"

static var _packs: Array = []
static var _packs_loaded := false


## Every pack found under PACKS_DIR: {"id" (folder name), "name",
## "description", "start", "levels": [registry-style entries with "pack"]}.
static func packs() -> Array:
	if not _packs_loaded:
		_packs_loaded = true
		_packs = _load_packs(PACKS_DIR)
	return _packs


## The rooms of every pack, as registry entries.
static func pack_levels() -> Array:
	var out := []
	for pack: Dictionary in packs():
		out.append_array(pack["levels"])
	return out


static func _load_packs(dir_path: String) -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var dirs := DirAccess.get_directories_at(dir_path)
	dirs.sort()
	for dir_name in dirs:
		var folder := "%s/%s" % [dir_path, dir_name]
		var text := FileAccess.get_file_as_string(folder + "/pack.json")
		var data: Variant = JSON.parse_string(text) if text != "" else null
		if not data is Dictionary:
			push_warning("LevelRegistry: skipping pack '%s' (missing or bad pack.json)." % folder)
			continue
		var levels := []
		for entry: Variant in data.get("levels", []):
			if not entry is Dictionary or not entry.has("id") or not entry.has("file"):
				continue
			var level: Dictionary = (entry as Dictionary).duplicate()
			level["path"] = "%s/%s" % [folder, level["file"]]
			level["pack"] = dir_name
			level["name"] = level.get("name", level["id"])
			level["realm"] = level.get("realm", "")
			levels.append(level)
		out.append({
			"id": dir_name,
			"name": data.get("name", dir_name),
			"description": data.get("description", ""),
			"start": data.get("start", levels[0]["id"] if not levels.is_empty() else ""),
			"levels": levels,
		})
	return out
