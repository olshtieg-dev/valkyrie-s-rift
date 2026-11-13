class_name LoadingScreen
extends Control
## Full-screen loading card LevelManager shows between levels.
##
## A realm-themed backdrop (Hel's ember glow and jagged rock, Yggdrasil's
## hanging roots, the Sky Realm's cloud banks, Valhalla's gold rays over its
## halls) with drifting particles, a knotwork title plate holding the realm
## and room name, a row of runes that light up as the level loads with her
## feather riding the progress head, and a rotating gameplay tip.
##
## Everything is drawn on a whole-pixel grid. One grid pixel is `unit()`
## screen pixels (3 at the default 1152x648 window, matching the level
## camera's 3x zoom). The dithered glow is a shader that works per grid pixel;
## the static silhouettes are baked once per realm into a grid-sized image drawn
## at that integer scale with nearest filtering; and the font is drawn at
## multiples of 8 with antialiasing off, so it all stays crisp like the rest of
## the game.
##
## Public API used by LevelManager: `show_for(info)`, `progress`, `hide_card()`.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const BACKDROP := Color(0.035, 0.03, 0.045)
const PLATE := Color(0.02, 0.017, 0.028, 0.9)
const TEXT := Color(0.94, 0.92, 0.87)
const DIM := Color(0.6, 0.59, 0.66)
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)
## Runes in the progress row (one per twelfth of the load).
const PIPS := 12
## Seconds a tip stays up before the next one, on a slow load.
const TIP_INTERVAL := 3.5
const FADE := 0.12
## Seconds for the room name to type in, letter by letter.
const REVEAL := 0.28
## Seconds a freshly lit rune flashes white.
const RUNE_FLASH := 0.14

## Short, accurate hints. Keep them in line with input_setup.gd / project.godot,
## and leave out the interact button (it's becoming "press up").
const TIPS := [
	"Once her wings are mended, jump again while falling to flutter.",
	"Hold jump for a higher leap.",
	"Hold down while falling to drop faster.",
	"Down + jump on a thin platform drops through it.",
	"Hold up while attacking to slash overhead.",
	"Down + attack in the air: a meteor strike.",
	"Each sword changes how she jumps and flutters.",
	"Switch swords with Q / R, or the triggers on a pad.",
	"Side routes hide swords, armor and abilities.",
	"Coins barter for gear at Valkyrie shrines.",
	"Armor can shrug off an element's damage.",
	"Not every wall is solid. Cracked rock gives way to a blow or a stomp.",
]

## The feather, quill on the left: '#' vane, '+' realm-tinted vane, 'S' shaft,
## 'q' quill. The gaps in the vane are where it's split, like her wings.
const FEATHER := [
	"..............####....",
	"......############.#..",
	"qqqSSSSSSSSSSSSSSSSSS#",
	"...+++++++++++.+++++..",
	".....++++++++++.+++...",
	"........+++++++.......",
]

