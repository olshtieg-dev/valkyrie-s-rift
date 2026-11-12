@tool
class_name WeaveBuilder
extends RefCounted
## Builds a level out of interlocking, weaving sub-areas, for the
## LevelGenerator styles WEAVE (Yggdrasil's hollow trunk) and MOUNTAIN (the
## roots, climbed like a mountain).
##
## How a level is put together:
##   1. The body is shaped in solid tiles: a straight trunk with open air on
##      both flanks, or a stepped mountain that narrows as it rises, its flanks
##      a staircase of cliffs and terraces under a solid cap.
##   2. The map is cut into lanes: an open-air flank on each side and one or
##      more lanes inside the body (`shaft_width` sets how wide each is). Each
##      lane is cut into bands `knothole_spacing` rows tall, and every other
##      lane is shifted half a band, like brickwork. Each lane x band cell is a
##      WeaveSlot.
##   3. Because of the brick offset each slot's upper half touches the lower
##      half of the slot beside it, so a doorway there always leads up. The main
##      route steps from slot to slot, always to a higher floor, swapping lanes
##      most of the time: it weaves in and out of the body (inside, out on the
##      flank, back inside, across...) while it climbs. It never doubles back
##      down, so the way on stays readable.
##   4. Side detours branch off the route into unused slots (a den in the wood,
##      a branch tip out in the air); these become the generator's side rooms,
##      so rewards, finds and gates work as in the other styles. A few loops
##      reconnect route slots that touch, so the strands rejoin.
##   5. Each used slot gets a sub-area template (WeaveArea) that carves it.
##      Then the connectors are cut (doors through walls and bark, holes
##      through floors, ledges between flank bands) and every slot's ports are
##      linked with ledges spaced for her real jump (no flutter needed).
##
## Seeded through the generator's RNG, so a seed always builds the same level.
## Adding a sub-area type: see WeaveArea, then add its script to AREA_SCRIPTS.

enum Body { TRUNK, MOUNTAIN }

const AIR := LevelGenerator.AIR
const SOLID := LevelGenerator.SOLID
const PLATFORM := LevelGenerator.PLATFORM

## Every sub-area template on offer. Each declares which bodies and roles it fits.
const AREA_SCRIPTS: Array = [
	preload("res://scripts/level/weave/areas/chamber.gd"),
	preload("res://scripts/level/weave/areas/gallery.gd"),
	preload("res://scripts/level/weave/areas/hollow.gd"),
	preload("res://scripts/level/weave/areas/tangle.gd"),
	preload("res://scripts/level/weave/areas/burrow.gd"),
	preload("res://scripts/level/weave/areas/den.gd"),
	preload("res://scripts/level/weave/areas/flank.gd"),
	preload("res://scripts/level/weave/areas/branch_tip.gd"),
	preload("res://scripts/level/weave/areas/stray_branches.gd"),
]

## Rows between generated ledges. Her held jump clears ~7 tiles (~6 with the
## heaviest sword), so 4 leaves room for a missed hold.
const RISE := 4
## Columns between generated ledge centres (ledges are 3 wide).
const RUN := 3
## Wood or rock kept around each inner slot; walls between slots are twice this.
const WALL := 1
## Most loops (extra doors between route slots that touch) per level.
const MAX_LOOPS := 2
## Chance that a detour runs on through a second slot before its reward room.
const LONG_DETOUR_CHANCE := 0.35

var g: LevelGenerator
var rng: RandomNumberGenerator
var body: Body
## "trunk" or "mountain", matched against WeaveArea.tags.
var tag: String
var band_h: int
## lane index -> Array of WeaveSlot, lowest band first.
var lanes: Array = []
## Main route, bottom to top.
var route: Array[WeaveSlot] = []
## Every connection: {"a": lower WeaveSlot, "b": higher WeaveSlot, "kind":
## "door"/"hole"/"ledge", "pa"/"pb": ports, plus door geometry}.
var links: Array[Dictionary] = []

