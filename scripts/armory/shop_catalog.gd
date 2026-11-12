class_name ShopCatalog
extends RefCounted
## What a shrine's barter stall offers for coins. Swords are listed through
## their WeaponData (`price` > 0, hidden once owned). Expendables are applied
## on purchase. Add stock here and every shrine sells it.

const WEAPONS := [
	"res://data/weapons/thunder_hammer.tres",
]

const ARMOR := [
	"res://data/armor/ember_mail.tres",
	"res://data/armor/iron_bulwark.tres",
	"res://data/armor/storm_hauberk.tres",
]

## id, name, price, description. Effects are applied in apply_expendable().
const EXPENDABLES := [
	{"id": "mead", "name": "Mead", "price": 5, "description": "Restores all hearts."},
]
# Carried consumables (used later from a hotkey) need an item slot and a "use"
# input; until then expendables take effect on purchase.


static func weapons_for_sale() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for path: String in WEAPONS:
		var data := load(path) as WeaponData
		if data and data.price > 0 and not GameManager.owns_weapon(data):
			out.append(data)
	return out


static func armor_for_sale() -> Array[ArmorData]:
	var out: Array[ArmorData] = []
	for path: String in ARMOR:
		var data := load(path) as ArmorData
		if data and data.price > 0 and not GameManager.owns_armor(data):
			out.append(data)
	return out


## Whether the expendable would do anything right now (no buying a heal at
## full health).
static func expendable_useful(id: String, player: Node) -> bool:
	match id:
		"mead":
			return player.current_health < player.max_health
	return true


static func apply_expendable(id: String, player: Node) -> void:
	match id:
		"mead":
			player._heal(player.max_health)
