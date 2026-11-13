class_name BootIntro
extends Control
## Intro cutscene before the title. A storm over a burning village: the blonde
## village girl (the death-reveal girl, before she had wings) cuts through
## charging armored knights, a swarm, and an ogre, with dashes, jumps, parries
## and combos, until the Hel warlord walks out of the storm: she duels him,
## parrying, vaulting, clashing in the air, and he cuts her down. The world goes black around her; a light opens above, a
## cherub flutters down, lifts her and carries her up out of sight.
##
## A director coroutine (_direct) scripts the beats; mobs (BootIntroMob) walk
## and chase on their own; effects come from BootIntroFX. The camera pans a
## 768px-wide field and shakes; kills get hit-stop and blood. Skippable.

signal finished
## Emitted every frame; the director awaits it (never a tree-wide signal, so
## a skipped, freed intro just stops instead of resuming on a dead instance).
signal _tick

const FX := preload("res://scripts/ui/boot_intro_fx.gd")
const STAGE := Vector2(384, 216)
const WORLD_W := 768.0
const GROUND_Y := 184.0
const BACKDROP := preload("res://assets/sprites/title/intro_backdrop.png")
const GIRL := preload("res://assets/sprites/title/village_girl.png")
const CREATURES := preload("res://assets/sprites/tiny_creatures/tilemap_packed.png")
const CHERUB_REGION := Rect2(96, 48, 16, 16)

## The storm's colour grade; lightning briefly lifts it.
const STORM_TINT := Color(0.58, 0.62, 0.88)
const FLASH_TINT := Color(1.9, 1.9, 2.2)
const LURK_TINT := Color(0.05, 0.04, 0.08)
## Fighters are lit a little above the storm grade so they read against it.
const HERO_LIGHT := Color(1.55, 1.5, 1.4)
const MOB_LIGHT := Color(1.35, 1.32, 1.3)
## Sword rotation (radians) at rest, raised, and at the end of a cut.
const SWORD_REST := -1.25
const SWORD_RAISED := -2.6
const SWORD_CUT := 0.7
## Her feet's y once she lies on her back (her 18px width resting on the ground).
const LYING_Y := GROUND_Y - 9.0
const RUN_SPEED := 150.0
const DASH_SPEED := 620.0

var _t := 0.0
var _dt := 0.0
var _done := false
var _cam: Node2D
var _cam_x := 0.0
var _cam_follow := true
var _shake := 0.0
var _curtain: ColorRect
var _fade: ColorRect
var _caption: Label
var _rain: FX.Rain
var _gore: FX.Gore
var _girl: Node2D
var _body: Sprite2D
var _hand: Node2D
var _sword: FX.Sword
var _facing := 1.0
var _pose := "idle"
var _ghosting := false
var _ghost_t := 0.0
var _mobs: Array = [] # of BootIntroMob
var _cherub: Sprite2D
var _next_bolt := 4.0


func _ready() -> void:
	size = STAGE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_cam = Node2D.new()
	_cam.modulate = STORM_TINT
	add_child(_cam)
	var back := Sprite2D.new()
	back.texture = BACKDROP
	back.centered = false
	_cam.add_child(back)
	for f in [[17.0, 138.0, 14.0], [83.0, 128.0, 16.0]]: # the burning roofs
		var fire := FX.Fire.new()
		fire.position = Vector2(f[0], f[1])
		fire.width = f[2]
		_cam.add_child(fire)

	# Goes black around her when she falls (field and mobs below it, she above).
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 0)
	_curtain.position = Vector2(-50, -50)
	_curtain.size = Vector2(WORLD_W + 100, STAGE.y + 100)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.z_index = 10
	_cam.add_child(_curtain)

	_gore = FX.Gore.new()
	_gore.ground_y = GROUND_Y
	_gore.z_index = 8
	_cam.add_child(_gore)

	_girl = Node2D.new()
	_girl.position = Vector2(110, GROUND_Y)
	_girl.z_index = 20
	_girl.modulate = HERO_LIGHT
	_cam.add_child(_girl)
	_body = Sprite2D.new()
	_body.texture = GIRL
	_body.position = Vector2(0, -GIRL.get_height() / 2.0) # pivot at her middle, for flips
	_girl.add_child(_body)
	_hand = Node2D.new() # mirrors for facing; the sword rotates inside it
	_girl.add_child(_hand)
	_sword = FX.Sword.new()
	_sword.rotation = SWORD_REST
	_hand.add_child(_sword)
	_set_facing(1.0)

	_rain = FX.Rain.new()
	_rain.area = STAGE
	_rain.ground_y = GROUND_Y
	_rain.z_index = 30
	add_child(_rain)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.size = Vector2(STAGE.x, 12)
	_caption.position = Vector2(0, 14)
	_caption.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	_caption.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.1))
	_caption.add_theme_constant_override("outline_size", 2)
	_caption.modulate.a = 0.0
	_caption.z_index = 40
	add_child(_caption)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = STAGE
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 50
	add_child(_fade)

	_direct()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# =========================================================================== director

