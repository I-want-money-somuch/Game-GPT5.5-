class_name EliteAffixDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var marker_color := Color(1.0, 0.55, 0.18, 1.0)

@export_group("Stats")
@export var max_health_multiplier := 1.0
@export var move_speed_multiplier := 1.0
@export var contact_damage_multiplier := 1.0
@export var armor_bonus := 0.0
@export var armor_multiplier := 1.0
@export var armor_durability_multiplier := 1.0
@export var armor_damage_reduction_bonus := 0.0

@export_group("Behavior")
@export var windup_duration_multiplier := 1.0
@export var attack_cooldown_multiplier := 1.0
@export var stagger_duration_multiplier := 1.0

@export_group("Flaming")
@export var death_explosion_radius := 0.0
@export var death_explosion_damage := 0.0
@export var death_explosion_warning := 0.2
@export var death_explosion_knockback := 140.0
@export var death_explosion_color := Color(1.0, 0.28, 0.08, 0.4)

@export_group("Phasing")
@export var phasing_interval := 0.0
@export var phasing_duration := 0.0
@export var phasing_recovery_duration := 0.0
@export var phasing_recovery_damage_taken_multiplier := 1.0

@export_group("Vampiric")
@export var vampiric_heal_ratio := 0.0
