class_name PlayerSkins
extends RefCounted
## Her armor skins: cosmetic only. Each skin is a pair of sprite sheets with
## exactly the original layout (knight.png + flutterfall.png), so a skin is
## applied by swapping the atlas of every frame in her SpriteFrames. "original"
## keeps the scene's own sheets untouched.
##
## The choice is a setting (user://settings.cfg, [cosmetic] skin), not part of a
## save file. Change it with PlayerSkins.cycle() / set_skin(); every node in the
## "player" group gets apply_skin() called so it updates at once.
## Sheets are made by tools/gen_player_skins.py.

const ORIGINAL_KNIGHT := preload("res://assets/sprites/knight.png")
const ORIGINAL_FLUTTER := preload("res://assets/sprites/flutterfall.png")
const SKIN_DIR := "res://assets/sprites/valkyrie/skins/"
const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "cosmetic"

## [id, display name], in cycle order. Sheets: SKIN_DIR + id + ".png" / "_flutter.png".
const SKINS := [
	["original", "Original"],
	["shieldmaiden", "Shieldmaiden"],
	["hel_forged", "Hel-Forged"],
	["rootwarden", "Rootwarden"],
	["einherjar", "Einherjar Gold"],
]

static var _current := ""


## The chosen skin's id.
static func current() -> String:
	if _current == "":
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		_current = str(cfg.get_value(SECTION, "skin", "original"))
		if _index_of(_current) < 0:
			_current = "original"
	return _current


static func current_name() -> String:
	return SKINS[_index_of(current())][1]


## Picks a skin, remembers it, and re-skins the player if one is in the scene.
static func set_skin(id: String, tree: SceneTree = null) -> void:
	if _index_of(id) < 0:
		return
	_current = id
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # keep the other sections
	cfg.set_value(SECTION, "skin", id)
	cfg.save(SETTINGS_PATH)
	if tree:
		for node in tree.get_nodes_in_group("player"):
			if node.has_method("apply_skin"):
				node.apply_skin()


## Steps to the next (step 1) or previous (step -1) skin. Returns its name.
static func cycle(step: int, tree: SceneTree = null) -> String:
	var i := posmod(_index_of(current()) + step, SKINS.size())
	set_skin(SKINS[i][0], tree)
	return SKINS[i][1]


## Returns `frames` re-skinned to `id` (a copy; the original is never changed).
## Frames whose atlas isn't one of the original sheets are kept as they are.
static func skinned(frames: SpriteFrames, id: String) -> SpriteFrames:
	if id == "original" or _index_of(id) < 0:
		return frames
	var knight := load(SKIN_DIR + id + ".png") as Texture2D
	var flutter := load(SKIN_DIR + id + "_flutter.png") as Texture2D
	var copy := frames.duplicate() as SpriteFrames
	for anim in copy.get_animation_names():
		for f in copy.get_frame_count(anim):
			var tex := copy.get_frame_texture(anim, f) as AtlasTexture
			if tex == null:
				continue
			var swap: Texture2D = null
			if tex.atlas == ORIGINAL_KNIGHT:
				swap = knight
			elif tex.atlas == ORIGINAL_FLUTTER:
				swap = flutter
			if swap:
				var t := tex.duplicate() as AtlasTexture
				t.atlas = swap
				copy.set_frame(anim, f, t, copy.get_frame_duration(anim, f))
	return copy


static func _index_of(id: String) -> int:
	for i in SKINS.size():
		if SKINS[i][0] == id:
			return i
	return -1
