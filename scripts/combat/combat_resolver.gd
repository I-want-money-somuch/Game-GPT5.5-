class_name CombatResolver
extends RefCounted

static func resolve(packet: RefCounted, armor_component: Node, rng: RandomNumberGenerator) -> Dictionary:
	var raw_damage := maxf(packet.amount, 0.0)
	var was_crit: bool = rng.randf() < packet.crit_chance
	if was_crit:
		raw_damage *= maxf(packet.crit_multiplier, 1.0)

	var reduction := 0.0
	if armor_component != null:
		reduction = armor_component.get_damage_reduction(packet.armor_pierce)
		armor_component.damage_armor(raw_damage * 0.22 * (1.0 - clampf(packet.armor_pierce, 0.0, 0.9)))

	return {
		"raw_damage": raw_damage,
		"final_damage": raw_damage * (1.0 - reduction),
		"reduction": reduction,
		"critical": was_crit,
		"element": packet.element,
	}
