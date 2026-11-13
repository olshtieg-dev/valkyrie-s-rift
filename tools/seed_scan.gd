extends SceneTree
## Seed scan: sweeps one generated room over a range of seeds (optionally with
## some generator knobs overridden), generates each candidate, runs the reach
## checker on it and prints one row per seed: how many flutters per airtime
## each exit and find needs, how long the room took to load, and whether it
## meets a target. Use it to tune a room and to build pools of approved seeds.
##
##   godot --headless --script res://tools/seed_scan.gd -- hel_h06 --seeds 600-620
##   godot --headless --script res://tools/seed_scan.gd -- hel_h06 --seeds 600-640 \
##       platform_chance=0.1 platform_spacing=7 --want find=2
##   godot --headless --script res://tools/seed_scan.gd -- hel_h02 --seeds 1000-1030 \
##       --want north=1-2 --want east=0-1 --pass-only
##   godot --headless --script res://tools/seed_scan.gd -- hel_h01 --seeds 101,102,150 --unarmed --want all=0
##
## Arguments (after `--`):
##   <level_id>          a LevelRegistry id (required), e.g. hel_h06
##   --seeds A-B | A,B,C seeds to try (default: the scene's own level_seed)
##   knob=value          override a LevelGenerator export for every seed, e.g.
##                       platform_spacing=7 platform_chance=0.2 fill_ratio=0.5
##                       height=120 find_at_top=true (style takes its number)
##   --want KEY=MIN[-MAX] target, repeatable or comma-joined (north=1,find=2).
##                       KEY: an exit's anchor (north, east, west, south), `find`
##                       / `find2` (side-route finds, best first), `path` /
##                       `path2` (main-path finds), or `all` (every goal).
##                       A goal that's unreachable within the budget never meets one.
##   --max-flutters N    budget the checker tries up to (default 3; anything
##                       above it prints -1). Lower is faster.
##   --unarmed           bare-handed, no flutter (the opening rooms): 0 or -1
##   --pass-only         print only the seeds that meet every --want
##
## Reach is judged with the Valkyrie Blade (the starter), flutters only, no
## dash, from the room's entrance (its start/south anchor, else its default
## spawn; the exit she enters by isn't a goal). See scripts/level/reach_check.gd
## for what the checker does and doesn't count (it's conservative: no attack
## moves). Columns are labelled `exit <anchor>><target level>`, `find <what>`
## (side route) and `path <what>` (main-path find). `load` is the time to
## build the room (generation + level setup), `check` the reach check's time.
## Big rooms take 1-2 s to load and the check 5-30 s, so keep ranges modest;
## run several processes on disjoint ranges to go wider.
## Debug-menu seed overrides are ignored: the scan sets its own.

const BLADE := "res://data/weapons/valkyrie_blade.tres"


