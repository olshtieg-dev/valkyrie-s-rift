class_name NewGameIntro
extends CanvasLayer
## The new-climb cutscene, played over everything when a fresh file starts.
## Black; a ray of light opens; the cherub from the title intro flutters down
## carrying the fallen village girl and lays her on the floor. A flash, and she
## lies there armored: the knight. The cherub commands her to rise, find her
## sword, earn her wings, and meet it again in the Golden Hall; she stands, it
## flies off, the light goes out. Then the black lifts on the knight standing
## in the first room.
##
## Start it with NewGameIntro.play(tree) right before SaveGame.new_game(): the
## first room loads underneath (LevelManager's fade and card are hidden below
## this layer), and once LevelManager is done the tree is held paused until the
## reveal, so nothing in the room moves while the scene plays. Skippable with
## jump / attack / Enter / Esc / a click (BootSplash._is_skip).

signal _tick

const STAGE := Vector2(384, 216)
const GROUND_Y := 168.0
const CENTRE_X := 192.0
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const GIRL := preload("res://assets/sprites/title/village_girl.png")
const CREATURES := preload("res://assets/sprites/tiny_creatures/tilemap_packed.png")
const CHERUB_REGION := Rect2(96, 48, 16, 16)
## The cherub's theme (tools/gen_cherub_theme.py): somber, turning hopeful. Plays
## over the room load and hands over to the realm track at the reveal.
const THEME := preload("res://assets/music/themes/cherub.ogg")
const GOLD := Color(1.0, 0.84, 0.4)
const INK := Color(0.08, 0.05, 0.1)
## Seconds the black takes to lift on the first room.
const REVEAL_TIME := 1.2
## If the room never arrives (load failed), lift the black anyway after this.
const LOAD_TIMEOUT := 12.0

var _t := 0.0
var _done := false
var _revealing := false
## LevelManager swapped the scene in and finished its transition.
var _scene_arrived := false
var _room_ready := false
var _stage: Control
var _black: ColorRect
var _flash: ColorRect
var _world: Node2D
var _beam: BootIntroFX.Beam
var _cherub: Sprite2D
## Her feet; the body hangs off it so she can lie down and stand up around it.
var _girl: Node2D
var _knight: Node2D
var _knight_sprite: Sprite2D
var _knight_idle := false
var _caption: Label


## Puts the cutscene over everything. Call right before SaveGame.new_game().
static func play(tree: SceneTree) -> NewGameIntro:
	var intro := NewGameIntro.new()
	tree.root.add_child(intro)
	return intro


func _ready() -> void:
	layer = 95 # above LevelManager's fade and loading card (90), below DebugMenu (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(func() -> void: _scene_arrived = true, CONNECT_ONE_SHOT)

	_stage = Control.new()
	_stage.size = STAGE
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 8
	_stage.theme = theme
	add_child(_stage)

	# Whole-window black (margins included); fades in over the title first.
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.modulate.a = 0.0
	add_child(_black)
	move_child(_black, 0)

	_world = Node2D.new()
	_stage.add_child(_world)
	var floor_glow := FloorGlow.new()
	floor_glow.position = Vector2(CENTRE_X, GROUND_Y)
	floor_glow.modulate.a = 0.0
	floor_glow.name = "Floor"
	_world.add_child(floor_glow)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.position = Vector2(12, 34)
	_caption.size = Vector2(STAGE.x - 24, 24)
	_caption.add_theme_font_override("font", FONT_BOLD)
	_caption.add_theme_color_override("font_color", GOLD)
	_caption.add_theme_color_override("font_outline_color", INK)
	_caption.add_theme_constant_override("outline_size", 3)
	_caption.modulate.a = 0.0
	_stage.add_child(_caption)

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.97, 0.88)
	_flash.size = STAGE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_stage.add_child(_flash)

	get_viewport().size_changed.connect(_fit)
	_fit()
	_direct()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var k := maxf(1.0, floorf(minf(view.x / STAGE.x, view.y / STAGE.y)))
	_stage.scale = Vector2(k, k)
	_stage.position = ((view - STAGE * k) / 2.0).floor()


# =========================================================================== director

