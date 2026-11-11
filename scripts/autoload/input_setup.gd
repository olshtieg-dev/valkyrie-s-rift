extends Node
## Gamepad setup, applied at startup before any input is read.
##
## Every action in project.godot is bound to Godot's *standard* layout
## (Xbox names / PlayStation names):
##   A / Cross     jump              X / Square    attack
##   Y / Triangle  switch weapon     RT / R2       switch weapon
##   left stick / D-pad  move        D-pad up      interact
##   Back / Select debug menu (debug builds)
##
## Godot translates each controller's raw buttons into that layout with a
## built-in database (SDL's gamecontrollerdb). Some third-party pads are in
## it with the wrong button order, so Square jumps and Cross does nothing.
## MAPPING_FIXES overrides those entries. To add a pad: find its GUID with
## Input.get_joy_guid(), log the raw button numbers, and add an SDL mapping
## string here (format: https://github.com/mdqinc/SDL_GameControllerDB).

const MAPPING_FIXES := [
	# PDP "Afterglow Gamepad for PS3" (USB 0e6f:0111). Generic HID pad whose raw
	# order is Square, Cross, Circle, Triangle, L1, R1, L2, R2, Select, Start,
	# L3, R3, PS; L2/R2 are digital. Godot's built-in entry swaps Square/Cross.
	# Listed with and without SDL3's CRC field in the GUID so either matches.
	"0300d3b76f0e00001101000011010000,Afterglow Gamepad for PS3,a:b1,b:b2,x:b0,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,back:b8,start:b9,leftstick:b10,rightstick:b11,guide:b12,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,",
	"030000006f0e00001101000011010000,Afterglow Gamepad for PS3,a:b1,b:b2,x:b0,y:b3,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,back:b8,start:b9,leftstick:b10,rightstick:b11,guide:b12,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,",
]


func _enter_tree() -> void:
	for mapping: String in MAPPING_FIXES:
		# true = also re-map a pad that is already plugged in.
		Input.add_joy_mapping(mapping, true)