## Elder Futhark, 5x7: fehu uruz thurisaz ansuz raidho kaunan gebo wunjo
## hagalaz naudiz algiz, ending on tiwaz, the up-arrow: the climb.
const RUNES := [
	["#..#.", "#.#..", "##..#", "#..#.", "#.#..", "##...", "#...."],
	["###..", "#..#.", "#...#", "#...#", "#...#", "#...#", "#...#"],
	["#....", "##...", "#.#..", "#..#.", "#.#..", "##...", "#...."],
	["##...", "#.#..", "##.#.", "#.#..", "#..#.", "#....", "#...."],
	["##...", "#.#..", "#..#.", "#.#..", "##...", "#.#..", "#..#."],
	[".....", "...#.", "..#..", ".#...", "..#..", "...#.", "....."],
	["#...#", ".#.#.", ".#.#.", "..#..", ".#.#.", ".#.#.", "#...#"],
	["#....", "##...", "#.#..", "##...", "#....", "#....", "#...."],
	["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	["..#..", "..#..", "..##.", ".##..", "..#..", "..#..", "..#.."],
	["#.#.#", "#.#.#", ".###.", "..#..", "..#..", "..#..", "..#.."],
	["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "..#.."],
]

## Corner knot of the title plate, centred on the corner.
const KNOT := [
	"...#...",
	"..#.#..",
	".#.#.#.",
	"#.#.#.#",
	".#.#.#.",
	"..#.#..",
	"...#...",
]

## The dithered realm glow behind everything, per grid pixel on the GPU:
## a gradient in the realm colour shaped per realm, a vignette, then a 4x4
## ordered dither down to a few flat tones so it reads as pixel art.
const GLOW_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size;
uniform float unit = 3.0;
uniform vec2 grid = vec2(384.0, 216.0);
uniform vec4 backdrop;
uniform vec4 glow;
uniform int mode = 0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 origin = floor((rect_size - grid * unit) / 2.0);
	vec2 g = floor((UV * rect_size - origin) / unit);
	vec2 f = (g + 0.5) / grid;
	float t;
	if (mode == 1) { // Hel: lava light from below.
		t = pow(f.y, 2.4) * 0.62 + pow(f.y, 6.0) * 0.25;
	} else if (mode == 2) { // Yggdrasil: green below, a soft shaft from above.
		t = pow(f.y, 2.2) * 0.42 + max(0.0, 1.0 - length(vec2(f.x - 0.5, f.y * 1.6)) * 2.2) * 0.22;
	} else if (mode == 3) { // Sky: open light above.
		t = pow(1.0 - f.y, 1.6) * 0.62 + pow(f.y, 3.0) * 0.16;
	} else if (mode == 4) { // Valhalla: gold rays fanning down from above.
		vec2 d = vec2((f.x - 0.5) * grid.x / grid.y, f.y + 0.15);
		float rays = 0.55 + 0.45 * sin(atan(d.x, d.y) * 13.0);
		t = max(0.0, 1.0 - length(d) / 1.15) * (0.35 + 0.35 * rays) + pow(f.y, 4.0) * 0.3;
	} else {
		t = pow(f.y, 2.0) * 0.25;
	}
	float v = length(vec2((f.x - 0.5) * 1.6, (f.y - 0.5) * 1.9));
	t -= clamp((v - 0.55) * 0.55, 0.0, 0.4);
	ivec2 b = ivec2(mod(g, 4.0));
	float q = floor(t * 7.0 + BAYER[b.y * 4 + b.x] / 16.0) / 7.0;
	COLOR = q >= 0.0 ? mix(backdrop, glow, q) : mix(backdrop, vec4(0.0, 0.0, 0.0, 1.0), min(1.0, -q * 1.6));
}
"""
const MODES := {"hel": 1, "yggdrasil": 2, "sky": 3, "valhalla": 4}

## Baked silhouettes, "realm:w:h" -> ImageTexture. Shared by every card.
static var _bg_cache := {}

## Shown progress, 0..1.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		var lit := int(progress * PIPS + 0.0001)
		for i in range(_lit, mini(lit, PIPS)):
			_lit_at[i] = _t
		_lit = maxi(_lit, mini(lit, PIPS))
		queue_redraw()

var _font: Font
var _realm_id := ""
var _realm_name := ""
var _level_name := ""
var _color := Color.WHITE
var _tip := 0
var _t := 0.0
var _tip_t := 0.0
var _parts: Array = [] # [x 0..1, y 0..1, speed, phase, kind]
var _lit := 0
var _lit_at: Array = []
var _tween: Tween
var _glow: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var crisp := FONT.duplicate() as FontFile
	if crisp:
		crisp.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		crisp.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		crisp.hinting = TextServer.HINTING_NONE
		_font = crisp
	else:
		_font = FONT
	_lit_at.resize(PIPS)
	_glow = ColorRect.new()
	_glow.show_behind_parent = true
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = GLOW_SHADER
	_glow.material = ShaderMaterial.new()
	(_glow.material as ShaderMaterial).shader = shader
	add_child(_glow)
	visible = false
	set_process(false)


## Show the card for a LevelRegistry entry and fade it in.
func show_for(level_info: Dictionary) -> void:
	_realm_id = level_info.get("realm", "")
	var realm_info := LevelRegistry.realm(_realm_id)
	_realm_name = String(realm_info.get("name", "")).to_upper()
	_level_name = level_info.get("name", level_info.get("id", ""))
	_color = realm_info.get("color", TEXT)
	_tip = randi() % TIPS.size()
	_t = 0.0
	_tip_t = 0.0
	_lit = 0
	_lit_at.fill(-1.0)
	progress = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_info.get("id", ""))
	_parts.clear()
	for i in 44:
		_parts.append([rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4), rng.randf() * TAU, rng.randi() % 4])
	visible = true
	set_process(true)
	queue_redraw()
	_fade_to(1.0)


## Fade the card out; returns when it's gone.
func hide_card() -> void:
	if not visible:
		return
	await _fade_to(0.0)
	visible = false
	set_process(false)


## Screen pixels per grid pixel.
func unit() -> int:
	return maxi(1, int(size.y / 216.0))


func _fade_to(alpha: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, FADE)
	await _tween.finished


func _process(delta: float) -> void:
	_t += delta
	_tip_t += delta
	if _tip_t >= TIP_INTERVAL:
		_tip_t = 0.0
		_tip = (_tip + 1) % TIPS.size()
	queue_redraw()


func _draw() -> void:
	var p := unit()
	var grid := Vector2i(int(size.x) / p, int(size.y) / p)
	if grid.x < 8 or grid.y < 8:
		return
	var origin := ((size - Vector2(grid * p)) / 2.0).floor()
	var mat := _glow.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("unit", float(p))
	mat.set_shader_parameter("grid", Vector2(grid))
	mat.set_shader_parameter("backdrop", BACKDROP)
	mat.set_shader_parameter("glow", _color.darkened(0.3))
	mat.set_shader_parameter("mode", MODES.get(_realm_id, 0))
	var cx := grid.x / 2
	var cy := grid.y / 2

	draw_texture_rect(_backdrop(grid), Rect2(origin, Vector2(grid * p)), false)
	_draw_particles(origin, p, grid)

	var small := 8 * p
	var big := 16 * p

	# Title plate: knotwork frame, realm name set into the top border, room
	# name typed in letter by letter.
	var lw := _text_units(_level_name, big, p)
	var pw := maxi(lw + 44, 156)
	pw += pw % 2
	var top := cy - 56
	var x0 := cx - pw / 2
	var ph := 34
	_px(origin, p, Vector2i(x0, top), Vector2i(pw, ph), PLATE)
	var rw := _spaced_units(_realm_name, small, p, 2)
	var notch := Vector2i(cx - rw / 2 - 9, cx + rw / 2 + 9) if _realm_name != "" else Vector2i(cx, cx)
	_braid(origin, p, x0 + 5, x0 + pw - 5, top - 1, notch)
	_braid(origin, p, x0 + 5, x0 + pw - 5, top + ph - 2, Vector2i(cx, cx))
	var side := _color.darkened(0.5)
	var inner := _color.darkened(0.78)
	for x: int in [x0, x0 + pw - 1]:
		_px(origin, p, Vector2i(x, top + 4), Vector2i(1, ph - 8), side)
	_px(origin, p, Vector2i(x0 + 2, top + 4), Vector2i(1, ph - 8), inner)
	_px(origin, p, Vector2i(x0 + pw - 3, top + 4), Vector2i(1, ph - 8), inner)
	for corner: Vector2i in [Vector2i(x0, top), Vector2i(x0 + pw - 1, top),
			Vector2i(x0, top + ph - 1), Vector2i(x0 + pw - 1, top + ph - 1)]:
		_glyph(origin, p, KNOT, corner - Vector2i(3, 3), _color)
	if _realm_name != "":
		_px(origin, p, Vector2i(notch.x + 1, top - 5), Vector2i(notch.y - notch.x - 1, 11), PLATE)
		_diamond(origin, p, Vector2i(notch.x + 3, top), _color)
		_diamond(origin, p, Vector2i(notch.y - 3, top), _color)
		_text_spaced(origin, p, cx - rw / 2, top + 4, _realm_name, small, 2, _color)
	_reveal(origin, p, cx - lw / 2, top + 25, big)

	# Rune row: each rune lights as its share of the load lands; her feather
	# rides the head of it.
	var ry := top + ph + 30
	var step := 9
	var row := PIPS * step - 4
	var rx := cx - row / 2
	_px(origin, p, Vector2i(rx - 22, ry + 3), Vector2i(14, 1), _color.darkened(0.6))
	_px(origin, p, Vector2i(rx + row + 8, ry + 3), Vector2i(14, 1), _color.darkened(0.6))
	_diamond(origin, p, Vector2i(rx - 6, ry + 3), _color.darkened(0.3))
	_diamond(origin, p, Vector2i(rx + row + 5, ry + 3), _color.darkened(0.3))
	var halo := Color(_color.darkened(0.55), 0.7)
	for i in PIPS:
		var at := Vector2i(rx + i * step, ry)
		if i < _lit:
			var age: float = _t - _lit_at[i]
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_glyph(origin, p, RUNES[i], at + d, halo)
			_glyph(origin, p, RUNES[i], at, Color.WHITE if age < RUNE_FLASH else _color.lightened(0.15))
		elif i == _lit and int(_t * 6.0) % 2 == 0:
			_glyph(origin, p, RUNES[i], at, _color.darkened(0.45))
		else:
			_glyph(origin, p, RUNES[i], at, _color.darkened(0.74))
	var head := rx + int(round(progress * row))
	_draw_feather(origin, p, head, ry - 9)

	# Tip under a small ornament, word-wrapped and centred near the bottom.
	var lines := _wrap(TIPS[_tip], small, p, grid.x - 40)
	var y0 := grid.y - 42 - (lines.size() - 1) * 11
	var oy := y0 - 17
	_px(origin, p, Vector2i(cx - 30, oy), Vector2i(24, 1), _color.darkened(0.62))
	_px(origin, p, Vector2i(cx + 7, oy), Vector2i(24, 1), _color.darkened(0.62))
	_diamond(origin, p, Vector2i(cx, oy), _color.darkened(0.2))
	var a := clampf(_tip_t / 0.2, 0.0, 1.0) if _t > TIP_INTERVAL else 1.0
	for i in lines.size():
		var tw := _text_units(lines[i], small, p)
		_text(origin, p, cx - tw / 2, y0 + i * 11 + 1, lines[i], small, Color(SHADOW, a))
		_text(origin, p, cx - tw / 2, y0 + i * 11, lines[i], small, Color(DIM, a))


# --- title --------------------------------------------------------------------

## The room name, typed in over REVEAL seconds: each letter drops in one grid
## pixel, flashes in the realm colour, then settles to white.
func _reveal(origin: Vector2, p: int, x: int, baseline: int, font_size: int) -> void:
	var n := _level_name.length()
	var deep := _color.darkened(0.72)
	for i in n:
		var ch := _level_name[i]
		var born := REVEAL * float(i) / maxf(1.0, float(n))
		var age := _t - born
		if age < 0.0:
			continue
		var cx := x + _text_units(_level_name.substr(0, i), font_size, p)
		var dy := -1 if age < 0.05 else 0
		var c := TEXT if age > 0.12 else _color.lightened(0.35)
		_text(origin, p, cx, baseline + 1, ch, font_size, deep)
		_text(origin, p, cx, baseline + dy, ch, font_size, c)


## A chain of 4-wide links along y..y+2 from x0 to x1, skipping `gap` (x range).
func _braid(origin: Vector2, p: int, x0: int, x1: int, y: int, gap: Vector2i) -> void:
	var edge := _color.darkened(0.42)
	var mid := _color.darkened(0.1)
	_px(origin, p, Vector2i(x0, y - 1), Vector2i(x1 - x0, 5), PLATE)
	for x in range(x0, x1):
		if x >= gap.x and x <= gap.y:
			continue
		var k := (x - x0) % 4
		if k == 1 or k == 2:
			_px(origin, p, Vector2i(x, y), Vector2i.ONE, edge)
			_px(origin, p, Vector2i(x, y + 2), Vector2i.ONE, edge)
		else:
			_px(origin, p, Vector2i(x, y + 1), Vector2i.ONE, mid if k == 0 else edge)


func _diamond(origin: Vector2, p: int, at: Vector2i, color: Color) -> void:
	_px(origin, p, at + Vector2i(0, -1), Vector2i(1, 3), color)
	_px(origin, p, at + Vector2i(-1, 0), Vector2i(3, 1), color)


func _glyph(origin: Vector2, p: int, rows: Array, at: Vector2i, color: Color) -> void:
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] == "#":
				_px(origin, p, at + Vector2i(x, y), Vector2i.ONE, color)


## A feather bobbing above the rune row. It never rotates: each tilt is a
## sheared copy of the pixel map, so every pixel stays on the grid.
func _draw_feather(origin: Vector2, p: int, cx: int, cy: int) -> void:
	var phase := _t * 2.2
	var lean := cos(phase)
	var tilt := 0 if absf(lean) < 0.45 else (1 if lean > 0.0 else -1)
	var w: int = FEATHER[0].length()
	var fx := cx - w / 2
	var fy := cy - int(round((sin(phase) * 0.5 + 0.5) * 2.0))
	var tint := Color.WHITE.lerp(_color, 0.45)
	for row in FEATHER.size():
		var line: String = FEATHER[row]
		for x in line.length():
			var ch := line[x]
			if ch == ".":
				continue
			var c := Color.WHITE
			match ch:
				"+": c = tint
				"S": c = Color(0.78, 0.82, 0.92)
				"q": c = Color(0.52, 0.55, 0.66)
			var dy := floori((x - w / 2) * tilt / 6.0)
			_px(origin, p, Vector2i(fx + x, fy + row - 2 + dy), Vector2i.ONE, c)


# --- particles ----------------------------------------------------------------

func _draw_particles(origin: Vector2, p: int, grid: Vector2i) -> void:
	var w := float(grid.x)
	var h := float(grid.y)
	for i in _parts.size():
		var m: Array = _parts[i]
		var sx: float = m[0]
		var sy: float = m[1]
		var sp: float = m[2]
		var ph: float = m[3]
		var kind: int = m[4]
		match _realm_id:
			"hel":
				# Embers: rise from the glow, cooling from yellow to deep red.
				var y := h - fmod(sy * h + _t * sp * 16.0, h + 8.0)
				var x := sx * w + sin(_t * 1.6 + ph) * 3.0
				var life := clampf(y / h, 0.0, 1.0)
				var c := Color(1.0, 0.85, 0.45).lerp(_color, clampf((1.0 - life) * 1.6, 0.0, 1.0))
				c = c.lerp(_color.darkened(0.6), clampf((0.6 - life) * 2.0, 0.0, 1.0))
				if int(_t * 10.0 + ph * 5.0) % 7 == 0:
					c = c.darkened(0.4)
				var s := Vector2i(2, 1) if kind == 0 and life > 0.5 else Vector2i.ONE
				_px(origin, p, Vector2i(int(x), int(y)), s, c)
			"yggdrasil":
				if kind < 3:
					# Leaves: fall and tumble.
					var y := fmod(sy * h + _t * sp * 9.0, h + 8.0) - 4.0
					var x := sx * w + sin(_t * 1.1 + ph) * 7.0
					var c := _color.darkened(0.25) if kind == 0 else (
							_color.darkened(0.5) if kind == 1 else Color(0.78, 0.74, 0.32))
					match int(_t * 4.0 + ph) % 4:
						0: _px(origin, p, Vector2i(int(x), int(y)), Vector2i(2, 1), c)
						1: _px(origin, p, Vector2i(int(x), int(y)), Vector2i(1, 2), c)
						2: _px(origin, p, Vector2i(int(x), int(y)), Vector2i(2, 1), c.darkened(0.2))
						_: _px(origin, p, Vector2i(int(x), int(y)), Vector2i.ONE, c)
				else:
					# Fireflies: drift up and blink.
					var y := h - fmod(sy * h + _t * sp * 5.0, h + 4.0)
					var x := sx * w + sin(_t * 0.8 + ph) * 5.0
					if sin(_t * 2.5 + ph * 3.0) > -0.2:
						_px(origin, p, Vector2i(int(x), int(y)), Vector2i.ONE, Color(0.86, 0.95, 0.55))
			"sky":
				if kind < 2:
					# Wisps of cloud sliding past.
					var len := 6 + int(sp * 10.0)
					var x := fmod(sx * (w + 40.0) + _t * sp * 10.0, w + 40.0) - 20.0
					var y := 6.0 + sy * (h - 12.0)
					_px(origin, p, Vector2i(int(x), int(y)), Vector2i(len, 1), Color(0.85, 0.92, 1.0, 0.12 + 0.1 * kind))
				else:
					# Motes rising with the updraft.
					var y := h - fmod(sy * h + _t * sp * 8.0, h + 4.0)
					var x := sx * w + sin(_t + ph) * 4.0
					_px(origin, p, Vector2i(int(x), int(y)), Vector2i.ONE, Color(0.92, 0.96, 1.0, 0.6))
			"valhalla":
				# Gold motes rising slowly, some twinkling into little stars.
				var y := h - fmod(sy * h + _t * sp * 6.0, h + 4.0)
				var x := sx * w + sin(_t * 0.9 + ph) * 3.0
				var at := Vector2i(int(x), int(y))
				var tw := sin(_t * 3.0 + ph * 4.0)
				if kind == 0 and tw > 0.7:
					_px(origin, p, at + Vector2i(-1, 0), Vector2i(3, 1), _color)
					_px(origin, p, at + Vector2i(0, -1), Vector2i(1, 3), _color)
					_px(origin, p, at, Vector2i.ONE, Color.WHITE)
				else:
					_px(origin, p, at, Vector2i.ONE, Color(_color, 0.45 + 0.4 * maxf(tw, 0.0)))
			_:
				var y := h - fmod(sy * h + _t * sp * 9.0, h + 4.0)
				_px(origin, p, Vector2i(int(sx * w), int(y)), Vector2i.ONE, Color(_color, 0.35))


# --- baked backdrop -------------------------------------------------------------

func _backdrop(grid: Vector2i) -> Texture2D:
	var key := "%s:%d:%d" % [_realm_id, grid.x, grid.y]
	if not _bg_cache.has(key):
		_bg_cache[key] = ImageTexture.create_from_image(_bake(grid))
	return _bg_cache[key]


## The realm's silhouettes at one texel per grid pixel, transparent elsewhere
## (the glow under them is the shader's).
func _bake(grid: Vector2i) -> Image:
	var w := grid.x
	var h := grid.y
	var glow := _color.darkened(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_realm_id)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var near := Color(0.015, 0.012, 0.02)
	var far := BACKDROP.lerp(glow, 0.22)
	var rim := _color.darkened(0.25)
	match _realm_id:
		"hel":
			_fill_heights(img, _ridge(rng, w, 13, 14, 30), far, Color(), true)
			_fill_heights(img, _ridge(rng, w, 8, 4, 18), near, rim, true)
			_fill_drips(img, rng, near.lerp(far, 0.4), 18)
		"yggdrasil":
			var mound := PackedInt32Array()
			var bumps := _ridge(rng, w, 20, 2, 8)
			for x in w:
				mound.append(10 + int(4.0 * sin(x * 0.045)) + bumps[x])
			_fill_heights(img, _ridge(rng, w, 24, 16, 28), far, Color(), true)
			_fill_heights(img, mound, near, rim.darkened(0.2), true)
			_fill_roots(img, rng, near, far)
		"sky":
			_fill_heights(img, _clouds(rng, w, 26, 10, 18), BACKDROP.lerp(_color, 0.12), BACKDROP.lerp(_color, 0.2), true)
			_fill_heights(img, _clouds(rng, w, 14, 8, 14), BACKDROP.lerp(_color, 0.2), BACKDROP.lerp(_color, 0.34), true)
			for i in 70:
				var sx := rng.randi_range(0, w - 1)
				var sy := rng.randi_range(0, h / 2)
				img.set_pixel(sx, sy, Color(1.0, 1.0, 1.0, rng.randf_range(0.15, 0.5)))
		"valhalla":
			_fill_heights(img, _halls(w), near, rim, true)
			# The great hall's door stands open, spilling gold.
			for y in range(h - 14, h):
				for x in range(w / 2 - 3, w / 2 + 3):
					img.set_pixel(x, y, _color if y > h - 13 else _color.darkened(0.3))
			for y in range(h - 9, h):
				for x in range(w / 2 - 7, w / 2 + 7):
					if absi(x - w / 2) >= 3 and (x + y) % 2 == 0 and absi(x - w / 2) - 3 < (y - (h - 9)):
						img.set_pixel(x, y, _color.darkened(0.55))
	return img


## Jagged ridge heights: peaks every `period` x, linear between, with jitter.
func _ridge(rng: RandomNumberGenerator, w: int, period: int, lo: int, hi: int) -> PackedInt32Array:
	var pts := []
	for i in w / period + 2:
		pts.append(rng.randi_range(lo, hi) if i % 2 == 0 else rng.randi_range(lo, (lo + hi) / 2))
	var out := PackedInt32Array()
	for x in w:
		var k := x / period
		var f := float(x % period) / float(period)
		out.append(int(lerpf(pts[k], pts[k + 1], f)) + rng.randi_range(0, 1))
	return out


## Puffy cloud-bank heights: the max of a row of overlapping circles.
func _clouds(rng: RandomNumberGenerator, w: int, base: int, rlo: int, rhi: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(w)
	out.fill(base - 6)
	var x := -10
	while x < w + 10:
		var r := rng.randi_range(rlo, rhi)
		for dx in range(-r, r + 1):
			var ix := x + dx
			if ix >= 0 and ix < w:
				out[ix] = maxi(out[ix], base - r / 2 + int(sqrt(float(r * r - dx * dx))))
		x += rng.randi_range(r / 2, r + 4)
	return out


## Valhalla's skyline: a palisade of spear points, two side halls and a great
## hall in the middle with crossed gable horns.
func _halls(w: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cx := w / 2
	for x in w:
		var hgt := 12 + (2 if x % 3 == 1 else 0)
		for hall: Vector3i in [Vector3i(cx, 46, 34), Vector3i(cx - 112, 28, 22), Vector3i(cx + 112, 28, 22)]:
			var dx := absi(x - hall.x)
			if dx <= hall.y:
				hgt = maxi(hgt, hall.z - int(dx * 0.42))
			# Crossed horns above the gable peak.
			if dx >= 1 and dx <= 6:
				hgt = maxi(hgt, hall.z + 6 - absi(dx - 3) * 2)
		out.append(hgt)
	return out


## Fill each column from the bottom up to its height; optional rim on top.
func _fill_heights(img: Image, heights: PackedInt32Array, color: Color, rim: Color, use_rim: bool) -> void:
	var h := img.get_height()
	for x in img.get_width():
		var top := clampi(h - heights[x], 0, h)
		img.fill_rect(Rect2i(x, top, 1, h - top), color)
		if use_rim and rim.a > 0.0 and top < h:
			img.set_pixel(x, top, rim)


## Stalactites hanging from the top edge.
func _fill_drips(img: Image, rng: RandomNumberGenerator, color: Color, count: int) -> void:
	var w := img.get_width()
	for i in count:
		var x := rng.randi_range(0, w - 1)
		var length := rng.randi_range(5, 22)
		var half := rng.randi_range(2, 4)
		for y in length:
			var hw := int(round(half * (1.0 - float(y) / length)))
			for dx in range(-hw, hw + 1):
				if x + dx >= 0 and x + dx < w:
					img.set_pixel(x + dx, y, color)
	for x in w:
		img.set_pixel(x, 0, color)
		img.set_pixel(x, 1, color)


## Roots of the world tree hanging in wavy strands from the top.
func _fill_roots(img: Image, rng: RandomNumberGenerator, near: Color, far: Color) -> void:
	var w := img.get_width()
	for i in 26:
		var x0 := rng.randf_range(0.0, w)
		var length := rng.randi_range(12, 70)
		var phase := rng.randf() * TAU
		var thick := 2 if length > 40 else 1
		var c := near if i % 2 == 0 else far
		for y in length:
			var x := int(x0 + sin(y * 0.12 + phase) * 3.0)
			var tw := thick if y < length * 0.6 else 1
			for dx in tw:
				if x + dx >= 0 and x + dx < w:
					img.set_pixel(x + dx, y, c)
	for x in w:
		for y in 3:
			img.set_pixel(x, y, near)


# --- text & pixels --------------------------------------------------------------

func _px(origin: Vector2, p: int, at: Vector2i, cells: Vector2i, color: Color) -> void:
	draw_rect(Rect2(origin + Vector2(at * p), Vector2(cells * p)), color)


func _text(origin: Vector2, p: int, x: int, baseline: int, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, origin + Vector2(x * p, baseline * p), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Text with `spacing` extra grid pixels between letters.
func _text_spaced(origin: Vector2, p: int, x: int, baseline: int, text: String, font_size: int, spacing: int, color: Color) -> void:
	var at := x
	for ch in text:
		_text(origin, p, at, baseline + 1, ch, font_size, SHADOW)
		_text(origin, p, at, baseline, ch, font_size, color)
		at += _text_units(ch, font_size, p) + spacing


func _spaced_units(text: String, font_size: int, p: int, spacing: int) -> int:
	var total := 0
	for ch in text:
		total += _text_units(ch, font_size, p) + spacing
	return maxi(0, total - spacing)


## Width of `text` in grid pixels.
func _text_units(text: String, font_size: int, p: int) -> int:
	return ceili(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / p)


func _wrap(text: String, font_size: int, p: int, max_units: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var attempt := word if line == "" else line + " " + word
		if line != "" and _text_units(attempt, font_size, p) > max_units:
			lines.append(line)
			line = word
		else:
			line = attempt
	if line != "":
		lines.append(line)
	return lines
