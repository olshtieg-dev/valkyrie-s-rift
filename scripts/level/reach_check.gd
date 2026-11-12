class_name ReachCheck
extends RefCounted
## Answers "how many flutters does this room ask for?" by replaying her real
## movement (player.gd's jump, hold, flutter, gravity and air control, frame
## by frame at 60 Hz) over the room's tiles. No physics engine, no scene: it
## reads the ground TileMapLayer, so it works on generated and baked rooms.
##
## From the entrance it tries a fixed set of inputs from every floor cell it
## can land on (walk off, hop, full jump with a mid-air steer, running jump;
## each with flutters spent at every apex, or stopped early), flood-filling
## the room. It does that with a budget of 0 flutters per airtime, then 1, 2,
## ... A target's number is the first budget that reaches it; -1 = not
## reachable within `max_flutters`. Calibrated against the real player: its
## jump comes out ~4% lower (conservative). Bare jump ~8 tiles of rise with
## the starter blade; each flutter ~4.6 more.
##
## With `with_dash` (she has the Dash Strike) a feather can instead be spent
## on an air dash (up, up-left, up-right, left or right), or on an up-dash
## straight off the floor, both as player.gd charges them: one feather each,
## from the same per-airtime count as flutters. Within one airtime every
## feather goes to the same move (all flutters, or all dashes one way), with
## the dash cooldown respected; mixed chains aren't tried.
##
## Deliberately conservative: it doesn't use attack moves (rising lift,
## lunge, meteor bounces off enemies), the free ground dash's speed into a
## jump, wall-hugging tricks or enemies as steps, and gates (vine walls,
## slime boulders) are treated as already cleared. If it says reachable, a
## plain jump+flutter(+dash) player can get there; if it says no, a skilled
## player may still manage it.
##
## Usage:
##   var check := ReachCheck.new(level.generator, weapon_data, 10, has_dash)
##   var result := check.run(start_feet, {"north": rect}, {"find": feet_pos})
##   result["north"] -> flutters needed (or -1)
## See tools/reach_check.gd for the all-levels report.

# Mirrors player.gd. Keep in step if her movement constants change.
const GRAVITY := 980.0
const DT := 1.0 / 60.0
const BASE_SPEED := 150.0
const MAX_SPEED := 250.0
const ACCELERATION := 800.0
const FRICTION := 1000.0
const BASE_JUMP_VELOCITY := -300.0
const JUMP_ADD_FORCE := -1200.0
const MAX_JUMP_TIME := 0.2
const MOMENTUM_GAIN_RATE := 1.5
const MAX_MOMENTUM_BONUS := 1.8
const JUMP_MOMENTUM_SHARE := 0.1
const TERMINAL_VELOCITY := 400.0
const FALL_GRAVITY_SCALE := 1.5
const FLUTTER_KICK := -150.0
const FLUTTER_DURATION := 0.4
const FLUTTER_GRAVITY_SCALE := 0.1
const DASH_SPEED := 500.0
const DASH_FRAMES := 10 # DASH_TIME 0.16 s: 9 full frames + the frame it ends
const DASH_COOLDOWN := 0.3
const DASH_CARRY_Y := 0.33
## Directions a feather-paid air dash is tried in.
const DASH_MOVES := [Vector2(0, -1), Vector2(-0.70710678, -0.70710678),
		Vector2(0.70710678, -0.70710678), Vector2(-1, 0), Vector2(1, 0)]
## Directions of an up-dash straight off the floor.
const GROUND_DASH_MOVES := [Vector2(0, -1), Vector2(-0.70710678, -0.70710678),
		Vector2(0.70710678, -0.70710678)]
# Her collision capsule (r 4, h 12, feet at the origin) as a box.
const HALF_W := 4.0
const BODY_H := 12.0

const TILE := 16
const AIR := 0
const SOLID := 1
const PLATFORM := 2
const HAZARD := 3

