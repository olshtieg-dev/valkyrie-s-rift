extends Level
## Debug test room for the Magigonne (scripts/combat/magigonne.gd). Built in
## code like debug_room.gd. Entering grants the gun, so it works straight
## from the debug warp. Left to right:
##   - portal back to the Debug Room, the Magigonne's ability shrine (to test
##     the find banner) and a mana well that refills the bar while you stand in it
##   - sword pedestals (ice rapier, flame greatsword, thunder hammer): shots
##     take the active sword's element, the hammer's are heavy
##   - the range: mobs on the floor, on a high ledge, in the air, and an
##     armored charger (shots clink off unless they're heavy)
##   - bank shot: a mob tucked behind a pillar under a low ceiling
##   - recoil climb: ledges 10, 13 and 16 tiles up (shoot straight down in
##     the air to kick yourself higher)
##   - elements: a vine wall to burn from afar, then a slime boulder to freeze
##     and shatter
## Switches, more mobs and toys go here later.

const ROWS := 26
const FLOOR_ROW := 23
const WIDTH := 88
const SURFACE := Vector2i(2, 0)
const FILL := Vector2i(3, 1)
const PLATFORM := Vector2i(10, 1)
const BACKDROP := Vector2i(3, 1)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const CRAWLER := preload("res://scenes/enemies/crawler.tscn")
const HOPPER := preload("res://scenes/enemies/hopper.tscn")
const CHARGER := preload("res://scenes/enemies/charger.tscn")
const FLYER := preload("res://scenes/enemies/flyer.tscn")
const RAPIER := preload("res://data/weapons/ice_rapier.tres")
const FLAME := preload("res://data/weapons/flame_greatsword.tres")
const HAMMER := preload("res://data/weapons/thunder_hammer.tres")
## Floor mobs stand this far above the floor line (as in debug_room.gd).
const MOB_LIFT := 11.0
const NOTE := Color(1, 1, 1, 0.5)
const SEIDR := Color(0.85, 0.75, 1.0, 0.8)

@export var background: TileMapLayer


func _build() -> void:
	GameManager.grant_ability(Magigonne.ABILITY)

	# Shell
	for y in ROWS:
		for x in WIDTH:
			if background:
				background.set_cell(Vector2i(x, y), 0, BACKDROP)
			if x < 2 or x >= WIDTH - 2 or y < 2 or y >= FLOOR_ROW:
				_tile(x, y, SURFACE if y == FLOOR_ROW and x >= 2 and x < WIDTH - 2 else FILL)

	_build_entry()
	_build_pedestals()
	_build_range()
	_build_bank_shot()
	_build_recoil_climb()
	_build_elements()


## Portal home, the find, the mana well and the controls.
func _build_entry() -> void:
	spawns["default"] = Vector2(6 * TILE + TILE / 2.0, FLOOR_ROW * TILE)
	var portal := LevelExit.new()
	portal.name = "Portal_debug_room"
	portal.target_level = "debug_room"
	portal.requires_interact = true
	portal.show_frame = true
	portal.frame_color = LevelRegistry.realm("debug").get("color", Color.WHITE)
	portal.label_text = "Debug Room"
	portal.size = Vector2(2 * TILE, 3 * TILE)
	portal.position = Vector2(3 * TILE, FLOOR_ROW * TILE - 1.5 * TILE)
	add_child(portal)

	var shrine := AbilityShrine.new()
	shrine.name = "MagigonneShrine"
	shrine.ability = Magigonne.ABILITY
	shrine.position = Vector2(9.5 * TILE, FLOOR_ROW * TILE)
	add_child(shrine)

	var well := ManaWell.new()
	well.name = "ManaWell"
	well.position = Vector2(12 * TILE, FLOOR_ROW * TILE)
	add_child(well)
	_world_label("mana well", Vector2(12 * TILE, (FLOOR_ROW - 2) * TILE), SEIDR)

	_world_label("MAGIGONNE RANGE", Vector2(8 * TILE, 4 * TILE), SEIDR)
	_world_label("hold F / R1 to aim, let go to fire", Vector2(8 * TILE, 5 * TILE), NOTE)
	_world_label("aim mode: F1 > Controller setup", Vector2(8 * TILE, 6 * TILE), NOTE)


## Swap swords to change the shots' element.
func _build_pedestals() -> void:
	var swords := [RAPIER, FLAME, HAMMER]
	for i in swords.size():
		var pedestal := SwordPedestal.new()
		pedestal.name = "RangePedestal%d" % i
		pedestal.weapon = swords[i]
		pedestal.position = Vector2((16.5 + i * 2) * TILE, FLOOR_ROW * TILE)
		add_child(pedestal)
	_world_label("shots take the sword's element", Vector2(18.5 * TILE, (FLOOR_ROW - 4) * TILE), NOTE)


## Targets at every height, and one in armor.
func _build_range() -> void:
	_world_label("range", Vector2(31 * TILE, 4 * TILE), SEIDR)
	_mob(CRAWLER, Vector2(31.5 * TILE, FLOOR_ROW * TILE - MOB_LIFT))
	_mob(CHARGER, Vector2(38.5 * TILE, FLOOR_ROW * TILE - MOB_LIFT))
	_world_label("armored: only heavy (hammer) shots crack it", Vector2(38.5 * TILE, (FLOOR_ROW - 3) * TILE), NOTE)
	# High ledge with a hopper on it.
	var ledge_row := FLOOR_ROW - 8
	for x in range(26, 30):
		_tile(x, ledge_row, PLATFORM)
	_mob(HOPPER, Vector2(28 * TILE, ledge_row * TILE - MOB_LIFT))
	_world_label("up high", Vector2(28 * TILE, (ledge_row - 3) * TILE), NOTE)
	_mob(FLYER, Vector2(35 * TILE, (FLOOR_ROW - 10) * TILE))
	_world_label("in the air", Vector2(35 * TILE, (FLOOR_ROW - 13) * TILE), NOTE)


