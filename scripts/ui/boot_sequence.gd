extends Node
## Main scene: studio splash -> intro cutscene -> title screen.
##
## Everything is laid out on a 384x216 stage (the game's view at zoom 3) and
## scaled up by a whole number so pixels stay square; the margins are black.
## Splash and intro skip on jump / attack / Enter / Esc / a click.
## The title screen hands off to LevelManager (Continue / New Game).

const STAGE_SIZE := Vector2(384, 216)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## Title music: the climb's own theme.
const TITLE_MUSIC := preload("res://assets/music/realms/yggdrasil.ogg")
## Intro music: the fight in the storm.
const INTRO_MUSIC := preload("res://assets/music/realms/valhalla.ogg")

var _stage: Control
var _phase: Node


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = STAGE_SIZE
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 8
	_stage.theme = theme
	layer.add_child(_stage)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_run()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var k := maxf(1.0, floorf(minf(view.x / STAGE_SIZE.x, view.y / STAGE_SIZE.y)))
	_stage.scale = Vector2(k, k)
	_stage.position = ((view - STAGE_SIZE * k) / 2.0).floor()


func _run() -> void:
	await _play(BootSplash.new())
	MusicPlayer.play_override(INTRO_MUSIC, 0.5)
	await _play(BootIntro.new())
	MusicPlayer.play_override(TITLE_MUSIC, 1.5)
	var title := TitleScreen.new()
	_stage.add_child(title)


## Adds a phase to the stage and waits for its `finished` signal.
func _play(phase: Node) -> void:
	_phase = phase
	_stage.add_child(phase)
	await phase.finished
	phase.queue_free()
	_phase = null
