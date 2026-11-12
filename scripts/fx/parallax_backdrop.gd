class_name ParallaxBackdrop
extends Node2D
## A realm's deep background: a screen-filling sky gradient that shifts with
## how high the camera has climbed in the level, plus the Parallax2D layers
## under this node (far to near, decreasing distance = rising scroll_scale).
##
## TileTheme.parallax points at a scene with this script at its root; the
## LevelGenerator instances it at runtime and calls `set_bounds()`. Everything
## draws at `z_index` far below the level's tile layers and has no physics.

## Gradient colour at the bottom of the level.
@export var bottom_color := Color(0.08, 0.02, 0.02)
## Gradient colour at the top of the level.
@export var top_color := Color(0.18, 0.05, 0.04)
## Extra darkening from the bottom of the screen to its top (negative lightens
## the top instead), so each screen has a little vertical gradient of its own.
@export_range(-0.5, 0.5) var screen_shade := 0.08
## Height of one stepped gradient band, in world pixels.
@export_range(1, 32) var band_height := 6
## Line the layers' bottom edges up with the bottom of the level, so the first
## screen shows each layer's foot (Valhalla's halls stand on the ground).
@export var anchor_layers_to_bottom := true
## Raise the anchored layers' feet by this many pixels (to clear a thick floor).
@export var anchor_lift := 0.0

var _bounds := Rect2()
var _view := Rect2()
var _layers: Array[Parallax2D] = []


func _ready() -> void:
	z_index = -100
	z_as_relative = false
	for child in get_children():
		if child is Parallax2D:
			# We feed the layers the camera's true top-left ourselves: Parallax2D's
			# own camera tracking offsets by the unzoomed viewport at zoom != 1,
			# which would need many extra repeat copies to cover the screen.
			child.ignore_camera_scroll = true
			_layers.append(child)
	_anchor_layers()


## Level rectangle in world pixels (the generator's grid).
func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	if is_inside_tree():
		_anchor_layers()


func _anchor_layers() -> void:
	if not anchor_layers_to_bottom or _bounds.size == Vector2.ZERO:
		return
	var view_h := _view_size().y
	for layer in _layers:
		if layer.repeat_size.y == 0.0:
			continue
		# A layer pixel at local y shows at screen y = y - cam_top * s + offset.
		# Put the layer tile's bottom (y = repeat_size.y) on the screen's bottom
		# while the camera rests at the bottom of the level.
		var cam_top := _bounds.end.y - view_h
		var offset := view_h - anchor_lift - layer.repeat_size.y + cam_top * layer.scroll_scale.y
		# Wrapped into one tile: Parallax2D only repeats copies near its offset.
		layer.scroll_offset.y = fposmod(offset, layer.repeat_size.y)


func _view_size() -> Vector2:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var cam := vp.get_camera_2d()
	if cam:
		size /= cam.zoom
	return size


func _process(_delta: float) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d()
	var size := _view_size()
	var center := cam.get_screen_center_position() if cam else size / 2.0
	var top_left := center - size / 2.0
	for layer in _layers:
		layer.screen_offset = top_left
	var view := Rect2(top_left, size).grow(2.0)
	if view != _view:
		var resized := view.size != _view.size
		_view = view
		if resized: # first frame with a camera, or the window/zoom changed
			_anchor_layers()
		queue_redraw()


func _draw() -> void:
	if _view.size == Vector2.ZERO:
		return
	var climbed := 0.5
	if _bounds.size.y > 0.0:
		climbed = clampf((_bounds.end.y - _view.get_center().y) / _bounds.size.y, 0.0, 1.0)
	var base := bottom_color.lerp(top_color, climbed)
	# Bands are pinned to the world grid so they don't swim as the camera moves.
	var y := floorf(_view.position.y / band_height) * band_height
	while y < _view.end.y:
		var up := clampf((_view.end.y - y) / _view.size.y, 0.0, 1.0)
		var color := base.darkened(screen_shade * up) if screen_shade >= 0.0 \
				else base.lightened(-screen_shade * up)
		draw_rect(Rect2(_view.position.x, y, _view.size.x, band_height), color)
		y += band_height
