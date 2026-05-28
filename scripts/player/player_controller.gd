class_name PlayerController
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
const GameConstantsScript := preload("res://scripts/core/game_constants.gd")
const CombatResolverScript := preload("res://scripts/combat/combat_resolver.gd")

signal weapon_changed(weapon: Resource)
signal inventory_changed(count: int)
signal loadout_changed(inventory: Array, equipped: Dictionary)
signal interaction_prompt_changed(prompt: String)
signal damaged(result: Dictionary)
signal died

@export var class_definition: Resource
@export var default_weapon: Resource
@export var projectile_scene: PackedScene

var health := 100.0
var max_health := 100.0
var move_speed := 180.0
var active_weapon: Resource
var inventory: Array[Resource] = []
var equipped: Dictionary = {}
var enhancement_levels: Dictionary = {}
var fire_cooldown := 0.0
var knockback_velocity := Vector2.ZERO
var nearby_interactables: Array = []
var current_interactable: Node
var interact_key_was_pressed := false
var affix_effect_service: Node
var input_enabled := true
var is_dead := false
var rng := RandomNumberGenerator.new()

@onready var armor_component: Node = $ArmorComponent
@onready var body_shape: Polygon2D = $BodyShape
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	rng.randomize()
	add_to_group("players")
	var armor := _armor_component()
	if armor != null:
		armor.armor_changed.connect(func(current: float, maximum: float) -> void: armor_changed.emit(current, maximum))
	var area := _interaction_area()
	if area != null:
		area.area_entered.connect(_on_interaction_area_entered)
		area.area_exited.connect(_on_interaction_area_exited)
	_recalculate_stats(true)
	if default_weapon != null:
		equip_weapon(default_weapon)

func initialize(loadout_class: Resource, weapon: Resource, projectile: PackedScene) -> void:
	class_definition = loadout_class
	default_weapon = weapon
	projectile_scene = projectile
	equipped.clear()
	inventory.clear()
	enhancement_levels.clear()
	input_enabled = true
	is_dead = false
	knockback_velocity = Vector2.ZERO
	_recalculate_stats(true)
	var shape := _body_shape()
	if shape != null:
		shape.modulate = Color.WHITE
	if default_weapon != null:
		inventory.append(default_weapon)
		equip_weapon(default_weapon)
	inventory_changed.emit(inventory.size())
	loadout_changed.emit(inventory, equipped)

func _physics_process(delta: float) -> void:
	fire_cooldown = maxf(fire_cooldown - delta, 0.0)
	if is_dead or not input_enabled:
		velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = _movement_vector() * move_speed + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire()
	_handle_interaction_input()
	_refresh_interactable_prompt()

func _movement_vector() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	return input.normalized()

func _try_fire() -> void:
	if active_weapon == null or projectile_scene == null or fire_cooldown > 0.0:
		return

	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() <= 0.01:
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction.normalized() * 20.0
	projectile.setup(active_weapon, direction, self, GameConstantsScript.Team.PLAYER)
	_feedback_call("weapon_fired", projectile.global_position)

	fire_cooldown = 1.0 / maxf(attack_rate_for_weapon(active_weapon), 0.1)

func collect_item(item: Resource) -> void:
	if item == null or is_dead:
		return

	inventory.append(item)
	if item.has_method("create_damage_packet"):
		equip_weapon(item)
	elif item.has_method("get_slot_name"):
		equip_equipment(item)
	inventory_changed.emit(inventory.size())
	loadout_changed.emit(inventory, equipped)

func force_interact_with(interactable: Node) -> void:
	if interactable != null and _can_use_interactable(interactable):
		interactable.interact(self)
		_refresh_interactable_prompt()

func equip_weapon(weapon: Resource) -> void:
	active_weapon = weapon
	weapon_changed.emit(active_weapon)
	loadout_changed.emit(inventory, equipped)

func bind_affix_effect_service(service: Node) -> void:
	affix_effect_service = service

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO

func attack_rate_for_weapon(weapon: Resource) -> float:
	if weapon == null:
		return 0.0
	var attack_speed_bonus: float = _current_stats(weapon).get("attack_speed", 0.0)
	return weapon.attack_rate + attack_speed_bonus

