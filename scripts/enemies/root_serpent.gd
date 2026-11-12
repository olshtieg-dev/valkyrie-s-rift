class_name RootSerpent
extends Enemy
## A serpent of living root that lairs in Yggdrasil's wood. Its burrow is a
## dark hole in a ceiling (or wall, or floor) with the head peeking out. When
## the player comes near, dust spills from the hole (telegraph), then it lunges
## out along a curve at where she was, a long chain of segments behind its
## head, sways there, and pulls back in. Every segment hurts to touch, and a
## hit anywhere on the body counts. Built for shafts and overhangs: it makes a
## stretch of the climb dangerous rather than a target to walk up to.
##
## Origin = the burrow mouth. It finds the nearest surface on its first
## physics frame (ceiling first), so it also works when hand-placed or spawned
## in the open (it snaps to a surface within `snap_range`).

enum State { HIDDEN, WARN, STRIKE, HOLD, RETRACT }

@export var sight: float = 120.0
## How far the head reaches from the burrow, in pixels.
@export var reach: float = 72.0
@export_range(2, 12) var segment_count: int = 7
@export var warn_time: float = 0.45
@export var strike_time: float = 0.28
@export var hold_time: float = 0.7
@export var retract_time: float = 0.5
@export var cooldown: float = 1.3
@export var snap_range: float = 96.0
@export var segment_texture: Texture2D
@export var body_region := Rect2(12, 0, 12, 12)
@export var tail_region := Rect2(24, 0, 10, 12)

const BURROW := Color(0.247, 0.149, 0.192) # #3f2631
const DUST := Color(0.74, 0.42, 0.29)

var _state := State.HIDDEN
var _found_surface := false
var _normal := Vector2.DOWN # out of the surface
var _target := Vector2.ZERO # local, where the head lunges to
var _extend := 0.0 # 0 = in the burrow, 1 = fully out
var _segments: Array[Area2D] = []
var _clock := 0.0
var _retract_from := 1.0 # _extend when RETRACT began (less than 1 after a thaw mid-lunge)


func _on_ready() -> void:
	uses_gravity = false
	for i in segment_count:
		var seg := Area2D.new()
		seg.name = "Segment%d" % i
		# Layer 1 so swords find it (they pass a hit on to the area's parent:
		# this serpent); mask 2 for touching the player.
		seg.collision_layer = 1
		seg.collision_mask = 2
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 4.0 if i < segment_count - 1 else 3.0
		shape.shape = circle
		seg.add_child(shape)
		var look := Sprite2D.new()
		look.texture = segment_texture if segment_texture else sprite.texture
		look.region_enabled = true
		look.region_rect = tail_region if i == segment_count - 1 else body_region
		seg.add_child(look)
		seg.z_index = -1 # behind the head
		add_child(seg)
		_segments.append(seg)
	_place_body()


