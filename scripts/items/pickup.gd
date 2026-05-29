class_name Pickup
extends Area2D

const WEAPON_TEXTURE := preload("res://assets/sprites/items/pickup_weapon.png")
const EQUIPMENT_TEXTURE := preload("res://assets/sprites/items/pickup_equipment.png")

@export var item_definition: Resource

@onready var label: Label = $Label
@onready var shape: Sprite2D = $Shape
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var picked_up := false

func _ready() -> void:
	add_to_group("interactables")
	_refresh_visuals()

func _refresh_visuals() -> void:
	if item_definition == null:
		label.text = "Drop"
		shape.texture = EQUIPMENT_TEXTURE
		shape.modulate = Color(0.9, 0.9, 0.9)
		return

	label.text = item_definition.display_name
	if item_definition.has_method("create_damage_packet"):
		shape.texture = WEAPON_TEXTURE
		shape.modulate = Color.WHITE
	elif item_definition.has_method("get_slot_name"):
		shape.texture = EQUIPMENT_TEXTURE
		shape.modulate = Color.WHITE
	else:
		shape.texture = EQUIPMENT_TEXTURE
		shape.modulate = Color(0.9, 0.9, 0.9)

func can_interact(player: Node) -> bool:
	return not picked_up and item_definition != null and player != null and player.has_method("collect_item")

func get_prompt_text() -> String:
	return "Pick Up %s" % item_definition.display_name if item_definition != null else "Pick Up"

func get_preview_item() -> Resource:
	return item_definition

func interact(player: Node) -> void:
	if not can_interact(player):
		return
	picked_up = true
	remove_from_group("interactables")
	set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	player.collect_item(item_definition)
	queue_free()
