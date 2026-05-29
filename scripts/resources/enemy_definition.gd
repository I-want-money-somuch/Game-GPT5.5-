class_name EnemyDefinition
extends Resource

enum EnemyType {
	NORMAL,
	ELITE,
	MINI_BOSS,
	BOSS
}

enum ArmorType {
	LIGHT,
	MEDIUM,
	HEAVY,
	WARDEN
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var enemy_type := EnemyType.NORMAL
@export var armor_type := ArmorType.LIGHT
@export var base_stats: Resource
@export var contact_damage := 8.0
@export var attack_range := 28.0
@export var attack_interval := 1.0
@export var aggro_range := 500.0
@export var color := Color(0.85, 0.2, 0.2)
@export var visual_texture: Texture2D
@export_group("Behavior")
@export var behavior_profile: Resource
@export_group("Boss")
@export var boss_skill_profile: Resource
@export var boss_mechanic_profile: Resource
@export var boss_loot_table: Resource

func is_boss() -> bool:
	return enemy_type == EnemyType.MINI_BOSS or enemy_type == EnemyType.BOSS

func is_mini_boss() -> bool:
	return enemy_type == EnemyType.MINI_BOSS