func equip_equipment(equipment: Resource) -> void:
	equipped[equipment.get("slot")] = equipment
	_recalculate_stats(false)
	loadout_changed.emit(inventory, equipped)

func modify_outgoing_packet(packet: RefCounted, weapon: Resource) -> void:
	var stats := _current_stats(weapon)
	var level := get_enhancement_level(weapon)
	packet.amount *= 1.0 + float(stats.get("damage_multiplier", 0.0)) + float(level) * 0.12
	packet.crit_chance = clampf(packet.crit_chance + float(stats.get("crit_chance", 0.0)), 0.0, 0.95)
	packet.crit_multiplier += float(stats.get("crit_damage", 0.0))
	packet.armor_pierce = clampf(packet.armor_pierce + float(stats.get("armor_pierce", 0.0)), 0.0, 0.95)
	packet.knockback_force += float(level) * 8.0

func notify_weapon_hit(packet: RefCounted, weapon: Resource, target: Node) -> void:
	if affix_effect_service != null and affix_effect_service.has_method("process_weapon_hit"):
		affix_effect_service.process_weapon_hit(self, weapon, target, packet, rng)

func take_damage(packet: RefCounted) -> void:
	if is_dead:
		return
	if packet.source == self:
		return

	var dodge_chance := clampf(float(_current_stats().get("dodge_chance", 0.0)), 0.0, 0.75)
	if rng.randf() < dodge_chance:
		return

	var result: Dictionary = CombatResolverScript.resolve(packet, _armor_component(), rng)
	health = maxf(health - float(result["final_damage"]), 0.0)
	_apply_knockback(packet)
	_play_damage_feedback(result)
	health_changed.emit(health, max_health)
	damaged.emit(result)
	if health <= 0.0:
		_die()

func get_enhancement_level(item: Resource) -> int:
	return int(enhancement_levels.get(_item_key(item), 0))

func apply_enhancement_result(item: Resource, result: Dictionary) -> void:
	if item == null:
		return

	var new_level := int(result.get("level", get_enhancement_level(item)))
	if new_level < 0:
		_remove_item(item)
	else:
		enhancement_levels[_item_key(item)] = new_level
	loadout_changed.emit(inventory, equipped)

func _remove_item(item: Resource) -> void:
	inventory.erase(item)
	if active_weapon == item:
		active_weapon = null
		for candidate in inventory:
			if candidate != null and candidate.has_method("create_damage_packet"):
				active_weapon = candidate
				break
		weapon_changed.emit(active_weapon)

	for slot in equipped.keys():
		if equipped[slot] == item:
			equipped.erase(slot)
			break
	enhancement_levels.erase(_item_key(item))
	_recalculate_stats(false)
	inventory_changed.emit(inventory.size())

func _item_key(item: Resource) -> String:
	if item == null:
		return ""
	return str(item.get("id")) if item.get("id") != null else item.resource_path

func _apply_knockback(packet: RefCounted) -> void:
	if packet.hit_direction.length_squared() <= 0.01:
		return
	knockback_velocity += packet.hit_direction.normalized() * maxf(packet.knockback_force, 0.0)

func _play_damage_feedback(result: Dictionary) -> void:
	var shape := _body_shape()
	if shape != null:
		if health <= 0.0:
			shape.modulate = Color(0.42, 0.46, 0.52)
		else:
			shape.modulate = Color(1.6, 0.72, 0.68)
			var tween := shape.create_tween()
			tween.tween_property(shape, "modulate", Color.WHITE, 0.12)
	_feedback_call("player_hit", global_position, result)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	set_input_enabled(false)
	var shape := _body_shape()
	if shape != null:
		shape.modulate = Color(0.42, 0.46, 0.52)
	_feedback_call("player_hit", global_position, {"final_damage": 0.0, "critical": false})
	died.emit()