## Runs on the first physics frame: tile collision doesn't exist yet in _ready.
func _find_surface() -> void:
	_found_surface = true
	for dir: Vector2 in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * snap_range, WORLD_MASK)
		query.exclude = [get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_normal = (hit["normal"] as Vector2).round()
			if _normal == Vector2.ZERO:
				_normal = -dir
			global_position = (hit["position"] as Vector2) + _normal * surface_offset
			break
	queue_redraw()


func _ai(delta: float) -> void:
	velocity = Vector2.ZERO
	if not _found_surface:
		_find_surface()
		return
	_clock += delta
	match _state:
		State.HIDDEN:
			_extend = 0.0
			if state_time >= cooldown and can_see_player(sight) and to_player().dot(_normal) > -4.0:
				play_sfx(&"enemy_rumble")
				_go(State.WARN)
		State.WARN:
			_extend = 0.0
			if int(state_time * 20.0) % 3 == 0:
				CombatFX.burst(self, global_position + _normal * 3.0, 4.0, DUST, 0.6, 1, 0.12)
			if state_time >= warn_time:
				_aim()
				play_sfx(&"enemy_swoop", 0.7)
				_go(State.STRIKE)
		State.STRIKE:
			var t := minf(1.0, state_time / strike_time)
			_extend = 1.0 - (1.0 - t) * (1.0 - t)
			if t >= 1.0:
				_go(State.HOLD)
		State.HOLD:
			_extend = 1.0
			if state_time >= hold_time:
				_go(State.RETRACT)
		State.RETRACT:
			_extend = maxf(0.0, _retract_from - state_time / retract_time)
			if _extend <= 0.0:
				_go(State.HIDDEN)
	_place_body()


## Picks the lunge point: toward the player, no farther than `reach`, and never
## back into the surface it lives in.
func _aim() -> void:
	var d := to_player()
	if d.dot(_normal) < 8.0:
		d += _normal * (8.0 - d.dot(_normal))
	_target = d.limit_length(reach)
	facing = 1 if _target.x >= 0.0 else -1


## Point on the body curve at t (0 = burrow, 1 = head at full reach), local.
## A quadratic curve that first leaves straight out of the hole.
func _curve(t: float) -> Vector2:
	var control := _normal * minf(reach * 0.45, _target.length() * 0.6)
	var p := (1.0 - t) * (1.0 - t) * Vector2.ZERO + 2.0 * (1.0 - t) * t * control + t * t * _target
	if _state == State.HOLD:
		var side := Vector2(-_normal.y, _normal.x)
		p += side * sin(_clock * 6.0 + t * 4.0) * 3.0 * t
	return p


func _place_body() -> void:
	var peek := _normal * 3.0
	var head := peek
	if _state == State.WARN:
		head = peek + _normal * roundf(1.0 + sin(state_time * 50.0))
	elif _target != Vector2.ZERO:
		head = _curve(_extend) + peek * (1.0 - _extend)
	head = head.round()
	sprite.position = head
	set_hurtbox_offset(head)
	var n := _segments.size()
	var out_states := _state == State.STRIKE or _state == State.HOLD or _state == State.RETRACT
	for i in n:
		var seg := _segments[i]
		var along := _extend * (1.0 - float(i + 1) / float(n + 1))
		var out := out_states and along * _target.length() > 4.0
		if seg.visible != out:
			seg.visible = out
			seg.set_deferred("monitoring", out)
			seg.set_deferred("monitorable", out)
		if out:
			seg.position = (_curve(along) + peek * (1.0 - along)).round()


## Every visible segment hurts to touch, not just the head's hurtbox.
func _deal_contact_damage() -> void:
	super()
	if contact_damage <= 0:
		return
	for seg in _segments:
		if not seg.visible or not seg.monitoring:
			continue
		for body in seg.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				var open := _can_hurt(body)
				body.take_damage(contact_damage, Vector2(signf(body.global_position.x - seg.global_position.x), -0.5), touch_element())
				_bite_if_landed(body, open)
				return


func _draw() -> void:
	if not _found_surface:
		return
	# The burrow: a dark slot in the surface, whole pixels.
	var side := Vector2(-_normal.y, _normal.x).abs()
	var size := side * 10.0 + _normal.abs() * 4.0
	var center := -_normal * 4.0 # on the surface face
	draw_rect(Rect2((center - size / 2.0).round(), size), BURROW)


## Frozen in its burrow or mid-lunge: the ice holds it where it is.
func _frozen_falls() -> bool:
	return false


## The whole body ices over, not just the head.
func freeze() -> void:
	super()
	if frozen:
		_tint_segments(FROZEN_TINT)


## Shakes off the ice and pulls back into the burrow from wherever it was
## caught (no thaw stagger: it's rooted, and the retreat is its recovery).
func thaw() -> void:
	if not frozen:
		return
	super()
	stagger_timer = 0.0
	_tint_segments(Color.WHITE)
	if _state == State.STRIKE or _state == State.HOLD or _state == State.RETRACT:
		_go(State.RETRACT)
	elif _state == State.WARN:
		_go(State.HIDDEN)


func _tint_segments(tint: Color) -> void:
	for seg in _segments:
		(seg.get_child(1) as Sprite2D).self_modulate = tint


func _go(s: State) -> void:
	_state = s
	if s == State.RETRACT:
		_retract_from = _extend
	enter_state()
