class_name Magigonne
extends Node2D
## The Magigonne: a flared, rune-banded hand cannon that fires seidr shots on
## mana. A side-route ability (AbilityShrine "ability:magigonne",
## GameManager.has_ability), meant to be found in Yggdrasil. Lives as a child
## of the player (scenes/player.tscn) and stays dormant until she owns it.
##
## Hold `fire` (F / R1) to aim, release to shoot. Two aim modes, a player
## setting (F1 > Controller setup, saved in user://settings.cfg):
##   SWEEP  the classic: a cursor swings up and down an arc in front of her on
##          its own; let go when it's on target. Left/right flips her facing.
##   STICK  aim where you hold: the right stick if pushed, else the move
##          stick / arrows (8-way on keys); nothing held = straight ahead.
## Aiming never stops her: she runs, jumps and flutters while the cursor is up.
##
## Each shot costs one mana. It takes the active sword's element (and the
## hammer's heavy hits), ricochets off walls and pops on the first thing it
## hits (MagigonneShot). The kick pushes her back opposite the shot: fired
## downward in the air, it lifts her, and it cancels a flutter in progress.
## There is no other limit: with mana in the bar she can shoot anywhere.
##
## Mana comes from drops (Pickup.Kind.MANA, enemies drop it once she owns
## the gun) and trickles back to TRICKLE_FLOOR on its own, so a room built
## around a shot can never strand her. Mana isn't carried between rooms yet:
## she enters every room with a full bar.

signal mana_changed(current: int, maximum: int)

const ABILITY := &"magigonne"
enum AimMode { SWEEP, STICK }

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "controls"
const SETTINGS_KEY := "magigonne_aim"

## Mana bar size before any upgrades.
const BASE_MANA := 4
## Mana refills on its own up to this many shots, one every TRICKLE_TIME s.
const TRICKLE_FLOOR := 1
const TRICKLE_TIME := 3.0
## Seconds between shots.
const FIRE_COOLDOWN := 0.22

## Sweep arc, in radians relative to "straight ahead" (negative = up).
const SWEEP_UP := -1.40 # ~80 degrees up: nearly vertical, it's a climb
const SWEEP_DOWN := 0.52 # ~30 degrees below level
const SWEEP_START := -0.2
const SWEEP_SPEED := 1.9 # rad/s: about a second end to end
## Stick aim: how far a stick must lean before it aims.
const STICK_DEADZONE := 0.35

const SHOT_SPEED := 280.0
## Shot damage as a share of the active sword's.
const DAMAGE_MULT := 1.0
## Kick: horizontal push opposite the shot, and the lift a straight-down shot
## gives in the air (jump launch is 300, a flutter kick 150).
const RECOIL_PUSH := 140.0
const RECOIL_LIFT := 230.0
const RECOIL_DOWN := 60.0 # an upward shot in the air nudges her down

## Where she holds it, from her feet (x is mirrored with her facing).
const HAND := Vector2(3, -6)
const CURSOR_DIST := 38.0
## Seconds the gun stays out after a shot.
const SHOW_AFTER_FIRE := 0.3

## Element tints: NONE is plain seidr violet. Order follows Hit.Element.
const ELEMENT_COLORS := [
	Color(0.72, 0.58, 1.0), Color(0.6, 0.9, 1.0), Color(1.0, 0.55, 0.2), Color(1.0, 0.95, 0.4),
]

## The gun, pointing right, 1 world pixel per cell. Outlined in code.
## 'h' bronze highlight, 'b' bronze, 'd' dark bronze, 'm' muzzle bore,
## 'r' rune band (glows in the element color), 'w' grip.
## 8 px long: she's small, and so is her gun.
const ART := [
	"......hh",
	"hhrhhhbm",
	"ddrdddbm",
	"ww....dd",
	"w.......",
]
## The cell she grips (rotation pivot), and the muzzle mouth.
const ART_GRIP := Vector2(1.0, 3.0)
const ART_MUZZLE := Vector2(8.0, 1.5)
const BRONZE_HI := Color(0.96, 0.78, 0.45)
const BRONZE := Color(0.76, 0.5, 0.24)
const BRONZE_DARK := Color(0.48, 0.29, 0.14)
const BORE := Color(0.12, 0.06, 0.05)
const GRIP := Color(0.38, 0.23, 0.13)
const OUTLINE := Color(0.08, 0.06, 0.1)

static var _aim_mode_loaded := false
static var _aim_mode: AimMode = AimMode.SWEEP

var mana := BASE_MANA
var max_mana := BASE_MANA

var _player # the player (untyped: player.gd has no class_name)
var _aiming := false
var _sweep := SWEEP_START
var _sweep_dir := -1.0 # -1 = swinging up
var _cooldown := 0.0
var _trickle := 0.0
var _show := 0.0
var _kick := 0.0 # px the gun jolts back after a shot
var _aim_dir := Vector2.RIGHT # world space, unit
var _t := 0.0
var _bar: CanvasLayer


