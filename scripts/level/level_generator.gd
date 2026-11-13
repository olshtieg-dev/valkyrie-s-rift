@tool
class_name LevelGenerator
extends Node
## Seeded room generator for general-purpose levels.
##
## Styles (the game is one vertical climb; the first four styles build upward):
##   CLIMB   - winding vertical shaft with side rooms branching off it (Hel, roots).
##   TRUNK   - Yggdrasil's hollow trunk: climb inside, or outside along branches,
##             crossing through knot-holes in the bark.
##   SKY     - zigzag of floating islands and cloud ledges, with side islands.
##   CAVERN  - cellular-automata caves joined by a guaranteed main path.
##   SHAFT   - plain vertical tube with alternating shelves.
##   ARENA   - enclosed combat room with tiered platforms (Valhalla).
##   SURFACE - horizontal heightmap; kept for short side areas, not main path.
##   WEAVE   - Yggdrasil's trunk built from interlocking sub-areas (chambers,
##             galleries, bark flanks) that the climb weaves in and out of.
##   MOUNTAIN- the roots climbed like a mountain: stepped slopes outside,
##             root tunnels and caves woven through the mass. See WeaveBuilder.
##
## Side rooms (CLIMB, TRUNK, SKY, WEAVE, MOUNTAIN) are the detours: each gets a few pickups and,
## if set, one `side_room_reward` (e.g. an ability) at its far end.
##
## Workflow: tweak exports, press "Generate" in the inspector to bake the result
## into the scene, then hand-edit the tiles. At runtime the generator only runs if
## the Ground layer is still empty (or the debug menu rerolls the seed).
##
## After generation, `anchors` holds each opening's arrival point and exit rect,
## which the Level uses to place spawns and snap LevelExits.

enum Style { CAVERN, SHAFT, SURFACE, ARENA, CLIMB, TRUNK, SKY, WEAVE, MOUNTAIN }

const AIR := 0
const SOLID := 1
const PLATFORM := 2
const HAZARD_TOP := 3
const HAZARD := 4

const TILE := 16
const SOURCE_ID := 0

@export var style: Style = Style.CAVERN
@export_range(24, 400) var width: int = 100
@export_range(18, 400) var height: int = 50
@export var level_seed: int = 1
@export var tile_theme: TileTheme
## Generate when the level loads if the Ground layer has no tiles yet.
@export var generate_at_runtime: bool = true

@export_tool_button("Generate", "Reload") var _generate_action := generate
@export_tool_button("Clear", "Clear") var _clear_action := clear
@export_tool_button("Save As New Level", "Save") var _save_action := save_as_new_level

@export_group("Openings")
## Side openings sit at a fraction of the height (0 = top, 1 = bottom);
## north/south openings at a fraction of the width. SURFACE ignores north/south
## and places west/east on the terrain.
@export var open_west: bool = false
@export_range(0.0, 1.0) var west_at: float = 0.7
@export var open_east: bool = false
@export_range(0.0, 1.0) var east_at: float = 0.7
@export var open_north: bool = false
@export_range(0.0, 1.0) var north_at: float = 0.5
@export var open_south: bool = false
@export_range(0.0, 1.0) var south_at: float = 0.5
## Plug the west/east exit's doorway with an element obstacle, so the room
## beyond waits for the right sword (see `side_room_gate`). Not for SURFACE.
@export var west_gate: Gate = Gate.NONE
@export var east_gate: Gate = Gate.NONE

@export_group("Cavern")
@export_range(0.3, 0.6) var fill_ratio: float = 0.46
@export_range(0, 8) var smoothing_passes: int = 5
## Extra winding tunnels beyond the main path, for loops and side pockets.
@export_range(0, 10) var extra_tunnels: int = 2

@export_group("Climb, Trunk & Sky")
## Main shaft width in tiles (CLIMB); width of each inner lane (WEAVE, MOUNTAIN).
@export_range(7, 21) var shaft_width: int = 11
## Chance to branch a side room at each candidate height (every ~6 rows).
@export_range(0.0, 1.0) var side_room_chance: float = 0.5
## Minimum rows between side rooms.
@export_range(8, 60) var side_room_spacing: int = 20
## Outer width of the tree (TRUNK). The rest of the width is open air outside.
@export_range(12, 60) var trunk_width: int = 22
@export_range(2, 5) var bark_thickness: int = 3
## Rows between knot-holes connecting inside and outside (TRUNK); height of
## each sub-area band (WEAVE, MOUNTAIN). trunk_width is the mountain's base.
@export_range(8, 40) var knothole_spacing: int = 16

@export_group("Traversal")
## Vertical gap (tiles) between generated climbing platforms. The player's
## held jump clears ~7 tiles at base momentum, a tap jump ~3.
@export_range(3, 7) var platform_spacing: int = 5
@export_range(0.0, 1.0) var platform_chance: float = 0.75
## Chance that a flat floor stretch gets sunk into a lava/poison pool.
@export_range(0.0, 1.0) var hazard_chance: float = 0.2

@export_group("Population")
## Mobs to scatter. Each Enemy scene declares where it lives (floor, ceiling,
## wall, air) and is placed on a matching surface. See EnemyCatalog.
@export var enemy_scenes: Array[PackedScene] = []
@export_range(0, 80) var enemy_count: int = 6
@export var pickup_scene: PackedScene
@export_range(0, 100) var pickup_count: int = 10
## Placed once at the far end of each side room (leave empty for coins only).
@export var side_room_reward: PackedScene
## Plugs every other side-room tunnel (CLIMB) with an element obstacle, so
## those detours wait until she has the right sword: VINE burns (flame),
## SLIME freezes then shatters (ice + a heavy hit). The find room stays open.
## The level registry can set this per level ("gate").
@export var side_room_gate: Gate = Gate.NONE
## Pick a detour spot for the level's side-route find (see `find_spot`).
## The level turns this on when its registry entry has a "find".
@export var reserve_find_spot: bool = false
## Rooms without side rooms (CAVERN, SHAFT, ...): put the find on the highest
## floor in the room instead of off to the side mid-climb, so the whole climb
## is the detour (e.g. Ash Chimney's dash shrine at the top of the chimney).
@export var find_at_top: bool = false

enum Gate { NONE, VINE, SLIME }

## After generation: feet position (level-local px) at the far end of the
## detour reserved for the side-route find, or Vector2.INF if none.
var find_spot := Vector2.INF
var _find_room := -1
## How many side-route finds to reserve spots for (one detour each; the level
## sets it from its registry "find" list). find_spot is the first of them.
var find_count := 1
## After generation: one feet position per find, best detour first.
var find_spots: Array[Vector2] = []
var _find_rooms: Array[int] = []

@export_group("Secrets")
## Hidden pockets carved into solid rock beside a floor, sealed either by a
## false wall (she walks through; it fades while she's inside) or a cracked
## wall (any sword blow breaks it). Each holds coins, or a find the level
## registry asks for ("secret_find"). Secrets are added last with their own
## RNG, so turning them on doesn't change the rest of the room's layout,
## mobs or pickups. The registry can set these per level ("secrets").
@export_range(0, 8) var secret_count: int = 0
@export var secret_style: SecretStyle = SecretStyle.MIXED
## Coins left in each pocket that doesn't hold a find.
@export_range(0, 10) var secret_coins: int = 3

enum SecretStyle { MIXED, FALSE_WALL, CRACKED }

## After generation: feet position (level-local px) at the back of each secret
## pocket, in placement order. The first `secret_find_count` hold the level's
## secret finds (placed by the Level); the rest hold coins.
var secret_spots: Array[Vector2] = []
var secret_find_count := 0

@export_group("Nodes")
@export var ground_layer: TileMapLayer
@export var background_layer: TileMapLayer
@export var decor_layer: TileMapLayer
@export var entities_root: Node2D

## name -> {"spawn": Vector2 (feet position), "exit": Rect2}, level-local pixels.
@export_storage var anchors: Dictionary = {}

