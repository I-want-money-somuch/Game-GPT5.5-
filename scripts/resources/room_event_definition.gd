class_name RoomEventDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var event_type: StringName = &"stat_pact"
@export var prompt_text := ""
@export_multiline var description := ""
@export var event_color := Color(0.85, 0.42, 0.18, 1.0)
@export var hp_cost := 0.0
@export var armor_durability_cost := 0.0
@export var stat_modifiers: Resource
@export var one_shot := true
@export var reward_attempts := 0
@export var trial_enemy_id: StringName = &""
@export var trial_uses_elite_affix := false
@export var exit_lock_during_trial := false

func get_prompt() -> String:
	if not prompt_text.is_empty():
		return prompt_text
	return "Use %s" % display_name
