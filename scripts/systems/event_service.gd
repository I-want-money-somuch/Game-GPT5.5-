class_name EventService
extends Node

signal event_resolved(event_definition: Resource, result: Dictionary)

func can_resolve_event(event_definition: Resource, player: Node) -> bool:
	if event_definition == null or player == null:
		return false
	if float(event_definition.get("hp_cost")) > 0.0 and not _can_pay_health(player, float(event_definition.get("hp_cost"))):
		return false
	if float(event_definition.get("armor_durability_cost")) > 0.0 and not _can_pay_armor(player, float(event_definition.get("armor_durability_cost"))):
		return false
	return true

func resolve_event(event_definition: Resource, player: Node) -> Dictionary:
	var result := {
		"success": false,
		"event_type": &"",
		"reason": &"invalid",
	}
	if event_definition == null or player == null:
		return result

	result["event_type"] = event_definition.get("event_type")
	if not can_resolve_event(event_definition, player):
		result["reason"] = &"cost"
		event_resolved.emit(event_definition, result)
		return result

	_apply_stat_modifiers(event_definition, player)
	_pay_costs(event_definition, player)
	result["success"] = true
	result["reason"] = &""
	event_resolved.emit(event_definition, result)
	return result

func _can_pay_health(player: Node, amount: float) -> bool:
	if player.get("health") == null:
		return false
	return float(player.get("health")) - amount >= 1.0

func _can_pay_armor(player: Node, amount: float) -> bool:
	if player.has_method("current_armor_durability"):
		return float(player.current_armor_durability()) >= amount
	var armor = player.get("armor_component")
	if armor != null and armor.get("current_durability") != null:
		return float(armor.get("current_durability")) >= amount
	return false

func _pay_costs(event_definition: Resource, player: Node) -> void:
	var hp_cost := float(event_definition.get("hp_cost"))
	if hp_cost > 0.0 and player.has_method("spend_health_for_event"):
		player.spend_health_for_event(hp_cost)

	var armor_cost := float(event_definition.get("armor_durability_cost"))
	if armor_cost > 0.0 and player.has_method("spend_armor_durability_for_event"):
		player.spend_armor_durability_for_event(armor_cost)

func _apply_stat_modifiers(event_definition: Resource, player: Node) -> void:
	var modifiers: Resource = event_definition.get("stat_modifiers")
	if modifiers == null or not player.has_method("apply_run_stat_modifiers"):
		return
	player.apply_run_stat_modifiers(modifiers, false)
