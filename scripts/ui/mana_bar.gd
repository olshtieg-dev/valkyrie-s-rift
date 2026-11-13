extends CanvasLayer
## The Magigonne's mana bar: a row of rune gems under her hearts, one per
## shot. Lit gems are ready, dim ones spent; the gem the trickle is refilling
## fills from the bottom. Tinted with the active sword's element, like the
## shots. Hidden until she owns the Magigonne. Created by Magigonne._ready().
## Drawn in code at an exact 2x, like the feather row (wings_label.gd).

## 5x7 gem. 'h' highlight, 'c' core, 's' shade. Outlined in code.
const GEM := [
	"..c..",
	".hcc.",
	"hhccs",
	"hccss",
	"cccss",
	".css.",
	"..s..",
]
const SCALE := 2.0
const GAP := 3.0
## Top-left of the row, in HUD pixels: under the hearts (LivesLabel).
const ORIGIN := Vector2(6, 56)
const OUTLINE := Color(0.08, 0.06, 0.12)
const SPENT_ALPHA := 0.28

## Set by the Magigonne that owns this bar.
var magigonne: Node

var _canvas: Control


func _ready() -> void:
	layer = 1
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.position = ORIGIN
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func _process(_delta: float) -> void:
	var show_bar: bool = is_instance_valid(magigonne) and magigonne.owned()
	_canvas.visible = show_bar
	if show_bar:
		_canvas.queue_redraw()


func _on_draw() -> void:
	var player: Node = magigonne.get_parent()
	var data: WeaponData = player.get("weapon_data")
	var tint: Color = Magigonne.element_color(data.element if data else Hit.Element.NONE)
	var w := float(GEM[0].length()) * SCALE
	var refill: float = magigonne.trickle_progress()
	for i in int(magigonne.max_mana):
		var origin := Vector2(i * (w + GAP), 0)
		var full: bool = i < int(magigonne.mana)
		# The trickle refills the first empty gem, from the bottom up.
		var fill_rows := GEM.size() if full else (roundi(refill * GEM.size()) if i == int(magigonne.mana) else 0)
		_draw_gem(origin, tint, fill_rows)


func _draw_gem(origin: Vector2, tint: Color, fill_rows: int) -> void:
	for row in GEM.size():
		var line: String = GEM[row]
		for col in line.length():
			if line[col] == ".":
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(col, row) + d
				if not _filled(n):
					_canvas.draw_rect(Rect2(origin + Vector2(n) * SCALE, Vector2.ONE * SCALE), OUTLINE)
	for row in GEM.size():
		var line: String = GEM[row]
		var lit := row >= GEM.size() - fill_rows
		for col in line.length():
			var ch := line[col]
			if ch == ".":
				continue
			var color: Color = tint.lerp(Color.WHITE, 0.55) if ch == "h" else tint.darkened(0.35) if ch == "s" else tint
			if not lit:
				color = Color(color.darkened(0.5), SPENT_ALPHA)
			_canvas.draw_rect(Rect2(origin + Vector2(col, row) * SCALE, Vector2.ONE * SCALE), color)


func _filled(p: Vector2i) -> bool:
	if p.y < 0 or p.y >= GEM.size():
		return false
	var line: String = GEM[p.y]
	return p.x >= 0 and p.x < line.length() and line[p.x] != "."
