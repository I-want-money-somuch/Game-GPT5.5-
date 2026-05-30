class_name ForgePanel
extends PanelContainer

const EnhancementCurveScript := preload("res://scripts/resources/enhancement_curve.gd")

var player
var enhancement_service
var feedback_service
var selected_item: Resource
var localization_service: Node

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

func set_localization_service(service: Node) -> void:
	localization_service = service
	_refresh()

func refresh_for_language() -> void:
	_refresh()

func set_selected_item(item: Resource) -> void:
	selected_item = item
	_refresh()

func _on_forge_pressed() -> void:
	if player == null or enhancement_service == null or selected_item == null:
		return
	if not _player_has_item(selected_item):
		selected_item = null
		_refresh()
		return

	var current_level: int = player.get_enhancement_level(selected_item)
	var result: Dictionary = enhancement_service.attempt(current_level)
	player.apply_enhancement_result(selected_item, result)
	if not _player_has_item(selected_item):
		selected_item = null
	if feedback_service != null and feedback_service.has_method("forge_result"):
		feedback_service.forge_result(bool(result.get("success", false)))
	_refresh()

func _refresh() -> void:
	if selected_item != null and player != null and not _player_has_item(selected_item):
		selected_item = null
	if selected_item == null or player == null:
		selected_label.text = _t("forge.selected_empty", "Selected: -")
		level_label.text = _t("forge.level_empty", "Level: -")
		chance_label.text = _t("forge.chance_empty", "Chance: -")
		outcome_label.text = _t("forge.outcome_empty", "Outcome: -")
		forge_button.disabled = true
		forge_button.text = _t("forge.enhance", "Enhance")
		return

	var level: int = player.get_enhancement_level(selected_item)
	selected_label.text = _lf("forge.selected", [_resource_name(selected_item)], "Selected: %s")
	level_label.text = _lf("forge.level", [level], "Level: +%d")
	forge_button.disabled = level < 0

	if enhancement_service == null or enhancement_service.curve == null:
		chance_label.text = _t("forge.chance_empty", "Chance: -")
		outcome_label.text = _t("forge.outcome_empty", "Outcome: -")
		return

	var chance: float = enhancement_service.curve.chance_for_next_level(level)
	var failure: int = enhancement_service.curve.failure_for_next_level(level)
	chance_label.text = _lf("forge.chance", [roundi(chance * 100.0)], "Chance: %d%%")
	outcome_label.text = _lf("forge.fail", [_failure_name(failure)], "Fail: %s")
	forge_button.text = _t("forge.enhance", "Enhance")

func _player_has_item(item: Resource) -> bool:
	if player == null or item == null:
		return false
	if player.inventory.has(item):
		return true
	if player.active_weapon == item:
		return true
	for equipped_item in player.equipped.values():
		if equipped_item == item:
			return true
	return false

func _failure_name(value: int) -> String:
	match value:
		EnhancementCurveScript.FailureOutcome.MATERIAL_LOSS:
			return _t("forge.failure.materials", "Materials")
		EnhancementCurveScript.FailureOutcome.DOWNGRADE:
			return _t("forge.failure.downgrade", "Downgrade")
		EnhancementCurveScript.FailureOutcome.DURABILITY_LOSS:
			return _t("forge.failure.durability", "Durability")
		EnhancementCurveScript.FailureOutcome.BREAK_ITEM:
			return _t("forge.failure.break", "Break")
		_:
			return "-"

func _t(key: String, fallback := "") -> String:
	if localization_service != null and localization_service.has_method("text"):
		return localization_service.text(key, fallback)
	return fallback if not fallback.is_empty() else key

func _lf(key: String, args: Array = [], fallback := "") -> String:
	if localization_service != null and localization_service.has_method("format_text"):
		return localization_service.format_text(key, args, fallback)
	return fallback % args if not fallback.is_empty() else key % args

func _resource_name(resource: Resource) -> String:
	if localization_service != null and localization_service.has_method("resource_name"):
		return localization_service.resource_name(resource)
	if resource == null:
		return ""
	return str(resource.get("display_name"))
