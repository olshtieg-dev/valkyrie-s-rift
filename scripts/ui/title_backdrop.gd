class_name TitleBackdrop
extends Control
## The title screen's living scene, back to front: a dusk sky (stars, moon,
## an aurora), snow peaks, nearer ranges, a pine valley under drifting mist,
## the hill with Yggdrasil (runes and golden apples pulsing), fireflies, falling
## leaves and golden motes, then the dark framing trees in the foreground.
##
## The layer art comes from tools/gen_title_art.py (392px wide: 4px spare each
## side so the layers can drift apart slowly in whole pixels).

const STAGE := Vector2(384, 216)
const DIR := "res://assets/sprites/title/"
const MOUNTAINS_FAR := preload(DIR + "title_mountains_far.png")
const MOUNTAINS_NEAR := preload(DIR + "title_mountains_near.png")
const FOREST := preload(DIR + "title_forest_far.png")
const HILL := preload(DIR + "title_hill.png")
const TREE := preload(DIR + "yggdrasil.png")
const TREE_GLOW := preload(DIR + "yggdrasil_glow.png")
const FRAME := preload(DIR + "title_frame.png")
## Where the tree's canvas sits on the stage.
const TREE_AT := Vector2(118, 0)
## Seconds for one full drift of the parallax layers.
const DRIFT_PERIOD := 40.0

var _t := 0.0
## [layer, drift in px] (layers sit at x = -4 + drift)
var _drifting: Array = []
var _glow: TextureRect
var _sky: DuskSky
var _particles: Wildlife


func _ready() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sky = DuskSky.new()
	_sky.size = STAGE
	add_child(_sky)
	_layer(MOUNTAINS_FAR, 1.0)
	_layer(MOUNTAINS_NEAR, 2.0)
	var mist := Mist.new()
	mist.size = STAGE
	add_child(mist)
	_layer(FOREST, 3.0)
	_layer(HILL, 0.0)
	var shade := Shade.new()
	shade.size = STAGE
	add_child(shade)
	var tree := _texture(TREE, TREE_AT)
	add_child(tree)
	_glow = _texture(TREE_GLOW, TREE_AT)
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_mat
	add_child(_glow)
	_particles = Wildlife.new()
	_particles.size = STAGE
	add_child(_particles)
	_layer(FRAME, -4.0)


func _process(delta: float) -> void:
	_t += delta
	var phase := sin(_t * TAU / DRIFT_PERIOD)
	for d in _drifting:
		(d[0] as Control).position.x = -4.0 + roundf(phase * float(d[1]))
	_glow.modulate.a = 0.55 + 0.45 * sin(_t * 1.6)


func _layer(tex: Texture2D, drift: float) -> void:
	var rect := _texture(tex, Vector2(-4, 0))
	add_child(rect)
	if drift != 0.0:
		_drifting.append([rect, drift])


