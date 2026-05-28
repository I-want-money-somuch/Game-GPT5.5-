class_name EnhancementCurve
extends Resource

enum FailureOutcome {
	MATERIAL_LOSS,
	DOWNGRADE,
	DURABILITY_LOSS,
	BREAK_ITEM
}

@export var id: StringName
@export var success_chances := PackedFloat32Array([1.0, 0.9, 0.75, 0.55, 0.35, 0.2])
@export var failure_outcomes := PackedInt32Array([
	FailureOutcome.MATERIAL_LOSS,
	FailureOutcome.MATERIAL_LOSS,
	FailureOutcome.DURABILITY_LOSS,
	FailureOutcome.DOWNGRADE,
	FailureOutcome.DOWNGRADE,
	FailureOutcome.BREAK_ITEM,
])

func chance_for_next_level(current_level: int) -> float:
	var index := clampi(current_level, 0, success_chances.size() - 1)
	return success_chances[index]

func failure_for_next_level(current_level: int) -> int:
	if failure_outcomes.is_empty():
		return FailureOutcome.MATERIAL_LOSS
	var index := clampi(current_level, 0, failure_outcomes.size() - 1)
	return failure_outcomes[index]
