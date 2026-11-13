class_name BootIntroFX
extends RefCounted
## Code-drawn effects for the intro cutscene (BootIntro): rain, lightning,
## blood, afterimages, sword arcs, sparks, fire, the light beam. All pixel
## crisp (whole-pixel rects, no rotation of pixel art).

const BLOOD := Color(0.72, 0.06, 0.08)
const BLOOD_DARK := Color(0.42, 0.03, 0.06)


## Slanted rain over the whole screen, splashing on the ground line.
## Screen space. `clear_from`..`clear_to` (screen x) stays dry: the light beam.
class Rain extends Node2D:
	var area := Vector2(384, 216)
	var ground_y := 184.0
	var intensity := 1.0
	var wind := -70.0
	var clear_from := 0.0
	var clear_to := 0.0
	var _drops: Array = [] # [pos, speed, len]
	var _splashes: Array = [] # [pos, age]
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 99
		for i in 170:
			_drops.append([Vector2(_rng.randf_range(-40, area.x + 40), _rng.randf_range(-20, area.y)), _rng.randf_range(260, 360), _rng.randi_range(4, 8)])

	func _process(delta: float) -> void:
		for d in _drops:
			var p: Vector2 = d[0]
			p += Vector2(wind, d[1]) * delta
			if p.y > ground_y + _rng.randf_range(0, 24):
				if p.y < ground_y + 3 and _splashes.size() < 60:
					_splashes.append([Vector2(roundf(p.x), ground_y), 0.0])
				p = Vector2(_rng.randf_range(-20, area.x + 60), _rng.randf_range(-30, -4))
			d[0] = p
		for s in _splashes:
			s[1] += delta
		_splashes = _splashes.filter(func(s: Array) -> bool: return s[1] < 0.18)
		queue_redraw()

	func _draw() -> void:
		var count := int(_drops.size() * intensity)
		var slope := wind / 300.0
		for i in count:
			var d: Array = _drops[i]
			var p: Vector2 = d[0]
			if clear_to > clear_from and p.x > clear_from and p.x < clear_to:
				continue
			var n: int = d[2]
			var c := Color(0.62, 0.68, 0.86, 0.45 if i % 3 else 0.7)
			for k in n:
				draw_rect(Rect2(roundf(p.x - slope * k), roundf(p.y - k), 1, 1), c)
		for s in _splashes:
			var p: Vector2 = s[0]
			if clear_to > clear_from and p.x > clear_from and p.x < clear_to:
				continue
			var k: float = s[1] / 0.18
			var c := Color(0.7, 0.76, 0.92, 0.7 * (1.0 - k))
			var w := 1.0 + roundf(k * 2.0)
			draw_rect(Rect2(p.x - w, p.y - 1 - roundf(k * 2.0), 1, 1), c)
			draw_rect(Rect2(p.x + w, p.y - 1 - roundf(k * 2.0), 1, 1), c)