## A pillar hides a crawler; a low ceiling lets a shot bounce down onto it.
func _build_bank_shot() -> void:
	var ceiling_row := FLOOR_ROW - 11
	for x in range(43, 56):
		for y in range(2, ceiling_row + 1):
			_tile(x, y, FILL)
	var pillar_x := 49
	for y in range(FLOOR_ROW - 6, FLOOR_ROW):
		_tile(pillar_x, y, FILL)
	_mob(CRAWLER, Vector2(52.5 * TILE, FLOOR_ROW * TILE - MOB_LIFT))
	_world_label("bank it off the ceiling", Vector2(46 * TILE, (ceiling_row + 2) * TILE), NOTE)


## Ledges 10, 13 and 16 tiles up, alternating sides of an open shaft.
func _build_recoil_climb() -> void:
	_world_label("recoil climb", Vector2(61 * TILE, (FLOOR_ROW - 3) * TILE), SEIDR)
	_world_label("in the air, shoot straight down", Vector2(61 * TILE, (FLOOR_ROW - 2) * TILE), NOTE)
	var ledges := [[57, 10], [63, 13], [57, 16]]
	for ledge: Array in ledges:
		var x0: int = ledge[0]
		var row: int = FLOOR_ROW - int(ledge[1])
		for x in range(x0, x0 + 3):
			_tile(x, row, PLATFORM)
		_world_label("%d" % ledge[1], Vector2((x0 + 1.5) * TILE, (row - 1) * TILE), Color(1, 1, 1, 0.7))


## A vine wall to burn from a distance, then a tunnel plugged by a slime
## boulder (ice shot freezes it, a heavy shot shatters it).
func _build_elements() -> void:
	var vine_x := 69
	_world_label("elements", Vector2(vine_x * TILE, 4 * TILE), SEIDR)
	for y in range(2, FLOOR_ROW - 4):
		_tile(vine_x, y, FILL)
	var vines := VineWall.new()
	vines.name = "RangeVineWall"
	vines.size_tiles = Vector2i(1, 4)
	vines.position = Vector2(vine_x * TILE, (FLOOR_ROW - 4) * TILE)
	add_child(vines)
	_world_label("burn it from afar (flame)", Vector2((vine_x - 3) * TILE, (FLOOR_ROW - 6) * TILE), Color(1, 0.6, 0.35, 0.7))

	for x in range(vine_x + 1, vine_x + 12):
		for y in range(2, FLOOR_ROW - 2):
			_tile(x, y, FILL)
	var boulder := SlimeBoulder.new()
	boulder.name = "RangeSlimeBoulder"
	boulder.position = Vector2((vine_x + 6) * TILE, FLOOR_ROW * TILE)
	add_child(boulder)
	_world_label("slime: freeze (rapier), shatter (hammer)", Vector2((vine_x - 4) * TILE, (FLOOR_ROW - 5) * TILE), Color(0.7, 0.9, 1.0, 0.7))
	_world_label("end", Vector2((vine_x + 14.5) * TILE, (FLOOR_ROW - 4) * TILE), NOTE)


func _mob(scene: PackedScene, at: Vector2) -> void:
	var mob: Node2D = scene.instantiate()
	mob.position = at
	add_child(mob)


func _tile(x: int, y: int, atlas: Vector2i) -> void:
	ground.set_cell(Vector2i(x, y), 0, atlas)


func _world_label(text: String, center: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(220, 10)
	label.position = center - Vector2(110, 5)
	add_child(label)


## Debug fixture: a shimmering pool that keeps her bar full while she stands
## in it. Origin = floor center, 2 tiles wide.
class ManaWell extends Area2D:
	const HALF_WIDTH := 16.0
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2 # player
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(HALF_WIDTH * 2.0, 20)
		shape.shape = rect
		shape.position = Vector2(0, -10)
		add_child(shape)
		z_index = -1

	func _physics_process(delta: float) -> void:
		_t += delta
		for body in get_overlapping_bodies():
			var gun := Magigonne.of(body)
			if gun and gun.mana < gun.max_mana:
				gun.add_mana(gun.max_mana)
				Sfx.play(&"mana", -1.0, -4.0, 1.25)
		queue_redraw()

	func _draw() -> void:
		var tint := Color(0.72, 0.58, 1.0)
		draw_rect(Rect2(-HALF_WIDTH, -2, HALF_WIDTH * 2.0, 2), Color(tint, 0.7))
		draw_rect(Rect2(-HALF_WIDTH, -1, HALF_WIDTH * 2.0, 1), Color(tint.lerp(Color.WHITE, 0.4), 0.8))
		for i in 6:
			var y := fmod(_t * 14.0 + i * 5.0, 22.0)
			var x := -HALF_WIDTH + 3.0 + fmod(i * 11.0, HALF_WIDTH * 2.0 - 6.0)
			draw_rect(Rect2(Vector2(x, -3.0 - y).round(), Vector2.ONE), Color(tint, 0.8 * (1.0 - y / 22.0)))
