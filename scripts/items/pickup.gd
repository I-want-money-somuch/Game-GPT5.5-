class_name Pickup
extends Area2D

@export var item_definition: Resource

@onready var label: Label = $Label
@onready var shape: Polygon2D = $Shape

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_visuals()

func _refresh_visuals() -> void:
	if item_definition == null:
		label.text = "Drop"
		shape.color = Color(0.9, 0.9, 0.9)
		return

	label.text = item_definition.display_name
	if item_definition.has_method("create_damage_packet"):
		shape.color = Color(0.9, 0.45, 0.2)
	elif item_definition.has_method("get_slot_name"):
		shape.color = Color(0.2, 0.65, 0.9)
	else:
		shape.color = Color(0.9, 0.9, 0.9)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and body.has_method("collect_item"):
		body.collect_item(item_definition)
		queue_free()