var _w: int
var _h: int
var _n_inner := 1
var _areas: Array[WeaveArea] = []
var _mass := PackedByteArray()
var _face_l := PackedInt32Array() # per row: leftmost column of the body
var _face_r := PackedInt32Array() # per row: rightmost column of the body
var _detours: Array[Dictionary] = []
var _start_anchor := Vector2i(-1, -1)


func _init(generator: LevelGenerator) -> void:
	g = generator
	rng = generator._rng
	_w = generator.width
	_h = generator.height


func build(p_body: Body) -> void:
	body = p_body
	tag = "trunk" if body == Body.TRUNK else "mountain"
	band_h = clampi(g.knothole_spacing, 12, 24)
	for script: Script in AREA_SCRIPTS:
		_areas.append(script.new())
	_mass.resize(_w * _h)
	_mass.fill(0)
	_face_l.resize(_h)
	_face_r.resize(_h)
	if body == Body.TRUNK:
		_shape_trunk()
	else:
		_shape_mountain()
	_make_lanes()

	var ends := _plan_openings()
	_plan_route(ends["start"], ends["goal"])
	_plan_detours()
	_plan_loops()
	_assign_areas()

	for slot in _all_slots():
		if slot.area:
			slot.area.carve(self, slot)
	for link in links:
		_cut(link)
	g._make_openings()
	for slot in _all_slots():
		if slot.area:
			slot.area.link(self, slot) # links never touch the openings' protected cells
	if _start_anchor.x >= 0:
		g._add_start_anchor(_start_anchor.x, _start_anchor.y)
	_register_side_rooms()
	_mark_areas()


# --------------------------------------------------------------------------
# Body shapes
# --------------------------------------------------------------------------

func _shape_trunk() -> void:
	g._grid.fill(AIR)
	var t0 := (_w - g.trunk_width) / 2
	var t1 := t0 + g.trunk_width - 1
	_n_inner = maxi(1, roundi(float(g.trunk_width - 2 * g.bark_thickness) / g.shaft_width))
	for y in _h:
		_face_l[y] = t0
		_face_r[y] = t1
	for y in _h:
		for x in range(t0, t1 + 1):
			_set_mass(x, y)
	_fill_body()
	_fill_ground()
	_rough_faces()


func _shape_mountain() -> void:
	g._grid.fill(AIR)
	var cx := _w / 2
	var hw_base := mini(g.trunk_width / 2, _w / 2 - 7)
	var hw_top := clampi(g.shaft_width, 6, hw_base)
	_n_inner = clampi(roundi(2.0 * hw_top / g.shaft_width), 1, 3)
	# Each flank steps in band by band, its own way: cliffs with terraces.
	for side: int in [-1, 1]:
		var lane := 0 if side < 0 else _n_inner + 1
		var bands := _bands(lane % 2 == 1)
		var hw := float(hw_base)
		var per := float(hw_base - hw_top) / maxf(1.0, bands.size() - 1)
		for i in bands.size():
			var band: Vector2i = bands[i]
			if i > 0:
				hw = maxf(hw_top, hw - per * rng.randf_range(0.2, 1.8))
			if i == bands.size() - 1:
				hw = hw_top
			for y in range(band.x, band.y + 1):
				if side < 0:
					_face_l[y] = cx - int(hw)
				else:
					_face_r[y] = cx + int(hw)
	for y in [0, 1, _h - 2, _h - 1]:
		_face_l[y] = 0
		_face_r[y] = _w - 1
	for y in _h:
		for x in range(_face_l[y], _face_r[y] + 1):
			_set_mass(x, y)
	_fill_body()
	_fill_ground()
	_rough_faces()


func _set_mass(x: int, y: int) -> void:
	_mass[y * _w + x] = 1


func _fill_body() -> void:
	for i in _w * _h:
		if _mass[i] == 1:
			g._grid[i] = SOLID


func _fill_ground() -> void:
	g._fill_rect(0, _h - 2, _w - 1, _h - 1, SOLID)


