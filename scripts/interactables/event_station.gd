class_name EventStation
extends Area2D

signal activated(station: Node, event_definition: Resource, result: Dictionary)

var event_service: Node
var event_definition: Resource
var completed := false

@onready var base_shape: Polygon2D = $BaseShape
@onready var core_shape: Polygon2D = $CoreShape
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("interactables")
	_refresh_visuals()

func configure(service: Node, definition: Resource) -> void:
	event_service = service
	event_definition = definition
	_refresh_visuals()

func can_interact(_player: Node) -> bool:
	return not completed

func get_prompt_text() -> String:
	if event_definition != null and event_definition.has_method("get_prompt"):
		return event_definition.get_prompt()
	if event_definition != null:
		return "Use %s" % event_definition.get("display_name")
	return "Use Event"

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
	label.text = "Resolved"
	_play_success_feedback()
	activated.emit(self, event_definition, result)

func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	var color := Color(0.85, 0.42, 0.18, 1.0)
	var text := "Event"
	if event_definition != null:
		color = event_definition.get("event_color")
		text = event_definition.get("display_name")
	if base_shape != null:
		base_shape.color = color.darkened(0.5)
	if core_shape != null:
		core_shape.color = color
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
