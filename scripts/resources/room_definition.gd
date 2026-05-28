class_name RoomDefinition
extends Resource

enum RoomType {
	COMBAT,
	ELITE,
	TREASURE,
	SHOP,
	FORGE,
	EVENT,
	BOSS
}

@export var id: StringName
@export var display_name := ""
@export var room_type := RoomType.COMBAT
@export var min_floor := 1
@export var max_floor := 999
@export var weight := 10
@export var enemy_group: StringName = &"normal"
@export var enemy_count := 0
@export var reward_attempts := 0
@export var guaranteed_reward := false
@export var forge_available := false
@export var exit_unlocked_on_start := false
@export var floor_color := Color(0.09, 0.105, 0.11)
@export var accent_color := Color(0.28, 0.33, 0.35)

func has_encounter() -> bool:
	return enemy_count > 0 or enemy_group == &"mini_boss" or enemy_group == &"boss"

func room_type_name() -> String:
	return RoomType.keys()[room_type].to_lower()