func _direct() -> void:
	create_tween().tween_property(_black, "modulate:a", 1.0, 0.5)
	MusicPlayer.play_override(THEME, 1.5, true) # sticky: the room loading underneath doesn't cut it
	if not await _wait(0.9): return

	# --- The light opens. ---------------------------------------------------------
	_beam = BootIntroFX.Beam.new()
	_beam.position = Vector2(CENTRE_X, 0)
	_beam.height = GROUND_Y
	_world.add_child(_beam)
	_world.move_child(_beam, 0)
	create_tween().tween_property(_world.get_node("Floor"), "modulate:a", 1.0, 1.6)
	Sfx.play(&"heal", 0.0, -4.0)
	if not await _wait(0.8): return

	# --- The cherub brings her down, lying in its arms. ---------------------------
	_girl = Node2D.new()
	_girl.rotation = -PI / 2.0 # on her back, feet to the right
	var body := Sprite2D.new()
	body.texture = GIRL
	body.position = Vector2(0, -GIRL.get_height() / 2.0)
	_girl.add_child(body)
	var feet_x := CENTRE_X + 12.0 # lying, she spans 24px left of her feet
	var rest_y := GROUND_Y - 9.0 # her 18px width resting on the floor
	_girl.position = Vector2(feet_x, -40.0)
	_world.add_child(_girl)
	var atlas := AtlasTexture.new()
	atlas.atlas = CREATURES
	atlas.region = CHERUB_REGION
	_cherub = Sprite2D.new()
	_cherub.texture = atlas
	_cherub.offset = Vector2(0, -8)
	_cherub.position = Vector2(CENTRE_X, _girl.position.y - 7.0)
	_world.add_child(_cherub)
	var descend := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	descend.tween_property(_girl, "position:y", rest_y, 3.2)
	descend.tween_property(_cherub, "position:y", rest_y - 7.0, 3.2)
	if not await _wait(3.3): return
	Sfx.play(&"land", 0.05, -10.0, 0.8)
	create_tween().tween_property(_cherub, "position:y", rest_y - 30.0, 0.9).set_trans(Tween.TRANS_SINE)
	if not await _wait(1.0): return

	# --- A flash: she lies there in armor. ----------------------------------------
	Sfx.play(&"power_up", 0.0, -4.0)
	Sfx.play(&"armor_burst", 0.0, -6.0)
	var flash := create_tween()
	flash.tween_property(_flash, "modulate:a", 0.9, 0.12)
	flash.tween_callback(_become_knight.bind(feet_x))
	flash.tween_property(_flash, "modulate:a", 0.0, 0.7)
	var feathers := FeatherBurst.new()
	feathers.count = 14
	feathers.position = Vector2(CENTRE_X, rest_y)
	_world.add_child(feathers)
	if not await _wait(1.2): return

	# --- The command. ------------------------------------------------------------
	_shout("Arise, fallen one!", 1.6)
	if not await _wait(0.5): return
	_rise()
	if not await _wait(1.4): return
	_shout("Find your sword!", 1.3)
	if not await _wait(1.7): return
	_shout("Earn your wings!", 1.3)
	if not await _wait(1.7): return
	_shout("And we will meet again in the Golden Hall, up high!", 2.6)
	if not await _wait(3.2): return

	# --- It flies off; the light goes out. ---------------------------------------
	var leave := create_tween().set_parallel()
	leave.tween_property(_cherub, "position:y", -30.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	leave.tween_property(_beam, "modulate:a", 0.0, 2.2).set_delay(0.6)
	leave.tween_property(_world.get_node("Floor"), "modulate:a", 0.0, 2.2).set_delay(0.6)
	if not await _wait(2.2): return
	create_tween().tween_property(_world, "modulate:a", 0.0, 1.0)
	if not await _wait(1.3): return
	_finish()


## The flash's peak: the girl is gone and the knight lies in her place.
func _become_knight(feet_x: float) -> void:
	_girl.queue_free()
	_knight = Node2D.new()
	_knight.position = Vector2(feet_x, GROUND_Y - 7.0) # lying on her ~13px-wide side
	_knight.rotation = -PI / 2.0
	_knight_sprite = Sprite2D.new()
	var id := PlayerSkins.current()
	var frame := AtlasTexture.new()
	frame.atlas = PlayerSkins.ORIGINAL_KNIGHT if id == "original" else load(PlayerSkins.SKIN_DIR + id + ".png")
	frame.region = Rect2(0, 0, 32, 32)
	_knight_sprite.texture = frame
	_knight_sprite.centered = false
	_knight_sprite.offset = Vector2(-16, -29) # her feet (frame row 28) on the node
	_knight.add_child(_knight_sprite)
	_world.add_child(_knight)
	_world.move_child(_knight, _world.get_children().find(_cherub)) # under the cherub


## She stands up around her feet.
func _rise() -> void:
	Sfx.play(&"land_heavy", 0.0, -8.0, 1.2)
	var up := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	up.tween_property(_knight, "rotation", 0.0, 0.6)
	up.tween_property(_knight, "position:y", GROUND_Y, 0.6)
	up.tween_property(_knight, "position:x", CENTRE_X, 0.6) # into the middle of the light
	up.chain().tween_callback(func() -> void: _knight_idle = true)


func _shout(text: String, hold: float) -> void:
	_caption.text = text
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, 0.25)
	tween.tween_interval(hold)
	tween.tween_property(_caption, "modulate:a", 0.0, 0.35)