## The player's Magigonne, or null.
static func of(player: Node) -> Magigonne:
	return player.get_node_or_null("Magigonne") as Magigonne if player else null


static func aim_mode() -> AimMode:
	if not _aim_mode_loaded:
		_aim_mode_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_PATH) == OK:
			_aim_mode = AimMode.STICK if cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, "sweep") == "stick" else AimMode.SWEEP
	return _aim_mode


static func set_aim_mode(mode: AimMode) -> void:
	_aim_mode = mode
	_aim_mode_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # keep the audio settings stored here
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, "stick" if mode == AimMode.STICK else "sweep")
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Magigonne: couldn't save %s (error %d)" % [SETTINGS_PATH, err])


static func aim_mode_name(mode: AimMode) -> String:
	return "Stick (aim where you hold)" if mode == AimMode.STICK else "Sweep (classic swinging cursor)"


static func element_color(element: Hit.Element) -> Color:
	return ELEMENT_COLORS[clampi(int(element), 0, ELEMENT_COLORS.size() - 1)]


func _ready() -> void:
	_player = get_parent()
	z_index = 1 # over her sprite (relative to the player's z)
	var bar_script: GDScript = load("res://scripts/ui/mana_bar.gd")
	_bar = bar_script.new()
	_bar.set("magigonne", self)
	add_child(_bar)


func owned() -> bool:
	return GameManager.has_ability(ABILITY)


## Adds mana (a drop); returns how much actually went in.
func add_mana(amount: int = 1) -> int:
	var before := mana
	mana = mini(mana + amount, max_mana)
	if mana >= TRICKLE_FLOOR:
		_trickle = 0.0
	if mana != before:
		mana_changed.emit(mana, max_mana)
	return mana - before


## 0..1 progress of the trickle toward its next shot (0 when not refilling).
func trickle_progress() -> float:
	return _trickle / TRICKLE_TIME if mana < TRICKLE_FLOOR else 0.0


func is_aiming() -> bool:
	return _aiming


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null or not owned():
		_aiming = false
		_show = 0.0
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_show = maxf(0.0, _show - delta)
	_kick = move_toward(_kick, 0.0, delta * 20.0)
	if mana < TRICKLE_FLOOR:
		_trickle += delta
		if _trickle >= TRICKLE_TIME:
			_trickle = 0.0
			add_mana(1)
			Sfx.play(&"mana", -1.0, -6.0, 0.8)

	var usable := _can_use()
	if not usable:
		_aiming = false
	elif Input.is_action_just_pressed("fire"):
		_aiming = true
		_sweep = SWEEP_START
		_sweep_dir = -1.0
	if _aiming:
		_update_aim(delta)
		if not Input.is_action_pressed("fire"):
			_aiming = false
			_fire()
	queue_redraw()


func _can_use() -> bool:
	var p = _player
	return not (p.is_dead or p.is_dive_attacking or p.hurt_stun_timer > 0.0
			or p.dash_timer > 0.0 or DebugMenu.noclip)


func _facing() -> float:
	var s: float = signf(_player.pivot.scale.x) if _player.pivot else 1.0
	return s if s != 0.0 else 1.0


func _update_aim(delta: float) -> void:
	var facing := _facing()
	if aim_mode() == AimMode.SWEEP:
		_sweep += _sweep_dir * SWEEP_SPEED * delta
		if _sweep <= SWEEP_UP:
			_sweep = SWEEP_UP
			_sweep_dir = 1.0
		elif _sweep >= SWEEP_DOWN:
			_sweep = SWEEP_DOWN
			_sweep_dir = -1.0
		_aim_dir = Vector2(cos(_sweep) * facing, sin(_sweep))
		return
	var stick := _right_stick()
	if stick.length() < STICK_DEADZONE:
		stick = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_aim_dir = stick.normalized() if stick.length() >= STICK_DEADZONE else Vector2(facing, 0.0)


## The right stick of the pad driving the game (any pad if none is chosen).
func _right_stick() -> Vector2:
	var device := InputSetup.active_device()
	var pads: Array = [device] if device >= 0 else Input.get_connected_joypads()
	for id: int in pads:
		var v := Vector2(Input.get_joy_axis(id, JOY_AXIS_RIGHT_X), Input.get_joy_axis(id, JOY_AXIS_RIGHT_Y))
		if v.length() >= STICK_DEADZONE:
			return v
	return Vector2.ZERO


func _hand() -> Vector2:
	return Vector2(HAND.x * _facing(), HAND.y)