## Knots and bumps on the faces, away from band edges where ledges and
## terraces meet. Slot rects keep a column clear of them.
func _rough_faces() -> void:
	for side: int in [-1, 1]:
		var lane := 0 if side < 0 else _n_inner + 1
		for band: Vector2i in _bands(lane % 2 == 1):
			for y in range(band.x + 2, band.y - 1):
				if rng.randf() < 0.22:
					var x := _face_l[y] - 1 if side < 0 else _face_r[y] + 1
					g._put(x, y, SOLID)


# --------------------------------------------------------------------------
# Lanes and slots
# --------------------------------------------------------------------------

## Bands for a lane as Vector2i(top row, bottom row), lowest first. Shifted
## lanes start with a half band, which staggers them like brickwork.
func _bands(shifted: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var bottom := _h - 3
	var size := band_h / 2 if shifted else band_h
	while bottom >= 2:
		var top := bottom - size + 1
		if top - 2 < 6:
			top = 2 # too little left above: fold it into this band
		out.append(Vector2i(top, bottom))
		bottom = top - 1
		size = band_h
	return out


func _make_lanes() -> void:
	lanes.clear()
	var n_lanes := _n_inner + 2
	for lane in n_lanes:
		var side := -1 if lane == 0 else (1 if lane == n_lanes - 1 else 0)
		var list: Array = []
		var bands := _bands(lane % 2 == 1)
		for i in bands.size():
			var rect := _slot_rect(lane, side, bands[i])
			if rect.size.x >= 4 and rect.size.y >= 5:
				list.append(WeaveSlot.new(lane, i, side, rect))
		lanes.append(list)


func _slot_rect(lane: int, side: int, band: Vector2i) -> Rect2i:
	var top := band.x
	var bottom := band.y
	if side != 0:
		if side < 0:
			var face := _w
			for y in range(top, bottom + 1):
				face = mini(face, _face_l[y])
			return Rect2i(1, top, maxi(0, face - 2), bottom - top + 1)
		var face_r := 0
		for y in range(top, bottom + 1):
			face_r = maxi(face_r, _face_r[y])
		var x0 := face_r + 2
		return Rect2i(x0, top, maxi(0, _w - 1 - x0), bottom - top + 1)
	var l := 0
	var r := _w
	for y in range(top, bottom + 1):
		l = maxi(l, _face_l[y])
		r = mini(r, _face_r[y])
	l += g.bark_thickness
	r -= g.bark_thickness
	var span := r - l + 1
	var k := lane - 1
	var x0 := l + k * span / _n_inner + (WALL if k > 0 else 0)
	var x1 := l + (k + 1) * span / _n_inner - 1 - (WALL if k < _n_inner - 1 else 0)
	return Rect2i(x0, top + WALL, x1 - x0 + 1, bottom - top + 1 - 2 * WALL)


func _all_slots() -> Array[WeaveSlot]:
	var out: Array[WeaveSlot] = []
	for list: Array in lanes:
		for slot: WeaveSlot in list:
			out.append(slot)
	return out


func _slot_at(lane: int, band: int) -> WeaveSlot:
	if lane < 0 or lane >= lanes.size():
		return null
	for slot: WeaveSlot in lanes[lane]:
		if slot.band == band:
			return slot
	return null


## The slot in `lane` whose rows contain `row`.
func _slot_in_lane_at_row(lane: int, row: int) -> WeaveSlot:
	if lane < 0 or lane >= lanes.size():
		return null
	for slot: WeaveSlot in lanes[lane]:
		if row >= slot.rect.position.y and row < slot.rect.end.y:
			return slot
	return null


func _inner_lane_near(col: int) -> int:
	var best := 1
	var best_d := 1 << 30
	for lane in range(1, _n_inner + 1):
		if lanes[lane].is_empty():
			continue
		var r: Rect2i = (lanes[lane][0] as WeaveSlot).rect
		var d := absi(r.get_center().x - col)
		if d < best_d:
			best_d = d
			best = lane
	return best


# --------------------------------------------------------------------------
# Openings, route, detours, loops
# --------------------------------------------------------------------------

## Finds the slot and arrival floor for each enabled opening, mirroring the
## geometry LevelGenerator._make_openings() carves. Returns {"start", "goal"},
## each {"slot": WeaveSlot, "pos": Vector2i} (goal may be empty).
func _plan_openings() -> Dictionary:
	var found: Array[Dictionary] = []
	if g.open_south:
		var lane := _inner_lane_near(g._col_for(g.south_at))
		var slot: WeaveSlot = lanes[lane][0]
		var c := clampi(slot.rect.get_center().x, slot.rect.position.x + 6, slot.rect.end.x - 2)
		g._south_col = c
		found.append({"name": "south", "slot": slot, "pos": Vector2i(c - 4, _h - 6)})
	if g.open_west:
		var r := g._row_for(g.west_at)
		var slot := _slot_in_lane_at_row(0, r - 1)
		if slot:
			found.append({"name": "west", "slot": slot, "pos": Vector2i(5, r)})
	if g.open_east:
		var r := g._row_for(g.east_at)
		var slot := _slot_in_lane_at_row(lanes.size() - 1, r - 1)
		if slot:
			found.append({"name": "east", "slot": slot, "pos": Vector2i(_w - 6, r)})
	if g.open_north:
		var lane := _inner_lane_near(g._col_for(g.north_at))
		var slot: WeaveSlot = lanes[lane].back()
		var c := clampi(slot.rect.get_center().x, slot.rect.position.x + 3, slot.rect.end.x - 4)
		g._north_col = c
		found.append({"name": "north", "slot": slot, "pos": Vector2i(c, 7)})

	var start := {}
	var goal := {}
	for f in found:
		if f["name"] == "south":
			start = f
	if start.is_empty():
		for f in found:
			if f["name"] != "north" and (start.is_empty() or f["pos"].y > start["pos"].y):
				start = f
	for f in found:
		if f != start and (goal.is_empty() or f["pos"].y < goal["pos"].y):
			goal = f
	if start.is_empty():
		var lane := _inner_lane_near(_w / 2)
		var slot: WeaveSlot = lanes[lane][0]
		var x := slot.rect.get_center().x
		_start_anchor = Vector2i(x, slot.floor_row())
		start = {"slot": slot, "pos": _start_anchor}
		g._south_col = x
	if goal.is_empty():
		var lane := _inner_lane_near(_w / 2)
		goal = {"slot": lanes[lane].back(), "pos": Vector2i(-1, -1)}
	for f in found:
		(f["slot"] as WeaveSlot).ports.append(f["pos"])
		if f != start and f != goal:
			_join_extra(f["slot"])
	return {"start": start["slot"], "goal": goal["slot"], "extras": found}


## A third opening: mark its slot as route and hook it to a touching route slot later.
func _join_extra(slot: WeaveSlot) -> void:
	slot.set_meta("extra", true)


## Slots one step up from `s`: the brick neighbours beside it whose floor is
## higher, and the next band of its own lane.
func _up_neighbors(s: WeaveSlot) -> Array[WeaveSlot]:
	var out: Array[WeaveSlot] = []
	for dl: int in [-1, 1]:
		var lane := s.lane + dl
		if lane < 0 or lane >= lanes.size():
			continue
		for t: WeaveSlot in lanes[lane]:
			if t.floor_row() < s.floor_row() and _door_fits(s, t):
				out.append(t)
	var up := _slot_at(s.lane, s.band + 1)
	if up and _vertical_fits(s, up):
		out.append(up)
	return out


## A door at the higher slot's floor row must open into the lower slot with
## headroom, at least two rows above its floor.
func _door_fits(lower: WeaveSlot, higher: WeaveSlot) -> bool:
	if lower.is_outside() and higher.is_outside():
		return false
	var f := higher.floor_row()
	return f - 3 >= lower.rect.position.y and f <= lower.floor_row() - 2 \
			and higher.rect.size.y >= 3


func _vertical_fits(a: WeaveSlot, b: WeaveSlot) -> bool:
	if a.is_outside():
		return true
	var x0 := maxi(a.rect.position.x, b.rect.position.x)
	var x1 := mini(a.rect.end.x, b.rect.end.x) - 1
	return x1 - x0 + 1 >= 5


func _can_reach(s: WeaveSlot, goal: WeaveSlot, memo: Dictionary) -> bool:
	if s == goal:
		return true
	if memo.has(s):
		return memo[s]
	memo[s] = false
	for n in _up_neighbors(s):
		if _can_reach(n, goal, memo):
			memo[s] = true
			break
	return memo[s]


## Weighted climb from start to goal: favours swapping lanes (the weave),
## turning back after a run in one direction, and the lanes the body likes
## (the trunk keeps her mostly inside, the mountain mostly on its slopes).
func _plan_route(start: WeaveSlot, goal: WeaveSlot) -> void:
	route.clear()
	var memo := {}
	if not _can_reach(start, goal, memo):
		push_warning("WeaveBuilder: no upward route from start to goal; check width/trunk_width/knothole_spacing.")
	var cur := start
	cur.role = WeaveSlot.Role.MAIN
	route.append(cur)
	var last_dir := 0
	var run := 0
	var verticals := 0
	while cur != goal:
		var cands: Array[WeaveSlot] = []
		var weights: Array[float] = []
		for n in _up_neighbors(cur):
			if not _can_reach(n, goal, memo):
				continue
			var dir := signi(n.lane - cur.lane)
			var w := 3.0 if dir != 0 else 1.0
			if body == Body.MOUNTAIN:
				w *= 1.5 if n.is_outside() else 1.0
				if dir == 0 and n.is_outside():
					w *= 2.0 # switchbacks up the slope
			else:
				w *= 0.75 if n.is_outside() else 1.0
			if dir != 0 and dir == last_dir:
				w *= 0.35 if run >= 2 else 0.8
			elif dir != 0 and dir == -last_dir:
				w *= 1.4
			if dir == 0 and verticals >= 2:
				w *= 0.15
			cands.append(n)
			weights.append(w)
		if cands.is_empty():
			break
		var next := cands[_pick(weights)]
		var d := signi(next.lane - cur.lane)
		if d == 0:
			verticals += 1
		else:
			verticals = 0
			run = run + 1 if d == last_dir else 1
			last_dir = d
		_connect(cur, next)
		next.role = WeaveSlot.Role.MAIN
		route.append(next)
		cur = next
	# Openings beyond start and goal join whichever route slot touches theirs.
	for slot in _all_slots():
		if slot.has_meta("extra") and slot.role == WeaveSlot.Role.NONE:
			for other: WeaveSlot in route:
				if other in _up_neighbors(slot):
					slot.role = WeaveSlot.Role.MAIN
					_connect(slot, other)
					break
				if slot in _up_neighbors(other):
					slot.role = WeaveSlot.Role.MAIN
					_connect(other, slot)
					break


## Off the route into unused slots beside it, every `side_room_spacing` rows
## at most, with `side_room_chance`. Inside they end in a den; on the flanks
## out along a branch. Sometimes the detour runs through a second slot first.
func _plan_detours() -> void:
	_detours.clear()
	var last_row := 1 << 20
	for i in route.size() - 1:
		var s := route[i]
		if absi(last_row - s.floor_row()) < g.side_room_spacing:
			continue
		if rng.randf() >= g.side_room_chance:
			continue
		var cands := _side_candidates(s, true)
		if cands.is_empty():
			continue
		var first: WeaveSlot = cands[rng.randi() % cands.size()]
		var dir := signi(first.lane - s.lane)
		var mouth_link := _connect_any(s, first)
		first.role = WeaveSlot.Role.SIDE
		var room := first
		if not first.is_outside() and rng.randf() < LONG_DETOUR_CHANCE:
			var more := _side_candidates(first, false).filter(
					func(t: WeaveSlot) -> bool: return not t.is_outside() and signi(t.lane - first.lane) != -dir)
			if not more.is_empty():
				var second: WeaveSlot = more[rng.randi() % more.size()]
				_connect_any(first, second)
				second.role = WeaveSlot.Role.SIDE
				room = second
		_detours.append({"room": room, "dir": dir, "link": mouth_link, "first": first})
		last_row = s.floor_row()


## Unused slots touching `s` that a door (or, if `lateral_only` is false, a
## hole) can reach. Flank slots only take branch-tip detours from inside.
func _side_candidates(s: WeaveSlot, lateral_only: bool) -> Array:
	var out: Array = []
	for dl: int in [-1, 1]:
		var lane := s.lane + dl
		if lane < 0 or lane >= lanes.size():
			continue
		for t: WeaveSlot in lanes[lane]:
			if t.is_used() or t.floor_row() == s.floor_row():
				continue
			if t.is_outside() and s.is_outside():
				continue
			var ok := _door_fits(s, t) if t.floor_row() < s.floor_row() else _door_fits(t, s)
			if ok and _offers(t, WeaveSlot.Role.SIDE):
				out.append(t)
	if not lateral_only and not s.is_outside():
		for db: int in [-1, 1]:
			var t := _slot_at(s.lane, s.band + db)
			if t and not t.is_used() and _offers(t, WeaveSlot.Role.SIDE) \
					and _vertical_fits(t if db < 0 else s, s if db < 0 else t):
				out.append(t)
	return out


## Extra doors between route slots that touch but aren't consecutive, so the
## strands reconnect. Lateral doors only, at most MAX_LOOPS.
func _plan_loops() -> void:
	var loops := 0
	for i in route.size():
		for j in range(i + 2, route.size()):
			if loops >= MAX_LOOPS:
				return
			var a := route[i]
			var b := route[j]
			if absi(a.lane - b.lane) != 1 or b.floor_row() >= a.floor_row():
				continue
			if _door_fits(a, b) and not _linked(a, b) and rng.randf() < 0.3:
				_connect(a, b)
				loops += 1


func _linked(a: WeaveSlot, b: WeaveSlot) -> bool:
	for link in links:
		if (link["a"] == a and link["b"] == b) or (link["a"] == b and link["b"] == a):
			return true
	return false


func _connect_any(s: WeaveSlot, t: WeaveSlot) -> Dictionary:
	if t.floor_row() < s.floor_row():
		return _connect(s, t)
	return _connect(t, s)


## Records a connection from `a` up to `b` and the ports it gives each slot.
## Nothing is cut yet; templates carve first, then _cut() opens the way.
func _connect(a: WeaveSlot, b: WeaveSlot) -> Dictionary:
	var link := {"a": a, "b": b}
	if a.lane != b.lane:
		var dir := signi(b.lane - a.lane)
		var f := b.floor_row()
		var ax := a.rect.end.x - 1 if dir > 0 else a.rect.position.x
		var bx := b.rect.position.x if dir > 0 else b.rect.end.x - 1
		link["kind"] = "door"
		link["dir"] = dir
		link["f"] = f
		link["ax"] = ax
		link["bx"] = bx
		link["pa"] = Vector2i(ax - dir, f)
		link["pb"] = Vector2i(bx + dir, f)
	elif a.is_outside():
		var row := b.floor_row()
		var out := a.side # outward, toward the map edge
		var x0 := b.rect.end.x - 1 if out < 0 else b.rect.position.x
		var px := x0 + out
		var terrace := g._cell(x0, row) == SOLID
		if terrace:
			px = x0
			while g._cell(px + out, row) == SOLID and absi(px - x0) < 12:
				px += out
		link["kind"] = "ledge"
		link["row"] = row
		link["x0"] = x0
		link["out"] = out
		link["terrace"] = terrace
		link["pa"] = Vector2i(px, row)
		link["pb"] = Vector2i(px, row)
	else:
		var x0 := maxi(a.rect.position.x, b.rect.position.x) + 2
		var x1 := mini(a.rect.end.x, b.rect.end.x) - 3
		var hx := rng.randi_range(x0, maxi(x0, x1))
		link["kind"] = "hole"
		link["hx"] = hx
		link["pa"] = Vector2i(hx, b.floor_row())
		link["pb"] = Vector2i(hx, b.floor_row())
	a.ports.append(link["pa"])
	b.ports.append(link["pb"])
	links.append(link)
	return link


## True if some template could fill `slot` in `role` (ignoring its ports).
func _offers(slot: WeaveSlot, role: WeaveSlot.Role) -> bool:
	for area in _areas:
		if tag in area.tags and area.inside == not slot.is_outside() and area.allows(role) \
				and slot.rect.size.x >= area.min_size.x and slot.rect.size.y >= area.min_size.y:
			return true
	return false


func _assign_areas() -> void:
	for slot in _all_slots():
		var cands: Array[WeaveArea] = []
		var weights: Array[float] = []
		for area in _areas:
			if tag in area.tags and area.inside == not slot.is_outside() \
					and area.allows(slot.role) and area.fits(slot):
				cands.append(area)
				weights.append(area.weight)
		if not cands.is_empty():
			slot.area = cands[_pick(weights)]
		elif slot.is_used() and not slot.is_outside():
			slot.area = _areas[0] # the plain chamber always fits


# --------------------------------------------------------------------------
# Cutting connectors and linking ports
# --------------------------------------------------------------------------

func _cut(link: Dictionary) -> void:
	match link["kind"]:
		"door":
			var dir: int = link["dir"]
			var f: int = link["f"]
			var ax: int = link["ax"]
			var bx: int = link["bx"]
			var a: WeaveSlot = link["a"]
			var b: WeaveSlot = link["b"]
			var x0 := mini(ax, bx)
			var x1 := maxi(ax, bx)
			g._fill_rect(x0, f - 3, x1, f - 1, AIR)
			for x in range(x0 + 1, x1):
				g._put(x, f, SOLID) # sill through the wall
			# A one-way sill (or lip out in the air) on each side.
			for x in [ax, ax - dir]:
				if g._cell(x, f) == AIR and _in_rect(a.rect, x, f - 1):
					g._put(x, f, PLATFORM)
			for x in [bx, bx + dir]:
				if g._cell(x, f) == AIR:
					g._put(x, f, PLATFORM)
			g._protect_rect(x0, f - 3, x1, f)
		"hole":
			var b: WeaveSlot = link["b"]
			var a: WeaveSlot = link["a"]
			var hx: int = link["hx"]
			g._fill_rect(hx - 1, b.floor_row(), hx + 1, a.rect.position.y - 1, AIR)
			g._fill_rect(hx - 1, b.floor_row(), hx + 1, b.floor_row(), PLATFORM)
			g._protect_rect(hx - 1, b.floor_row(), hx + 1, a.rect.position.y - 1)
		"ledge":
			if not link["terrace"]:
				var row: int = link["row"]
				var x0: int = link["x0"]
				var out: int = link["out"]
				for i in 3:
					if g._cell(x0 + out * i, row) == AIR:
						g._put(x0 + out * i, row, PLATFORM)
				g._protect_rect(mini(x0, x0 + out * 2), row, maxi(x0, x0 + out * 2), row)


## Default link: inside, every port above the floor gets a ledge chain down to
## the floor; on a flank the ports are chained bottom to top.
func link_ports(slot: WeaveSlot) -> void:
	if slot.ports.is_empty():
		return
	if not slot.is_outside():
		var fl := slot.floor_row()
		for q in slot.ports:
			if q.y >= fl - 1:
				continue
			var inward := signi(slot.rect.get_center().x - q.x)
			var x := clampi(q.x + inward * 2, slot.rect.position.x, slot.rect.end.x - 1)
			ledges(slot, Vector2i(x, fl), q)
		return
	var sorted := slot.ports.duplicate()
	sorted.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y > q.y)
	for i in range(1, sorted.size()):
		ledges(slot, sorted[i - 1], sorted[i])


