class_name LootTable
extends Resource

@export var id: StringName
@export var entries: Array[Resource] = []
@export var guaranteed_entries: Array[Resource] = []

func roll(rng: RandomNumberGenerator, floor: int = 1, drop_chance_bonus := 0.0) -> Resource:
	var candidates: Array[Resource] = []
	var total_weight := 0
	for entry in entries:
		if entry == null:
			continue
		if not entry.is_available(floor):
			continue
		var effective_chance := clampf(float(entry.drop_chance) + drop_chance_bonus, 0.0, 1.0)
		if rng.randf() > effective_chance:
			continue
		candidates.append(entry)
		total_weight += entry.weight

	if candidates.is_empty() or total_weight <= 0:
		return null

	var pick := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in candidates:
		cursor += entry.weight
		if pick <= cursor:
			return entry.item

	return candidates.back().item

func roll_guaranteed(rng: RandomNumberGenerator, floor: int = 1) -> Resource:
	var candidates: Array[Resource] = []
	var total_weight := 0
	for entry in entries:
		if entry == null or not entry.is_available(floor):
			continue
		candidates.append(entry)
		total_weight += entry.weight

	if candidates.is_empty() or total_weight <= 0:
		return null

	var pick := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in candidates:
		cursor += entry.weight
		if pick <= cursor:
			return entry.item

	return candidates.back().item

func roll_primary_guaranteed(rng: RandomNumberGenerator, floor: int = 1) -> Resource:
	if guaranteed_entries.is_empty():
		return roll_guaranteed(rng, floor)

	var candidates: Array[Resource] = []
	var total_weight := 0
	for entry in guaranteed_entries:
		if entry == null or not entry.is_available(floor):
			continue
		candidates.append(entry)
		total_weight += entry.weight

	if candidates.is_empty() or total_weight <= 0:
		return roll_guaranteed(rng, floor)

	var pick := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in candidates:
		cursor += entry.weight
		if pick <= cursor:
			return entry.item

	return candidates.back().item
