class_name EnemyCatalog
extends RefCounted
## Every mob type, for the debug menu's spawner and as a reference for level
## design. Any Enemy scene also works on its own: drag it into a level, or add
## it to a LevelGenerator's enemy_scenes.

const ENEMIES := [
	{"id": "crawler", "name": "Crawler", "path": "res://scenes/enemies/crawler.tscn",
		"move": "Patrols floors, turns at walls and ledges. 1 hit."},
	{"id": "hopper", "name": "Hopper", "path": "res://scenes/enemies/hopper.tscn",
		"move": "Crouches, then leaps at you. Rests after landing. 2 hits."},
	{"id": "charger", "name": "Charger", "path": "res://scenes/enemies/charger.tscn",
		"move": "ARMORED: slashes clink off; meteor strike (down + attack in the air) shatters it. Shudders, then dashes along its ledge; stunned by walls (double damage)."},
	{"id": "flyer", "name": "Flyer", "path": "res://scenes/enemies/flyer.tscn",
		"move": "Hovers, pulls back, swoops at you, drifts home. Guards open shafts. 1 hit."},
	{"id": "dropper", "name": "Dropper", "path": "res://scenes/enemies/dropper.tscn",
		"move": "Hangs from ceilings, falls when you pass under, then crawls. 1 hit."},
	{"id": "spitter", "name": "Spitter", "path": "res://scenes/enemies/spitter.tscn",
		"move": "Rooted. Swells, spits a glob. Swing at the glob to bat it back. 2 hits."},
	{"id": "climber", "name": "Climber", "path": "res://scenes/enemies/climber.tscn",
		"move": "Crawls up and down walls, lunges when you're level with it. 2 hits."},
]


static func find(enemy_id: String) -> Dictionary:
	for e: Dictionary in ENEMIES:
		if e["id"] == enemy_id:
			return e
	return {}