func _fire() -> void:
	if _cooldown > 0.0:
		return
	if mana <= 0:
		Sfx.play(&"magigonne_empty", -1.0, 0.0, 0.6)
		_show = SHOW_AFTER_FIRE
		return
	var data: WeaponData = _player.weapon_data
	var dir := _aim_dir
	mana -= 1
	mana_changed.emit(mana, max_mana)
	_cooldown = FIRE_COOLDOWN
	_show = SHOW_AFTER_FIRE
	_kick = 2.0
	var color := element_color(data.element if data else Hit.Element.NONE)
	var muzzle: Vector2 = _player.global_position + _hand() + dir * (ART_MUZZLE.x - ART_GRIP.x)

	var shot := MagigonneShot.new()
	shot.velocity = dir * SHOT_SPEED
	shot.damage = maxi(1, roundi((data.damage if data else 15) * DAMAGE_MULT))
	shot.element = data.element if data else Hit.Element.NONE
	shot.heavy = data.heavy_hits if data else false
	shot.color = color
	shot.shooter = _player
	var host: Node = get_tree().current_scene if get_tree().current_scene else _player.get_parent()
	host.add_child(shot)
	shot.global_position = muzzle

	_recoil(dir)
	Sfx.play(&"magigonne_fire", -1.0, 0.0, 1.6)
	CombatFX.burst(self, muzzle, 7.0, color.lerp(Color.WHITE, 0.4), 1.0, 4, 0.14)
	CombatFX.burst(self, muzzle - dir * 3.0, 5.0, Color(0.75, 0.72, 0.8, 0.8), 1.0, 3, 0.3) # smoke


## Pushes her opposite the shot. In the air a downward shot lifts her (and
## ends a flutter, which would otherwise damp the kick straight away).
func _recoil(dir: Vector2) -> void:
	var p = _player
	p.velocity.x -= dir.x * RECOIL_PUSH
	if p.is_on_floor():
		return
	if dir.y > 0.2:
		p.velocity.y = minf(p.velocity.y, -RECOIL_LIFT * dir.y)
		p.is_fluttering = false
	elif dir.y < -0.2:
		p.velocity.y += RECOIL_DOWN * -dir.y


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	if not owned() or (not _aiming and _show <= 0.0):
		return
	var data: WeaponData = _player.weapon_data
	var color := element_color(data.element if data else Hit.Element.NONE)
	var hand := _hand().round()
	if _aiming:
		_draw_cursor(hand, color)
	_draw_gun(hand - (_aim_dir * _kick).round(), _aim_dir, color)


## Dotted line out to a little crosshair, whole pixels, gently blinking.
func _draw_cursor(hand: Vector2, color: Color) -> void:
	var lit := fmod(_t, 0.3) < 0.2
	for i in 4:
		var d := 14.0 + i * 6.0
		var p := (hand + _aim_dir * d).round()
		draw_rect(Rect2(p, Vector2.ONE), Color(color, 0.55 if lit else 0.35))
	var c := (hand + _aim_dir * CURSOR_DIST).round()
	for o: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		var arm := o.sign()
		for k in 2:
			var px := c + o - arm * k
			draw_rect(Rect2(px + Vector2(1, 0), Vector2.ONE), OUTLINE)
			draw_rect(Rect2(px + Vector2(0, 1), Vector2.ONE), OUTLINE)
	for o: Vector2 in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
		var arm := o.sign()
		for k in 2:
			draw_rect(Rect2(c + o - arm * k, Vector2.ONE), Color.WHITE if lit else color)
	draw_rect(Rect2(c, Vector2.ONE), Color(color, 0.8))


## The gun turned to `dir` about her hand, sampled pixel by pixel from ART so
## it stays crisp at any angle. Mirrored (not flipped over) when aiming left,
## so the grip always hangs down.
func _draw_gun(hand: Vector2, dir: Vector2, rune: Color) -> void:
	var side := signf(dir.x) if absf(dir.x) > 0.01 else _facing()
	var angle := atan2(dir.y, dir.x * side)
	var r := 10
	var filled := {}
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var ch := _sample(Vector2(x + 0.5, y + 0.5), side, angle)
			if ch != "":
				filled[Vector2i(x, y)] = ch
	for cell: Vector2i in filled:
		for n: Vector2i in [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
			if not filled.has(n):
				draw_rect(Rect2(hand + Vector2(n), Vector2.ONE), OUTLINE)
	var glow := 0.8 + 0.2 * sin(_t * 9.0)
	for cell: Vector2i in filled:
		var col: Color
		match filled[cell]:
			"h": col = BRONZE_HI
			"b": col = BRONZE
			"d": col = BRONZE_DARK
			"m": col = BORE
			"w": col = GRIP
			"r": col = rune.lerp(Color.WHITE, 0.25) * Color(1, 1, 1, glow)
		draw_rect(Rect2(hand + Vector2(cell), Vector2.ONE), col)


## The ART cell under a pixel (offset from the hand), or "".
func _sample(p: Vector2, side: float, angle: float) -> String:
	var q := Vector2(p.x * side, p.y).rotated(-angle) + ART_GRIP
	var cx := floori(q.x)
	var cy := floori(q.y)
	if cy < 0 or cy >= ART.size():
		return ""
	var line: String = ART[cy]
	if cx < 0 or cx >= line.length() or line[cx] == ".":
		return ""
	return line[cx]
