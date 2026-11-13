extends Area2D

var _collected := false
var _player_prev := Vector2.INF


func _ready() -> void:
	# The scene's small capsule was hard to hit at her speed; widen it here
	# (one place for every placed and generated coin). Visuals unchanged.
	Pickup.set_collect_radius(self, Pickup.COIN_COLLECT_RADIUS)


func _physics_process(_delta: float) -> void:
	var sweep := Pickup.swept_player(self, Pickup.COIN_COLLECT_RADIUS, _player_prev)
	_player_prev = sweep["prev"]
	if sweep["player"]:
		_on_body_entered(sweep["player"])


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true

	GameManager.add_point()
	Pickup.play_coin_sound()
	if body.has_method("on_coin_collected"):
		body.on_coin_collected(1)
	queue_free()
