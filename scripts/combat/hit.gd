class_name Hit
extends RefCounted
## Everything about one blow, passed to `take_hit(hit)` on whatever it lands on.
## Targets decide what it means: armor needs `heavy`, a living tree only
## listens to FIRE, a frozen boulder shatters on `heavy`, and so on.
##
## Older code calls `take_damage(amount, knockback)`; targets that implement
## take_hit should keep take_damage working for those callers.

enum Element { NONE, ICE, FIRE, THUNDER }

var damage: int = 0
var element: Element = Element.NONE
## Breaks armor, shatters frozen things.
var heavy: bool = false
## Push direction and strength (the target applies its own resistance).
var knockback: Vector2 = Vector2.ZERO
## Who dealt it (the player, an enemy, a projectile), when known.
var source: Node
## Dealt from afar (a Magigonne shot): targets that bounce her off a blow
## (vine walls, slime boulders) must not shove her from across the room.
var ranged: bool = false


static func make(p_damage: int, p_knockback: Vector2 = Vector2.ZERO,
		p_element: Element = Element.NONE, p_heavy: bool = false, p_source: Node = null) -> Hit:
	var hit := Hit.new()
	hit.damage = p_damage
	hit.knockback = p_knockback
	hit.element = p_element
	hit.heavy = p_heavy
	hit.source = p_source
	return hit


## Delivers `hit` to `target` through the best method it has. Returns true if
## the target could be hit at all.
static func deliver(target: Object, hit: Hit) -> bool:
	if target.has_method("take_hit"):
		target.take_hit(hit)
		return true
	if hit.heavy and target.has_method("take_heavy_hit"):
		target.take_heavy_hit(hit.damage, hit.knockback)
		return true
	if target.has_method("take_damage"):
		target.take_damage(hit.damage, hit.knockback)
		return true
	return false
