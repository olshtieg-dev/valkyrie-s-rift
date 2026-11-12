class_name DeathSequence
extends Node2D
## Player death: the world freezes, the armor shakes while everything else
## fades to black, then it bursts into feathers and reveals the girl inside.
## A throwback to the classic suit-off reveal. Runs in real time while the
## tree is paused; press jump/attack after the reveal to skip ahead.
##
##   0.0  freeze, knight shakes harder and harder, background fades out
##   0.95 white flash, armor bursts into feathers, girl appears
##   1.55 she sways, then topples backward to the left and lies still
##   2.5  she starts to sink, slowly, then plunges off the bottom of the screen
##   3.9  fade to black, then `finished` (the player reloads the level)

signal finished

## Bigger than the knight on purpose: the world is blacked out by the reveal,
## so she gets a bigger, detailed sprite (28x24, feet on the bottom row).
const GIRL_TEXTURE := preload("res://assets/sprites/valkyrie/fallen_valkyrie.png")
const SHAKE_TIME := 0.95
const FADE_TIME := 0.8
const HOLD_UNTIL := 3.9
const SINK_DELAY := 0.4      # lies still this long after landing
const SINK_TIME := 1.3
const SINK_DISTANCE := 160.0 # past the bottom edge at the default zoom
const FALL_AT := 1.55
const FALL_TIME := 0.4
## Lying on her back the sprite's left side is the bottom; lift so her hair
## (not the raised wing, which can dip past it) rests on the ground.
const LYING_LIFT := 7.0
## Where her head lands once she has tipped over (for the dust puff).
const HEAD_LANDS_AT := Vector2(-16, 0)
const OUT_TIME := 0.5
const SKIP_AFTER := 1.3

var _player: Node2D
var _pivot: Node2D
var _sprite: CanvasItem
var _pivot_base := Vector2.ZERO
var _t := 0.0
var _burst_done := false
var _ending := false
var _backdrop: ColorRect
var _curtain: ColorRect
var _girl: Sprite2D
var _fallen := false


## Starts the sequence for `player` (needs a Pivot child holding the sprite).
static func play(player: Node2D) -> DeathSequence:
	var seq := DeathSequence.new()
	seq._player = player
	var host := player.get_tree().current_scene
	host.add_child(seq)
	return seq


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	global_position = _player.global_position
	_pivot = _player.get_node_or_null("Pivot")
	_sprite = _player.get_node_or_null("Pivot/AnimatedSprite2D")
	if _pivot:
		_pivot_base = _pivot.position
	get_tree().paused = true
	Engine.time_scale = 1.0

	# Black backdrop above the world, below the knight.
	_backdrop = _make_rect(40, 0.0)
	_player.z_as_relative = false
	_player.z_index = 50
	# Final curtain over everything (including the girl).
	_curtain = _make_rect(60, 0.0)

	var fade := create_tween().set_parallel()
	fade.tween_property(_backdrop, "color:a", 1.0, FADE_TIME).set_ease(Tween.EASE_IN)
	# Lift the realm's color grading so the reveal shows true colors.
	for cm in get_tree().current_scene.find_children("*", "CanvasModulate", true, false):
		fade.tween_property(cm, "color", Color.WHITE, FADE_TIME)
	# Hide HUD layers (the debug overlay is an autoload, outside the scene).
	for layer in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


func _process(delta: float) -> void:
	_t += delta
	if not _burst_done:
		_shake()
		if _t >= SHAKE_TIME:
			_burst()
	elif not _ending:
		if _girl and not _fallen:
			if _t >= FALL_AT:
				_fall()
			elif _t >= FALL_AT - 0.3:
				# a last wobble before she goes
				_girl.position.x = 1.0 if fmod(_t, 0.12) < 0.06 else 0.0
		var skip := _t > SKIP_AFTER and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack"))
		if _t >= HOLD_UNTIL or skip:
			_end(OUT_TIME if not skip else 0.2)


func _shake() -> void:
	if not _pivot:
		return
	var k := _t / SHAKE_TIME
	var amp := lerpf(0.5, 2.5, k * k)
	_pivot.position = _pivot_base + Vector2(randf_range(-amp, amp), randf_range(-amp * 0.5, amp * 0.5)).round()
	# Flicker white faster and faster toward the burst.
	if _sprite:
		var rate := lerpf(6.0, 22.0, k)
		_sprite.modulate = Color(3, 3, 3) if k > 0.35 and fmod(_t * rate, 1.0) < 0.35 else Color.WHITE


func _burst() -> void:
	_burst_done = true
	if _pivot:
		_pivot.position = _pivot_base
		_pivot.visible = false
	var center := Vector2(0, -11)

	var ring := Burst.new()
	ring.radius = 20.0
	ring.color = Color(1, 1, 1)
	ring.debris = 0
	ring.duration = 0.35
	ring.position = center
	add_child(ring)
	ring.z_index = 53 # after _ready, which sets its own default

	var feathers := FeatherBurst.new()
	feathers.position = center
	add_child(feathers)

	_girl = Sprite2D.new()
	_girl.texture = GIRL_TEXTURE
	_girl.offset = Vector2(0, -GIRL_TEXTURE.get_height() / 2.0) # origin at her feet, so she tips over from there
	_girl.z_index = 51
	_girl.modulate = Color(3, 3, 3) # appears out of the flash
	add_child(_girl)
	create_tween().tween_property(_girl, "modulate", Color.WHITE, 0.45).set_ease(Tween.EASE_OUT)


func _fall() -> void:
	_fallen = true
	_girl.position = Vector2.ZERO
	var tween := create_tween().set_parallel()
	# Negative = counterclockwise: head swings back to the left.
	tween.tween_property(_girl, "rotation", -PI / 2.0, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_girl, "position:y", -LYING_LIFT, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Thud: a puff of dust where her head lands, and a 1px bounce.
	tween.chain().tween_callback(func() -> void:
		var dust := Burst.new()
		dust.radius = 10.0
		dust.flatten = 0.35
		dust.color = Color(0.85, 0.85, 0.9, 0.8)
		dust.debris = 4
		dust.debris_speed = 40.0
		dust.debris_up_only = true
		dust.duration = 0.3
		dust.position = HEAD_LANDS_AT
		add_child(dust)
		dust.z_index = 52)
	tween.chain().tween_property(_girl, "position:y", -LYING_LIFT - 1.0, 0.06)
	tween.chain().tween_property(_girl, "position:y", -LYING_LIFT, 0.08)
	# Then she's pulled down: barely moving at first, then gone (exponential ease-in).
	tween.chain().tween_interval(SINK_DELAY)
	tween.chain().tween_property(_girl, "position:y", SINK_DISTANCE, SINK_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _end(duration: float) -> void:
	_ending = true
	var tween := create_tween()
	tween.tween_property(_curtain, "color:a", 1.0, duration)
	tween.tween_callback(_finish)


func _finish() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	finished.emit()


func _make_rect(z: int, alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, alpha)
	rect.size = Vector2(4000, 4000)
	rect.position = -rect.size / 2.0
	rect.z_as_relative = false
	rect.z_index = z
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
