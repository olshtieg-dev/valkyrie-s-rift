extends Level
## Hub for development. Built in code so it grows with LevelRegistry:
##   - jump-height ladder (one-way platforms 3/5/7/9 tiles up)
##   - lava strip to test hazard respawn
##   - training pen with slimes
##   - one portal per registered level, grouped by realm (W / Up / E to enter)

const ROWS := 18
const FLOOR_ROW := 15
const SURFACE := Vector2i(2, 0)
const FILL := Vector2i(3, 1)
const PLATFORM := Vector2i(10, 1)
const LAVA_TOP := Vector2i(4, 13)
const LAVA := Vector2i(4, 14)
const BACKDROP := Vector2i(3, 1)
const PORTAL_START_X := 52
const PORTAL_STEP := 7
const PEN_MOBS := [
	preload("res://scenes/enemies/crawler.tscn"),
	preload("res://scenes/enemies/hopper.tscn"),
	preload("res://scenes/enemies/charger.tscn"),
]
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

@export var background: TileMapLayer


func _build() -> void:
	var levels: Array = []
	for level: Dictionary in LevelRegistry.LEVELS:
		if level["id"] != level_id:
			levels.append(level)
	var width := PORTAL_START_X + levels.size() * PORTAL_STEP + 4

	# Shell
	for y in ROWS:
		for x in width:
			if background:
				background.set_cell(Vector2i(x, y), 0, BACKDROP)
			if x < 2 or x >= width - 2 or y < 2 or y >= FLOOR_ROW:
				_tile(x, y, SURFACE if y == FLOOR_ROW and x >= 2 and x < width - 2 else FILL)

	# Jump-height ladder
	var heights := [3, 5, 7, 9]
	for i in heights.size():
		var x0 := 4 + i * 5
		var row: int = FLOOR_ROW - heights[i]
		for x in range(x0, x0 + 3):
			_tile(x, row, PLATFORM)
		_world_label("%d" % heights[i], Vector2((x0 + 1.5) * TILE, row * TILE - 12), Color(1, 1, 1, 0.7))
	_world_label("jump height (tiles)", Vector2(13 * TILE, 3 * TILE), Color(1, 1, 1, 0.5))

	# Lava strip
	for x in range(25, 29):
		_tile(x, FLOOR_ROW, LAVA_TOP)
		_tile(x, FLOOR_ROW + 1, LAVA)
	_world_label("hazard", Vector2(27 * TILE, (FLOOR_ROW - 2) * TILE), Color(1, 0.6, 0.4, 0.7))

	# Training pen
	for x in [31, 46]:
		_tile(x, FLOOR_ROW - 1, SURFACE)
		_tile(x, FLOOR_ROW - 2, SURFACE)
	var pen_x := [35, 39, 43]
	for i in PEN_MOBS.size():
		var mob: Node2D = PEN_MOBS[i].instantiate()
		mob.position = Vector2(pen_x[i] * TILE + TILE / 2.0, FLOOR_ROW * TILE - 11)
		add_child(mob)
	_world_label("training  (F1 > Spawn for more)", Vector2(38.5 * TILE, (FLOOR_ROW - 6) * TILE), Color(1, 1, 1, 0.5))

	# Portals
	spawns["default"] = Vector2(49 * TILE + TILE / 2.0, FLOOR_ROW * TILE)
	_world_label("W / Up / E to enter", Vector2(49.5 * TILE, (FLOOR_ROW - 5) * TILE), Color(1, 1, 1, 0.5))
	var last_realm := ""
	for i in levels.size():
		var level: Dictionary = levels[i]
		var realm_info := LevelRegistry.realm(level["realm"])
		var color: Color = realm_info.get("color", Color.WHITE)
		var x := PORTAL_START_X + i * PORTAL_STEP
		if level["realm"] != last_realm:
			last_realm = level["realm"]
			_world_label(String(realm_info.get("name", last_realm)).to_upper(), Vector2((x + 1) * TILE, 4 * TILE), color)
		var portal := LevelExit.new()
		portal.name = "Portal_%s" % level["id"]
		portal.target_level = level["id"]
		portal.requires_interact = true
		portal.show_frame = true
		portal.frame_color = color
		portal.label_text = level["name"]
		portal.size = Vector2(2 * TILE, 3 * TILE)
		portal.position = Vector2((x + 1) * TILE, FLOOR_ROW * TILE - 1.5 * TILE)
		add_child(portal)


func _tile(x: int, y: int, atlas: Vector2i) -> void:
	ground.set_cell(Vector2i(x, y), 0, atlas)


func _world_label(text: String, center: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 10)
	label.position = center - Vector2(80, 5)
	add_child(label)
