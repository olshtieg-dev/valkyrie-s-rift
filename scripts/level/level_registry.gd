class_name LevelRegistry
extends RefCounted
## Single list of every playable room. The debug room and debug menu build
## their portals/buttons from this, and LevelManager resolves ids through it.
## Add a level here and it shows up everywhere.

const REALMS := [
	{"id": "debug", "name": "Debug", "color": Color(0.62, 0.64, 0.72)},
	{"id": "hel", "name": "Hel", "color": Color(0.92, 0.36, 0.2)},
	{"id": "yggdrasil", "name": "Yggdrasil", "color": Color(0.45, 0.78, 0.36)},
	{"id": "sky", "name": "Sky Realm", "color": Color(0.62, 0.8, 1.0)},
	{"id": "valhalla", "name": "Valhalla", "color": Color(0.96, 0.82, 0.38)},
]

const LEVELS := [
	{"id": "debug_room", "name": "Debug Room", "realm": "debug", "path": "res://levels/debug/debug_room.tscn"},
	{"id": "prototype", "name": "Prototype", "realm": "debug", "path": "res://game.tscn"},
	{"id": "hel_01", "name": "The Pit", "realm": "hel", "path": "res://levels/hel/hel_01_the_pit.tscn"},
	{"id": "hel_02", "name": "Brimstone Ascent", "realm": "hel", "path": "res://levels/hel/hel_02_brimstone_ascent.tscn"},
	{"id": "ygg_01", "name": "Roots", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_01_roots.tscn"},
	{"id": "ygg_02", "name": "Hollow Trunk", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_02_hollow_trunk.tscn"},
	{"id": "ygg_03", "name": "Canopy", "realm": "yggdrasil", "path": "res://levels/yggdrasil/ygg_03_canopy.tscn"},
	{"id": "sky_01", "name": "Cloud Steps", "realm": "sky", "path": "res://levels/sky/sky_01_cloud_steps.tscn"},
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