func _initialize() -> void:
	# Joypads attached to a dev box would otherwise feed the player input.
	for a in InputMap.get_actions():
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(a, e)
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var level_id := ""
	var seeds: Array[int] = []
	var knobs := {}
	var wants := {} # KEY -> Vector2i(min, max)
	var max_flutters := 3
	var unarmed := false
	var pass_only := false
	var i := 0
	while i < args.size():
		var a: String = args[i]
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--seeds":
				seeds = _parse_seeds(next)
				i += 1
			"--want":
				for part in next.split(",", false):
					var kv := part.split("=")
					var lo_hi := kv[1].split("-") if kv.size() == 2 else PackedStringArray()
					if lo_hi.is_empty() or not lo_hi[0].is_valid_int():
						_fail("bad --want '%s' (use KEY=MIN or KEY=MIN-MAX)" % part)
						return
					wants[kv[0]] = Vector2i(lo_hi[0].to_int(), lo_hi[lo_hi.size() - 1].to_int())
				i += 1
			"--max-flutters":
				max_flutters = next.to_int()
				i += 1
			"--unarmed":
				unarmed = true
			"--pass-only":
				pass_only = true
			_:
				if a.contains("="):
					var kv := a.split("=", true, 1)
					knobs[kv[0]] = kv[1]
				elif level_id == "":
					level_id = a
				else:
					_fail("unexpected argument '%s'" % a)
					return
		i += 1
	if level_id == "":
		_fail("give a level id, e.g. hel_h06 (see the header for usage)")
		return

	var registry: GDScript = load("res://scripts/level/level_registry.gd")
	var entry: Dictionary = registry.find(level_id)
	if entry.is_empty():
		_fail("no level '%s' in LevelRegistry" % level_id)
		return
	var checker: GDScript = load("res://scripts/level/reach_check.gd")
	var blade: Resource = load(BLADE)
	var scene: PackedScene = load(entry["path"])
	var manager: Node = root.get_node_or_null("LevelManager")

	print("%s  %s  %s" % [level_id, entry["name"], "unarmed, no flutter" if unarmed
			else "Valkyrie Blade, flutters 0-%d (-1 = more)" % max_flutters])
	if not knobs.is_empty():
		print("knobs: %s" % " ".join(knobs.keys().map(func(k: String) -> String: return "%s=%s" % [k, knobs[k]])))
	if not wants.is_empty():
		print("want:  %s" % " ".join(wants.keys().map(func(k: String) -> String:
				var w: Vector2i = wants[k]
				return "%s=%d" % [k, w.x] if w.x == w.y else "%s=%d-%d" % [k, w.x, w.y])))

	var passed: Array[int] = []
	var header_done := false
	var order: Array[String] = []
	var col_w := 6
	var tried := 0
	for s_i in maxi(seeds.size(), 1):
		var level: Node = scene.instantiate()
		var gen: Node = level.get_node_or_null("Generator")
		if gen == null:
			gen = level.get("generator")
		if gen == null:
			_fail("%s has no LevelGenerator" % level_id)
			level.free()
			return
		var bad := ""
		for k: String in knobs:
			if not k in gen:
				bad = k
				break
			gen.set(k, _typed(knobs[k], gen.get(k)))
		if bad != "":
			_fail("LevelGenerator has no export '%s'" % bad)
			level.free()
			return
		var seed_value: int = seeds[s_i] if not seeds.is_empty() else gen.level_seed
		gen.level_seed = seed_value
		if manager:
			manager.seed_overrides[level_id] = seed_value
		var t0 := Time.get_ticks_msec()
		root.add_child(level) # Level._ready generates the room
		current_scene = level
		var load_s := (Time.get_ticks_msec() - t0) / 1000.0
		await physics_frame
		await physics_frame

		var start := Vector2.INF
		var start_anchor := ""
		for key in ["start", "south"]:
			if gen.anchors.has(key):
				start = gen.anchors[key]["spawn"]
				start_anchor = key
				break
		if start == Vector2.INF and level.spawns.has(level.default_spawn):
			start = level.get_spawn_position(level.default_spawn)
			start_anchor = level.default_spawn
		if start == Vector2.INF:
			_fail("%s: no entrance spawn" % level_id)
			level.queue_free()
			return

		var goals := {}
		var points := {}
		for node in level.find_children("*", "Area2D", true, false):
			if not node.has_method("set_rect") or node.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			var size: Vector2 = node.size
			var r := Rect2(level.to_local(node.global_position) - size / 2.0, size)
			if node.anchor == start_anchor or r.grow(48.0).has_point(start):
				continue
			var label: String = node.anchor if node.anchor != "" else String(node.name)
			goals["exit %s>%s" % [label, node.target_level]] = r
		var keys := {} # goal name -> its --want key
		for g: String in goals:
			keys[g] = g.trim_prefix("exit ").get_slice(">", 0)
		var counts := {"find": 0, "path": 0}
		for node in level.get_children():
			var nm := String(node.name)
			var kind := "path" if nm.begins_with("PathFind") else "find" if nm.begins_with("SideRouteFind") else ""
			if kind == "":
				continue
			var what := "heart"
			if node.get_script().resource_path.ends_with("/wings.gd"):
				what = "wings"
			elif node.get("ability"):
				what = String(node.ability)
			elif node.get("weapon"):
				what = node.weapon.display_name
			elif node.get("armor"):
				what = node.armor.display_name
			counts[kind] += 1
			var key: String = kind if counts[kind] == 1 else "%s%d" % [kind, counts[kind]]
			var label := "%s %s" % [kind, what]
			if points.has(label):
				label += " %d" % counts[kind]
			points[label] = node.position
			keys[label] = key

		var check: RefCounted = checker.unarmed(gen) if unarmed else checker.new(gen, blade, max_flutters, false)
		var t1 := Time.get_ticks_msec()
		var result: Dictionary = check.run(start, goals, points)
		var check_s := (Time.get_ticks_msec() - t1) / 1000.0

		if not header_done:
			order.assign(goals.keys() + points.keys())
			for g in order:
				col_w = maxi(col_w, g.length())
			var cols := " ".join(order.map(func(g: String) -> String: return g.lpad(col_w)))
			print("%8s %5s %6s  %s  %s" % ["seed", "load", "check", cols, "target" if not wants.is_empty() else ""])
			header_done = true
		var ok := true
		for key: String in wants:
			var w: Vector2i = wants[key]
			var matched := false
			for g: String in keys:
				if key != "all" and keys[g] != key:
					continue
				matched = true
				var n: int = result.get(g, -1)
				if n < 0 or n < w.x or n > w.y:
					ok = false
			if not matched:
				ok = false
		var nums := " ".join(order.map(func(g: String) -> String: return str(result.get(g, "?")).lpad(col_w)))
		tried += 1
		if ok and not wants.is_empty():
			passed.append(seed_value)
		if not pass_only or (ok and not wants.is_empty()):
			print("%8d %4.1fs %5.1fs  %s  %s" % [seed_value, load_s, check_s, nums,
					("PASS" if ok else "-") if not wants.is_empty() else ""])
		level.queue_free()
		await process_frame
		await process_frame
	if not wants.is_empty():
		print("\n%d / %d seeds meet the target: %s" % [passed.size(), tried, ", ".join(passed.map(str))])
	quit()


## "A-B" (inclusive) or "A,B,C".
func _parse_seeds(s: String) -> Array[int]:
	var out: Array[int] = []
	for part in s.split(",", false):
		var ab := part.split("-", false)
		if ab.size() == 2 and ab[0].is_valid_int() and ab[1].is_valid_int():
			for n in range(ab[0].to_int(), ab[1].to_int() + 1):
				out.append(n)
		elif part.is_valid_int():
			out.append(part.to_int())
	return out


## A command-line string as the type of the export it overrides.
func _typed(text: String, current: Variant) -> Variant:
	match typeof(current):
		TYPE_BOOL:
			return text == "true" or text == "1"
		TYPE_INT:
			return text.to_int()
		TYPE_FLOAT:
			return text.to_float()
	return text


func _fail(msg: String) -> void:
	printerr("seed_scan: " + msg)
	quit(1)
