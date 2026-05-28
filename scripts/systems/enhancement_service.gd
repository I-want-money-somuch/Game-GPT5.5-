class_name EnhancementService
extends Node

const EnhancementCurveScript := preload("res://scripts/resources/enhancement_curve.gd")

@export var curve: Resource

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func attempt(current_level: int) -> Dictionary:
	if curve == null:
		return {
			"success": false,
			"level": current_level,
			"failure_outcome": EnhancementCurveScript.FailureOutcome.MATERIAL_LOSS,
		}

	var chance: float = curve.chance_for_next_level(current_level)
	var success: bool = rng.randf() <= chance
	if success:
		return {
			"success": true,
			"level": current_level + 1,
			"chance": chance,
		}

	return {
		"success": false,
		"level": _level_after_failure(current_level, curve.failure_for_next_level(current_level)),
		"chance": chance,
		"failure_outcome": curve.failure_for_next_level(current_level),
	}

func _level_after_failure(current_level: int, outcome: int) -> int:
	match outcome:
		EnhancementCurveScript.FailureOutcome.DOWNGRADE:
			return maxi(current_level - 1, 0)
		EnhancementCurveScript.FailureOutcome.BREAK_ITEM:
			return -1
		_:
			return current_level