func _texture(tex: Texture2D, at: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = at
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


## Dusk: deep night at the top, violet, then a sunset ember along the
## horizon behind the peaks, in hard bands with an ordered-dither seam.
## Stars twinkle, a crescent moon hangs over the valley, an aurora ripples.
class DuskSky extends Control:
	const BANDS := [
		Color8(10, 10, 28), Color8(14, 12, 36), Color8(20, 16, 46), Color8(28, 20, 58),
		Color8(40, 26, 70), Color8(58, 34, 84), Color8(84, 44, 94), Color8(118, 58, 100),
		Color8(158, 78, 100), Color8(202, 110, 104), Color8(236, 150, 110), Color8(250, 190, 128),
	]
	## Height the bands span (below that, the hills cover the sky).
	const SPAN := 118.0
	const MOON := Vector2(196, 14)
	const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
	var _stars: Array = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		for i in 120:
			var y := rng.randi_range(0, 92)
			_stars.append([Vector2(rng.randi_range(0, int(size.x)), y), rng.randf() * TAU, rng.randf_range(0.6, 2.4), 1.0 - y / 110.0])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var band_h := SPAN / BANDS.size()
		for i in BANDS.size():
			var y0 := floorf(i * band_h)
			draw_rect(Rect2(0, y0, size.x, ceilf(band_h) + 1), BANDS[i])
		draw_rect(Rect2(0, SPAN, size.x, size.y - SPAN), BANDS[-1])
		# dither each seam: the next band's colour creeps up in a Bayer pattern
		for i in range(1, BANDS.size()):
			var seam := floorf(i * band_h)
			for dy in 4:
				var y := int(seam) - 4 + dy
				for x in int(size.x):
					if BAYER[y % 4][x % 4] < (dy + 1) * 3:
						draw_rect(Rect2(x, y, 1, 1), BANDS[i])
		_draw_aurora()
		for s in _stars:
			var tw: float = 0.5 + 0.5 * sin(_t * s[2] + s[1])
			var c := Color(0.88, 0.88, 1.0, (0.2 + 0.8 * tw) * float(s[3]))
			draw_rect(Rect2(s[0], Vector2.ONE), c)
			if tw > 0.95 and float(s[3]) > 0.6:
				draw_rect(Rect2(s[0] - Vector2(1, 0), Vector2(3, 1)), Color(c, 0.35))
				draw_rect(Rect2(s[0] - Vector2(0, 1), Vector2(1, 3)), Color(c, 0.35))
		_draw_moon()

	func _draw_aurora() -> void:
		# two ribbons: each column a short vertical streak, fading at both ends
		for r in [[18.0, 0.035, 0.7, Color(0.35, 1.0, 0.7)], [34.0, 0.05, -0.5, Color(0.5, 0.75, 1.0)]]:
			var base: float = r[0]
			for x in range(0, int(size.x), 1):
				var fx := float(x)
				var y := base + sin(fx * float(r[1]) + _t * float(r[2])) * 8.0 + sin(fx * 0.013 - _t * 0.3) * 6.0
				var strength := clampf(0.5 + 0.5 * sin(fx * 0.021 + _t * 0.4), 0.0, 1.0) * clampf(1.0 - absf(fx - 230.0) / 200.0, 0.0, 1.0)
				if strength < 0.08:
					continue
				var col: Color = r[3]
				var streak := 6.0 + 10.0 * strength
				for k in 3:
					draw_rect(Rect2(x, roundf(y + k * streak / 3.0), 1, ceilf(streak / 3.0)), Color(col, 0.3 * strength * (1.0 - k * 0.3)))

	func _draw_moon() -> void:
		for h in [[16.0, 0.04], [11.0, 0.06], [8.0, 0.09]]:
			draw_circle(MOON, float(h[0]), Color(0.9, 0.9, 1.0, float(h[1])), true, -1.0, false)
		draw_circle(MOON, 6.0, Color8(236, 232, 214), true, -1.0, false)
		draw_circle(MOON + Vector2(-1, 0), 5.0, Color8(250, 248, 236), true, -1.0, false)
		# craters
		draw_rect(Rect2(MOON + Vector2(1, -3), Vector2(2, 1)), Color8(214, 208, 190))
		draw_rect(Rect2(MOON + Vector2(-3, 1), Vector2(2, 2)), Color8(214, 208, 190))
		draw_rect(Rect2(MOON + Vector2(2, 2), Vector2(1, 1)), Color8(214, 208, 190))


## Thin bands of valley mist sliding slowly past the far forest.
class Mist extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for band in [[150.0, 6.0, 4.0, 0.10], [158.0, 4.0, -6.0, 0.14], [166.0, 5.0, 3.0, 0.12]]:
			var y: float = band[0]
			for x in range(-40, int(size.x) + 40, 4):
				var fx := float(x) + fmod(_t * float(band[2]), 40.0)
				var a := float(band[3]) * (0.6 + 0.4 * sin(fx * 0.05 + y))
				var h := float(band[1]) * (0.7 + 0.3 * sin(fx * 0.031))
				draw_rect(Rect2(roundf(fx), roundf(y - h / 2.0), 4, roundf(h)), Color(0.72, 0.68, 0.86, a))


## Fireflies blinking over the meadow, leaves drifting down from the crown, and
## golden motes rising up the trunk (the climb, from Hel to the summit).
class Wildlife extends Control:
	const CROWN := Rect2(150, 20, 230, 90)
	var _rng := RandomNumberGenerator.new()
	var _flies: Array = []
	var _leaves: Array = []
	var _motes: Array = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.seed = 9
		for i in 22:
			_flies.append([Vector2(_rng.randf_range(0, size.x), _rng.randf_range(150, 208)), _rng.randf() * TAU, _rng.randf_range(0.5, 1.3)])
		for i in 9:
			_leaves.append(_new_leaf(true))
		for i in 18:
			_motes.append(_new_mote(true))

	func _new_leaf(anywhere: bool) -> Array:
		var p := Vector2(_rng.randf_range(CROWN.position.x, CROWN.end.x), _rng.randf_range(CROWN.position.y + 40, CROWN.end.y))
		if anywhere:
			p.y = _rng.randf_range(CROWN.end.y, size.y)
		return [p, _rng.randf_range(8.0, 15.0), _rng.randf() * TAU, _rng.randi_range(0, 2)]

	func _new_mote(anywhere: bool) -> Array:
		var x := _rng.randf_range(244.0, 292.0)
		var y := _rng.randf_range(40.0, size.y) if anywhere else size.y - 10.0
		return [Vector2(x, y), _rng.randf_range(6.0, 13.0), _rng.randf() * TAU]

	func _process(delta: float) -> void:
		_t += delta
		for f in _flies:
			f[1] += delta * float(f[2])
			f[0] += Vector2(cos(f[1] * 0.7), sin(f[1] * 1.3)) * 4.0 * delta
		for i in _leaves.size():
			var l: Array = _leaves[i]
			l[2] += delta * 2.2
			l[0] += Vector2(sin(l[2]) * 10.0 - 3.0, float(l[1])) * delta
			if l[0].y > size.y:
				_leaves[i] = _new_leaf(false)
		for i in _motes.size():
			var m: Array = _motes[i]
			m[0].y -= float(m[1]) * delta
			m[2] += delta
			if m[0].y < 20.0:
				_motes[i] = _new_mote(false)
		queue_redraw()

	func _draw() -> void:
		for f in _flies:
			var blink := sin(float(f[1]) * 3.0)
			if blink < 0.2:
				continue
			var p: Vector2 = (f[0] as Vector2).round()
			draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), Color(0.8, 1.0, 0.4, 0.18 * blink))
			draw_rect(Rect2(p, Vector2.ONE), Color(0.92, 1.0, 0.6, blink))
		for l in _leaves:
			var p: Vector2 = (l[0] as Vector2).round()
			var cols := [Color8(76, 146, 82), Color8(138, 196, 108), Color8(232, 176, 112)]
			var col: Color = cols[int(l[3])]
			var flip := sin(float(l[2])) > 0.0
			draw_rect(Rect2(p, Vector2(2, 1) if flip else Vector2(1, 2)), col)
		for m in _motes:
			var p: Vector2 = m[0] + Vector2(sin(float(m[2])) * 3.0, 0)
			var a := clampf((p.y - 20.0) / 60.0, 0.0, 1.0)
			draw_rect(Rect2(p.round(), Vector2.ONE), Color(1.0, 0.85, 0.4, a))


## A soft dark falloff on the left, behind the title and menu, so the text
## reads over the mountains and forest.
class Shade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for x in range(0, 176, 4):
			var a := 0.42 * pow(1.0 - x / 176.0, 1.5)
			draw_rect(Rect2(x, 0, 4, size.y), Color(0.03, 0.02, 0.07, a))