const MAX_AIR_FRAMES := 60 * 8
## Mid-air steer: hold d0, switch to d1 after this many seconds.
const STEER_TIMES := [0.15, 0.35, 0.6, 1.0]
## Running jump: floor cells behind her needed to count as a full run-up.
const RUNUP_CELLS := 3

var max_flutters: int
var with_dash := false
var _w: int
var _h: int
var _grid := PackedByteArray()
var _offset := Vector2.ZERO # ground layer position (level-local)
var _has_hazard := false

# Movement from the sword.
var _jump_height := 1.0
var _top_speed := 1.0
var _accel := 1.0
var _traction := 1.0
var _momentum_gain := 1.0
var _flutter_height := 1.0

## Per-run state.
var _goal_names: Array[String] = []
var _goal_rects: Array[Rect2] = []
var _goal_hit: Array[bool] = []
var _goal_any := Rect2() # union, a cheap first test
var _limit := 0
## What this airtime's feathers buy: ZERO = flutters, else a dash direction.
var _feather_move := Vector2.ZERO
## The next _air() call starts mid-dash (an up-dash off the floor).
var _launch_dash := false


func _init(generator: LevelGenerator, weapon: WeaponData = null, flutter_limit: int = 10,
		dash: bool = false) -> void:
	max_flutters = flutter_limit
	with_dash = dash
	if weapon:
		_jump_height = weapon.jump_height
		_top_speed = weapon.top_speed
		_accel = weapon.acceleration
		_traction = weapon.traction
		_momentum_gain = weapon.momentum_gain
		_flutter_height = weapon.flutter_height
	_read_grid(generator)


## start: feet position (level-local) she enters at.
## goals: name -> Rect2 (level-local); reached if her body touches it.
## points: name -> feet position (level-local) of something she touches
## (a pedestal, a heart vessel).
## Returns name -> fewest flutters per airtime that reach it (-1 = none up to
## max_flutters), and "_cells" -> Dictionary of floor cells reached with the
## final budget tried.
func run(start: Vector2, goals: Dictionary = {}, points: Dictionary = {}) -> Dictionary:
	_goal_names.clear()
	_goal_rects.clear()
	for goal_name: String in goals:
		var r: Rect2 = goals[goal_name]
		_goal_names.append(goal_name)
		_goal_rects.append(Rect2(r.position - _offset, r.size))
	for point_name: String in points:
		var p: Vector2 = points[point_name] - _offset
		_goal_names.append(point_name)
		_goal_rects.append(Rect2(p + Vector2(-8, -20), Vector2(16, 20)))
	_goal_any = Rect2()
	for i in _goal_rects.size():
		_goal_any = _goal_rects[i] if i == 0 else _goal_any.merge(_goal_rects[i])
	var out := {}
	for goal_name in _goal_names:
		out[goal_name] = -1
	var start_cell := _feet_cell(start - _offset)
	var cells := {}
	# Raise the budget one flutter at a time; a target's number is the first
	# budget that reaches it. Stops early once every target is reached.
	for budget in max_flutters + 1:
		_limit = budget
		_goal_hit.clear()
		_goal_hit.resize(_goal_names.size())
		cells = {start_cell: true}
		var queue: Array[Vector2i] = [start_cell]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for to: Vector2i in _jumps_from(cell):
				if not cells.has(to):
					cells[to] = true
					queue.append(to)
		var done := true
		for i in _goal_names.size():
			if _goal_hit[i] and out[_goal_names[i]] == -1:
				out[_goal_names[i]] = budget
			if out[_goal_names[i]] == -1:
				done = false
		if done:
			break
	out["_cells"] = cells
	return out


# --------------------------------------------------------------------------
# One cell's outgoing jumps

