class_name AffixDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var stat_modifiers: Resource
@export var tags: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var proc_chance := 0.0
@export var effect_id: StringName