func _feedback_call(method: StringName, arg1 = null, arg2 = null) -> void:
	var services := get_tree().get_nodes_in_group("feedback_service")
	if services.is_empty():
		return
	var service: Node = services[0]
	if not service.has_method(method):
		return
	if arg2 != null:
		service.call(method, arg1, arg2)
	elif arg1 != null:
		service.call(method, arg1)
	else:
		service.call(method)

func _recalculate_stats(reset_health: bool) -> void:
	var stats := _current_stats()
	var old_max := max_health
	max_health = maxf(float(stats.get("max_health", 100.0)), 1.0)
	move_speed = maxf(float(stats.get("move_speed", 180.0)), 1.0)
	if reset_health:
		health = max_health
	else:
		health = minf(health + maxf(max_health - old_max, 0.0), max_health)
	var armor := _armor_component()
	if armor != null:
		armor.configure(stats)
	health_changed.emit(health, max_health)

func _armor_component() -> Node:
	if armor_component != null:
		return armor_component
	return get_node_or_null("ArmorComponent")

func _body_shape() -> Polygon2D:
	if body_shape != null:
		return body_shape
	return get_node_or_null("BodyShape") as Polygon2D

func _interaction_area() -> Area2D:
	if interaction_area != null:
		return interaction_area
	return get_node_or_null("InteractionArea") as Area2D

func _handle_interaction_input() -> void:
	var pressed := Input.is_key_pressed(KEY_E)
	if pressed and not interact_key_was_pressed:
		_try_interact()
	interact_key_was_pressed = pressed

func _try_interact() -> void:
	_refresh_interactable_prompt()
	if current_interactable == null:
		return
	force_interact_with(current_interactable)

func _on_interaction_area_entered(area: Area2D) -> void:
	if area == null or not area.is_in_group("interactables"):
		return
	if not nearby_interactables.has(area):
		nearby_interactables.append(area)
	_refresh_interactable_prompt()

func _on_interaction_area_exited(area: Area2D) -> void:
	nearby_interactables.erase(area)
	if current_interactable == area:
		current_interactable = null
	_refresh_interactable_prompt()

func _refresh_interactable_prompt() -> void:
	nearby_interactables = nearby_interactables.filter(func(item: Node) -> bool:
		return is_instance_valid(item) and _can_use_interactable(item)
	)

	var nearest: Node
	var nearest_distance := INF
	for item in nearby_interactables:
		var node := item as Node2D
		if node == null:
			continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance < nearest_distance:
			nearest = item
			nearest_distance = distance

	if current_interactable == nearest:
		return

	current_interactable = nearest
	var prompt := ""
	if current_interactable != null and current_interactable.has_method("get_prompt_text"):
		prompt = current_interactable.get_prompt_text()
	interaction_prompt_changed.emit(prompt)

func _can_use_interactable(interactable: Node) -> bool:
	if interactable == null or not is_instance_valid(interactable):
		return false
	if not interactable.is_in_group("interactables"):
		return false
	if not interactable.has_method("can_interact") or not interactable.has_method("interact"):
		return false
	return bool(interactable.can_interact(self))

func _current_stats(weapon: Resource = null) -> Dictionary:
	var stats := {
		"max_health": 100.0,
		"move_speed": 180.0,
		"armor": 0.0,
		"armor_durability": 0.0,
		"armor_damage_reduction": 0.0,
		"attack_speed": 0.0,
		"dodge_chance": 0.0,
		"crit_chance": 0.0,
		"crit_damage": 0.0,
		"damage_multiplier": 0.0,
		"armor_pierce": 0.0,
	}

	if class_definition != null and class_definition.base_stats != null:
		class_definition.base_stats.apply_to_dictionary(stats)

	for equipment in equipped.values():
		if equipment is Resource and equipment.get("stat_modifiers") != null:
			equipment.get("stat_modifiers").apply_to_dictionary(stats)

	if weapon != null:
		_apply_weapon_affix_stats(weapon, stats)

	return stats

func _apply_weapon_affix_stats(weapon: Resource, stats: Dictionary) -> void:
	for affix in weapon.get("affixes"):
		if affix is Resource and affix.get("stat_modifiers") != null:
			affix.get("stat_modifiers").apply_to_dictionary(stats)
