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
	{"id": "cinder_mite", "name": "Cinder Mite", "path": "res://scenes/enemies/cinder_mite.tscn",
		"move": "Hel. Tiny living ember; one placed = a swarm of 3. Skitters and hops at you; burns on touch. 1 hit each."},
	{"id": "draugr", "name": "Draugr", "path": "res://scenes/enemies/draugr.tscn",
		"move": "Hel, 32x36. Plods closer, rears up, slams: rubble crests run along the floor both ways (jump them). Winded after. Barely flinches. 5 hits."},
	{"id": "bark_beetle", "name": "Bark Beetle", "path": "res://scenes/enemies/bark_beetle.tscn",
		"move": "Yggdrasil. Tucks in, then rolls at you; rolling it's ARMORED and rolls off ledges down shafts. Dizzy after (double damage); meteor cracks it mid-roll. 2 hits."},
	{"id": "sap_leech", "name": "Sap Leech", "path": "res://scenes/enemies/sap_leech.tscn",
		"move": "Yggdrasil wall. Inches along the wall to stay level with you, rears back, lashes out across the shaft. Never lets go. 2 hits."},
	{"id": "root_serpent", "name": "Root Serpent", "path": "res://scenes/enemies/root_serpent.tscn",
		"move": "Yggdrasil ceiling (snaps to the nearest surface). Dust spills from its burrow, then a long segmented body lunges out at you, sways, pulls back. Every segment hurts; a hit anywhere counts. 4 hits."},
	{"id": "gale_ray", "name": "Gale Ray", "path": "res://scenes/enemies/gale_ray.tscn",
		"move": "Sky, 32 wide and flat. Glides a level lane, gently bobbing. Its back is a platform you can ride; the underside stings. 3 hits."},
	{"id": "gale_hawk", "name": "Gale Hawk", "path": "res://scenes/enemies/gale_hawk.tscn",
		"move": "Sky. Patrols high; when you're below it, rises over you and stoops straight down. On a miss it sticks in the ground, dazed (double damage). 2 hits."},
	{"id": "einherjar", "name": "Einherjar", "path": "res://scenes/enemies/einherjar.tscn",
		"move": "Valhalla. SHIELD: slashes from the front clink off. Turns slowly: jump over and strike its back, or meteor it from above; a heavy hit smashes the shield. Lunges up close; holds its ledge. 3 hits."},
]


static func find(enemy_id: String) -> Dictionary:
	for e: Dictionary in ENEMIES:
		if e["id"] == enemy_id:
			return e
	return {}