var _grid := PackedByteArray()
var _protected := PackedByteArray()
var _region := PackedInt32Array()
var _air_run := PackedInt32Array()
var _cooldown := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _side_rooms: Array[Dictionary] = [] # {"rect": Rect2i (air), "dir": -1 left / 1 right}
var _spine := PackedInt32Array() # CLIMB: shaft centre column per row
var _climb_area := PackedByteArray() # empty = climb platforms anywhere
var _backdrop := PackedByteArray() # empty = paint background everywhere
var _north_col := -1
var _south_col := -1
var _gates: Array[Dictionary] = [] # {"mouth": Vector2i, "dir": int}


func _ready() -> void:
	if not Engine.is_editor_hint():
		_add_parallax()
	# Normally the Level drives generation; this covers a generator used on its own.
	if not Engine.is_editor_hint() and not (get_parent() is Level):
		generate_if_needed.call_deferred()


## Instance the theme's parallax backdrop. It hangs under this plain Node, so it
## sits at the canvas root with its own far-back z_index and no physics.
func _add_parallax() -> void:
	if not tile_theme or not tile_theme.parallax:
		return
	var backdrop := tile_theme.parallax.instantiate()
	var origin := ground_layer.global_position if ground_layer else Vector2.ZERO
	if backdrop.has_method("set_bounds"):
		backdrop.set_bounds(Rect2(origin, Vector2(width, height) * TILE))
	add_child(backdrop)


## Runtime entry point used by Level.
func generate_if_needed() -> void:
	if Engine.is_editor_hint():
		return
	var level := get_parent()
	var manager := get_node_or_null("/root/LevelManager")
	if manager and level is Level:
		var overrides: Dictionary = manager.get("seed_overrides")
		if overrides.has(level.level_id):
			level_seed = overrides[level.level_id]
			generate()
			return
	if generate_at_runtime and ground_layer and ground_layer.get_used_cells().is_empty():
		generate()


func generate() -> void:
	if not ground_layer:
		push_error("LevelGenerator: assign ground_layer first.")
		return
	if not tile_theme:
		push_error("LevelGenerator: assign a tile_theme first.")
		return
	_rng.seed = level_seed
	var n := width * height
	_grid.resize(n)
	_grid.fill(SOLID)
	_protected.resize(n)
	_protected.fill(0)
	anchors = {}
	_side_rooms.clear()
	_climb_area = PackedByteArray()
	_backdrop = PackedByteArray()
	_north_col = -1
	_south_col = -1

	match style:
		Style.CAVERN:
			_gen_cavern()
		Style.SHAFT:
			_gen_shaft()
		Style.SURFACE:
			_gen_surface()
		Style.ARENA:
			_gen_arena()
		Style.CLIMB:
			_gen_climb()
		Style.TRUNK:
			_gen_trunk()
		Style.SKY:
			_gen_sky()
		Style.WEAVE:
			WeaveBuilder.new(self).build(WeaveBuilder.Body.TRUNK)
		Style.MOUNTAIN:
			WeaveBuilder.new(self).build(WeaveBuilder.Body.MOUNTAIN)

	find_spot = Vector2.INF
	_find_room = -1
	find_spots.clear()
	_find_rooms.clear()
	if reserve_find_spot:
		_pick_find_room()
	_plan_gates()
	if style in [Style.CAVERN, Style.SHAFT, Style.CLIMB, Style.TRUNK]:
		_add_climb_platforms()
	if tile_theme.has_hazard() and hazard_chance > 0.0:
		_add_hazard_pools()
	if reserve_find_spot and find_spots.size() < maxi(find_count, 1):
		_pick_find_cell()
	_paint()
	_populate()
	_add_secrets()
	if Engine.is_editor_hint():
		_snap_exits_in_editor()


func clear() -> void:
	for layer in [ground_layer, background_layer, decor_layer]:
		if layer:
			layer.clear()
	_clear_generated_entities()
	anchors = {}


## Editor only: save the open level, as generated right now, to a new scene
## `res://levels/<realm>/<realm>_seed_<seed>.tscn` (never overwrites; adds a
## suffix if taken), then open that copy for hand-editing. The scene you
## generated in is left unsaved; discard its changes unless you meant to keep them.
## Add the new level to LevelRegistry to put it in the game.
func save_as_new_level() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var root := get_tree().edited_scene_root
	if not root is Level:
		push_error("LevelGenerator: Save As New Level needs a Level as the scene root.")
		return
	if not ground_layer or ground_layer.get_used_cells().is_empty():
		push_error("LevelGenerator: nothing to save; press Generate first.")
		return
	var level := root as Level
	var realm_dir := level.realm if level.realm != "" else "misc"
	var dir := "res://levels/%s" % realm_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var base := "%s_seed_%d" % [realm_dir, level_seed]
	var id := base
	var n := 2
	while FileAccess.file_exists("%s/%s.tscn" % [dir, id]):
		id = "%s_%d" % [base, n]
		n += 1
	var path := "%s/%s.tscn" % [dir, id]

	# Give the copy its own id/name while packing, then restore the original.
	var old_id := level.level_id
	var old_name := level.display_name
	level.level_id = id
	level.display_name = "%s (seed %d)" % [old_name if old_name != "" else realm_dir.capitalize(), level_seed]
	var packed := PackedScene.new()
	var err := packed.pack(root)
	level.level_id = old_id
	level.display_name = old_name
	if err != OK:
		push_error("LevelGenerator: could not pack scene (%s)." % error_string(err))
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("LevelGenerator: could not save %s (%s)." % [path, error_string(err)])
		return
	print("LevelGenerator: saved %s (level_id \"%s\"). Add it to LevelRegistry to use it." % [path, id])
	# EditorInterface is looked up by name so this script still compiles in exported builds.
	if Engine.has_singleton("EditorInterface"):
		var editor: Object = Engine.get_singleton("EditorInterface")
		editor.get_resource_filesystem().scan()
		editor.open_scene_from_path(path)


# --------------------------------------------------------------------------
# Styles
# --------------------------------------------------------------------------

func _gen_cavern() -> void:
	for y in height:
		for x in width:
			var border := x < 2 or y < 2 or x >= width - 2 or y >= height - 2
			_put(x, y, SOLID if border or _rng.randf() < fill_ratio else AIR)
	for i in smoothing_passes:
		_smooth()

	var points := _make_openings()
	if points.is_empty():
		points.append(_random_interior())
	if points.size() == 1:
		points.append(_random_interior())
	for i in range(1, points.size()):
		_carve_walk(points[i - 1], points[i], 2)
	for i in extra_tunnels:
		_carve_walk(points[_rng.randi() % points.size()], _random_interior(), 2)

	_connect_regions(points[0])
	_remove_specks()
	_make_openings() # re-assert floors/ledges the tunnels may have chewed through


func _gen_shaft() -> void:
	var left := 3.0
	var right := 3.0
	for y in height:
		left = clampf(left + _rng.randf_range(-0.7, 0.7), 2.0, 6.0)
		right = clampf(right + _rng.randf_range(-0.7, 0.7), 2.0, 6.0)
		for x in width:
			var inside := x >= int(left) and x < width - int(right) and y >= 2 and y < height - 2
			_put(x, y, AIR if inside else SOLID)

	# Shelves growing out of alternating walls, like fungus on the inner bark.
	var y := height - 7
	var side := _rng.randi() % 2
	while y > 6:
		var length := _rng.randi_range(4, maxi(5, width / 2 - 2))
		var thick := 1 if _rng.randf() < 0.6 else 2
		if side == 0:
			var x0 := 0
			while x0 < width and _cell(x0, y) == SOLID:
				x0 += 1
			_fill_rect(x0, y, x0 + length - 1, y + thick - 1, SOLID)
		else:
			var x1 := width - 1
			while x1 >= 0 and _cell(x1, y) == SOLID:
				x1 -= 1
			_fill_rect(x1 - length + 1, y, x1, y + thick - 1, SOLID)
		side = 1 - side
		y -= _rng.randi_range(4, 6)

	_make_openings()


