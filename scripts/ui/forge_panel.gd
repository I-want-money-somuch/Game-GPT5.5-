class_name ForgePanel
extends PanelContainer

const EnhancementCurveScript := preload("res://scripts/resources/enhancement_curve.gd")

var player
var enhancement_service
var feedback_service
var selected_item: Resource

@onready var selected_label: Label = %ForgeSelectedLabel
@onready var level_label: Label = %ForgeLevelLabel
@onready var chance_label: Label = %ForgeChanceLabel
@onready var outcome_label: Label = %ForgeOutcomeLabel
@onready var forge_button: Button = %ForgeButton

func _ready() -> void:
	forge_button.pressed.connect(_on_forge_pressed)
	_refresh()

func bind_services(target_player: Node, target_enhancement_service: Node, target_feedback_service: Node) -> void:
	player = target_player
	enhancement_service = target_enhancement_service
	feedback_service = target_feedback_service
	if player != null and player.has_signal("loadout_changed"):
		player.loadout_changed.connect(func(_inventory: Array, _equipped: Dictionary) -> void: _refresh())
	_refresh()

func set_selected_item(item: Resource) -> void:
	selected_item = item
	_refresh()

func _on_forge_pressed() -> void:
	if player == null or enhancement_service == null or selected_item == null:
		return

	var current_level: int = player.get_enhancement_level(selected_item)
	var result: Dictionary = enhancement_service.attempt(current_level)
	player.apply_enhancement_result(selected_item, result)
	if feedback_service != null and feedback_service.has_method("forge_result"):
		feedback_service.forge_result(bool(result.get("success", false)))
	_refresh()

func _refresh() -> void:
	if selected_item == null or player == null:
		selected_label.text = "Selected: -"
		level_label.text = "Level: -"
		chance_label.text = "Chance: -"
		outcome_label.text = "Outcome: -"
		forge_button.disabled = true
		return

	var level: int = player.get_enhancement_level(selected_item)
	selected_label.text = "Selected: %s" % selected_item.display_name
	level_label.text = "Level: +%d" % level
	forge_button.disabled = level < 0

	if enhancement_service == null or enhancement_service.curve == null:
		chance_label.text = "Chance: -"
		outcome_label.text = "Outcome: -"
		return

	var chance: float = enhancement_service.curve.chance_for_next_level(level)
	var failure: int = enhancement_service.curve.failure_for_next_level(level)
	chance_label.text = "Chance: %d%%" % roundi(chance * 100.0)
	outcome_label.text = "Fail: %s" % _failure_name(failure)

func _failure_name(value: int) -> String:
	match value:
		EnhancementCurveScript.FailureOutcome.MATERIAL_LOSS:
			return "Materials"
		EnhancementCurveScript.FailureOutcome.DOWNGRADE:
			return "Downgrade"
		EnhancementCurveScript.FailureOutcome.DURABILITY_LOSS:
			return "Durability"
		EnhancementCurveScript.FailureOutcome.BREAK_ITEM:
			return "Break"
		_:
			return "-"