## Lays one-way ledges between floor cells p and q, no more than RISE rows
## and RUN columns apart, and clears the jumps between them.
func ledges(slot: WeaveSlot, p: Vector2i, q: Vector2i) -> void:
	if p.y < q.y:
		var tmp := p
		p = q
		q = tmp
	var dy := p.y - q.y
	var dx := q.x - p.x
	var n := maxi(ceili(dy / float(RISE)), ceili(absi(dx) / float(RUN))) - 1
	var prev := p
	for i in range(1, n + 1):
		var t := float(i) / (n + 1)
		var pt := Vector2i(roundi(lerpf(p.x, q.x, t)), roundi(lerpf(p.y, q.y, t)))
		if absi(dx) < 2 * n:
			pt.x += 1 if i % 2 == 0 else -1 # zigzag a straight stack
		pt.x = clampi(pt.x, slot.rect.position.x + 1, slot.rect.end.x - 2)
		pt = _clear_of_openings(slot, pt, signi(dx))
		for x in range(pt.x - 1, pt.x + 2):
			if g._cell(x, pt.y) == AIR and not g._is_protected(x, pt.y):
				g._put(x, pt.y, PLATFORM)
		clear_between(slot, prev, pt)
		prev = pt
	clear_between(slot, prev, q)


## Openings and doors keep their pockets clear: slide a ledge sideways out
## of a protected box (toward `toward` first), else step it up.
func _clear_of_openings(slot: WeaveSlot, pt: Vector2i, toward: int) -> Vector2i:
	if not _ledge_blocked(pt):
		return pt
	var first := toward if toward != 0 else 1
	var dirs: Array[int] = [first, -first]
	for k in range(1, 5):
		for d in dirs:
			var c := Vector2i(pt.x + d * k, pt.y)
			if c.x >= slot.rect.position.x + 1 and c.x <= slot.rect.end.x - 2 and not _ledge_blocked(c):
				return c
	for lift in range(1, 4):
		var c := Vector2i(pt.x, pt.y - lift)
		if not _ledge_blocked(c):
			return c
	return pt