func _gen_surface() -> void:
	_grid.fill(AIR)
	var heights := PackedInt32Array()
	heights.resize(width)
	var h := int(height * 0.65)
	var lo := int(height * 0.4)
	var hi := height - 4
	var x := 0
	while x < width:
		var near_edge := x < 10 or x > width - 12
		if not near_edge and _rng.randf() < 0.16:
			var gap := _rng.randi_range(3, 5)
			for i in gap:
				if x + i < width:
					heights[x + i] = -1
			x += gap
			continue
		var seg := _rng.randi_range(4, 10)
		for i in seg:
			if x + i < width:
				heights[x + i] = h
		x += seg
		h = clampi(h + _rng.randi_range(-3, 3), lo, hi)

	for cx in width:
		if heights[cx] >= 0:
			_fill_rect(cx, heights[cx], cx, height - 1, SOLID)

	# Bridges over some chasms; floating ledges for the flutter to play with.
	cx_loop_bridges(heights)
	var fx := 8
	while fx < width - 8:
		if heights[fx] > 0 and _rng.randf() < 0.55:
			var length := _rng.randi_range(3, 5)
			var row := heights[fx] - _rng.randi_range(4, 6)
			if row > 2:
				_fill_rect(fx, row, fx + length - 1, row, PLATFORM)
		fx += _rng.randi_range(8, 14)

	if open_west:
		var r := heights[0]
		_add_anchor("west", Vector2i(3, heights[3]), Rect2(0, 0, TILE, r * TILE))
		_protect_rect(0, r - 4, 6, r)
	if open_east:
		var r := heights[width - 1]
		_add_anchor("east", Vector2i(width - 4, heights[width - 4]), Rect2((width - 1) * TILE, 0, TILE, r * TILE))
		_protect_rect(width - 7, r - 4, width - 1, r)


func cx_loop_bridges(heights: PackedInt32Array) -> void:
	var x := 0
	while x < width:
		if heights[x] >= 0:
			x += 1
			continue
		var start := x
		while x < width and heights[x] < 0:
			x += 1
		if _rng.randf() < 0.5 and start > 0 and x < width:
			var row := mini(heights[start - 1], heights[x])
			_fill_rect(start, row, x - 1, row, PLATFORM)


func _gen_arena() -> void:
	_fill_rect(2, 2, width - 3, height - 4, AIR)
	var floor_row := height - 3
	# Two tiers of one-way platforms, offset so they stagger.
	for tier in 2:
		var row := floor_row - platform_spacing * (tier + 1)
		if row < 4:
			break
		var x := 4 + tier * 4
		while x < width - 8:
			var length := _rng.randi_range(4, 7)
			_fill_rect(x, row, x + length - 1, row, PLATFORM)
			x += length + _rng.randi_range(5, 9)
	_make_openings()


func _gen_climb() -> void:
	_spine.resize(height)
	var half := shaft_width / 2.0
	var cx := float(_col_for(south_at)) if open_south else width / 2.0
	for y in range(height - 3, 1, -1):
		cx = clampf(cx + _rng.randf_range(-0.9, 0.9), half + 3.0, width - half - 4.0)
		_spine[y] = int(cx)
		var w := half + _rng.randf_range(-1.0, 1.0)
		_fill_rect(int(cx - w), y, int(cx + w), y, AIR)
	_spine[0] = _spine[2]
	_spine[1] = _spine[2]
	_spine[height - 2] = _spine[height - 3]
	_spine[height - 1] = _spine[height - 3]
	_south_col = _spine[height - 3]
	_north_col = _spine[2]

	# Rock outcrops on alternating walls break up the shaft.
	var y := height - 8
	var side := -1 if _rng.randf() < 0.5 else 1
	while y > 6:
		_outcrop(y, _spine[y], side, _rng.randi_range(2, maxi(2, int(half) - 1)))
		side = -side
		y -= _rng.randi_range(5, 7)

	# Detours: tunnels off the shaft into small rooms.
	y = height - 12
	while y > 10:
		var dir := -1 if _rng.randf() < 0.5 else 1
		if _rng.randf() < side_room_chance and _side_room(y, _spine[y], dir):
			y -= side_room_spacing
		else:
			y -= 6

	var points := _make_openings()
	for p in points:
		_carve_walk(p, Vector2i(_spine[p.y], p.y), 1)
	_make_openings()
	if not open_south:
		_add_start_anchor(_spine[height - 3], height - 2)


func _gen_trunk() -> void:
	_grid.fill(AIR)
	var t0 := (width - trunk_width) / 2
	var t1 := t0 + trunk_width - 1
	var in0 := t0 + bark_thickness
	var in1 := t1 - bark_thickness
	var mid := (in0 + in1) / 2

	_fill_rect(0, height - 2, width - 1, height - 1, SOLID) # ground at the base
	for y in range(0, height - 2):
		var wl := bark_thickness + (1 if _rng.randf() < 0.2 else 0)
		var wr := bark_thickness + (1 if _rng.randf() < 0.2 else 0)
		_fill_rect(t0, y, t0 + wl - 1, y, SOLID)
		_fill_rect(t1 - wr + 1, y, t1, y, SOLID)
	_fill_rect(t0, 0, t1, 1, SOLID)

	# Dark backdrop and auto-platforms only inside the hollow.
	_backdrop.resize(width * height)
	_backdrop.fill(0)
	_climb_area.resize(width * height)
	_climb_area.fill(0)
	for y in height:
		for x in range(t0, t1 + 1):
			_backdrop[y * width + x] = 1
			if x >= in0 and x <= in1:
				_climb_area[y * width + x] = 1

	# Inside: shelves on alternating inner walls.
	var y := height - 7
	var side := -1
	while y > 5:
		_outcrop(y, mid, side, _rng.randi_range(2, maxi(2, (in1 - in0) / 2 - 1)))
		side = -side
		y -= _rng.randi_range(5, 7)

	# Outside: one-way branches up each flank, alternating long and short.
	# Long branch tips are the outside detours; some carry rewards.
	for dir: int in [-1, 1]:
		var wall_x := t0 - 1 if dir < 0 else t1 + 1
		var reach := (t0 - 2) if dir < 0 else (width - 3 - t1)
		var long := _rng.randf() < 0.5
		y = height - 6
		while y > 4:
			var length := _rng.randi_range(maxi(3, reach - 3), maxi(3, reach - 1)) if long else _rng.randi_range(3, 4)
			_put(wall_x, y, SOLID)
			for i in range(1, length):
				_put(wall_x + dir * i, y, PLATFORM)
			if long and _rng.randf() < side_room_chance:
				var tip := wall_x + dir * (length - 1)
				_side_rooms.append({"rect": Rect2i(mini(tip, tip - dir * 3), y - 3, 4, 3), "dir": dir})
			long = not long
			y -= _rng.randi_range(4, 5)

	# Knot-holes: doorways through the bark, with footing on both sides.
	y = height - 10
	side = 1 if _rng.randf() < 0.5 else -1
	while y > 6:
		if side < 0:
			_fill_rect(t0, y - 2, in0, y, AIR)
			_fill_rect(in0, y + 1, in0 + 2, y + 1, SOLID)
			_put(t0 - 1, y + 1, SOLID)
			_fill_rect(t0 - 5, y + 1, t0 - 2, y + 1, PLATFORM)
		else:
			_fill_rect(in1, y - 2, t1, y, AIR)
			_fill_rect(in1 - 2, y + 1, in1, y + 1, SOLID)
			_put(t1 + 1, y + 1, SOLID)
			_fill_rect(t1 + 2, y + 1, t1 + 5, y + 1, PLATFORM)
		side = -side
		y -= _rng.randi_range(knothole_spacing - 4, knothole_spacing + 4)

	_south_col = mid
	_north_col = mid
	_make_openings()
	if not open_south:
		_add_start_anchor(mid, height - 2)


