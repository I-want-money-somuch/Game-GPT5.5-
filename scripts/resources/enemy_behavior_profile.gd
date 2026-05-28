class_name EnemyBehaviorProfile
extends Resource

enum AttackShape {
	CIRCLE,
	LINE
}

@export var id: StringName
@export var display_name := ""
@export var behavior_id: StringName = &"chaser"
@export var chase_range := 500.0
@export var preferred_range := 40.0
@export var attack_range := 36.0
@export var windup_duration := 0.25
@export var attack_duration := 0.1
@export var recover_duration := 0.35
@export var attack_cooldown := 0.9
@export var move_speed_multiplier := 1.0
@export var windup_move_multiplier := 0.0
@export var stagger_duration := 0.18
@export var attack_shape := AttackShape.CIRCLE
@export var attack_radius := 40.0
@export var attack_length := 58.0
@export var attack_width := 36.0
@export var dash_distance := 0.0
@export var dash_duration := 0.0
@export var knockback_force := 150.0
@export var warning_color := Color(1.0, 0.35, 0.14, 0.38)

func is_line_attack() -> bool:
	return attack_shape == AttackShape.LINE
