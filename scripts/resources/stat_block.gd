class_name StatBlock
extends Resource

@export_group("Core")
@export var max_health := 0.0
@export var armor := 0.0
@export var armor_durability := 0.0
@export_range(0.0, 0.95, 0.01) var armor_damage_reduction := 0.0

@export_group("Offense")
@export var damage_multiplier := 0.0
@export_range(0.0, 1.0, 0.01) var crit_chance := 0.0
@export var crit_damage := 0.0
@export var armor_pierce := 0.0
@export var attack_speed := 0.0

@export_group("Utility")
@export var move_speed := 0.0
@export var dodge_chance := 0.0
@export var skill_cooldown_reduction := 0.0
@export var energy_recovery := 0.0

func to_dictionary() -> Dictionary:
	return {
		"max_health": max_health,
		"armor": armor,
		"armor_durability": armor_durability,
		"armor_damage_reduction": armor_damage_reduction,
		"damage_multiplier": damage_multiplier,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"armor_pierce": armor_pierce,
		"attack_speed": attack_speed,
		"move_speed": move_speed,
		"dodge_chance": dodge_chance,
		"skill_cooldown_reduction": skill_cooldown_reduction,
		"energy_recovery": energy_recovery,
	}

func apply_to_dictionary(target: Dictionary) -> void:
	for key in to_dictionary().keys():
		target[key] = float(target.get(key, 0.0)) + float(to_dictionary()[key])