func _gen_sky() -> void:
	_grid.fill(AIR)
	var x := width / 2
	var y := height - 4
	_island(x, y, 14)
	_south_col = x
	if not open_south:
		_add_start_anchor(x, y)
	while y > 10:
		y -= _rng.randi_range(4, 5)
		var dx := _rng.randi_range(4, 9) * (1 if _rng.randf() < 0.5 else -1)
		if x + dx < 6 or x + dx > width - 7:
			dx = -dx
		x = clampi(x + dx, 6, width - 7)
		if _rng.randf() < 0.35:
			_island(x, y, _rng.randi_range(5, 8))
		else:
			_fill_rect(x - 2, y, x + 2 + _rng.randi_range(0, 2), y, PLATFORM)
		# Detour: an island out to the side, a flutter-jump away.
		if _rng.randf() < side_room_chance * 0.4:
			var sx := x + _rng.randi_range(11, 15) * (1 if x < width / 2 else -1)
			if sx > 5 and sx < width - 6:
				var sy := y - _rng.randi_range(0, 2)
				_island(sx, sy, 6)
				_side_rooms.append({"rect": Rect2i(sx - 2, sy - 3, 5, 3), "dir": 1 if sx > x else -1})
	_north_col = x
	_make_openings()


## Pushes a rock lip out from the wall the scan hits.
func _outcrop(y: int, from_x: int, dir: int, length: int) -> void:
	var x := from_x
	while x > 0 and x < width - 1 and _cell(x, y) == AIR:
		x += dir
	for i in range(1, length + 1):
		_put(x - dir * i, y, SOLID)


## Tunnel from the shaft wall at row y into a small room. False if it can't fit.
func _side_room(y: int, from_x: int, dir: int) -> bool:
	var x := from_x
	while x > 0 and x < width - 1 and _cell(x, y) == AIR:
		x += dir
	var wall_x := x
	var near := wall_x + dir * _rng.randi_range(3, 7)
	if near < 3 or near > width - 4:
		return false
	var far := clampi(near + dir * (_rng.randi_range(8, 13) - 1), 2, width - 3)
	var x0 := mini(near, far)
	var x1 := maxi(near, far)
	if x1 - x0 + 1 < 6:
		return false
	var rh := _rng.randi_range(5, 7)
	_fill_rect(mini(wall_x, near), y - 2, maxi(wall_x, near), y, AIR)
	_fill_rect(x0, y - rh + 1, x1, y, AIR)
	_fill_rect(mini(wall_x, x0), y + 1, maxi(wall_x, x1), y + 1, SOLID)
	# Ledge in the shaft at the tunnel mouth.
	_fill_rect(mini(wall_x - dir, wall_x - dir * 3), y + 1, maxi(wall_x - dir, wall_x - dir * 3), y + 1, SOLID)
	# mouth = the tunnel column next to the room, at the tunnel's floor row.
	_side_rooms.append({"rect": Rect2i(x0, y - rh + 1, x1 - x0 + 1, rh), "dir": dir,
			"mouth": Vector2i(near - dir, y)})
	return true


func _island(cx: int, top: int, w: int) -> void:
	var x0 := cx - w / 2
	var x1 := x0 + w - 1
	_fill_rect(x0, top, x1, top + 1, SOLID)
	if w > 4:
		_fill_rect(x0 + 1, top + 2, x1 - 1, top + 2, SOLID)
	if w > 7:
		_fill_rect(x0 + 3, top + 3, x1 - 3, top + 3, SOLID)


## Arrival point for levels whose bottom is closed (the start of a run).
func _add_start_anchor(x: int, floor_y: int) -> void:
	_add_anchor("start", Vector2i(x, floor_y), Rect2())
	_protect_rect(x - 3, floor_y - 4, x + 3, floor_y)


# --------------------------------------------------------------------------
# Openings & anchors
# --------------------------------------------------------------------------

## Carves every enabled opening and records its anchor. Deterministic, so it
## can be called again after other passes to restore the geometry.
## Returns an interior point near each opening, for path carving.
func _make_openings() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if open_west:
		var r := _row_for(west_at)
		_fill_rect(0, r - 3, 6, r - 1, AIR)
		_fill_rect(0, r, 7, r + 1, SOLID)
		_protect_rect(0, r - 4, 8, r + 1)
		_add_anchor("west", Vector2i(3, r), Rect2(0, (r - 3) * TILE, TILE, 3 * TILE))
		points.append(Vector2i(6, r - 2))
	if open_east:
		var r := _row_for(east_at)
		_fill_rect(width - 7, r - 3, width - 1, r - 1, AIR)
		_fill_rect(width - 8, r, width - 1, r + 1, SOLID)
		_protect_rect(width - 9, r - 4, width - 1, r + 1)
		_add_anchor("east", Vector2i(width - 4, r), Rect2((width - 1) * TILE, (r - 3) * TILE, TILE, 3 * TILE))
		points.append(Vector2i(width - 7, r - 2))
	if open_north:
		var c := _north_col if _north_col >= 0 else _col_for(north_at)
		_fill_rect(c - 1, 0, c + 1, 6, AIR)
		_fill_rect(c - 3, 7, c + 3, 10, AIR)
		_fill_rect(c - 2, 7, c + 2, 7, PLATFORM) # ledge to jump back up from
		_protect_rect(c - 3, 0, c + 3, 8)
		_add_anchor("north", Vector2i(c, 7), Rect2((c - 1) * TILE, 0, 3 * TILE, 2 * TILE))
		points.append(Vector2i(c, 9))
	if open_south:
		var c := _south_col if _south_col >= 0 else _col_for(south_at)
		_fill_rect(c - 6, height - 10, c + 1, height - 7, AIR)
		_fill_rect(c - 6, height - 6, c - 2, height - 5, SOLID) # ledge beside the hole
		_fill_rect(c - 1, height - 6, c + 1, height - 1, AIR)
		_protect_rect(c - 7, height - 11, c + 2, height - 1)
		_add_anchor("south", Vector2i(c - 4, height - 6), Rect2((c - 1) * TILE, (height - 2) * TILE, 3 * TILE, 2 * TILE))
		points.append(Vector2i(c - 3, height - 8))
	return points


## spawn_floor is the solid cell the player arrives standing on.
func _add_anchor(anchor_name: String, spawn_floor: Vector2i, exit_rect: Rect2) -> void:
	anchors[anchor_name] = {
		"spawn": Vector2(spawn_floor.x * TILE + TILE / 2.0, spawn_floor.y * TILE),
		"exit": exit_rect,
	}


func _row_for(f: float) -> int:
	return clampi(int(f * height), 6, height - 4)


func _col_for(f: float) -> int:
	return clampi(int(f * width), 8, width - 9)


# --------------------------------------------------------------------------
# Cavern helpers
# --------------------------------------------------------------------------

func _smooth() -> void:
	var next := _grid.duplicate()
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var n := 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if (ox != 0 or oy != 0) and _cell(x + ox, y + oy) == SOLID:
						n += 1
			if n > 4:
				next[y * width + x] = SOLID
			elif n < 4:
				next[y * width + x] = AIR
	_grid = next


## Random walk from a to b that favours horizontal travel, carving as it goes.
func _carve_walk(a: Vector2i, b: Vector2i, radius: int) -> void:
	var p := a
	var guard := width * height * 4
	while p != b and guard > 0:
		guard -= 1
		_carve_interior(p, radius)
		var d := b - p
		if _rng.randf() < 0.7:
			if d.x != 0 and (absi(d.x) >= absi(d.y) or _rng.randf() < 0.35):
				p.x += signi(d.x)
			elif d.y != 0:
				p.y += signi(d.y)
		else:
			match _rng.randi() % 4:
				0: p.x -= 1
				1: p.x += 1
				2: p.y -= 1
				_: p.y += 1
		p.x = clampi(p.x, 3, width - 4)
		p.y = clampi(p.y, 3, height - 4)
	_carve_interior(b, radius)