# =========================================================================== per frame

func _process(delta: float) -> void:
	_t += delta
	if _cherub:
		_cherub.offset.y = -8.0 - (1.0 if fmod(_t, 0.16) < 0.08 else 0.0)
		if not _done and int(_t / 0.32) != int((_t - delta) / 0.32):
			Sfx.play(&"flutter", 0.05, -14.0)
	if _knight_idle and is_instance_valid(_knight_sprite):
		(_knight_sprite.texture as AtlasTexture).region.position.x = (int(_t * 6.0) % 4) * 32
	_hold_room()
	_tick.emit()


## Once LevelManager has swapped in the room and unpaused, keep the tree paused
## until the reveal so she and the room wait for the scene to end.
func _hold_room() -> void:
	if _revealing or not _scene_arrived:
		return
	if not _room_ready:
		if get_tree().paused: # LevelManager is still fading its (hidden) card
			return
		_room_ready = true
	get_tree().paused = true


## Swallow every input while the black is up; a skip press ends the scene.
func _input(event: InputEvent) -> void:
	if _revealing:
		return
	get_viewport().set_input_as_handled()
	if not _done and _t > 0.5 and BootSplash._is_skip(event):
		_skip()


func _skip() -> void:
	_done = true
	_black.modulate.a = 1.0
	var out := create_tween()
	out.tween_property(_stage, "modulate:a", 0.0, 0.3)
	await out.finished
	_finish()


## The scene is over (or skipped): wait for the room, then lift the black.
func _finish() -> void:
	_done = true
	var waited := 0.0
	while not _room_ready and waited < LOAD_TIMEOUT:
		await _tick
		waited += get_process_delta_time()
	_revealing = true
	_stage.visible = false # cherub, captions and flash; leftover tweens can't show them
	get_tree().paused = false
	var level := LevelManager.current_level
	if level and level.has_method("announce"):
		level.announce() # the hidden card named the room; let the HUD do it now
	MusicPlayer.clear_override(2.5) # the cherub's theme hands over to the realm's
	var lift := create_tween()
	lift.tween_property(_black, "modulate:a", 0.0, REVEAL_TIME)
	await lift.finished
	queue_free()


## Waits `seconds` of scene time. False once the scene has ended or been skipped.
func _wait(seconds: float) -> bool:
	var end := _t + seconds
	while _t < end and not _done:
		await _tick
	return not _done


## A dim stone floor lit only where the light falls.
class FloorGlow extends Node2D:
	func _draw() -> void:
		for band in [[80.0, 0.05], [56.0, 0.08], [36.0, 0.12], [20.0, 0.18]]:
			var w: float = band[0]
			draw_rect(Rect2(-w, 0, w * 2.0, 2), Color(0.85, 0.72, 0.5, band[1]))
			draw_rect(Rect2(-w * 0.8, 2, w * 1.6, 4), Color(0.5, 0.38, 0.3, band[1] * 0.6))
