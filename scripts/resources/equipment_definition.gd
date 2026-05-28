class_name EquipmentDefinition
extends Resource

enum Slot {
	HELMET,
	CHEST,
	GLOVES,
	BOOTS,
	TRINKET,
	RING
}

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var slot := Slot.CHEST
@export var rarity := Rarity.COMMON
@export var stat_modifiers: Resource
@export var affixes: Array[Resource] = []

func get_slot_name() -> String:
	return Slot.keys()[slot].to_lower()