func _carve_interior(p: Vector2i, radius: int) -> void:
	for y in range(maxi(2, p.y - radius), mini(height - 2, p.y + radius + 1)):
		for x in range(maxi(2, p.x - radius), mini(width - 2, p.x + radius + 1)):
			_put(x, y, AIR)


## Flood-fills open space; tiny disconnected pockets are filled in, larger ones
## get a tunnel to the region containing `start`.
func _connect_regions(start: Vector2i) -> void:
	var n := width * height
	_region.resize(n)
	_region.fill(-1)
	var regions: Array = []
	for i in n:
		if _region[i] != -1 or _grid[i] == SOLID:
			continue
		var id := regions.size()
		var cells: Array[int] = []
		var stack: Array[int] = [i]
		_region[i] = id
		while not stack.is_empty():
			var c: int = stack.pop_back()
			cells.append(c)
			var cx := c % width
			var cy := c / width
			if cx > 0: _flood_push(c - 1, id, stack)
			if cx < width - 1: _flood_push(c + 1, id, stack)
			if cy > 0: _flood_push(c - width, id, stack)
			if cy < height - 1: _flood_push(c + width, id, stack)
		regions.append(cells)
	if regions.is_empty():
		return

	var main_id := _region[start.y * width + start.x]
	if main_id < 0:
		main_id = 0
		for id in regions.size():
			if regions[id].size() > regions[main_id].size():
				main_id = id
	var main_cells: Array[int] = regions[main_id]

	for id in regions.size():
		if id == main_id:
			continue
		var cells: Array[int] = regions[id]
		if cells.size() < 24:
			for c in cells:
				_grid[c] = SOLID
			continue
		var from := cells[_rng.randi() % cells.size()]
		var fp := Vector2i(from % width, from / width)
		var best := main_cells[0]
		var best_d := 1 << 30
		for mc in main_cells:
			var dd := absi(mc % width - fp.x) + absi(mc / width - fp.y)
			if dd < best_d:
				best_d = dd
				best = mc
		_carve_walk(fp, Vector2i(best % width, best / width), 1)


func _flood_push(c: int, id: int, stack: Array[int]) -> void:
	if _region[c] == -1 and _grid[c] != SOLID:
		_region[c] = id
		stack.append(c)


func _remove_specks() -> void:
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			if _cell(x, y) != SOLID:
				continue
			if _cell(x - 1, y) != SOLID and _cell(x + 1, y) != SOLID \
					and _cell(x, y - 1) != SOLID and _cell(x, y + 1) != SOLID:
				_put(x, y, AIR)


func _random_interior() -> Vector2i:
	return Vector2i(_rng.randi_range(6, width - 7), _rng.randi_range(5, height - 6))


# --------------------------------------------------------------------------
# Traversal & hazards
# --------------------------------------------------------------------------

## Scans bottom-up. Wherever open air rises `platform_spacing` tiles above the
## nearest floor, drops in short one-way platforms so every chamber is climbable.
func _add_climb_platforms() -> void:
	_air_run.resize(width)
	_air_run.fill(0)
	_cooldown.resize(width)
	_cooldown.fill(0)
	for y in range(height - 1, 2, -1):
		for x in width:
			_air_run[x] = _air_run[x] + 1 if _cell(x, y) == AIR else 0
			if _cooldown[x] > 0:
				_cooldown[x] -= 1
		var x := 2
		while x < width - 2:
			if not _can_platform(x, y):
				x += 1
				continue
			var end := x
			while end + 1 < width - 2 and _can_platform(end + 1, y):
				end += 1
			_place_platform_runs(x, end, y)
			x = end + 1


func _can_platform(x: int, y: int) -> bool:
	return _air_run[x] >= platform_spacing and _cooldown[x] == 0 \
			and not _is_protected(x, y) \
			and (_climb_area.is_empty() or _climb_area[y * width + x] == 1) \
			and _cell(x, y - 1) == AIR and _cell(x, y - 2) == AIR


func _place_platform_runs(x0: int, x1: int, y: int) -> void:
	var x := x0
	while x <= x1:
		var run := mini(_rng.randi_range(3, 5), x1 - x + 1)
		if run < 2:
			break
		var forced := _air_run[x] >= platform_spacing + 2
		if forced or _rng.randf() < platform_chance:
			for i in run:
				_put(x + i, y, PLATFORM)
				_air_run[x + i] = 0
			for cx in range(maxi(0, x - 3), mini(width, x + run + 3)):
				_cooldown[cx] = maxi(_cooldown[cx], platform_spacing - 1)
		x += run + _rng.randi_range(3, 6)


## Sinks short stretches of flat floor into lava/poison, keeping a lip on each side.
func _add_hazard_pools() -> void:
	for y in range(2, height - 3):
		var x := 2
		while x < width - 2:
			var run := 0
			while x + run < width - 2 and _is_pool_cell(x + run, y):
				run += 1
			if run >= 5 and _rng.randf() < hazard_chance:
				var w := mini(run - 2, _rng.randi_range(2, 4))
				var start := x + 1 + _rng.randi_range(0, run - 2 - w)
				for i in w:
					_put(start + i, y + 1, HAZARD_TOP)
					_put(start + i, y + 2, HAZARD)
			x += maxi(run, 1)


func _is_pool_cell(x: int, y: int) -> bool:
	return _cell(x, y) == AIR and _cell(x, y + 1) == SOLID and _cell(x, y + 2) == SOLID \
			and not _is_protected(x, y) and not _is_protected(x, y + 1)


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

func _paint() -> void:
	ground_layer.clear()
	if decor_layer:
		decor_layer.clear()
	var paint_background := background_layer != null and style != Style.SURFACE and style != Style.SKY
	if background_layer:
		background_layer.clear()
		background_layer.modulate = tile_theme.background_tint
	var near_ground := _background_reach_mask() if paint_background else PackedByteArray()

	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if paint_background and (_backdrop.is_empty() or _backdrop[y * width + x] == 1) \
					and (near_ground.is_empty() or near_ground[y * width + x] == 1):
				background_layer.set_cell(c, SOURCE_ID, tile_theme.background)
			match _cell(x, y):
				SOLID:
					var above := _cell(x, y - 1)
					var tile := tile_theme.surface if above != SOLID and above != HAZARD and above != HAZARD_TOP \
							else tile_theme.pick_fill(_rng)
					ground_layer.set_cell(c, SOURCE_ID, tile)
				PLATFORM:
					ground_layer.set_cell(c, SOURCE_ID, tile_theme.platform)
				HAZARD_TOP:
					ground_layer.set_cell(c, SOURCE_ID, tile_theme.hazard_top)
				HAZARD:
					ground_layer.set_cell(c, SOURCE_ID, tile_theme.hazard_fill)
				AIR:
					if decor_layer and not tile_theme.decor.is_empty() \
							and y + 1 < height and _cell(x, y + 1) == SOLID and not _is_protected(x, y) \
							and _rng.randf() < tile_theme.decor_chance:
						decor_layer.set_cell(c, SOURCE_ID, tile_theme.decor[_rng.randi() % tile_theme.decor.size()])


