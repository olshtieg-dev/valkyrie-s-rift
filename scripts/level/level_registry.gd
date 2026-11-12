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
	# Optional per level: "find" = a WeaponData/ArmorData on a pedestal at the end
	# of one side route, "heart_container" for a HeartVessel (+1 heart), or
	# "ability:<id>" for an AbilityShrine (e.g. "ability:dash"). A list of finds
	# puts each at the end of its own side route, best detour first.
	# "gate" = "vine" / "slime" plugs every other side room (never a find's).
	{"id": "hel_01", "name": "The Pit", "realm": "hel", "path": "res://levels/hel/hel_01_the_pit.tscn",
			"find": ["res://data/weapons/ice_rapier.tres", "ability:dash"], "gate": "slime"},
	{"id": "hel_02", "name": "Brimstone Ascent", "realm": "hel", "path": "res://levels/hel/hel_02_brimstone_ascent.tscn",
			"find": "res://data/weapons/flame_greatsword.tres"},
	# Hel test run: the 13 rooms of docs/realms/hel.md (H01-H13).
	{"id": "hel_h01", "name": "Where She Fell", "realm": "hel", "path": "res://levels/hel/h01_where_she_fell.tscn"},
	{"id": "hel_h02", "name": "The Pit", "realm": "hel", "path": "res://levels/hel/h02_the_pit.tscn"},
	{"id": "hel_h03", "name": "Frozen Hollow", "realm": "hel", "path": "res://levels/hel/h03_frozen_hollow.tscn",
			"find": "res://data/weapons/ice_rapier.tres"},
	{"id": "hel_h04", "name": "Ember Hub", "realm": "hel", "path": "res://levels/hel/h04_ember_hub.tscn"},
	{"id": "hel_h05", "name": "Cinder Hall", "realm": "hel", "path": "res://levels/hel/h05_cinder_hall.tscn"},
	{"id": "hel_h06", "name": "Ash Chimney", "realm": "hel", "path": "res://levels/hel/h06_ash_chimney.tscn",
			"find": "ability:dash"},
	{"id": "hel_h07", "name": "Sealed Cache", "realm": "hel", "path": "res://levels/hel/h07_sealed_cache.tscn",
			"find": "res://data/armor/ember_mail.tres"},
	{"id": "hel_h08", "name": "Brimstone Ascent", "realm": "hel", "path": "res://levels/hel/h08_brimstone_ascent.tscn"},
	{"id": "hel_h09", "name": "Ember Forge", "realm": "hel", "path": "res://levels/hel/h09_ember_forge.tscn",
			"find": "res://data/weapons/flame_greatsword.tres"},
	{"id": "hel_h10", "name": "Draugr Hall", "realm": "hel", "path": "res://levels/hel/h10_draugr_hall.tscn",
			"find": "heart_container"},
	{"id": "hel_h11", "name": "Modgud's Rest", "realm": "hel", "path": "res://levels/hel/h11_modguds_rest.tscn"},
	{"id": "hel_h12", "name": "Garmr's Den", "realm": "hel", "path": "res://levels/hel/h12_garmrs_den.tscn"},
	{"id": "hel_h13", "name": "Hel's Breach", "realm": "hel", "path": "res://levels/hel/h13_hels_breach.tscn"},
	{"id": "ygg_01", "name": "Roots", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_01_roots.tscn",
			"gate": "vine"},
	{"id": "ygg_02", "name": "Hollow Trunk", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_02_hollow_trunk.tscn",
			"find": "heart_container"},
	{"id": "ygg_03", "name": "Canopy", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_03_canopy.tscn",
			"find": "res://data/armor/swan_mantle.tres"},
	{"id": "sky_01", "name": "Cloud Steps", "realm": "sky", "path": "res://levels/sky/sky_01_cloud_steps.tscn",
			"find": "heart_container"},
	{"id": "val_01", "name": "Gate of Valhalla", "realm": "valhalla", "path": "res://levels/valhalla/val_01_gate.tscn"},
]


static func find(level_id: String) -> Dictionary:
	for level: Dictionary in LEVELS:
		if level["id"] == level_id:
			return level
	return {}


static func find_by_path(path: String) -> Dictionary:
	for level: Dictionary in LEVELS:
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