## One forked lightning bolt from the top of the screen down to `end`.
class Bolt extends Node2D:
	var end := Vector2(200, 160)
	var _points: PackedVector2Array
	var _forks: Array = []
	var _t := 0.0
	const LIFE := 0.28

	func _ready() -> void:
		_points = _jagged(Vector2(end.x + randf_range(-60, 60), -4), end, 14)
		for i in 2:
			var from := _points[randi_range(3, 8)]
			_forks.append(_jagged(from, from + Vector2(randf_range(-50, 50), randf_range(30, 60)), 6))

	func _jagged(a: Vector2, b: Vector2, steps: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in steps + 1:
			var t := float(i) / steps
			var p := a.lerp(b, t)
			if i > 0 and i < steps:
				p.x += randf_range(-9, 9)
			pts.append(p.round())
		return pts

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# flickers: on, off, on, fade
		var on := _t < 0.05 or (_t > 0.09 and _t < 0.2)
		if not on:
			return
		var a := 1.0 if _t < 0.2 else 1.0 - (_t - 0.2) / (LIFE - 0.2)
		draw_polyline(_points, Color(0.6, 0.7, 1.0, 0.5 * a), 3.0)
		draw_polyline(_points, Color(1, 1, 1, a), 1.0)
		for f in _forks:
			draw_polyline(f, Color(0.85, 0.9, 1.0, 0.8 * a), 1.0)


## Blood: droplets that arc, fall and leave splats on the ground. World space.
class Gore extends Node2D:
	var ground_y := 184.0
	var _drops: Array = [] # [pos, vel, size, color]
	var _stains: Array = [] # [pos, width, color]

	func spray(at: Vector2, dir: float, amount: int = 14, power: float = 1.0) -> void:
		for i in amount:
			var angle := randf_range(-2.4, -0.4) if dir == 0.0 else (randf_range(-1.1, 0.2) if dir > 0.0 else randf_range(PI - 0.2, PI + 1.1))
			var v := Vector2.from_angle(angle) * randf_range(50.0, 170.0) * power
			_drops.append([at + Vector2(randf_range(-2, 2), randf_range(-2, 2)), v, randi_range(1, 2), BLOOD if randf() < 0.7 else BLOOD_DARK])

	func _process(delta: float) -> void:
		for d in _drops:
			d[1].y += 420.0 * delta
			d[0] += d[1] * delta
			if d[0].y >= ground_y:
				if _stains.size() < 160:
					_stains.append([Vector2(roundf(d[0].x), ground_y + randi_range(0, 2)), randi_range(1, 3), d[3]])
				d[2] = 0
		_drops = _drops.filter(func(d: Array) -> bool: return d[2] > 0)
		queue_redraw()

	func _draw() -> void:
		for s in _stains:
			draw_rect(Rect2(s[0], Vector2(s[1], 1)), s[2])
		for d in _drops:
			var p: Vector2 = d[0]
			draw_rect(Rect2(p.round(), Vector2(d[2], d[2])), d[3])


## Bright metal sparks (blocked blows, armor hits). World space, self-freeing.
class Sparks extends Node2D:
	var count := 9
	var _bits: Array = []
	var _t := 0.0

	func _ready() -> void:
		for i in count:
			_bits.append([Vector2.ZERO, Vector2.from_angle(randf() * TAU) * randf_range(60, 150)])

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.3:
			queue_free()
		for b in _bits:
			b[1].y += 300.0 * delta
			b[0] += b[1] * delta
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / 0.3
		draw_rect(Rect2(-2, -2, 5, 5), Color(1, 1, 0.8, maxf(0.0, 1.0 - _t / 0.06)))
		for b in _bits:
			draw_rect(Rect2(b[0].round(), Vector2.ONE), Color(1, 0.9, 0.5, a))


## An afterimage of a sprite, fading in place.
class Ghost extends Sprite2D:
	var life := 0.22

	func _ready() -> void:
		modulate = Color(0.6, 0.85, 1.0, 0.55)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, life)
		tween.tween_callback(queue_free)


## Sword arc. kind: "cut" (overhead, forward), "rise" (upward), "spin" (full ring),
## "plunge" (big downward crescent).
class Slash extends Node2D:
	var kind := "cut"
	var radius := 14.0
	var _t := 0.0
	const LIFE := 0.15

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var col := Color(1, 1, 1, 1.0 - k)
		var warm := Color(1, 0.9, 0.6, 0.6 * (1.0 - k))
		match kind:
			"spin":
				draw_arc(Vector2.ZERO, radius + k * 4.0, 0.0, TAU, 24, col, 2.0)
				draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 20, warm, 1.0)
			"rise":
				draw_arc(Vector2.ZERO, radius, 0.4, -1.9, 10, col, 2.0)
				draw_arc(Vector2.ZERO, radius - 3.0, 0.2, -1.5, 8, warm, 1.0)
			"plunge":
				draw_arc(Vector2.ZERO, radius, -2.6, -0.5, 14, col, 3.0)
				draw_arc(Vector2.ZERO, radius - 4.0, -2.4, -0.7, 12, warm, 2.0)
			_:
				draw_arc(Vector2.ZERO, radius, -2.0, 0.9, 10, col, 2.0)
				draw_arc(Vector2.ZERO, radius - 3.0, -1.6, 0.6, 8, warm, 1.0)


## A speed line streak left behind by a dash.
class Streak extends Node2D:
	var length := 40.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.2:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / 0.2
		draw_rect(Rect2(minf(0.0, length), -12, absf(length), 1), Color(1, 1, 1, 0.8 * a))
		draw_rect(Rect2(minf(0.0, length) + absf(length) * 0.2, -6, absf(length) * 0.7, 1), Color(0.7, 0.9, 1, 0.6 * a))
		draw_rect(Rect2(minf(0.0, length) + absf(length) * 0.4, -18, absf(length) * 0.5, 1), Color(0.7, 0.9, 1, 0.5 * a))


