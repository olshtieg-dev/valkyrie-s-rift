@tool
class_name ArmorData
extends Resource
## One suit of armor. She wears one at a time, swapped at shrines like swords.
## Armor is purely defensive: it never changes how she moves (that's the
## sword's job). It decides how much each kind of damage hurts, and can add
## heart containers and feathers (flutters) while worn.
## Edit the .tres files in data/armor/ in the Inspector.

@export var id: StringName
@export var display_name: String = "Armor"
@export_multiline var description: String = ""
## Tints her sprite while worn.
@export var tint: Color = Color.WHITE
## Plate color used for the pedestal icon.
@export var icon_color: Color = Color(0.75, 0.8, 0.9)
## Coins at a shrine's barter stall. 0 = not for sale (found only).
@export var price: int = 0

@export_group("Resistance")
## Fraction of each kind of damage blocked (0 = none, 0.5 = half, 1 = immune).
## Plain blows, bites and falls are physical. Lava is fire.
@export_range(0.0, 1.0, 0.05) var physical: float = 0.0
@export_range(0.0, 1.0, 0.05) var fire: float = 0.0
@export_range(0.0, 1.0, 0.05) var ice: float = 0.0
@export_range(0.0, 1.0, 0.05) var thunder: float = 0.0
## Fraction of hit knockback shrugged off.
@export_range(0.0, 1.0, 0.05) var stagger_resist: float = 0.0

@export_group("Bonuses")
## Extra heart containers while worn.
@export_range(0, 4) var bonus_hearts: int = 0
## Extra flutters per airtime while worn (still capped by the player's FLUTTER_CAP).
@export_range(0, 2) var bonus_feathers: int = 0


func resistance(element: Hit.Element) -> float:
	match element:
		Hit.Element.FIRE: return fire
		Hit.Element.ICE: return ice
		Hit.Element.THUNDER: return thunder
	return physical


## One line for menus, e.g. "Fire -50%  +1 heart".
func summary() -> String:
	var parts: Array[String] = []
	for pair: Array in [["Physical", physical], ["Fire", fire], ["Ice", ice], ["Thunder", thunder]]:
		if pair[1] > 0.0:
			parts.append("%s -%d%%" % [pair[0], roundi(pair[1] * 100.0)])
	if stagger_resist > 0.0:
		parts.append("Steady %d%%" % roundi(stagger_resist * 100.0))
	if bonus_hearts > 0:
		parts.append("+%d heart%s" % [bonus_hearts, "s" if bonus_hearts > 1 else ""])
	if bonus_feathers > 0:
		parts.append("+%d feather%s" % [bonus_feathers, "s" if bonus_feathers > 1 else ""])
	return "  ".join(parts) if not parts.is_empty() else "No resistances"