## Cells whose background tile stays when the theme has a parallax backdrop:
## everything that isn't air, plus air within `background_reach` cells of it
## (a ragged extra cell at the rim). Empty = paint everywhere. Hashes instead
## of `_rng` so seeds keep producing the same rooms and enemies.
func _background_reach_mask() -> PackedByteArray:
	var reach := tile_theme.background_reach
	if reach < 0 or not tile_theme.parallax or not _backdrop.is_empty():
		return PackedByteArray()
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(reach + 2)
	var frontier: Array[int] = []
	for i in width * height:
		if _grid[i] != AIR:
			dist[i] = 0
			frontier.append(i)
	# Multi-source BFS (8-neighbour = Chebyshev distance), capped at reach + 1.
	var head := 0
	while head < frontier.size():
		var i := frontier[head]
		head += 1
		var d := dist[i] + 1
		if d > reach + 1:
			continue
		var x := i % width
		var y := i / width
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var j := ny * width + nx
				if dist[j] > d:
					dist[j] = d
					frontier.append(j)
	var mask := PackedByteArray()
	mask.resize(width * height)
	for i in width * height:
		var rim := dist[i] == reach + 1 and (hash(i * 7919 + level_seed) & 3) == 0
		mask[i] = 1 if dist[i] <= reach or rim else 0
	return mask


func _populate() -> void:
	_clear_generated_entities()
	var root: Node = entities_root if entities_root else self
	var avoid: Array[Vector2i] = []
	for a: Dictionary in anchors.values():
		var spawn: Vector2 = a["spawn"]
		avoid.append(Vector2i(int(spawn.x) / TILE, int(spawn.y) / TILE))

	if not enemy_scenes.is_empty() and enemy_count > 0:
		_populate_enemies(root, avoid)
	_populate_side_rooms(root)
	_populate_gates(root)

	if pickup_scene and pickup_count > 0:
		var spots: Array = []
		for y in range(2, height - 2):
			for x in range(2, width - 2):
				var below := _cell(x, y + 2)
				if _cell(x, y) == AIR and _cell(x, y + 1) == AIR \
						and (below == SOLID or below == PLATFORM) and not _is_protected(x, y):
					spots.append(Vector2i(x, y))
		_shuffle(spots)
		var placed := _pick_spread(spots, pickup_count, 4, avoid, 3)
		for cell: Vector2i in placed:
			_spawn_entity(root, pickup_scene, Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0))


## Enemies go where their scene says they live (Enemy.spawn_placement).
## Plain scenes without that property (e.g. the old slime) count as FLOOR.
func _populate_enemies(root: Node, avoid: Array[Vector2i]) -> void:
	var spots := {0: [], 1: [], 2: [], 3: []} # Enemy.Placement values
	for y in range(2, height - 2):
		for x in range(3, width - 3):
			if _cell(x, y) != AIR or _is_protected(x, y):
				continue
			var below := _cell(x, y + 1)
			if _cell(x, y - 1) == AIR and _cell(x - 1, y) == AIR and _cell(x + 1, y) == AIR \
					and _is_standable(x - 1, y + 1) and _is_standable(x, y + 1) and _is_standable(x + 1, y + 1):
				spots[0].append(Vector3i(x, y, 0))
			if _cell(x, y - 1) == SOLID and below == AIR and _cell(x, y + 2) == AIR \
					and _cell(x, y + 3) == AIR and _cell(x, y + 4) == AIR:
				spots[1].append(Vector3i(x, y, 0))
			if _cell(x, y - 1) == AIR and below == AIR:
				if _cell(x - 1, y - 1) == SOLID and _cell(x - 1, y) == SOLID and _cell(x - 1, y + 1) == SOLID \
						and _cell(x + 1, y) == AIR:
					spots[2].append(Vector3i(x, y, -1))
				elif _cell(x + 1, y - 1) == SOLID and _cell(x + 1, y) == SOLID and _cell(x + 1, y + 1) == SOLID \
						and _cell(x - 1, y) == AIR:
					spots[2].append(Vector3i(x, y, 1))
			var open := true
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if _cell(x + ox, y + oy) != AIR:
						open = false
			if open:
				spots[3].append(Vector3i(x, y, 0))
	for key in spots:
		_shuffle(spots[key])

	# Read each scene's placement once.
	var kinds: Array = []
	for scene in enemy_scenes:
		if not scene:
			continue
		var probe := scene.instantiate()
		var placement = probe.get("spawn_placement")
		var offset = probe.get("surface_offset")
		kinds.append({
			"scene": scene,
			"placement": placement if placement != null else 0,
			"offset": offset if offset != null else 11.0,
		})
		probe.free()
	if kinds.is_empty():
		return

	var taken: Array[Vector2i] = []
	for i in enemy_count:
		var kind: Dictionary = kinds[_rng.randi() % kinds.size()]
		var list: Array = spots[kind["placement"]]
		while not list.is_empty():
			var s: Vector3i = list.pop_back()
			var cell := Vector2i(s.x, s.y)
			if _too_close(cell, avoid, 10) or _too_close(cell, taken, 6):
				continue
			taken.append(cell)
			var off: float = kind["offset"]
			var pos := Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
			match kind["placement"]:
				0: pos.y = (cell.y + 1) * TILE - off
				1: pos.y = cell.y * TILE + off
				2: pos.x = cell.x * TILE + off if s.z < 0 else (cell.x + 1) * TILE - off
			_spawn_entity(root, kind["scene"], pos)
			break


func _is_standable(x: int, y: int) -> bool:
	var v := _cell(x, y)
	return v == SOLID or v == PLATFORM


func _too_close(cell: Vector2i, others: Array[Vector2i], dist: int) -> bool:
	for o in others:
		if absi(o.x - cell.x) + absi(o.y - cell.y) < dist:
			return true
	return false


func _populate_side_rooms(root: Node) -> void:
	for side_room in _side_rooms:
		var room: Rect2i = side_room["rect"]
		var floor_y := room.end.y - 1 # last air row
		var mid := room.position.x + room.size.x / 2
		var find_col := _far_x(side_room) if _side_rooms.find(side_room) in _find_rooms else -99
		if pickup_scene:
			for dx in range(-1, 2):
				if absi(mid + dx - find_col) <= 0:
					continue # keep the find's pedestal clear
				_spawn_entity(root, pickup_scene, Vector2((mid + dx) * TILE + TILE / 2.0, (floor_y - 1) * TILE + TILE / 2.0))
		if side_room_reward:
			var far_x: int = room.position.x + 1 if side_room["dir"] < 0 else room.end.x - 2
			_spawn_entity(root, side_room_reward, Vector2(far_x * TILE + TILE / 2.0, floor_y * TILE + TILE / 2.0))


# --------------------------------------------------------------------------
# Side-route find and gates
# --------------------------------------------------------------------------

## The find goes in a side room early in the climb (lower part of the map),
## the one reaching farthest out to the side. With several finds
## (find_count), each takes the next best detour; find_spot is the first.
func _pick_find_room() -> void:
	for n in maxi(find_count, 1):
		var pick := -1
		var best := -1.0
		for pass_low: bool in [true, false]:
			for i in _side_rooms.size():
				var room: Rect2i = _side_rooms[i]["rect"]
				if i in _find_rooms or (pass_low and room.position.y < height * 0.35):
					continue
				var far_x := _far_x(_side_rooms[i])
				var reach := absf(far_x - width / 2.0)
				if reach > best:
					best = reach
					pick = i
			if pick >= 0:
				break
		if pick < 0:
			break
		_find_rooms.append(pick)
		var room: Rect2i = _side_rooms[pick]["rect"]
		find_spots.append(Vector2(_far_x(_side_rooms[pick]) * TILE + TILE / 2.0, room.end.y * TILE))
	if not _find_rooms.is_empty():
		_find_room = _find_rooms[0]
		find_spot = find_spots[0]


