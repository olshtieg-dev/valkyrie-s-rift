extends SceneTree
## Reach report for every generated level: how many feathers per airtime the
## climb to each exit and each side-route find asks for, per sword, first as
## flutters only, then with the Dash Strike (an air or upward dash also
## spends a feather; see ReachCheck).
##
##   godot --headless --script res://tools/reach_check.gd
##   godot --headless --script res://tools/reach_check.gd -- hel_01 sky_01
##
## Uses scripts/level/reach_check.gd (see there for what it does and doesn't
## count). Rooms use their seed overrides from the debug menu, if any.
## Generated rooms start at their start/south anchor, hand-built ones at their
## default spawn; goals are every LevelExit but the one beside the start, plus
## side-route finds.

const SWORDS := [
	"res://data/weapons/valkyrie_blade.tres",
	"res://data/weapons/ice_rapier.tres",
	"res://data/weapons/flame_greatsword.tres",
	"res://data/weapons/thunder_hammer.tres",
]
const MAX_FLUTTERS := 10


func _initialize() -> void:
	# Joypads attached to a dev box would otherwise feed the player input.
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(a, e)
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var registry: GDScript = load("res://scripts/level/level_registry.gd")
	var checker: GDScript = load("res://scripts/level/reach_check.gd")
	var swords: Array = SWORDS.map(func(p: String) -> Resource: return load(p))
	print("Feathers per airtime needed (-1 = not reachable with %d)." % MAX_FLUTTERS)
	print("Columns: %s, flutters only | the same with the dash.\n" % ", ".join(swords.map(func(w: Resource) -> String: return w.display_name)))
	for entry: Dictionary in registry.LEVELS:
		if not only.is_empty() and not only.has(entry["id"]):
			continue
		var scene: PackedScene = load(entry["path"])
		var level: Node = scene.instantiate()
		root.add_child(level)
		current_scene = level
		await physics_frame
		await physics_frame
		var gen: Node = level.get("generator")
		if gen == null:
			level.queue_free()
			await process_frame
			continue
		# Entry: the generator's start/south anchor, else the room's default
		# spawn (hand-built rooms place SpawnPoints).
		var start := Vector2.INF
		for key in ["start", "south"]:
			if gen.anchors.has(key):
				start = gen.anchors[key]["spawn"]
				break
		if start == Vector2.INF and not level.spawns.is_empty():
			start = level.get_spawn_position(level.default_spawn)
		if start == Vector2.INF:
			print("%s: no spawn point, skipped" % entry["id"])
			level.queue_free()
			await process_frame
			continue
		# Goals: every live LevelExit, except the one she enters by (within a
		# few tiles of the spawn).
		var goals := {}
		for node in level.find_children("*", "Area2D", true, false):
			if not node.has_method("set_rect") or node.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			var size: Vector2 = node.size
			var r := Rect2(level.to_local(node.global_position) - size / 2.0, size)
			if r.grow(48.0).has_point(start):
				continue
			var label: String = node.anchor if node.anchor != "" else String(node.target_level)
			goals["exit %s" % (label if label != "" else String(node.name))] = r
		var points := {}
		for node in level.get_children():
			if String(node.name).begins_with("SideRouteFind"):
				var what := "heart"
				if node.get_script().resource_path.ends_with("/wings.gd"):
					what = "wings"
				elif node.get("ability"):
					what = String(node.ability)
				elif node.get("weapon"):
					what = node.weapon.display_name
				elif node.get("armor"):
					what = node.armor.display_name
				points["find %s" % what] = node.position
		var rows := {}
		var t0 := Time.get_ticks_msec()
		var cells := 0
		for dash in [false, true]:
			for sword: Resource in swords:
				var check: RefCounted = checker.new(gen, sword, MAX_FLUTTERS, dash)
				var result: Dictionary = check.run(start, goals, points)
				cells = maxi(cells, result["_cells"].size())
				for key: String in goals.keys() + points.keys():
					if not rows.has(key):
						rows[key] = []
					rows[key].append(result[key])
		print("%s  %s  (%d floor cells reached, %.1fs)" % [entry["id"], entry["name"], cells, (Time.get_ticks_msec() - t0) / 1000.0])
		if rows.is_empty():
			print("    (no exits or finds)")
		for key: String in rows:
			var nums: Array = rows[key].map(func(n: int) -> String: return "%3d" % n)
			var half := nums.size() / 2
			print("    %-28s %s  |%s" % [key, "  ".join(nums.slice(0, half)), "  ".join(nums.slice(half))])
		level.queue_free()
		await process_frame
	quit()
