extends Label
## Wing flutters as a row of feathers: one per flutter she can make this
## airtime. Bright feathers are still available, dim ones are spent. Drawn in
## code from a small pixel bitmap at an exact 2x (the HUD isn't zoomed like the
## world), in the same white/blue-grey as the feather bursts.

## 7x14 feather, tip up. '#' vane, 's' shaded vane edge, 'q' quill.
const FEATHER := [
	"....#..",
	"...##s.",
	"..###s.",
	"..##qs.",
	".###qs.",
	".##q#s.",
	".##q#s.",
	"##q##s.",
	"##q#s..",
	"#q##s..",
	"#q#s...",
	".qs....",
	".q.....",
	"q......",
]
const SCALE := 2.0
## Screen pixels between feathers.
const GAP := 4.0
const VANE := Color(1, 1, 1)
const SHADE := Color(0.78, 0.84, 0.95)
const QUILL := Color(0.62, 0.66, 0.78)
const OUTLINE := Color(0.08, 0.08, 0.14)
## Spent feathers keep their outline but fade out.
const SPENT_ALPHA := 0.28

var _player: Node
var _left := 0
var _max := 0


func _ready() -> void:
	text = ""
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.wings_updated.connect(_on_wings_updated)
		_on_wings_updated(_player.flutter_charges_left)


func _on_wings_updated(count: int) -> void:
	_left = count
	_max = maxi(int(_player.max_flutter_charges), count) if is_instance_valid(_player) else count
	queue_redraw()


func _draw() -> void:
	var w := float(FEATHER[0].length()) * SCALE
	var h := float(FEATHER.size()) * SCALE
	var y := roundf((size.y - h) / 2.0)
	for i in _max:
		var origin := Vector2(i * (w + GAP), y)
		var alpha := 1.0 if i < _left else SPENT_ALPHA
		_draw_feather(origin, alpha)


func _draw_feather(origin: Vector2, alpha: float) -> void:
	var px := Vector2(SCALE, SCALE)
	# Outline pass: every empty neighbour of a filled pixel.
	for row in FEATHER.size():
		var line: String = FEATHER[row]
		for col in line.length():
			if line[col] == ".":
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(col, row) + d
				if not _filled(n):
					draw_rect(Rect2(origin + Vector2(n) * SCALE, px), Color(OUTLINE, alpha))
	# Fill pass.
	for row in FEATHER.size():
		var line: String = FEATHER[row]
		for col in line.length():
			var c := line[col]
			if c == ".":
				continue
			var color := QUILL if c == "q" else SHADE if c == "s" else VANE
			draw_rect(Rect2(origin + Vector2(col, row) * SCALE, px), Color(color, alpha))


func _filled(p: Vector2i) -> bool:
	if p.y < 0 or p.y >= FEATHER.size():
		return false
	var line: String = FEATHER[p.y]
	return p.x >= 0 and p.x < line.length() and line[p.x] != "."
