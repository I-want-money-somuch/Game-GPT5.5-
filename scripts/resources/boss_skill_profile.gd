class_name BossSkillProfile
extends Resource

@export var id: StringName
@export var display_name := ""
@export var skill_ids: Array[StringName] = []
@export var cooldowns := PackedFloat32Array()
@export var weights := PackedFloat32Array()
@export var phase_two_cooldown_multiplier := 0.72
@export var phase_two_power_multiplier := 1.35

func get_skill_count() -> int:
	return skill_ids.size()

func get_skill_id(index: int) -> StringName:
	if skill_ids.is_empty():
		return &""
	return skill_ids[clampi(index, 0, skill_ids.size() - 1)]

func get_cooldown(index: int, phase_two := false) -> float:
	var value := 2.0
	if index >= 0 and index < cooldowns.size():
		value = cooldowns[index]
	if phase_two:
		value *= phase_two_cooldown_multiplier
	return maxf(value, 0.2)

func get_weight(index: int) -> float:
	if index >= 0 and index < weights.size():
		return maxf(weights[index], 0.0)
	return 1.0

func get_power_multiplier(phase_two := false) -> float:
	return phase_two_power_multiplier if phase_two else 1.0

