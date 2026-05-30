class_name EventStation
extends Area2D

signal activated(station: Node, event_definition: Resource, result: Dictionary)

var event_service: Node
var event_definition: Resource
var completed := false

@onready var base_shape: Node2D = $BaseShape
@onready var core_shape: Node2D = $CoreShape
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("interactables")
	var localization := _localization_service()
	if localization != null and localization.has_signal("language_changed"):
		var language_callable := Callable(self, "refresh_localization")
		if not localization.language_changed.is_connected(language_callable):
			localization.language_changed.connect(language_callable)
	_refresh_visuals()

func configure(service: Node, definition: Resource) -> void:
	event_service = service
	event_definition = definition
	_refresh_visuals()

func can_interact(_player: Node) -> bool:
	return not completed

func get_prompt_text() -> String:
	var localization := _localization_service()
	if event_definition != null and localization != null and localization.has_method("resource_prompt"):
		return localization.resource_prompt(event_definition)
	if event_definition != null and event_definition.has_method("get_prompt"):
		return event_definition.get_prompt()
	if event_definition != null:
		return _lf("interact.use_event", [_resource_name(event_definition)], "Use %s")
	return _t("state.event", "Event")

func interact(player: Node) -> void:
	if completed or event_service == null or not event_service.has_method("resolve_event"):
		return

	var result: Dictionary = event_service.resolve_event(event_definition, player)
	if not bool(result.get("success", false)):
		_play_denied_feedback()
		return

	completed = bool(event_definition.get("one_shot")) if event_definition != null else true
	if completed:
		remove_from_group("interactables")
		set_deferred("monitorable", false)
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)
	label.text = _t("state.resolved", "Resolved")
	_play_success_feedback()
	if player != null and player.has_method("refresh_interaction_target"):
		player.refresh_interaction_target()
	activated.emit(self, event_definition, result)

func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	var color := Color(0.85, 0.42, 0.18, 1.0)
	var text := _t("state.resolved", "Resolved") if completed else _t("state.event", "Event")
	if event_definition != null:
		color = event_definition.get("event_color")
		text = _t("state.resolved", "Resolved") if completed else _resource_name(event_definition)
	if base_shape != null:
		base_shape.modulate = color.darkened(0.25)
	if core_shape != null:
		core_shape.modulate = color.lightened(0.12)
	if label != null:
		label.text = text

func _play_success_feedback() -> void:
	core_shape.scale = Vector2.ONE
	var tween := core_shape.create_tween()
	tween.tween_property(core_shape, "scale", Vector2(1.28, 1.28), 0.1)
	tween.tween_property(core_shape, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_denied_feedback() -> void:
	var original := core_shape.modulate
	core_shape.modulate = Color(1.0, 0.2, 0.18, 1.0)
	var tween := core_shape.create_tween()
	tween.tween_property(core_shape, "modulate", original, 0.18)

func refresh_localization(_language := "") -> void:
	_refresh_visuals()

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

func _lf(key: String, args: Array = [], fallback := "") -> String:
	var localization := _localization_service()
	if localization != null and localization.has_method("format_text"):
		return localization.format_text(key, args, fallback)
	return fallback % args if not fallback.is_empty() else key % args

func _resource_name(resource: Resource) -> String:
	var localization := _localization_service()
	if localization != null and localization.has_method("resource_name"):
		return localization.resource_name(resource)
	if resource == null:
		return ""
	return str(resource.get("display_name"))