func _direct() -> void:
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0)
	if not await _wait(0.5): return
	_lightning(Vector2(300, 150), true)
	_say("Midgard. The night the dead marched.", 0.2, 2.4)
	if not await _wait(1.2): return

	# --- Beat 1: three armored knights charge; she runs to meet them. ----------
	var k1 := _spawn("knight", 440.0, 1, 75.0)
	var k2 := _spawn("knight_f", 470.0, 1, 75.0)
	var k3 := _spawn("knight", 505.0, 2, 75.0)
	for k in [k1, k2, k3]:
		k.target_x = -200.0
	# A flourish: the sword whirls once in her hand.
	Sfx.play(&"swing_rapier")
	var twirl := create_tween()
	twirl.tween_property(_sword, "rotation", SWORD_REST + TAU, 0.3)
	twirl.tween_callback(func() -> void: _sword.rotation = SWORD_REST)
	if not await _wait(0.35): return
	await _run_until(func() -> bool: return k1.position.x - _girl.position.x < 64.0, 1.0)
	if _done: return
	await _dash_through(k1)
	if _done: return
	# The second raises its blade; she vaults it, cutting as she flips over.
	k2.target_x = k2.position.x
	k2.wind_up(0.3)
	k3.target_x = k2.position.x + 40.0
	await _jump_over(k2)
	if _done: return
	# The third swings; she parries and answers with a combo.
	_set_facing(1.0)
	k3.target_x = _girl.position.x + 17.0
	if not await _until(func() -> bool: return not k3.is_moving()): return
	k3.wind_up(0.25)
	if not await _wait(0.25): return
	k3.strike()
	_swing("rise")
	await _parry(k3)
	if _done: return
	await _lunge_cut(k3, "cut", 60.0)
	if _done: return
	await _lunge_cut(k3, "rise", 260.0)
	if _done: return
	if not await _wait(0.35): return

	# --- Beat 2: a swarm from both sides. -------------------------------------
	_lightning(Vector2(_girl.position.x + 120.0, 160), true)
	var waves := [["goblin", 1.0, 70.0, 1], ["skeleton", -1.0, 60.0, 1], ["wolf", 1.0, 150.0, 1],
			["zombie", -1.0, 55.0, 1], ["orc", 1.0, 55.0, 2], ["goblin", -1.0, 75.0, 1], ["skeleton", 1.0, 65.0, 1]]
	for w in waves:
		var x: float = _cam_x - 20.0 if w[1] < 0.0 else _cam_x + STAGE.x + 20.0
		var m := _spawn(w[0], x, w[3], w[2])
		m.set_meta("chase", true)
		if w[0] == "wolf":
			Sfx.play(&"enemy_growl", 0.05, -2.0, 1.3)
		if not await _wait(0.22): return
	await _brawl()
	if _done: return
	if not await _wait(0.3): return

	# --- Beat 3: the ogre. ------------------------------------------------------
	var ogre := _spawn("ogre", _cam_x + STAGE.x + 30.0, 5, 40.0)
	ogre.set_meta("chase", true)
	ogre.set_meta("stomp", true)
	_lightning(Vector2(ogre.position.x - 40.0, 160), true)
	Sfx.play(&"enemy_growl", 0.0, 2.0, 0.6)
	_set_facing(1.0)
	if not await _until(func() -> bool: return not ogre.is_moving() and absf(ogre.position.x - _girl.position.x) < 40.0): return
	ogre.set_meta("chase", false)
	ogre.wind_up(0.45)
	Sfx.play(&"meteor_windup")
	if not await _wait(0.3): return
	# She backflips clear as the club comes down.
	_jump(Vector2(_girl.position.x - _facing * 46.0, GROUND_Y), 26.0, 0.45, -TAU * _facing)
	if not await _wait(0.15): return
	ogre.strike()
	Sfx.play(&"meteor_impact")
	_kick_shake(6.0)
	_dust(Vector2(ogre.position.x + ogre.facing * 20.0, GROUND_Y), 18.0)
	if not await _wait(0.45): return
	# Back in: dash, cut, rising cut, spin...
	await _dash_to(ogre.position.x - _facing * 20.0)
	if _done: return
	await _hit_with(ogre, "cut", 40.0)
	if _done: return
	await _hit_with(ogre, "rise", 40.0)
	if _done: return
	await _hit_with(ogre, "spin", 40.0)
	if _done: return
	# ...then straight up into the lightning, and down through it.
	var apex := Vector2(ogre.position.x, GROUND_Y - 78.0)
	_set_pose("air")
	Sfx.play(&"jump")
	var up := create_tween()
	up.tween_property(_girl, "position", apex, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.parallel().tween_property(_body, "rotation", -TAU * _facing, 0.32)
	if not await _wait(0.3): return
	_body.rotation = 0.0
	_lightning(Vector2(apex.x, GROUND_Y), true)
	_sword.rotation = PI / 2.0 # point down
	_sword.glint = 1.0
	_sword.queue_redraw()
	_hitstop(0.25)
	if not await _wait(0.06): return
	_ghosting = true
	create_tween().tween_property(_girl, "position:y", GROUND_Y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not await _wait(0.12): return
	_ghosting = false
	_sword.glint = 0.0
	_sword.queue_redraw()
	_slash_fx("plunge", Vector2(0, -6), 22.0)
	ogre.hp = 1
	_land_hit(ogre, 0.0, 200.0, true)
	Sfx.play(&"meteor_impact_big")
	_dust(Vector2(_girl.position.x, GROUND_Y), 24.0)
	_kick_shake(8.0)
	_set_pose("idle")
	create_tween().tween_property(_sword, "rotation", SWORD_REST, 0.3)
	if not await _wait(0.6): return

	# --- Beat 4: the last charge. -----------------------------------------------
	var r1 := _spawn("knight", _cam_x + STAGE.x + 20.0, 1, 90.0)
	var r2 := _spawn("knight_f", _cam_x + STAGE.x + 50.0, 1, 90.0)
	var brute := _spawn("brute", _cam_x + STAGE.x + 90.0, 3, 50.0)
	for m in [r1, r2, brute]:
		m.set_meta("chase", true)
	_set_facing(1.0)
	await _run_until(func() -> bool: return r1.position.x - _girl.position.x < 70.0, 1.0)
	if _done: return
	await _dash_through(r1)
	if _done: return
	await _brawl_target(r2)
	if _done: return
	await _brawl_target(brute)
	if _done: return
	if not await _wait(0.3): return

	# --- Beat 5: the warlord. He walks in dragging his blade; they duel. -------
	_set_facing(1.0)
	var w := _spawn("warlord", _cam_x + STAGE.x + 30.0, 99, 26.0)
	w.set_meta("stomp", true)
	w.set_meta("drag", true)
	w.target_x = _girl.position.x + 34.0
	_lightning(Vector2(w.position.x - 30.0, 160), true)
	Sfx.play(&"enemy_growl", 0.0, 4.0, 0.4)
	# She settles into her stance: one slow twirl of the sword.
	var stance := create_tween()
	stance.tween_property(_sword, "rotation", SWORD_REST - TAU, 0.45)
	stance.tween_callback(func() -> void: _sword.rotation = SWORD_REST)
	if not await _until(func() -> bool: return not w.is_moving()): return
	w.set_meta("drag", false)
	if not await _wait(0.3): return

	# 1. His overhead cleave; she catches it on her blade and is driven back.
	Sfx.play(&"meteor_windup")
	_blade(w, -2.4, 0.35, Tween.EASE_OUT)
	if not await _wait(0.4): return
	_blade(w, 0.9, 0.08, Tween.EASE_IN)
	_swing("rise")
	if not await _wait(0.07): return
	_clash(_girl.position + Vector2(8, -16), 4.0, 0.14)
	create_tween().tween_property(_girl, "position:x", _girl.position.x - 12.0, 0.2).set_ease(Tween.EASE_OUT)
	_dust(_girl.position, 6.0)
	if not await _wait(0.45): return

	# 2. She answers: two cuts he turns aside, a third that bites.
	await _dash_to(w.position.x - 18.0)
	if _done: return
	for guard in [-0.3, 0.3]:
		_set_facing(1.0)
		_swing("cut")
		_blade(w, guard, 0.06, Tween.EASE_OUT)
		if not await _wait(0.07): return
		_clash(_girl.position + Vector2(12, -14), 2.5, 0.06)
		if not await _wait(0.16): return
	await _hit_with(w, "rise", 30.0)
	if _done: return
	_blade(w, 0.9, 0.3, Tween.EASE_OUT)
	if not await _wait(0.25): return

	# 3. He sweeps low; she vaults it and cuts his back on the way over.
	_blade(w, -0.9, 0.25, Tween.EASE_OUT)
	if not await _wait(0.25): return
	Sfx.play(&"swing_heavy")
	_blade(w, 1.5, 0.12, Tween.EASE_IN)
	_jump(Vector2(w.position.x + 26.0, GROUND_Y), 38.0, 0.55, TAU)
	if not await _wait(0.3): return
	_set_facing(-1.0)
	_swing("cut")
	_land_hit(w, 1.0, 30.0)
	if not await _wait(0.3): return
	_dust(_girl.position, 8.0)
	Sfx.play(&"land")
	_blade(w, 0.9, 0.2, Tween.EASE_OUT)

	# 4. He turns and shoulders into her; she tumbles away and comes up again.
	w.facing = 1.0
	if not await _wait(0.2): return
	w.wind_up(0.2)
	if not await _wait(0.2): return
	w.strike()
	create_tween().tween_property(w, "position:x", w.position.x + 12.0, 0.08)
	Sfx.play(&"hit_heavy")
	Sfx.play(&"hurt", 0.05, -2.0)
	_hitstop(0.08)
	_kick_shake(4.0)
	_gore.spray(_girl.position + Vector2(0, -14), 1.0, 8)
	_set_pose("air")
	var tumble := create_tween().set_parallel()
	tumble.tween_property(_girl, "position:x", _girl.position.x + 38.0, 0.45).set_ease(Tween.EASE_OUT)
	tumble.tween_property(_body, "rotation", TAU, 0.45)
	if not await _wait(0.45): return
	_body.rotation = 0.0
	_set_pose("idle")
	_dust(_girl.position, 8.0)
	_set_facing(-1.0)
	if not await _wait(0.4): return

	# 5. She leaps at him, sword first; he meets her in the air. Lightning.
	var leap_to := Vector2(w.position.x + 16.0, GROUND_Y - 40.0)
	_set_pose("air")
	Sfx.play(&"jump")
	_ghosting = true
	create_tween().tween_property(_girl, "position", leap_to, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blade(w, -2.0, 0.22, Tween.EASE_OUT)
	if not await _wait(0.25): return
	_ghosting = false
	_swing("cut")
	_clash(_girl.position + Vector2(-8, -10), 6.0, 0.22)
	_lightning(Vector2(w.position.x, 150), true)
	# The clash hurls her clean over him; she lands on his far side.
	_jump(Vector2(w.position.x - 46.0, GROUND_Y), 22.0, 0.45, -TAU)
	create_tween().tween_property(w, "position:x", w.position.x + 6.0, 0.2)
	if not await _wait(0.47): return
	_dust(_girl.position, 10.0)
	create_tween().tween_property(_girl, "position:x", _girl.position.x - 8.0, 0.2).set_ease(Tween.EASE_OUT)
	_set_facing(1.0)
	w.facing = -1.0
	_blade(w, 1.3, 0.3, Tween.EASE_OUT)
	if not await _wait(0.5): return

	# 6. One last rush. He reads it: a rising cleave catches her mid-dash.
	_set_facing(1.0)
	_set_pose("run")
	_ghosting = true
	Sfx.play(&"dash")
	create_tween().tween_property(_girl, "position:x", w.position.x - 20.0, 0.12)
	if not await _wait(0.06): return
	Sfx.play(&"swing_heavy")
	_blade(w, -2.3, 0.1, Tween.EASE_OUT)
	if not await _wait(0.07): return
	_ghosting = false
	await _cut_down(w, -1.0) # thrown back toward the middle of the field
	if _done: return

	# --- Black out around her; the light and the cherub. -----------------------
	# The camera settles on her: centred as far as the field allows, then,
	# once only she is lit, exactly centred.
	_cam_follow = false
	var body_x := _girl.position.x - 12.0 # lying down, she spans 24px left of her feet
	var centre := body_x - STAGE.x / 2.0
	create_tween().tween_property(self, "_cam_x", clampf(centre, 0.0, WORLD_W - STAGE.x), 1.0).set_trans(Tween.TRANS_SINE)
	if not await _wait(0.9): return
	create_tween().tween_property(_curtain, "color:a", 1.0, 1.4).set_ease(Tween.EASE_IN)
	create_tween().tween_property(_rain, "intensity", 0.4, 2.0)
	if not await _wait(1.5): return
	create_tween().tween_property(self, "_cam_x", centre, 0.5).set_trans(Tween.TRANS_SINE)
	if not await _wait(0.5): return
	var beam := FX.Beam.new()
	beam.position = Vector2(body_x, 0)
	beam.height = GROUND_Y
	beam.z_index = 15
	_cam.add_child(beam)
	var screen_x := STAGE.x / 2.0
	_rain.clear_from = screen_x - 17.0
	_rain.clear_to = screen_x + 17.0
	var atlas := AtlasTexture.new()
	atlas.atlas = CREATURES
	atlas.region = CHERUB_REGION
	_cherub = Sprite2D.new()
	_cherub.texture = atlas
	_cherub.offset = Vector2(0, -8)
	_cherub.position = Vector2(body_x, -12)
	_cherub.z_index = 30
	_cam.add_child(_cherub)
	_say("The slain are not always left where they fall.", 0.6, 4.4)
	Sfx.play(&"heal", 0.0, -4.0)
	var land_y := GROUND_Y - 16.0
	create_tween().tween_property(_cherub, "position:y", land_y, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not await _wait(2.5): return
	var feathers := FeatherBurst.new()
	feathers.count = 10
	feathers.position = _cherub.position + Vector2(0, 2)
	_cam.add_child(feathers)
	feathers.z_index = 31
	Sfx.play(&"power_up", 0.0, -6.0)
	if not await _wait(0.6): return
	var rise_time := 3.0
	var lift := create_tween().set_parallel()
	lift.tween_property(_cherub, "position:y", -60.0, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	lift.tween_property(_girl, "position:y", -60.0 + (LYING_Y - land_y), rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	lift.tween_property(beam, "modulate:a", 0.0, rise_time + 0.4).set_delay(0.6)
	if not await _wait(rise_time - 0.6): return
	create_tween().tween_property(_fade, "color:a", 1.0, 0.8)
	if not await _wait(1.1): return
	_finish()


## The killing blow from `killer`: she's flung in direction `dir`, her sword
## flies, she lands on her back; he raises his blade to the storm.
func _cut_down(killer: BootIntroMob, dir: float) -> void:
	Sfx.play(&"hit_heavy")
	Sfx.play(&"hurt", 0.0, 0.0, 0.8)
	_hitstop(0.3)
	_kick_shake(7.0)
	var flash := ColorRect.new()
	flash.color = Color(1, 0.2, 0.15, 0.6)
	flash.size = STAGE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 45
	add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.5)
	_body.modulate = Color(3, 1.6, 1.6)
	create_tween().tween_property(_body, "modulate", Color.WHITE, 0.6)
	_gore.spray(_girl.position + Vector2(-2, -14), dir, 30, 1.4)
	_lightning(Vector2(killer.position.x, 160), true)

	# The sword spins away and sticks in the ground.
	_sword.reparent(_cam)
	_sword.z_index = 5
	var from := _sword.position
	var land := Vector2(clampf(_girl.position.x + dir * 96.0, 20.0, WORLD_W - 20.0), GROUND_Y - 6.0)
	var fly := create_tween().set_parallel()
	fly.tween_property(_sword, "position:x", land.x, 0.8)
	fly.tween_property(_sword, "position:y", from.y - 50.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	fly.tween_property(_sword, "position:y", land.y, 0.45).set_delay(0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fly.tween_property(_sword, "rotation", PI * 6.0 * dir + PI / 2.0 + 0.25, 0.8)
	fly.chain().tween_callback(Sfx.play.bind(&"deflect", 0.05, -6.0))

	# She's thrown high, turning over, and lands on her back.
	_set_pose("down")
	var start := _girl.position
	var end := Vector2(clampf(start.x + dir * 60.0, 30.0, WORLD_W - 10.0), LYING_Y)
	var throw := create_tween().set_parallel()
	throw.tween_method(func(k: float) -> void:
		_girl.position = start.lerp(end, k) + Vector2(0, -44.0 * 4.0 * k * (1.0 - k)), 0.0, 1.0, 0.8)
	throw.tween_property(_girl, "rotation", -PI / 2.0 - TAU, 0.8).set_ease(Tween.EASE_OUT)
	if not await _wait(0.8): return
	_girl.rotation = -PI / 2.0
	Sfx.play(&"land_heavy")
	_kick_shake(3.0)
	_dust(Vector2(_girl.position.x - 14.0, GROUND_Y), 12.0)
	create_tween().tween_property(_girl, "position:x", _girl.position.x + dir * 6.0, 0.25).set_ease(Tween.EASE_OUT)
	if not await _wait(0.6): return
	# He lifts the greatsword to the sky; the storm answers.
	if killer.blade:
		_blade(killer, -PI / 2.0, 0.5, Tween.EASE_OUT) # straight up
		if not await _wait(0.5): return
		var tip := killer.position + Vector2(killer.facing * 7.0, -19.0 - 26.0)
		_lightning(tip, true)
		killer.blade.set("glow", 1.0)
		killer.blade.queue_redraw()
		var glow := create_tween()
		glow.tween_method(func(v: float) -> void:
			killer.blade.set("glow", v)
			killer.blade.queue_redraw(), 1.0, 0.0, 1.2)
	Sfx.play(&"enemy_growl", 0.0, 4.0, 0.45)
	_kick_shake(2.0)
	for m in _mobs:
		m.set_meta("chase", false)
		m.target_x = m.position.x


## Turns the warlord's greatsword to `angle` (in his facing-right frame).
func _blade(w: BootIntroMob, angle: float, time: float, ease_type: Tween.EaseType) -> void:
	if w.blade == null:
		return
	create_tween().tween_property(w.blade, "rotation", angle, time).set_ease(ease_type).set_trans(Tween.TRANS_QUAD)


## Steel on steel: a burst of sparks at `at`, a ring, a freeze and a shake.
func _clash(at: Vector2, shake: float, stop: float) -> void:
	for i in 2:
		var sparks := FX.Sparks.new()
		sparks.count = 14
		sparks.position = at
		sparks.z_index = 25
		_cam.add_child(sparks)
	var ring := Burst.new()
	ring.radius = 10.0 + shake * 2.0
	ring.color = Color(1, 0.95, 0.7)
	ring.debris = 0
	ring.duration = 0.2
	ring.position = at
	_cam.add_child(ring)
	ring.z_index = 26
	Sfx.play(&"deflect")
	Sfx.play(&"block", 0.05, -2.0)
	_hitstop(stop)
	_kick_shake(shake)


# =========================================================================== her moves

## Runs in direction `dir` until `cond` holds.
func _run_until(cond: Callable, dir: float) -> void:
	_set_facing(dir)
	_set_pose("run")
	var step_t := 0.0
	while not _done and not cond.call():
		_girl.position.x = clampf(_girl.position.x + _facing * RUN_SPEED * _dt, 16.0, WORLD_W - 16.0)
		step_t += _dt
		if step_t > 0.16:
			step_t = 0.0
			Sfx.play(&"step_stone", 0.1, -6.0)
			_dust(_girl.position + Vector2(-_facing * 4.0, 0), 4.0)
		await _tick
	_set_pose("idle")


## Dashes to x, leaving afterimages and a streak.
func _dash_to(x: float) -> void:
	var dist := x - _girl.position.x
	if absf(dist) < 1.0:
		return
	_set_facing(signf(dist))
	_set_pose("run")
	_ghosting = true
	Sfx.play(&"dash")
	var streak := FX.Streak.new()
	streak.position = Vector2(x, GROUND_Y)
	streak.length = -dist
	streak.z_index = 19
	_cam.add_child(streak)
	create_tween().tween_property(_girl, "position:x", x, absf(dist) / DASH_SPEED)
	await _wait(absf(dist) / DASH_SPEED)
	_ghosting = false
	_set_pose("idle")


## Dashes clean through `m`, cutting it as she passes.
func _dash_through(m: BootIntroMob) -> void:
	var dir := signf(m.position.x - _girl.position.x)
	if dir == 0.0:
		dir = _facing
	var end := clampf(m.position.x + dir * 26.0, 16.0, WORLD_W - 16.0)
	_swing("cut")
	var dist := absf(end - _girl.position.x)
	var hit_at := absf(m.position.x - _girl.position.x) / DASH_SPEED
	_dash_to(end)
	await _wait(hit_at)
	if not _done and not m.dead:
		_land_hit(m, dir, 160.0)
	await _wait(maxf(0.0, dist / DASH_SPEED - hit_at) + 0.02)
	_set_facing(-dir) # whips round after the pass


## Vaults over `m`, spinning, cutting it from above.
func _jump_over(m: BootIntroMob) -> void:
	var dir := signf(m.position.x - _girl.position.x)
	var land := Vector2(m.position.x + dir * 28.0, GROUND_Y)
	_jump(land, 34.0, 0.5, TAU * dir)
	await _wait(0.22)
	if _done: return
	_swing("spin")
	_slash_fx("spin", Vector2(0, -12), 15.0)
	if not m.dead:
		_land_hit(m, dir, 120.0)
	await _wait(0.3)
	if _done: return
	_dust(_girl.position, 8.0)
	Sfx.play(&"land")
	_set_facing(-dir)


## Blocks `m`'s blow: sparks, a ring of steel, it reels back.
func _parry(m: BootIntroMob) -> void:
	var dir := signf(m.position.x - _girl.position.x)
	var sparks := FX.Sparks.new()
	sparks.position = _girl.position + Vector2(dir * 9.0, -14.0)
	sparks.z_index = 25
	_cam.add_child(sparks)
	Sfx.play(&"deflect")
	Sfx.play(&"block", 0.05, -4.0)
	_hitstop(0.1)
	_kick_shake(2.5)
	m.stagger(dir)
	await _wait(0.22)


## A step-in strike at `m`.
func _lunge_cut(m: BootIntroMob, kind: String, force: float) -> void:
	var dir := signf(m.position.x - _girl.position.x)
	_set_facing(dir)
	if absf(m.position.x - _girl.position.x) > 16.0:
		create_tween().tween_property(_girl, "position:x", m.position.x - dir * 14.0, 0.07)
	await _hit_with(m, kind, force)


## Swing `kind` at `m` and land it.
func _hit_with(m: BootIntroMob, kind: String, force: float) -> void:
	var dir := signf(m.position.x - _girl.position.x)
	if dir != 0.0:
		_set_facing(dir)
	_swing(kind)
	await _wait(0.06)
	if _done or m.dead:
		return
	_land_hit(m, _facing, force)
	await _wait(0.14)


## Spin slash: everything around her at once.
func _spin_attack(targets: Array) -> void:
	_swing("spin")
	_slash_fx("spin", Vector2(0, -12), 22.0)
	var spin := create_tween()
	spin.tween_property(_body, "rotation", TAU * _facing, 0.25)
	spin.tween_callback(func() -> void: _body.rotation = 0.0)
	await _wait(0.08)
	for m in targets:
		if is_instance_valid(m) and not m.dead:
			_land_hit(m, signf(m.position.x - _girl.position.x), 150.0)
	await _wait(0.2)


## Fights the chasing mobs until none are left: runs, dashes through, cuts,
## spins when surrounded.
func _brawl() -> void:
	while not _done:
		var alive := _mobs.filter(func(m) -> bool: return not m.dead and m.get_meta("chase", false))
		if alive.is_empty():
			return
		var near := alive.filter(func(m) -> bool: return absf(m.position.x - _girl.position.x) < 28.0)
		if near.size() >= 3:
			await _spin_attack(near)
			continue
		var target: BootIntroMob = alive[0]
		for a in alive:
			if absf(a.position.x - _girl.position.x) < absf(target.position.x - _girl.position.x):
				target = a
		await _brawl_target(target)
		await _wait(0.04)


## Kills `m` however fits the distance.
func _brawl_target(m: BootIntroMob) -> void:
	var kinds := ["cut", "rise", "cut", "spin"]
	var i := 0
	while not _done and not m.dead:
		var dist := absf(m.position.x - _girl.position.x)
		if dist > 90.0:
			await _run_until(func() -> bool: return m.dead or absf(m.position.x - _girl.position.x) < 70.0, signf(m.position.x - _girl.position.x))
		elif dist > 34.0:
			await _dash_through(m)
		else:
			await _lunge_cut(m, kinds[i % kinds.size()], 140.0)
			i += 1


# =========================================================================== hits & fx

## Applies a hit on `m` from her, with blood, sparks, sound, hit-stop and shake.
func _land_hit(m: BootIntroMob, dir: float, force: float, heavy: bool = false) -> void:
	var at := m.position + Vector2(0, -m.height() * 0.5)
	var killed := m.hurt(dir, force)
	_gore.spray(at, dir, 22 if killed else 9, 1.4 if (killed and m.big) else 1.0)
	if m.armored:
		var sparks := FX.Sparks.new()
		sparks.position = at
		sparks.z_index = 25
		_cam.add_child(sparks)
	if killed:
		Sfx.play(&"enemy_die")
		Sfx.play(&"hit_heavy" if m.big else &"hit", 0.08)
		_hitstop(0.2 if m.big or heavy else 0.07)
		_kick_shake(6.0 if m.big else 2.5)
		if m.big:
			_gore.spray(at, -dir, 18, 1.2)
			var boom := Burst.new()
			boom.radius = 30.0
			boom.color = Color(1, 0.5, 0.4)
			boom.debris = 12
			boom.position = at
			_cam.add_child(boom)
			boom.z_index = 25
	else:
		Sfx.play(&"hit_heavy" if m.big else &"hit")
		_hitstop(0.04)
		_kick_shake(1.5)


## Animates the sword for a swing of `kind` (and draws its arc).
func _swing(kind: String) -> void:
	Sfx.play(&"swing_blade" if kind != "spin" else &"swing_heavy")
	var tween := create_tween()
	match kind:
		"rise":
			_sword.rotation = SWORD_CUT
			tween.tween_property(_sword, "rotation", SWORD_RAISED, 0.08).set_ease(Tween.EASE_OUT)
			_slash_fx("rise", Vector2(4.0 * _facing, -10.0), 14.0)
		"spin":
			tween.tween_property(_sword, "rotation", _sword.rotation + TAU, 0.22)
		_:
			tween.tween_property(_sword, "rotation", SWORD_RAISED, 0.03)
			tween.tween_property(_sword, "rotation", SWORD_CUT, 0.07).set_ease(Tween.EASE_OUT)
			_slash_fx("cut", Vector2(4.0 * _facing, -10.0), 14.0)
	tween.tween_property(_sword, "rotation", SWORD_REST, 0.2)


func _slash_fx(kind: String, offset: Vector2, radius: float) -> void:
	var arc := FX.Slash.new()
	arc.kind = kind
	arc.radius = radius
	arc.position = offset
	arc.scale.x = _facing
	arc.z_index = 2
	_girl.add_child(arc)


## A parabolic jump to `to`, turning `spin` radians on the way.
func _jump(to: Vector2, height: float, time: float, spin: float = 0.0) -> void:
	_set_pose("air")
	Sfx.play(&"jump")
	var from := _girl.position
	var tween := create_tween().set_parallel()
	tween.tween_method(func(k: float) -> void:
		_girl.position = from.lerp(to, k) + Vector2(0, -height * 4.0 * k * (1.0 - k)), 0.0, 1.0, time)
	if spin != 0.0:
		tween.tween_property(_body, "rotation", spin, time)
	tween.chain().tween_callback(func() -> void:
		_body.rotation = 0.0
		_set_pose("idle"))


func _lightning(at: Vector2, thunder: bool) -> void:
	var bolt := FX.Bolt.new()
	bolt.end = at
	bolt.z_index = 1
	_cam.add_child(bolt)
	var tween := create_tween()
	tween.tween_property(_cam, "modulate", FLASH_TINT, 0.03)
	tween.tween_property(_cam, "modulate", STORM_TINT * 1.2, 0.06)
	tween.tween_property(_cam, "modulate", FLASH_TINT, 0.03)
	tween.tween_property(_cam, "modulate", STORM_TINT, 0.5)
	# Lurkers show only while the sky is lit.
	for m in _mobs:
		if m.get_meta("lurk", false) and not m.dead:
			var mt := create_tween()
			mt.tween_property(m, "tint", MOB_LIGHT, 0.03)
			mt.tween_interval(0.12)
			mt.tween_property(m, "tint", LURK_TINT, 0.4)
	if thunder:
		Sfx.play(&"jolt", 0.05, 8.0)
		Sfx.play(&"enemy_rumble", 0.05, 0.0, 0.7)
	_kick_shake(1.5)
	_next_bolt = _t + randf_range(3.5, 6.0)


func _dust(at: Vector2, radius: float) -> void:
	var dust := Burst.new()
	dust.radius = radius
	dust.flatten = 0.35
	dust.color = Color(0.75, 0.72, 0.8, 0.7)
	dust.debris = 4
	dust.debris_speed = 40.0
	dust.debris_up_only = true
	dust.position = at
	_cam.add_child(dust)
	dust.z_index = 21


func _kick_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Freezes the action for `seconds` of real time (impact weight).
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(BootIntro._restore_time)


static func _restore_time() -> void:
	Engine.time_scale = 1.0


# =========================================================================== per frame

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_dt = delta
	_mobs = _mobs.filter(func(m) -> bool: return is_instance_valid(m))
	# Camera: lead a little ahead of her, shake on top.
	if _cam_follow:
		var target := clampf(_girl.position.x - STAGE.x / 2.0 + _facing * 30.0, 0.0, WORLD_W - STAGE.x)
		_cam_x = lerpf(_cam_x, target, 1.0 - exp(-5.0 * delta))
	_shake = maxf(0.0, _shake - delta * 18.0)
	_cam.position = Vector2(-roundf(_cam_x) + roundf(randf_range(-_shake, _shake)), roundf(randf_range(-_shake, _shake) * 0.6))
	# Her body: breathing, running bob and lean.
	match _pose:
		"idle":
			_body.position.y = -12.0 - (1.0 if fmod(_t, 0.8) < 0.4 else 0.0)
			_body.skew = 0.0
		"run":
			_body.position.y = -12.0 - roundf(absf(sin(_t * 16.0)) * 2.0)
			_body.skew = -0.15 * _facing
		_:
			_body.position.y = -12.0
			_body.skew = 0.0
	if _ghosting:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.025
			var ghost := FX.Ghost.new()
			ghost.texture = GIRL
			ghost.position = _girl.position + _body.position.rotated(_girl.rotation)
			ghost.rotation = _girl.rotation + _body.rotation
			ghost.z_index = 19
			_cam.add_child(ghost)
	# Mobs that chase her stop just short of her; heavy ones shake the ground.
	for m in _mobs:
		if m.dead:
			continue
		if m.get_meta("drag", false) and m.is_moving() and int(_t / 0.18) != int((_t - delta) / 0.18):
			var sp := FX.Sparks.new()
			sp.count = 4
			sp.position = m.position + Vector2(22.0 * m.facing, -1.0)
			sp.z_index = 9
			_cam.add_child(sp)
		if m.get_meta("stomp", false) and m.is_moving() and int(_t / 0.4) != int((_t - delta) / 0.4):
			Sfx.play(&"land_heavy", 0.05, -4.0, 0.7)
			_kick_shake(2.0)
		if not m.get_meta("chase", false):
			continue
		var side := signf(m.position.x - _girl.position.x)
		if side == 0.0:
			side = 1.0
		var reach: float = 22.0 if m.big else (15.0 if m.armored else 12.0)
		m.target_x = _girl.position.x + side * reach
	if _cherub:
		_cherub.offset.y = -8.0 - (1.0 if fmod(_t, 0.16) < 0.08 else 0.0)
		if int(_t / 0.32) != int((_t - delta) / 0.32):
			Sfx.play(&"flutter", 0.05, -14.0)
	# Distant lightning now and then.
	if _t > _next_bolt and _curtain.color.a < 0.5:
		_lightning(Vector2(_cam_x + randf_range(20, STAGE.x - 20), 150), randf() < 0.5)
	_tick.emit()


func _spawn(kind_id: String, x: float, hp: int, speed: float) -> BootIntroMob:
	var m := BootIntroMob.make(kind_id, Vector2(x, GROUND_Y), hp, speed)
	m.z_index = 7 # under the curtain, so they black out with the field
	m.tint = MOB_LIGHT
	_cam.add_child(m)
	_mobs.append(m)
	return m


func _set_facing(dir: float) -> void:
	if dir == 0.0:
		return
	_facing = dir
	_hand.position = Vector2(6.0 * dir, -9.0)
	_hand.scale.x = dir


func _set_pose(pose: String) -> void:
	_pose = pose


func _say(text: String, delay: float, hold: float) -> void:
	_caption.text = text
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, 0.5).set_delay(delay)
	tween.tween_interval(hold)
	tween.tween_property(_caption, "modulate:a", 0.0, 0.6)


## Waits `seconds` of this node's time. False if the intro was skipped.
func _wait(seconds: float) -> bool:
	var end := _t + seconds
	while _t < end and not _done:
		await _tick
	return not _done


## Waits until `cond` holds. False if the intro was skipped.
func _until(cond: Callable) -> bool:
	while not _done and not cond.call():
		await _tick
	return not _done


func _unhandled_input(event: InputEvent) -> void:
	if _done or _t < 0.3:
		return
	if BootSplash._is_skip(event):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = 1.0
	finished.emit()
