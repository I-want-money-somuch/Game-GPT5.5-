class_name ExitPortal
extends Area2D

signal activated

@onready var label: Label = $Label
@onready var ring: Node2D = $Ring
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var available := false
var label_text := "Next"
var localization_service: Node

func _ready() -> void:
	set_available(false, "Next")

func set_available(available: bool, text := "Next") -> void:
	self.available = available
	label_text = text
	visible = available
	monitoring = available
	monitorable = available
	if available:
		add_to_group("interactables")
	else:
		remove_from_group("interactables")
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not available)
	refresh_localization()
	_refresh_players_deferred()
	if available:
		_pulse()

func can_interact(_player: Node) -> bool:
	return available

func get_prompt_text() -> String:
	return _t("interact.enter_next_room", "Enter Next Room")

func interact(_player: Node) -> void:
	if available:
		activated.emit()

func get_interaction_priority() -> float:
	return 100.0

func _pulse() -> void:
	ring.scale = Vector2.ONE
	ring.modulate.a = 1.0
	var tween := ring.create_tween()
	tween.set_loops()
	tween.tween_property(ring, "scale", Vector2(1.12, 1.12), 0.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE)

func set_localization_service(service: Node) -> void:
	localization_service = service
	if localization_service != null and localization_service.has_signal("language_changed"):
		var language_callable := Callable(self, "refresh_localization")
		if not localization_service.language_changed.is_connected(language_callable):
			localization_service.language_changed.connect(language_callable)
	refresh_localization()

func refresh_localization(_language := "") -> void:
	if label == null:
		return
	label.text = _localized_label_text()

func _localized_label_text() -> String:
	if label_text == "Next" or label_text == "Next Room":
		return _t("ui.next_room", "Next Room")
	return label_text

func _t(key: String, fallback := "") -> String:
	if localization_service != null and localization_service.has_method("text"):
		return localization_service.text(key, fallback)
	return fallback if not fallback.is_empty() else key

func _refresh_players_deferred() -> void:
	if not is_inside_tree():
		return
	call_deferred("_refresh_players_now")

func _refresh_players_now() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if player != null and player.has_method("refresh_interaction_target"):
			player.refresh_interaction_target()