func _ledge_blocked(pt: Vector2i) -> bool:
	return g._is_protected(pt.x - 1, pt.y) or g._is_protected(pt.x, pt.y) or g._is_protected(pt.x + 1, pt.y)


## Opens the air a jump from floor cell a to floor cell b passes through.
func clear_between(slot: WeaveSlot, a: Vector2i, b: Vector2i) -> void:
	var x0 := maxi(mini(a.x, b.x) - 1, slot.rect.position.x)
	var x1 := mini(maxi(a.x, b.x) + 1, slot.rect.end.x - 1)
	var y0 := maxi(mini(a.y, b.y) - 2, slot.rect.position.y)
	var y1 := mini(maxi(a.y, b.y) - 1, slot.rect.end.y - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if g._cell(x, y) == SOLID and not g._is_protected(x, y):
				g._put(x, y, AIR)


# --------------------------------------------------------------------------
# Hand-off to the generator
# --------------------------------------------------------------------------

func _register_side_rooms() -> void:
	for d in _detours:
		var room: WeaveSlot = d["room"]
		var link: Dictionary = d["link"]
		var first: WeaveSlot = d["first"]
		var rect := room.room_rect if room.room_rect.has_area() else room.rect
		var entry := {"rect": rect, "dir": d["dir"]}
		# The gate (vine/slime) plugs the first door, in the wall column next to the detour.
		if link["kind"] == "door" and not first.is_outside():
			var dir: int = link["dir"]
			var f: int = link["f"]
			var mx: int = link["ax"] + dir if link["a"] == first else link["bx"] - dir
			entry["mouth"] = Vector2i(mx, f - 1)
		g._side_rooms.append(entry)


## Background behind the body. The generator's auto climbing platforms are
## not used here: every port already has its own ledges.
func _mark_areas() -> void:
	g._backdrop = _mass.duplicate()


# --------------------------------------------------------------------------
# Helpers for templates
# --------------------------------------------------------------------------

func fill(rect: Rect2i, v: int) -> void:
	g._fill_rect(rect.position.x, rect.position.y, rect.end.x - 1, rect.end.y - 1, v)


func put(x: int, y: int, v: int) -> void:
	g._put(x, y, v)


func cell(x: int, y: int) -> int:
	return g._cell(x, y)


func _in_rect(r: Rect2i, x: int, y: int) -> bool:
	return r.has_point(Vector2i(x, y))


func _pick(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


## Debug: one line per route slot (lane, band, template), bottom to top.
func describe() -> String:
	var lines: PackedStringArray = []
	for slot in route:
		lines.append("lane %d band %d %s" % [slot.lane, slot.band, slot.area.area_name if slot.area else "-"])
	return "\n".join(lines)
