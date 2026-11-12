class_name CinderMite
extends Enemy
## A living ember from Hel's floors, smaller than a tile. Weak alone, it comes
## in swarms: the placed mite brings `swarm_size - 1` siblings with it. They
## skitter at the player in little hops, each at its own pace, so the swarm
## spreads out and has to be cut down one swing at a time. Burns on touch.

## Mites spawned together, this one included. Hand-placed or generated, one
## instance is a whole swarm. Set to 1 for a lone mite.
@export_range(1, 8) var swarm_size: int = 3
@export var speed: float = 62.0
@export var sight: float = 150.0
@export var hop_velocity: float = -170.0
@export var hop_interval: float = 0.8

var _hop_timer := 0.0
var _pace := 1.0


func _on_ready() -> void:
	_pace = randf_range(0.8, 1.2)
	_hop_timer = randf_range(0.2, hop_interval)
	facing = 1 if randf() < 0.5 else -1
	if swarm_size > 1 and not scene_file_path.is_empty():
		_spawn_swarm.call_deferred()


func _spawn_swarm() -> void:
	var scene := load(scene_file_path) as PackedScene
	var parent := get_parent()
	if not scene or not parent:
		return
	for i in swarm_size - 1:
		var mite := scene.instantiate() as CinderMite
		mite.swarm_size = 1
		var side := 1.0 if i % 2 == 0 else -1.0
		mite.position = position + Vector2(side * (6.0 + 5.0 * float(i / 2)), -2.0)
		parent.add_child(mite)


func _ai(delta: float) -> void:
	apply_gravity(delta)
	play_row(1)
	if not is_on_floor():
		return
	if can_see_player(sight):
		face_player()
		velocity.x = facing * speed * _pace
		if wall_ahead(5.0):
			velocity.x = 0.0
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			_hop_timer = hop_interval * randf_range(0.7, 1.3)
			velocity.y = hop_velocity * _pace
			play_sfx(&"enemy_hop_small", 1.3 * _pace)
	else:
		if wall_ahead(5.0) or ledge_ahead(4.0):
			facing = -facing
		velocity.x = facing * speed * 0.4 * _pace
