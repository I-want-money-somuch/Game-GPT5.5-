class_name BossMechanicProfile
extends Resource

@export var id: StringName
@export var display_name := ""
@export_range(0.05, 0.95, 0.01) var phase_two_threshold := 0.5
@export var phase_transition_invulnerable_duration := 1.0
@export_range(0.0, 1.0, 0.01) var phase_transition_damage_reduction := 1.0
@export var special_mechanics: Array[StringName] = []
@export var mechanic_parameters := {}

func has_mechanic(mechanic_id: StringName) -> bool:
	return special_mechanics.has(mechanic_id)

func parameter(key: StringName, default_value = null):
	return mechanic_parameters.get(key, default_value)

