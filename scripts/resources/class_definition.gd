class_name ClassDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var starting_weapon: Resource
@export var active_skill_id: StringName
@export var passive_id: StringName
@export var base_stats: Resource
@export var growth_tags: Array[StringName] = []
