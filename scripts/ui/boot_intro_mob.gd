class_name BootIntroMob
extends Node2D
## A monster in the intro cutscene. Feet at the node's origin. Walks toward
## `target_x` when set, animates idle/run frames (0x72 strips) or hops (single
## Tiny Creatures tiles), flashes and staggers when hit, and is flung off,
## spinning, when killed.

signal died

const DUNGEON := preload("res://assets/sprites/0x72_dungeontileset_ii/0x72_DungeonTilesetII_v1.7.png")
const CREATURES := preload("res://assets/sprites/tiny_creatures/tilemap_packed.png")
const WARLORD := preload("res://assets/sprites/title/warlord.png")
const FX := preload("res://scripts/ui/boot_intro_fx.gd")
## The warlord's sword hand, relative to his feet when facing right.
const WARLORD_HAND := Vector2(7, -19)
## Greatsword rotation at rest: held low and forward, point down.
const BLADE_REST := 0.9

## kind -> [atlas, first frame rect, frame step x, idle count, run count, faces_right]
## 0x72 rows: 4 idle frames then 4 run frames. Tiny Creatures: one tile.
const KINDS := {
	"knight": [DUNGEON, Rect2(128, 100, 16, 28), 16, 4, 4, true],   # knight_m: armored man
	"knight_f": [DUNGEON, Rect2(128, 68, 16, 28), 16, 4, 4, true],  # knight_f
	"ogre": [DUNGEON, Rect2(16, 336, 32, 32), 32, 4, 4, true],
	"brute": [DUNGEON, Rect2(16, 380, 32, 36), 32, 4, 4, true],     # big_zombie (the draugr)
	"demon": [DUNGEON, Rect2(16, 428, 32, 36), 32, 4, 4, true],     # big_demon
	"warlord": [WARLORD, Rect2(0, 0, 30, 44), 30, 2, 4, true],      # original: the Hel warlord
	"zombie": [CREATURES, Rect2(0, 0, 16, 16), 0, 1, 0, true],
	"skeleton": [CREATURES, Rect2(16, 0, 16, 16), 0, 1, 0, false],
	"goblin": [CREATURES, Rect2(0, 16, 16, 16), 0, 1, 0, false],
	"orc": [CREATURES, Rect2(16, 16, 16, 16), 0, 1, 0, false],
	"wolf": [CREATURES, Rect2(48, 32, 16, 16), 0, 1, 0, false],
}

var kind := "goblin"
var hp := 1
var speed := 50.0
var target_x := NAN
var facing := -1.0
## Armored: hits spark as well as bleed.
var armored := false
var big := false
var dead := false
var ground_y := 184.0
## Base color (the director darkens a lurking mob to a silhouette).
var tint := Color.WHITE

var sprite: Sprite2D
var _atlas: AtlasTexture
var _first: Rect2
var _step := 0.0
var _idle := 1
var _run := 0
var _faces_right := true
var _t := 0.0
var _knock := 0.0
var _vel := Vector2.ZERO
var _spin := 0.0
var _flash := 0.0
var _lean := 0.0
var _winding := false
## The warlord's greatsword (rotate it; it mirrors with his facing).
var blade: Node2D
var _hand: Node2D


static func make(kind_id: String, at: Vector2, hp_: int = 1, speed_: float = 50.0) -> BootIntroMob:
	var m := BootIntroMob.new()
	m.kind = kind_id
	m.position = at
	m.ground_y = at.y
	m.hp = hp_
	m.speed = speed_
	m.armored = kind_id.begins_with("knight")
	m.big = kind_id in ["ogre", "brute", "demon", "warlord"]
	m.armored = m.armored or kind_id == "warlord"
	return m


