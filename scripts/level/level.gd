class_name Level
extends Node2D
## Root script for every playable room. On load it:
##   1. runs the LevelGenerator if the room isn't baked yet,
##   2. collects spawn points (generator anchors + SpawnPoint nodes),
##   3. snaps anchored LevelExits onto their openings,
##   4. walls off the room's edges and adds a kill floor below it,
##   5. spawns the player, camera and HUD at the requested spawn.
## Every level scene can be run on its own with F6.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const TILE := 16
const CAMERA_ZOOM := Vector2(3, 3)
const BOUNDS_THICKNESS := 64.0

@export var level_id: String = ""
@export var display_name: String = ""
@export var realm: String = ""
## Spawn used when arriving without a specific target (debug warp, F6).
@export var default_spawn: String = "default"
## Put a Valkyrie shrine (armory + barter) beside the entrance spawn.
@export var place_shrine: bool = true

@export_group("Atmosphere")
@export var clear_color: Color = Color(0.08, 0.07, 0.1)
## Tints the whole room (not the HUD). White = no tint.
@export var ambient_color: Color = Color.WHITE

@export_group("Nodes")
## Tile layer that defines the room's extent (and the collision).
@export var ground: TileMapLayer
@export var generator: LevelGenerator

var player: CharacterBody2D
var hud: CanvasLayer
var bounds_rect: Rect2
var spawns: Dictionary = {} # String -> Vector2 (feet position, level-local)


func _ready() -> void:
	_build()
	_collect_spawns()
	_place_exits()
	if place_shrine:
		_place_shrine()
	bounds_rect = _compute_bounds()
	_create_bounds(bounds_rect)
	_apply_atmosphere()
	_spawn_player()
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	LevelManager.register_level(self)


## Override in subclasses that build their geometry in code (see debug_room.gd).
func _build() -> void:
	if generator:
		_configure_detours()
		generator.generate_if_needed()
		_place_side_route_find()


## The registry says what this level's side route holds ("find") and what
## plugs its other detours ("gate"); the generator lays them out.
func _configure_detours() -> void:
	var entry := LevelRegistry.find(level_id)
	generator.reserve_find_spot = entry.has("find")
	generator.find_count = maxi(LevelRegistry.finds_of(entry).size(), 1)
	match entry.get("gate", ""):
		"vine": generator.side_room_gate = LevelGenerator.Gate.VINE
		"slime": generator.side_room_gate = LevelGenerator.Gate.SLIME


## Each find rests at the far end of its own detour: a pedestal (sword or
## armor), a heart vessel, or an ability shrine ("ability:<id>"). Taken finds
## stay taken (each remembers, keyed by this level + its name: the first is
## "SideRouteFind", later ones "SideRouteFind2", ...).
func _place_side_route_find() -> void:
	var finds := LevelRegistry.finds_of(LevelRegistry.find(level_id))
	for i in mini(finds.size(), generator.find_spots.size()):
		var find: String = finds[i]
		var node: Node2D
		if find == "heart_container":
			node = HeartVessel.new()
		elif find.begins_with("ability:"):
			var shrine := AbilityShrine.new()
			shrine.ability = StringName(find.trim_prefix("ability:"))
			node = shrine
		else:
			var item: Resource = load(find)
			var pedestal := SwordPedestal.new()
			pedestal.weapon = item as WeaponData
			pedestal.armor = item as ArmorData
			node = pedestal
		node.name = "SideRouteFind" if i == 0 else "SideRouteFind%d" % (i + 1)
		node.position = generator.find_spots[i]
		add_child(node)


func announce() -> void:
	if hud and hud.has_method("show_title"):
		var realm_info := LevelRegistry.realm(realm)
		var prefix: String = realm_info.get("name", "")
		hud.show_title("%s — %s" % [prefix, display_name] if prefix != "" else display_name)


## Damage type of this room's hazard tiles, for armor resistance: Hel's pools
## are lava (fire); elsewhere they're poison/bog (physical).
func hazard_element() -> Hit.Element:
	return Hit.Element.FIRE if realm == "hel" else Hit.Element.NONE


## The element this realm's creatures carry: Hel burns, the sky freezes,
## Valhalla's storm shocks. Yggdrasil's are plain. Spitters' globs and the
## touch of `elemental_touch` enemies use it, so armor matters by realm.
func realm_element() -> Hit.Element:
	match realm:
		"hel": return Hit.Element.FIRE
		"sky": return Hit.Element.ICE
		"valhalla": return Hit.Element.THUNDER
	return Hit.Element.NONE


func get_spawn_position(spawn_id: String) -> Vector2:
	for key in [spawn_id, default_spawn, "default"]:
		if key != "" and spawns.has(key):
			return spawns[key]
	if not spawns.is_empty():
		return spawns.values()[0]
	push_warning("Level %s has no spawn points; spawning at origin." % level_id)
	return Vector2.ZERO


