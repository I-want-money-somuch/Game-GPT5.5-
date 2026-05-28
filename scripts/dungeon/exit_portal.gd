class_name ExitPortal
extends Area2D

signal activated

@onready var label: Label = $Label
@onready var ring: Polygon2D = $Ring
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var available := false

func _ready() -> void:
	set_available(false, "Next")

func set_available(available: bool, text := "Next") -> void:
	self.available = available
	visible = available
	monitorable = available
	if available:
		add_to_group("interactables")
	else:
		remove_from_group("interactables")
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not available)
	label.text = text
	if available:
		_pulse()

func can_interact(_player: Node) -> bool:
	return available

func get_prompt_text() -> String:
	return "Enter Next Room"

func interact(_player: Node) -> void:
	if available:
		activated.emit()

func _pulse() -> void:
	ring.scale = Vector2.ONE
	ring.modulate.a = 1.0
	var tween := ring.create_tween()
	tween.set_loops()
	tween.tween_property(ring, "scale", Vector2(1.12, 1.12), 0.42).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE)