func _ready() -> void:
	var k: Array = KINDS[kind]
	_first = k[1]
	_step = k[2]
	_idle = k[3]
	_run = k[4]
	_faces_right = k[5]
	_atlas = AtlasTexture.new()
	_atlas.atlas = k[0]
	_atlas.region = _first
	sprite = Sprite2D.new()
	sprite.texture = _atlas
	sprite.offset = Vector2(0, -_first.size.y / 2.0)
	add_child(sprite)
	if kind == "warlord":
		_hand = Node2D.new()
		_hand.position = WARLORD_HAND
		add_child(_hand)
		blade = FX.GreatSword.new()
		blade.rotation = BLADE_REST
		_hand.add_child(blade)
	_t = randf() * 2.0


func height() -> float:
	return _first.size.y


func is_moving() -> bool:
	return not dead and not is_nan(target_x) and absf(target_x - position.x) > 0.5 and _knock <= 0.0


func _process(delta: float) -> void:
	_t += delta
	if dead:
		_vel.y += 520.0 * delta
		position += _vel * delta
		rotation += _spin * delta
		if position.y > ground_y and _vel.y > 0.0:
			# bounce once, then slide to a stop
			position.y = ground_y
			_vel = Vector2(_vel.x * 0.4, -_vel.y * 0.25) if absf(_vel.y) > 60.0 else Vector2(move_toward(_vel.x, 0.0, 400.0 * delta), 0.0)
			_spin *= 0.4
		_flash = maxf(0.0, _flash - delta * 4.0)
		sprite.modulate = tint.lerp(Color(3, 3, 3), _flash)
		return
	if _knock > 0.0:
		_knock -= delta
		position.x += _vel.x * delta
		_vel.x = move_toward(_vel.x, 0.0, 700.0 * delta)
	elif is_moving():
		var dir := signf(target_x - position.x)
		facing = dir
		position.x = move_toward(position.x, target_x, speed * delta)
	var moving := is_moving()
	# frames
	if _run > 0 and moving:
		_atlas.region = Rect2(_first.position + Vector2(_step * (_idle + int(_t * 10.0) % _run), 0), _first.size)
	elif _idle > 1:
		_atlas.region = Rect2(_first.position + Vector2(_step * (int(_t * 6.0) % _idle), 0), _first.size)
	sprite.position.y = -roundf(absf(sin(_t * 11.0)) * 2.0) if (moving and _run == 0) else 0.0
	sprite.position.x = roundf(_lean)
	sprite.flip_h = (facing < 0.0) == _faces_right
	if _hand:
		_hand.scale.x = facing
		_hand.position = Vector2(WARLORD_HAND.x * facing + roundf(_lean), WARLORD_HAND.y)
	_flash = maxf(0.0, _flash - delta * 6.0)
	sprite.modulate = (Color(1.6, 0.8, 0.8) if _winding else tint).lerp(Color(3, 3, 3), _flash)


## A hit from direction `dir` (+1 = pushed right). True if it killed.
func hurt(dir: float, force: float = 120.0) -> bool:
	if dead:
		return false
	hp -= 1
	_flash = 1.0
	if hp <= 0:
		die(dir, force)
		return true
	_knock = 0.12 if not big else 0.08
	_vel.x = dir * force * (0.4 if big else 1.0)
	return false


## Flung off in direction `dir`, spinning.
func die(dir: float, force: float = 120.0) -> void:
	dead = true
	_flash = 1.0
	var weight := 0.45 if big else 1.0
	_vel = Vector2(dir * (force + 60.0) * weight, -(160.0 + force * 0.5) * weight)
	_spin = dir * (9.0 if not big else 3.0)
	z_index -= 1
	died.emit()
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


## Rears back before a blow (seconds). Then call strike().
func wind_up(time: float = 0.35) -> void:
	var tween := create_tween()
	tween.tween_property(self, "_lean", -facing * 3.0, time).set_ease(Tween.EASE_OUT)
	_winding = true


func strike() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_lean", facing * 5.0, 0.05)
	tween.tween_property(self, "_lean", 0.0, 0.25)
	_winding = false


## Reels back without taking damage (a parried blow).
func stagger(dir: float, force: float = 140.0) -> void:
	_flash = 0.6
	_knock = 0.2
	_vel.x = dir * force
	_winding = false