## No side rooms (CAVERN, SHAFT): the floor spot farthest off the straight
## line between the bottom and top openings, in the middle of the climb.
## Also fills in any finds the side rooms had no room for, each well apart.
## With `find_at_top`, the highest floor in the room wins instead.
func _pick_find_cell() -> void:
	var south := _south_col if _south_col >= 0 else width / 2
	var north := _north_col if _north_col >= 0 else width / 2
	var rows := range(2, height - 2) if find_at_top else range(int(height * 0.3), int(height * 0.8))
	while find_spots.size() < maxi(find_count, 1):
		var best := -INF
		var spot := Vector2.INF
		for y: int in rows:
			var line_x := lerpf(north, south, float(y) / height)
			for x in range(3, width - 3):
				if _cell(x, y) != AIR or _cell(x, y - 1) != AIR or _cell(x, y - 2) != AIR or _is_protected(x, y):
					continue
				if _cell(x - 1, y + 1) != SOLID or _cell(x, y + 1) != SOLID or _cell(x + 1, y + 1) != SOLID:
					continue
				var here := Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
				if find_spots.any(func(f: Vector2) -> bool: return f.distance_to(here) < 12.0 * TILE):
					continue
				var reach := absf(x - line_x)
				if find_at_top:
					reach -= y * 1000.0 # higher rows first, then farthest off the line
				if reach > best:
					best = reach
					spot = here
		if spot == Vector2.INF:
			break
		find_spots.append(spot)
		if find_spot == Vector2.INF:
			find_spot = spot
		var c := Vector2i(int(spot.x) / TILE, int(spot.y) / TILE - 1)
		_protect_rect(c.x - 1, c.y - 2, c.x + 1, c.y + 1)


func _far_x(side_room: Dictionary) -> int:
	var room: Rect2i = side_room["rect"]
	return room.position.x + 1 if side_room["dir"] < 0 else room.end.x - 2


## Every other tunnel-mouthed side room gets plugged (never a find room).
## A slime boulder is only 2 tiles tall, so its tunnel gets a lower ceiling.
func _plan_gates() -> void:
	_gates.clear()
	if style != Style.SURFACE:
		for side: String in ["west", "east"]:
			var gate_type: Gate = west_gate if side == "west" else east_gate
			if gate_type == Gate.NONE or not anchors.has(side):
				continue
			# The doorway from _make_openings: floor row r, air rows r-3..r-1.
			var r := int(anchors[side]["spawn"].y) / TILE
			var dir := -1 if side == "west" else 1
			var mx := 4 if side == "west" else width - 5
			_add_gate(Vector2i(mx, r - 1), dir, gate_type)
	if side_room_gate == Gate.NONE:
		return
	var k := 0
	for i in _side_rooms.size():
		if i in _find_rooms or not _side_rooms[i].has("mouth"):
			continue
		k += 1
		if k % 2 == 0:
			continue
		_add_gate(_side_rooms[i]["mouth"], _side_rooms[i]["dir"], side_room_gate)


## Plug the 3-tall passage whose bottom air cell is `m` (dir points away from
## the room's interior). A slime needs the ceiling lowered to 2 tiles over it.
func _add_gate(m: Vector2i, dir: int, gate_type: Gate) -> void:
	var back := m.x - dir # the column toward the room
	if gate_type == Gate.SLIME:
		if _cell(back, m.y) != AIR or _cell(back, m.y - 1) != AIR:
			return
		_put(m.x, m.y - 2, SOLID)
		_put(back, m.y - 2, SOLID)
	_protect_rect(mini(m.x, back), m.y - 2, maxi(m.x, back), m.y + 1)
	_gates.append({"mouth": m, "dir": dir, "type": gate_type})


func _populate_gates(root: Node) -> void:
	for gate in _gates:
		var m: Vector2i = gate["mouth"]
		var dir: int = gate["dir"]
		var node: Node2D
		if gate.get("type", side_room_gate) == Gate.VINE:
			var vine := VineWall.new()
			vine.size_tiles = Vector2i(1, 3)
			vine.position = Vector2(m.x * TILE, (m.y - 2) * TILE)
			node = vine
		else:
			node = SlimeBoulder.new()
			node.position = Vector2(mini(m.x, m.x - dir) * TILE + TILE, (m.y + 1) * TILE)
		node.set_meta("generated", true)
		root.add_child(node)
		if Engine.is_editor_hint() and is_inside_tree():
			node.owner = get_tree().edited_scene_root


# --------------------------------------------------------------------------
# Secrets
# --------------------------------------------------------------------------

## Carves `secret_count` hidden pockets into solid rock, with a one-tile
## shell of real rock left around each. Two shapes, alternating when both fit:
##   wall  - opens sideways off a floor: 3 tiles tall, 3-6 deep (fits caverns,
##           halls and chimney walls).
##   floor - a 3-tall pit under 3-5 tiles of floor (fits hallways and any thick
##           ground). Its lid is the floor she walks on.
## The pocket is covered by a FalseWall (fake rock that fades while she's
## inside). A false seal is walked or dropped through; a cracked seal is a
## CrackedWall plug: a sword blow breaks a wall plug, a stomp (down + attack in
## the air, which she has even unarmed) breaks a floor lid. Runs after
## _paint/_populate on the painted tiles, with its own RNG, so the rest of the
## room is untouched.
func _add_secrets() -> void:
	secret_spots.clear()
	if secret_count <= 0 or not ground_layer:
		return
	var srng := RandomNumberGenerator.new()
	srng.seed = hash("secrets:%d" % level_seed)
	var root: Node = entities_root if entities_root else self
	var keep_clear: Array[Vector2i] = []
	for a: Dictionary in anchors.values():
		var spawn: Vector2 = a["spawn"]
		keep_clear.append(Vector2i(int(spawn.x) / TILE, int(spawn.y) / TILE))
	for f in find_spots:
		keep_clear.append(Vector2i(int(f.x) / TILE, int(f.y) / TILE))
	var occupied: Array[Vector2i] = []
	for n in root.get_children():
		if n is Node2D:
			occupied.append(Vector2i(int((n as Node2D).position.x) / TILE, int((n as Node2D).position.y) / TILE))

	# Floor cells she can stand on: [x, y (her feet's air cell), dir], dir -1 /
	# 1 = wall face to the west / east (wall pocket), 0 = floor pocket below.
	var walls: Array = []
	var floors: Array = []
	for y in range(4, height - 2):
		for x in range(3, width - 3):
			if _cell(x, y) != AIR or _cell(x, y - 1) != AIR or _cell(x, y - 2) != AIR or _cell(x, y + 1) != SOLID:
				continue
			floors.append([x, y, 0])
			for dir: int in [-1, 1]:
				if _cell(x + dir, y) == SOLID and _cell(x + dir, y - 1) == SOLID and _cell(x + dir, y - 2) == SOLID:
					walls.append([x, y, dir])
	_shuffle_with(walls, srng)
	_shuffle_with(floors, srng)

	var placed: Array[Vector2i] = []
	var want_wall := true
	while placed.size() < secret_count:
		var plan := _next_secret_plan(walls if want_wall else floors, srng, keep_clear, placed, occupied)
		if plan.is_empty():
			plan = _next_secret_plan(floors if want_wall else walls, srng, keep_clear, placed, occupied)
		if plan.is_empty():
			break
		var cracked := secret_style == SecretStyle.CRACKED \
				or (secret_style == SecretStyle.MIXED and srng.randf() < 0.5)
		_carve_secret(root, plan, cracked, placed.size())
		placed.append(plan["at"])
		want_wall = not want_wall


## Pops candidates until one fits; returns its plan (see _wall_plan /
## _floor_plan), or {} when the list runs dry.
func _next_secret_plan(cands: Array, srng: RandomNumberGenerator, keep_clear: Array[Vector2i],
		placed: Array[Vector2i], occupied: Array[Vector2i]) -> Dictionary:
	while not cands.is_empty():
		var cand: Array = cands.pop_back()
		var at := Vector2i(cand[0], cand[1])
		if _too_close(at, keep_clear, 8) or _too_close(at, placed, 14):
			continue
		var plan := {}
		if cand[2] != 0:
			for depth in range(srng.randi_range(3, 6), 2, -1):
				plan = _wall_plan(at.x, at.y, cand[2], depth)
				if not plan.is_empty():
					break
		else:
			for w in range(srng.randi_range(3, 5), 2, -1):
				plan = _floor_plan(at.x - w / 2, at.y, w)
				if not plan.is_empty():
					break
		if plan.is_empty():
			continue
		var area: Rect2i = plan["area"]
		if occupied.any(func(c: Vector2i) -> bool: return area.has_point(c)):
			continue
		plan["at"] = at
		return plan
	return {}


