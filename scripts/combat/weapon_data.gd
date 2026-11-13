@tool
class_name WeaponData
extends Resource
## One sword = one loadout. Besides its swing, a sword decides how she moves:
## speed, momentum, traction, and her flutter. Edit the .tres files in
## data/weapons/ in the Inspector to tune them.
##
## All movement values are multipliers on the player's base movement
## (1.0 = the starter blade), so the base feel lives in one place: player.gd.

@export var id: StringName
@export var display_name: String = "Sword"
@export_multiline var description: String = ""
## The swing scene (a Weapon: sprite, AnimationPlayer, hitbox).
@export var scene: PackedScene
## Optional art swapped into the swing scene's sprite, so several weapons can
## share one swing. Draw it blade-up, grip at the bottom center, 1:1 pixels
## (16x16 like the rest of the world). Empty = the scene's own sprite.
@export var swing_texture: Texture2D
## Shown on pedestals and in the shrine menu.
@export var icon: Texture2D
## Tints the swing sprite and icon (lets one sword art stand in for another).
@export var tint: Color = Color.WHITE
## Coins at a shrine's barter stall. 0 = not for sale (found only).
@export var price: int = 0

@export_group("Attack")
@export var damage: int = 15
@export var element: Hit.Element = Hit.Element.NONE
## Every hit is heavy: breaks armor and shatters frozen things (the hammer).
## The meteor strike is always heavy regardless.
@export var heavy_hits: bool = false

## Swing speed: the swing animation's playback rate and the recovery after it.
@export_range(0.4, 2.0, 0.05) var attack_speed: float = 1.0
## Swing reach: grows the hitbox (and the close-range catch radius) about her
## hand in every direction, meteor strike included. The art keeps its pixels
## and is only pushed outward to stay centered on the hitbox, so above 1.0 the
## hitbox runs a little past the blade.
@export_range(0.5, 2.0, 0.05) var reach: float = 1.0
## Where the overhead (up + attack) swing turns, moved from her side-swing
## hand, in world pixels (x = ahead of her, y = down). Negative y lifts the
## swing above her helmet, so it starts over her head rather than at her face.
@export var up_offset: Vector2 = Vector2(0, -4)

@export_group("Attack movement")
## Up + attack launches her upward this fast (px/s): on the ground a launcher,
## in the air once per airtime (refreshed by landing a hit). 0 = no lift.
@export_range(0, 400, 10) var rising_lift: float = 230.0
## Side attack in the air dashes her forward this fast (px/s) for a moment,
## gravity off. Once per airtime, refreshed by landing a hit. 0 = no lunge.
@export_range(0, 500, 10) var lunge_speed: float = 0.0
## Scales the meteor strike's bounce off enemies and its landing shockwave.
@export_range(0.5, 2.0, 0.05) var meteor_power: float = 1.0

@export_group("Movement")
## Jump height (multiplies the jump's launch speed).
@export_range(0.6, 1.4, 0.05) var jump_height: float = 1.0
## Run speed and the momentum-boosted top speed.
@export_range(0.5, 1.5, 0.05) var top_speed: float = 1.0
## How fast she gets up to speed.
@export_range(0.5, 2.0, 0.05) var acceleration: float = 1.0
## How fast running builds momentum toward the top speed.
@export_range(0.5, 2.0, 0.05) var momentum_gain: float = 1.0
## Grip: how quickly she stops and turns around. Low = slides.
@export_range(0.3, 2.0, 0.05) var traction: float = 1.0

@export_group("Flutter")
## Upward kick of each flutter.
@export_range(0.5, 1.5, 0.05) var flutter_height: float = 1.0
## Flutters per airtime before armor/feather bonuses.
@export_range(0, 4) var flutter_charges: int = 2

@export_group("Sound")
## Sfx id of the swing (see scripts/audio/sfx.gd). Empty = by element.
@export var swing_sound: StringName = &""
## Sfx id when a swing lands. Empty = by element (heavy hitters thud).
@export var hit_sound: StringName = &""


## Her "loadout" with no sword at all: the start of the climb, before she finds
## the Valkyrie Blade in hel_02. The blade's movement (so tuning the blade
## tunes her bare-handed feel too), but no swing, no flutters of its own and
## no rising slash or lunge: her one attack is the meteor strike, a bare power
## stomp. Built in code (never a .tres, so no list of swords picks it up) and
## shared; its empty resource_path keeps it out of saves and owned_weapons.
const UNARMED_BASE := "res://data/weapons/valkyrie_blade.tres"
static var _unarmed: WeaponData


static func unarmed() -> WeaponData:
	if _unarmed == null:
		var w := (load(UNARMED_BASE) as WeaponData).duplicate() as WeaponData
		w.id = &"unarmed"
		w.display_name = "Unarmed"
		w.description = "No sword. Down + attack in the air is a power stomp."
		w.scene = null
		w.swing_texture = null
		w.icon = null
		w.tint = Color.WHITE
		w.price = 0
		w.element = Hit.Element.NONE
		w.heavy_hits = false
		w.reach = 1.0 # her boots, not a blade
		w.rising_lift = 0.0
		w.lunge_speed = 0.0
		w.flutter_charges = 0
		_unarmed = w
	return _unarmed
