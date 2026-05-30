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
	var localization := _localization_service()
	if localization != null and localization.has_signal("language_changed"):
		var language_callable := Callable(self, "refresh_localization")
		if not localization.language_changed.is_connected(language_callable):
			localization.language_changed.connect(language_callable)
	_refresh_visuals()

func _refresh_visuals() -> void:
	if item_definition == null:
		label.text = _t("state.drop", "Drop")
		shape.texture = EQUIPMENT_TEXTURE
		shape.modulate = Color(0.9, 0.9, 0.9)
		return

	label.text = _resource_name(item_definition)
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
	return _lf("interact.pick_up", [_resource_name(item_definition)], "Pick Up %s") if item_definition != null else _t("interact.pick_up_generic", "Pick Up")

func get_interaction_priority() -> float:
	return 10.0

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