## A wall pocket beside her feet cell (x, y): columns 1..depth toward `dir`,
## rows y-2..y. Needs rows y-3..y+1 and column depth+1 to be solid,
## unprotected rock inside the room's border. {} if it doesn't fit.
func _wall_plan(x: int, y: int, dir: int, depth: int) -> Dictionary:
	for i in range(1, depth + 2):
		var cx := x + dir * i
		if i <= depth and (cx < 2 or cx > width - 3):
			return {}
		for r in range(y - 3, y + 2):
			if r < 1 or _cell(cx, r) != SOLID or _is_protected(cx, r):
				return {}
	var carve: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []
	var coins: Array[Vector2i] = []
	for i in range(1, depth + 1):
		var cx := x + dir * i
		for r in range(y - 2, y + 1):
			carve.append(Vector2i(cx, r))
		floor_cells.append(Vector2i(cx, y + 1))
	for i in range(depth, 1, -1):
		coins.append(Vector2i(x + dir * i, y - 1))
	var near := mini(x, x + dir * (depth + 1)) # the wall face too: wall crawlers sit there
	return {
		"carve": carve,
		"plug": Rect2i(x + dir, y - 2, 1, 3),
		"floor": floor_cells,
		"coins": coins,
		"back": Vector2((x + dir * depth) * TILE + TILE / 2.0, (y + 1) * TILE),
		"area": Rect2i(near, y - 3, depth + 2, 5),
	}


## A floor pocket under columns x0..x0+w-1, where she stands on row y+1 (the
## lid) and the pit is rows y+2..y+4. Needs the lid to be walkable floor and
## rows y+1..y+5, columns x0-1..x0+w to be solid, unprotected rock. {} if not.
func _floor_plan(x0: int, y: int, w: int) -> Dictionary:
	if x0 - 1 < 1 or x0 + w > width - 2 or y + 4 > height - 3:
		return {}
	for cx in range(x0, x0 + w):
		if _cell(cx, y) != AIR or _cell(cx, y - 1) != AIR or _is_protected(cx, y):
			return {}
	for cx in range(x0 - 1, x0 + w + 1):
		for r in range(y + 1, y + 6):
			if _cell(cx, r) != SOLID or _is_protected(cx, r):
				return {}
	var carve: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []
	var coins: Array[Vector2i] = []
	for cx in range(x0, x0 + w):
		for r in range(y + 1, y + 5):
			carve.append(Vector2i(cx, r))
		floor_cells.append(Vector2i(cx, y + 5))
		coins.append(Vector2i(cx, y + 3))
	return {
		"carve": carve,
		"plug": Rect2i(x0, y + 1, w, 1),
		"floor": floor_cells,
		"coins": coins,
		"back": Vector2((x0 + w / 2) * TILE + TILE / 2.0, (y + 5) * TILE),
		"area": Rect2i(x0 - 1, y - 2, w + 2, 8),
	}


func _carve_secret(root: Node, plan: Dictionary, cracked: bool, index: int) -> void:
	var plug: Rect2i = plan["plug"]
	var cover_cells: Array[Vector2i] = []
	var cover_tiles: Array[Vector2i] = []
	var plug_tiles: Array[Vector2i] = []
	plug_tiles.resize(plug.size.x * plug.size.y)
	for c: Vector2i in plan["carve"]:
		var atlas := ground_layer.get_cell_atlas_coords(c)
		if cracked and plug.has_point(c):
			var k := (c.y - plug.position.y) * plug.size.x + (c.x - plug.position.x)
			plug_tiles[k] = atlas
		else:
			cover_cells.append(c)
			cover_tiles.append(atlas)
		_put(c.x, c.y, AIR)
		_protected[c.y * width + c.x] = 1
		ground_layer.erase_cell(c)
		if background_layer:
			background_layer.set_cell(c, SOURCE_ID, tile_theme.background)
	# The pocket's floor shows its top face once the fake rock fades.
	for c: Vector2i in plan["floor"]:
		ground_layer.set_cell(c, SOURCE_ID, tile_theme.surface)

	var cover := FalseWall.new()
	cover.name = "Secret%d" % (index + 1)
	cover.tile_set = ground_layer.tile_set
	cover.source_id = SOURCE_ID
	cover.cells = cover_cells
	cover.tiles = cover_tiles
	_add_generated(root, cover)
	if cracked:
		var wall := CrackedWall.new()
		wall.name = "Secret%dPlug" % (index + 1)
		wall.tile_set = ground_layer.tile_set
		wall.source_id = SOURCE_ID
		wall.tiles = plug_tiles
		wall.size_tiles = plug.size
		wall.position = Vector2(plug.position * TILE)
		_add_generated(root, wall)

	# The back of the pocket: a find goes here (Level), otherwise coins.
	secret_spots.append(plan["back"])
	if index < secret_find_count or not pickup_scene:
		return
	var coins := 0
	for c: Vector2i in plan["coins"]:
		if coins >= secret_coins:
			break
		if cracked and plug.has_point(c):
			continue
		_spawn_entity(root, pickup_scene, Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0))
		coins += 1


func _shuffle_with(arr: Array, srng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := srng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _add_generated(root: Node, node: Node) -> void:
	node.set_meta("generated", true)
	root.add_child(node)
	if Engine.is_editor_hint() and is_inside_tree():
		node.owner = get_tree().edited_scene_root


func _pick_spread(candidates: Array, count: int, spacing: int, avoid: Array[Vector2i], avoid_dist: int) -> Array:
	var picked: Array = []
	for cell: Vector2i in candidates:
		if picked.size() >= count:
			break
		var ok := true
		for a in avoid:
			if absi(a.x - cell.x) + absi(a.y - cell.y) < avoid_dist:
				ok = false
				break
		if ok:
			for p: Vector2i in picked:
				if absi(p.x - cell.x) + absi(p.y - cell.y) < spacing:
					ok = false
					break
		if ok:
			picked.append(cell)
	return picked


func _spawn_entity(root: Node, scene: PackedScene, pos: Vector2) -> void:
	# In the editor, keep the instance linked to its scene so baking the room
	# (Save As New Level) doesn't save the scene's own signal connections a
	# second time (coins then logged "already connected" on every load).
	var node := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE if Engine.is_editor_hint() \
			else PackedScene.GEN_EDIT_STATE_DISABLED)
	if node is Node2D:
		node.position = pos
	node.set_meta("generated", true)
	root.add_child(node)
	if Engine.is_editor_hint() and is_inside_tree():
		node.owner = get_tree().edited_scene_root


func _clear_generated_entities() -> void:
	var root: Node = entities_root if entities_root else self
	for child in root.get_children():
		if child.has_meta("generated"):
			root.remove_child(child)
			child.queue_free()


## Editor-only convenience: move anchored exits onto their openings so the
## baked scene shows where doors are. The Level does the same at runtime.
func _snap_exits_in_editor() -> void:
	var level := get_parent()
	if not level:
		return
	for child in level.get_children():
		var anchor_name = child.get("anchor")
		if anchor_name is String and anchors.has(anchor_name):
			var rect: Rect2 = anchors[anchor_name]["exit"]
			child.position = rect.get_center()
			child.set("size", rect.size)


# --------------------------------------------------------------------------
# Grid utilities
# --------------------------------------------------------------------------

func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return SOLID
	return _grid[y * width + x]


func _put(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		_grid[y * width + x] = v


func _fill_rect(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(x, y, v)


func _protect_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(0, y0), mini(height, y1 + 1)):
		for x in range(maxi(0, x0), mini(width, x1 + 1)):
			_protected[y * width + x] = 1


func _is_protected(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return true
	return _protected[y * width + x] == 1


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
