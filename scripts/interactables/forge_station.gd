class_name ForgeStation
extends Area2D

signal activated(station: Node)

@onready var core_shape: Node2D = $CoreShape
@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("interactables")
	var localization := _localization_service()
	if localization != null and localization.has_signal("language_changed"):
		var language_callable := Callable(self, "refresh_localization")
		if not localization.language_changed.is_connected(language_callable):
			localization.language_changed.connect(language_callable)
	refresh_localization()

func can_interact(_player: Node) -> bool:
	return true

func get_prompt_text() -> String:
	return _t("interact.use_forge", "Use Forge")

func get_interaction_priority() -> float:
	return 60.0

func interact(_player: Node) -> void:
	_pulse()
	activated.emit(self)

func _pulse() -> void:
	core_shape.scale = Vector2.ONE
	var tween := core_shape.create_tween()
	tween.tween_property(core_shape, "scale", Vector2(1.18, 1.18), 0.08)
	tween.tween_property(core_shape, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func refresh_localization(_language := "") -> void:
	if label != null:
		label.text = _t("state.forge", "Forge")

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
