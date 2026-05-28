class_name ArmorComponent
extends Node

signal armor_changed(current: float, maximum: float)
signal armor_broken

var current_armor := 0.0
var max_armor := 0.0
var current_durability := 0.0
var max_durability := 0.0
var base_damage_reduction := 0.0

func configure(stats: Dictionary) -> void:
	max_armor = maxf(float(stats.get("armor", 0.0)), 0.0)
	current_armor = max_armor
	max_durability = maxf(float(stats.get("armor_durability", 0.0)), 0.0)
	current_durability = max_durability
	base_damage_reduction = clampf(float(stats.get("armor_damage_reduction", 0.0)), 0.0, 0.95)
	armor_changed.emit(current_durability, max_durability)

func get_damage_reduction(armor_pierce: float) -> float:
	if current_armor <= 0.0 or current_durability <= 0.0:
		return 0.0

	var durability_ratio := current_durability / maxf(max_durability, 1.0)
	var armor_curve := current_armor / (current_armor + 100.0)
	var reduction := (base_damage_reduction + armor_curve * 0.35) * durability_ratio
	return clampf(reduction - armor_pierce, 0.0, 0.9)

func damage_armor(amount: float) -> void:
	if max_durability <= 0.0 or current_durability <= 0.0:
		return

	current_durability = maxf(current_durability - maxf(amount, 0.0), 0.0)
	armor_changed.emit(current_durability, max_durability)
	if current_durability <= 0.0:
		armor_broken.emit()

