class_name RewardChest
extends Area2D

signal opened(chest: Node)

var loot_service: Node
var floor := 1
var reward_attempts := 1
var guaranteed := false
var source_definition: Resource
var is_open := false

@onready var body_shape: Node2D = $BodyShape
@onready var lid_shape: Node2D = $LidShape
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("interactables")
	var localization := _localization_service()
	if localization != null and localization.has_signal("language_changed"):
		var language_callable := Callable(self, "refresh_localization")
		if not localization.language_changed.is_connected(language_callable):
			localization.language_changed.connect(language_callable)
	refresh_localization()

func configure(target_loot_service: Node, target_floor: int, attempts: int, force_reward: bool, source: Resource = null) -> void:
	loot_service = target_loot_service
	floor = target_floor
	reward_attempts = attempts
	guaranteed = force_reward
	source_definition = source

func can_interact(_player: Node) -> bool:
	return not is_open

func get_prompt_text() -> String:
	return _t("interact.open_chest", "Open Chest")

func interact(_player: Node) -> void:
	if is_open:
		return

	is_open = true
	remove_from_group("interactables")
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	label.text = _t("state.opened", "Opened")
	_play_open_feedback()

	if loot_service != null and loot_service.has_method("drop_room_reward"):
		loot_service.drop_room_reward(global_position + Vector2(0, 26), floor, reward_attempts, guaranteed, source_definition)
	opened.emit(self)

func _play_open_feedback() -> void:
	lid_shape.rotation = -0.45
	body_shape.modulate = Color(0.92, 0.78, 0.55)
	var tween := create_tween()
	tween.tween_property(lid_shape, "position", lid_shape.position + Vector2(0, -10), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lid_shape, "modulate:a", 0.45, 0.16)

func refresh_localization(_language := "") -> void:
	if label == null:
		return
	label.text = _t("state.opened", "Opened") if is_open else _t("state.chest", "Chest")

func _localization_service() -> Node:
	if not is_inside_tree():
		return null
	var services := get_tree().get_nodes_in_group("localization_service")
	return services[0] if not services.is_empty() else null

func _t(key: String, fallback := "") -> String:
	var localization := _localization_service()
	if localization != null and localization.has_method("text"):
		return localization.text(key, fallback)
	return fallback if not fallback.is_empty() else key
