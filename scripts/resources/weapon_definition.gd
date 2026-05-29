class_name WeaponDefinition
extends Resource

enum WeaponFamily {
	HANDGUN,
	RIFLE,
	SHOTGUN,
	SNIPER,
	STAFF,
	BOW,
	SPEAR,
	GREATSWORD,
	DUAL_BLADE,
	THROWN,
	SUMMON
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

enum Element {
	PHYSICAL,
	FIRE,
	ICE,
	POISON,
	LIGHTNING,
	ARCANE
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var family := WeaponFamily.HANDGUN
@export var rarity := Rarity.COMMON
@export var element := Element.PHYSICAL
@export var base_damage := 10.0
@export var attack_rate := 2.0
@export_range(0.0, 1.0, 0.01) var crit_chance := 0.05
@export var crit_damage := 1.5
@export var armor_pierce := 0.0
@export var knockback_force := 90.0
@export var projectile_speed := 520.0
@export var projectile_lifetime := 1.0
@export var pierce := 0
@export var durability := 100.0
const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")

@export var affixes: Array[Resource] = []

func create_damage_packet(source = null) -> RefCounted:
	var packet = DamagePacketScript.new()
	packet.amount = base_damage
	packet.element = Element.keys()[element].to_lower()
	packet.crit_chance = crit_chance
	packet.crit_multiplier = crit_damage
	packet.armor_pierce = armor_pierce
	packet.knockback_force = knockback_force
	packet.source = source if source != null and is_instance_valid(source) else null
	packet.tags = _collect_tags()
	return packet

func _collect_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for affix in affixes:
		if affix == null:
			continue
		for tag in affix.get("tags"):
			if not result.has(tag):
				result.append(tag)
	return result
