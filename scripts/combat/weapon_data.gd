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
@export var icon: Texture2D

@export_group("Attack")
@export var damage: int = 15
@export var element: Hit.Element = Hit.Element.NONE
## Every hit is heavy: breaks armor and shatters frozen things (the hammer).
## The meteor strike is always heavy regardless.
@export var heavy_hits: bool = false

@export_group("Movement")
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
