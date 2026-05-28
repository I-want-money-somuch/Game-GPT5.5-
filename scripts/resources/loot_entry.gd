class_name LootEntry
extends Resource

@export var item: Resource
@export_range(0.0, 1.0, 0.01) var drop_chance := 0.25
@export_range(1, 100, 1) var weight := 10
@export var min_floor := 1
@export var max_floor := 999

func is_available(floor: int) -> bool:
	return floor >= min_floor and floor <= max_floor