## Flickering fire on a burning roof, plus its glow. World space.
class Fire extends Node2D:
	var width := 20.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.03 * sin(_t * 9.0)
		draw_circle(Vector2(0, -4), width * 2.2, Color(1, 0.45, 0.15, 0.05 + pulse * 0.5))
		draw_circle(Vector2(0, -4), width * 1.3, Color(1, 0.5, 0.2, 0.07 + pulse))
		var n := int(width / 2.0)
		for i in n:
			var x := -width / 2.0 + i * 2.0
			var h := 4.0 + 6.0 * absf(sin(_t * 7.0 + i * 1.7)) + 3.0 * absf(sin(_t * 13.0 + i))
			draw_rect(Rect2(x, -h, 2, h), Color(1, 0.42, 0.1))
			draw_rect(Rect2(x, -h * 0.6, 2, h * 0.6), Color(1, 0.78, 0.25))
		# embers drifting up
		for i in 6:
			var y := -fposmod(_t * 22.0 + i * 9.0, 50.0)
			var x := roundf(sin(_t * 2.0 + i * 3.1) * width * 0.6)
			draw_rect(Rect2(x, roundf(y) - 8, 1, 1), Color(1, 0.6, 0.2, 1.0 + y / 50.0))


## Her sword, drawn in pixels pointing along +x from the grip.
class Sword extends Node2D:
	var glint := 0.0

	func _draw() -> void:
		draw_rect(Rect2(-3, -1, 3, 2), Color(0.45, 0.29, 0.2))      # grip
		draw_rect(Rect2(-4, -1, 1, 2), Color(0.96, 0.73, 0.22))     # pommel
		draw_rect(Rect2(0, -3, 1, 6), Color(0.96, 0.73, 0.22))      # guard
		draw_rect(Rect2(1, -1, 12, 2), Color(0.78, 0.8, 0.88))      # blade
		draw_rect(Rect2(1, -1, 12, 1), Color(0.97, 0.97, 1.0))      # edge light
		draw_rect(Rect2(13, -1, 1, 1), Color(0.97, 0.97, 1.0))      # tip
		if glint > 0.0:
			draw_rect(Rect2(1, -2, 13, 4), Color(1, 1, 1, glint * 0.6))


## The warlord's greatsword, pointing along +x from the grip: black steel,
## a red-hot edge.
class GreatSword extends Node2D:
	var glow := 0.0

	func _draw() -> void:
		draw_rect(Rect2(-5, -1, 5, 2), Color(0.28, 0.16, 0.14))     # grip
		draw_rect(Rect2(-6, -2, 1, 4), Color(0.67, 0.46, 0.16))     # pommel
		draw_rect(Rect2(0, -4, 2, 8), Color(0.67, 0.46, 0.16))      # guard
		draw_rect(Rect2(2, -2, 22, 4), Color(0.16, 0.14, 0.2))      # blade
		draw_rect(Rect2(2, -1, 22, 1), Color(0.36, 0.34, 0.44))     # fuller light
		draw_rect(Rect2(2, 1, 22, 1), Color(0.75, 0.12, 0.1))       # red edge
		draw_rect(Rect2(24, -1, 2, 2), Color(0.16, 0.14, 0.2))      # tip
		if glow > 0.0:
			draw_rect(Rect2(2, -3, 24, 6), Color(1, 0.3, 0.2, glow * 0.5))


## A soft column of light from the sky, in hard pixel bands, with motes.
class Beam extends Node2D:
	var height := 184.0
	var _t := 0.0

	func _ready() -> void:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.2)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for band in [[16.0, 0.10], [11.0, 0.14], [7.0, 0.22], [3.0, 0.35]]:
			var w: float = band[0]
			draw_rect(Rect2(-w, 0, w * 2.0, height), Color(1.0, 0.92, 0.65, band[1]))
		for i in 12:
			var y := fposmod(height - (_t * 18.0 + i * 23.0), height)
			var x := roundf(sin(i * 2.3 + _t) * 9.0)
			draw_rect(Rect2(x, roundf(y), 1, 1), Color(1, 0.95, 0.7, 0.8))
		draw_rect(Rect2(-20, height - 2, 40, 2), Color(1.0, 0.92, 0.65, 0.25))