## Every floor cell she can land on from `cell` in one airtime.
func _jumps_from(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x := cell.x * TILE + TILE * 0.5
	var y := float(cell.y * TILE)
	_touch_goals(x, y)
	var jump_v := BASE_JUMP_VELOCITY * _jump_height
	var moves: Array = [Vector2.ZERO]
	if with_dash and _limit > 0:
		moves.append_array(DASH_MOVES)
		# Up-dash straight off the floor: a feather spent before leaving it.
		for mv: Vector2 in GROUND_DASH_MOVES:
			_feather_move = mv
			_launch_dash = true
			var d := int(signf(mv.x))
			_air(out, x, y, 0.0, 0.0, 1.0, d, d, 0.0, 0.0, 1, _limit, false)
	for mv: Vector2 in moves:
		_feather_move = mv
		_programs(out, cell, x, y, jump_v)
	_feather_move = Vector2.ZERO
	return out


## The jump/walk input programs from one cell, for the current _feather_move.
func _programs(out: Array[Vector2i], cell: Vector2i, x: float, y: float, jump_v: float) -> void:
	for d in [-1, 1]:
		# Walk off the ledge.
		_air(out, x, y, 0.0, 0.0, 1.0, d, d, 0.0, 0.0, 0, _limit, true)
		# A short hop.
		_air(out, x, y, 0.0, jump_v, 1.0, d, d, 0.0, 0.0, 0, _limit, false)
		# A running jump.
		if _has_runup(cell, d):
			var m := MAX_MOMENTUM_BONUS
			var vx: float = d * minf(BASE_SPEED * _top_speed * m, MAX_SPEED * _top_speed)
			_air(out, x, y, vx, jump_v * (1.0 + (m - 1.0) * JUMP_MOMENTUM_SHARE), m, d, d, 0.0, MAX_JUMP_TIME, 0, _limit, false)
	# Full jumps: straight, or switching direction mid-air.
	for d0 in [-1, 0, 1]:
		for d1 in [-1, 0, 1]:
			if d0 == d1:
				_air(out, x, y, 0.0, jump_v, 1.0, d0, d1, 0.0, MAX_JUMP_TIME, 0, _limit, false)
			else:
				for t: float in STEER_TIMES:
					_air(out, x, y, 0.0, jump_v, 1.0, d0, d1, t, MAX_JUMP_TIME, 0, _limit, false)


func _has_runup(cell: Vector2i, d: int) -> bool:
	for k in range(1, RUNUP_CELLS + 1):
		if not _standable(cell - Vector2i(d * k, 0)):
			return false
	return true


## One airtime: holding d0 until `steer_at` seconds, then d1; jump held for
## `hold` seconds; a feather at every apex while used < limit (a flutter, or
## a dash along _feather_move). Each one also forks the branch that stops
## spending there, so one call covers 0..limit feathers. `walking` starts on
## the floor (walk off a ledge).
## Appends the landing cell(s) to `out`.
func _air(out: Array[Vector2i], px: float, py: float, vx: float, vy: float, m: float,
		d0: int, d1: int, steer_at: float, hold: float, used: int, limit: int, walking: bool) -> void:
	var t := 0.0
	var flutter := 0.0
	var on_floor := walking
	var walk_frames := 0
	var dash := _feather_move
	var dash_left := 0 # frames of the dash still to run
	var dash_cd := 0.0
	if _launch_dash:
		_launch_dash = false
		dash_left = DASH_FRAMES
	for frame in MAX_AIR_FRAMES:
		var d := d0 if t < steer_at else d1
		dash_cd -= DT
		var steer := true
		# --- vertical (player.gd step 1) ---
		if dash_left > 0:
			# Dash Strike: fixed velocity, no gravity, no steering; the last
			# frame eases off to her run speed and a third of the vertical.
			dash_left -= 1
			if dash_left == 0:
				vx = dash.x * BASE_SPEED * _top_speed
				vy = dash.y * DASH_SPEED * DASH_CARRY_Y
				dash_cd = DASH_COOLDOWN
			else:
				vx = dash.x * DASH_SPEED
				vy = dash.y * DASH_SPEED
				steer = false
		elif not on_floor:
			if flutter > 0.0:
				vy += GRAVITY * FLUTTER_GRAVITY_SCALE * DT
				vy = move_toward(vy, FLUTTER_KICK * _flutter_height, 15.0)
				flutter -= DT
			else:
				vy = minf(vy + GRAVITY * (1.0 if vy < 0.0 else FALL_GRAVITY_SCALE) * DT, TERMINAL_VELOCITY)
				if hold > 0.0:
					vy += JUMP_ADD_FORCE * DT
					hold -= DT
				elif vy > 10.0 and used < limit and (dash == Vector2.ZERO or dash_cd <= 0.0):
					# A feather at the apex; the fork stops spending here.
					_air_tail(out, px, py, vx, vy, m, d0, d1, steer_at, t)
					used += 1
					if dash == Vector2.ZERO:
						flutter = FLUTTER_DURATION
						vy = FLUTTER_KICK * _flutter_height
					else:
						dash_left = DASH_FRAMES - 1 # this frame is the first
						vx = dash.x * DASH_SPEED
						vy = dash.y * DASH_SPEED
						steer = false
		# --- horizontal (step 2) ---
		if not steer:
			pass
		elif d != 0:
			if on_floor:
				if signf(vx) != float(d) and absf(vx) > 20.0:
					m = 1.0
				else:
					m = move_toward(m, MAX_MOMENTUM_BONUS, DT * MOMENTUM_GAIN_RATE * _momentum_gain)
			var a := ACCELERATION * _accel
			if signf(vx) != float(d) and absf(vx) > 20.0:
				a = maxf(a, FRICTION) * _traction
			vx = move_toward(vx, d * minf(BASE_SPEED * _top_speed * m, MAX_SPEED * _top_speed), a * DT)
		else:
			vx = move_toward(vx, 0.0, FRICTION * _traction * DT)
		# --- move & collide ---
		var r := _step(px, py, vx, vy)
		if r == STEP_DEAD:
			return
		px = _px
		py = _py
		if r & STEP_WALL:
			vx = 0.0
		if r & STEP_VERT:
			vy = 0.0
		if dash_left > 0:
			# A dash stops at a wall it drives into, or a ceiling.
			var into_wall := (r & STEP_WALL) != 0 and dash.x != 0.0
			if into_wall or ((r & STEP_VERT) != 0 and dash.y < 0.0):
				dash_left = 0
				dash_cd = DASH_COOLDOWN
				vx = 0.0 if into_wall else dash.x * BASE_SPEED * _top_speed
				vy = dash.y * DASH_SPEED * DASH_CARRY_Y
		t += DT
		_touch_goals(px, py)
		if on_floor:
			if not (r & STEP_LANDED):
				on_floor = false # walked off the edge
			else:
				walk_frames += 1
				if walk_frames > 90 or r & STEP_WALL:
					return # blocked, or a long walk the next cell covers
		elif r & STEP_LANDED:
			out.append(_feet_cell(Vector2(px, py)))
			return


## The no-more-flutters fork: carries on from mid-air with nothing left.
func _air_tail(out: Array[Vector2i], px: float, py: float, vx: float, vy: float, m: float,
		d0: int, d1: int, steer_at: float, t: float) -> void:
	# Shift the steer time so the fork switches direction at the same moment.
	_air(out, px, py, vx, vy, m, d0 if t < steer_at else d1, d1, maxf(steer_at - t, 0.0), 0.0, 0, 0, false)


const STEP_WALL := 1
const STEP_VERT := 2
const STEP_LANDED := 4
const STEP_DEAD := 8
var _px := 0.0
var _py := 0.0

## Moves her box x then y through the grid (into _px/_py). Returns STEP_*
## flags; STEP_DEAD alone for a hazard or falling out of the room.
func _step(px: float, py: float, vx: float, vy: float) -> int:
	var flags := 0
	var nx := px + vx * DT
	var row0 := floori((py - BODY_H) / TILE)
	var row1 := floori((py - 0.001) / TILE)
	if vx != 0.0:
		var col := floori((nx + HALF_W - 0.001) / TILE) if vx > 0.0 else floori((nx - HALF_W) / TILE)
		for row in range(row0, row1 + 1):
			if _cell(col, row) == SOLID:
				flags |= STEP_WALL
				nx = (col * TILE - HALF_W) if vx > 0.0 else ((col + 1) * TILE + HALF_W)
				break
	var ny := py + vy * DT
	var c0 := floori((nx - HALF_W) / TILE)
	var c1 := floori((nx + HALF_W - 0.001) / TILE)
	if vy > 0.0:
		var row := floori((ny - 0.001) / TILE)
		if row > row1: # feet crossed into a new row: is its top solid?
			for col in range(c0, c1 + 1):
				var v := _cell(col, row)
				if v == SOLID or v == PLATFORM:
					ny = row * TILE
					flags |= STEP_VERT | STEP_LANDED
					break
	elif vy < 0.0:
		var row := floori((ny - BODY_H) / TILE)
		if row < row0:
			for col in range(c0, c1 + 1):
				if _cell(col, row) == SOLID:
					ny = (row + 1) * TILE + BODY_H
					flags |= STEP_VERT
					break
	if vy >= 0.0 and not (flags & STEP_LANDED) and fmod(ny, TILE) == 0.0:
		# Standing (or walking) on a floor.
		var row := int(ny) / TILE
		for col in range(c0, c1 + 1):
			var v := _cell(col, row)
			if v == SOLID or v == PLATFORM:
				flags |= STEP_LANDED
				break
	if ny - BODY_H > _h * TILE:
		return STEP_DEAD
	if _has_hazard:
		for row in range(floori((ny - BODY_H) / TILE), floori((ny - 0.001) / TILE) + 1):
			for col in range(c0, c1 + 1):
				if _cell(col, row) == HAZARD:
					return STEP_DEAD
	_px = nx
	_py = ny
	return flags


func _touch_goals(x: float, y: float) -> void:
	var body := Rect2(x - HALF_W, y - BODY_H, HALF_W * 2.0, BODY_H)
	if not body.intersects(_goal_any):
		return
	for i in _goal_rects.size():
		if not _goal_hit[i] and body.intersects(_goal_rects[i]):
			_goal_hit[i] = true


# --------------------------------------------------------------------------
# Grid

## Tile under her feet: the floor cell she stands on (the one under her
## centre if solid, else under whichever edge holds her).
func _feet_cell(p: Vector2) -> Vector2i:
	var row := floori((p.y + 0.5) / TILE)
	var mid := floori(p.x / TILE)
	if _standable(Vector2i(mid, row)):
		return Vector2i(mid, row)
	for col in [floori((p.x - HALF_W) / TILE), floori((p.x + HALF_W - 0.001) / TILE)]:
		if _standable(Vector2i(col, row)):
			return Vector2i(col, row)
	return Vector2i(mid, row)


func _standable(c: Vector2i) -> bool:
	var v := _cell(c.x, c.y)
	return (v == SOLID or v == PLATFORM) and _cell(c.x, c.y - 1) != SOLID


func _cell(x: int, y: int) -> int:
	if x < 0 or x >= _w or y < 0:
		return SOLID # side walls and ceiling of the room
	if y >= _h:
		return AIR # the kill floor
	return _grid[y * _w + x]


func _read_grid(generator: LevelGenerator) -> void:
	_w = generator.width
	_h = generator.height
	var layer := generator.ground_layer
	var theme := generator.tile_theme
	_offset = layer.position
	_grid.resize(_w * _h)
	_grid.fill(AIR)
	for c: Vector2i in layer.get_used_cells():
		if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
			continue
		var atlas := layer.get_cell_atlas_coords(c)
		var v := SOLID
		if theme:
			if atlas == theme.platform:
				v = PLATFORM
			elif theme.has_hazard() and (atlas == theme.hazard_top or atlas == theme.hazard_fill):
				v = HAZARD
				_has_hazard = true
		_grid[c.y * _w + c.x] = v