# --------------------------------------------------------------------------

func _collect_spawns() -> void:
	if generator:
		for anchor_name: String in generator.anchors:
			spawns[anchor_name] = generator.anchors[anchor_name]["spawn"]
	for node in find_children("*", "Marker2D", true, false):
		if node is SpawnPoint:
			spawns[String(node.spawn_id)] = to_local(node.global_position)


## Beside the spawn she enters from below ("start" or "south"), on solid
## floor with headroom, a couple of tiles to the side if there's room.
func _place_shrine() -> void:
	var entrance := Vector2.INF
	for key in ["start", "south", default_spawn, "default"]:
		if spawns.has(key):
			entrance = spawns[key]
			break
	if entrance == Vector2.INF:
		return
	var at := entrance
	for dx in [-32.0, 32.0, -16.0, 16.0]:
		if _standable(entrance + Vector2(dx, 0)):
			at = entrance + Vector2(dx, 0)
			break
	var shrine := Shrine.new()
	shrine.name = "Shrine"
	shrine.position = at
	add_child(shrine)


## Feet at `feet`: a tile directly below, and two empty tiles above.
func _standable(feet: Vector2) -> bool:
	if not ground:
		return false
	var cell := ground.local_to_map(ground.to_local(to_global(feet + Vector2(0, 1))))
	return ground.get_cell_source_id(cell) != -1 \
			and ground.get_cell_source_id(cell + Vector2i.UP) == -1 \
			and ground.get_cell_source_id(cell + Vector2i.UP * 2) == -1


func _place_exits() -> void:
	for node in find_children("*", "Area2D", true, false):
		if not (node is LevelExit) or node.anchor == "":
			continue
		if generator and generator.anchors.has(node.anchor):
			node.set_rect(generator.anchors[node.anchor]["exit"])
		else:
			push_warning("%s: exit '%s' wants anchor '%s', but that opening isn't enabled on the generator." \
					% [level_id, node.name, node.anchor])
			node.process_mode = Node.PROCESS_MODE_DISABLED


func _compute_bounds() -> Rect2:
	if not ground:
		push_warning("Level %s has no ground layer; camera and bounds are unlimited." % level_id)
		return Rect2(-100000, -100000, 200000, 200000)
	if generator:
		# The generator's grid is the room, including open sky with no tiles in it.
		return Rect2(ground.position, Vector2(generator.width, generator.height) * TILE)
	var used := ground.get_used_rect()
	return Rect2(Vector2(used.position * TILE) + ground.position, Vector2(used.size * TILE))


## Invisible walls left/right/top so nothing leaves the room except through
## exits, and a kill floor underneath that returns the player to safe ground.
func _create_bounds(rect: Rect2) -> void:
	var t := BOUNDS_THICKNESS
	var walls := StaticBody2D.new()
	walls.name = "LevelBounds"
	walls.collision_layer = 1
	walls.collision_mask = 0
	for r in [
		Rect2(rect.position.x - t, rect.position.y - t, t, rect.size.y + t * 2), # left
		Rect2(rect.end.x, rect.position.y - t, t, rect.size.y + t * 2), # right
		Rect2(rect.position.x - t, rect.position.y - t, rect.size.x + t * 2, t), # top
	]:
		walls.add_child(_rect_shape(r))
	add_child(walls)

	var kill := Area2D.new()
	kill.name = "KillFloor"
	kill.collision_layer = 0
	kill.collision_mask = 2 # player
	kill.monitorable = false
	kill.add_child(_rect_shape(Rect2(rect.position.x - t * 4, rect.end.y + 48, rect.size.x + t * 8, t)))
	kill.body_entered.connect(func(body: Node2D) -> void:
		if body.has_method("respawn_from_hazard"):
			body.respawn_from_hazard(1))
	add_child(kill)


func _rect_shape(r: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = r.size
	shape.shape = rect_shape
	shape.position = r.get_center()
	return shape


func _apply_atmosphere() -> void:
	RenderingServer.set_default_clear_color(clear_color)
	if ambient_color != Color.WHITE:
		var modulate_node := CanvasModulate.new()
		modulate_node.color = ambient_color
		add_child(modulate_node)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = get_spawn_position(LevelManager.spawn_id)
	var camera := Camera2D.new()
	camera.zoom = CAMERA_ZOOM
	camera.position = Vector2(0, -7)
	camera.position_smoothing_enabled = true
	camera.limit_left = int(bounds_rect.position.x)
	camera.limit_top = int(bounds_rect.position.y)
	camera.limit_right = int(bounds_rect.end.x)
	camera.limit_bottom = int(bounds_rect.end.y)
	player.add_child(camera)
	add_child(player)
	camera.reset_smoothing()
