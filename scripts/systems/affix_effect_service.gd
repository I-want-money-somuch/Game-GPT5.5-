class_name AffixEffectService
extends Node

const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")

var effect_parent: Node

func _ready() -> void:
	add_to_group("affix_effect_service")

func configure(parent: Node) -> void:
	effect_parent = parent

func process_weapon_hit(source: Node, weapon: Resource, target: Node, packet: RefCounted, rng: RandomNumberGenerator, forced_effect_id: StringName = &"") -> Array[StringName]:
	var triggered: Array[StringName] = []
	if source == null or weapon == null or target == null or packet == null:
		return triggered
	if not target.is_in_group("enemies"):
		return triggered

	for affix in weapon.get("affixes"):
		if affix == null:
			continue
		var effect_id: StringName = affix.get("effect_id")
		if effect_id == &"":
			continue
		if forced_effect_id != &"" and effect_id != forced_effect_id:
			continue
		if forced_effect_id == &"" and rng != null and rng.randf() > float(affix.get("proc_chance")):
			continue
		if _apply_effect(effect_id, source, target, packet):
			triggered.append(effect_id)
	return triggered

func force_weapon_effect(source: Node, weapon: Resource, target: Node, packet: RefCounted, effect_id: StringName) -> Array[StringName]:
	return process_weapon_hit(source, weapon, target, packet, null, effect_id)

func _apply_effect(effect_id: StringName, source: Node, target: Node, packet: RefCounted) -> bool:
	match effect_id:
		&"fire_burst":
			_spawn_fire_burst(source, packet.hit_position if packet.hit_position != Vector2.ZERO else target.global_position, packet.amount * 0.55)
			return true
		&"frostbite":
			if target.has_method("apply_status_effect"):
				target.apply_status_effect(&"frostbite", {
					"duration": 1.25,
					"move_speed_multiplier": 0.55,
				})
				return true
		&"chain_lightning":
			_trigger_chain_lightning(source, target, packet)
			return true
		&"rift_echo":
			_trigger_rift_echo(source, target, packet)
			return true
		&"gravity_well":
			_spawn_gravity_well(source, packet.hit_position if packet.hit_position != Vector2.ZERO else target.global_position, packet.amount * 0.35)
			return true
	return false

func _spawn_fire_burst(source: Node, center: Vector2, damage: float) -> void:
	var visual := Node2D.new()
	visual.global_position = center
	visual.add_to_group("affix_effects")
	_effect_parent().add_child(visual)

	var polygon := Polygon2D.new()
	polygon.color = Color(1.0, 0.28, 0.08, 0.36)
	polygon.polygon = _circle_polygon(64.0, 28)
	polygon.z_index = 20
	visual.add_child(polygon)

	var tween := polygon.create_tween()
	tween.tween_property(polygon, "modulate:a", 0.78, 0.16).from(0.18)
	var source_id := source.get_instance_id() if source != null and is_instance_valid(source) else 0
	_after_on(visual, 0.18, func() -> void:
		var resolved_source := instance_from_id(source_id) if source_id != 0 else null
		_apply_area_damage(resolved_source, center, 64.0, damage, &"fire", 120.0)
		polygon.color = Color(1.0, 0.55, 0.18, 0.5)
		var fade := polygon.create_tween()
		fade.tween_property(polygon, "modulate:a", 0.0, 0.12)
		_after_on(visual, 0.13, visual.queue_free)
	)

func _trigger_chain_lightning(source: Node, primary_target: Node, packet: RefCounted) -> void:
	var origin: Vector2 = primary_target.global_position
	var chained := 0
	var exclusions := [primary_target]
	for enemy in _nearby_enemies(origin, 150.0, exclusions):
		if chained >= 2:
			break
		_damage_enemy(source, enemy, packet.amount * 0.45, &"lightning", origin, 80.0)
		_spawn_chain_visual(origin, enemy.global_position)
		exclusions.append(enemy)
		origin = enemy.global_position
		chained += 1

func _trigger_rift_echo(source: Node, target: Node, packet: RefCounted) -> void:
	if not _is_damageable_enemy(target):
		return
	var visual := Node2D.new()
	visual.global_position = packet.hit_position if packet.hit_position != Vector2.ZERO else target.global_position
	visual.add_to_group("affix_effects")
	_effect_parent().add_child(visual)

	var ring := Polygon2D.new()
	ring.color = Color(0.56, 0.28, 1.0, 0.38)
	ring.polygon = _circle_polygon(24.0, 18)
	ring.z_index = 22
	visual.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.45, 1.45), 0.22).from(Vector2(0.45, 0.45))
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)

	var source_id: int = source.get_instance_id() if source != null and is_instance_valid(source) else 0
	var target_id: int = target.get_instance_id()
	var amount: float = float(packet.amount) * 0.4
	_after_on(visual, 0.22, func() -> void:
		var resolved_source := instance_from_id(source_id) if source_id != 0 else null
		var resolved_target := instance_from_id(target_id)
		if _is_damageable_enemy(resolved_target):
			_damage_enemy(resolved_source, resolved_target, amount, &"arcane", visual.global_position, 70.0)
		visual.queue_free()
	)

func _spawn_gravity_well(source: Node, center: Vector2, damage: float) -> void:
	var visual := Node2D.new()
	visual.global_position = center
	visual.add_to_group("affix_effects")
	_effect_parent().add_child(visual)

	var polygon := Polygon2D.new()
	polygon.color = Color(0.42, 0.18, 0.95, 0.32)
	polygon.polygon = _circle_polygon(86.0, 30)
	polygon.z_index = 20
	visual.add_child(polygon)
	var tween := polygon.create_tween()
	tween.tween_property(polygon, "scale", Vector2(1.08, 1.08), 0.2).from(Vector2(0.76, 0.76))
	tween.parallel().tween_property(polygon, "modulate:a", 0.7, 0.2)

	var source_id := source.get_instance_id() if source != null and is_instance_valid(source) else 0
	_after_on(visual, 0.2, func() -> void:
		var resolved_source := instance_from_id(source_id) if source_id != 0 else null
		_apply_gravity_damage(resolved_source, center, 86.0, damage, 3)
		polygon.color = Color(0.78, 0.58, 1.0, 0.5)
		var fade := polygon.create_tween()
		fade.tween_property(polygon, "scale", Vector2(0.3, 0.3), 0.14)
		fade.parallel().tween_property(polygon, "modulate:a", 0.0, 0.14)
		_after_on(visual, 0.15, visual.queue_free)
	)

func _spawn_chain_visual(from_position: Vector2, to_position: Vector2) -> void:
	var visual := Node2D.new()
	visual.add_to_group("affix_effects")
	_effect_parent().add_child(visual)

	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.36, 0.82, 1.0, 0.85)
	line.points = PackedVector2Array([from_position, to_position])
	line.z_index = 21
	visual.add_child(line)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.finished.connect(visual.queue_free)

func _apply_area_damage(source: Node, center: Vector2, radius: float, damage: float, element: StringName, knockback: float) -> void:
	for enemy in _nearby_enemies(center, radius, []):
		_damage_enemy(source, enemy, damage, element, center, knockback)

func _apply_gravity_damage(source: Node, center: Vector2, radius: float, damage: float, max_targets: int) -> void:
	var hit_count := 0
	for enemy in _nearby_enemies(center, radius, []):
		if hit_count >= max_targets:
			break
		var direction: Vector2 = (center - enemy.global_position).normalized()
		_damage_enemy_with_direction(source, enemy, damage, &"arcane", direction, 145.0)
		hit_count += 1

func _damage_enemy(source: Node, enemy: Node, amount: float, element: StringName, origin: Vector2, knockback: float) -> void:
	_damage_enemy_with_direction(source, enemy, amount, element, (enemy.global_position - origin).normalized(), knockback)

func _damage_enemy_with_direction(source: Node, enemy: Node, amount: float, element: StringName, hit_direction: Vector2, knockback: float) -> void:
	if not _is_damageable_enemy(enemy):
		return
	var packet = DamagePacketScript.new()
	packet.amount = amount
	packet.source = source if source != null and is_instance_valid(source) else null
	packet.element = element
	packet.hit_position = enemy.global_position
	packet.hit_direction = hit_direction
	packet.knockback_force = knockback
	enemy.take_damage(packet)

func _nearby_enemies(center: Vector2, radius: float, exclusions: Array) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if exclusions.has(enemy) or not _is_damageable_enemy(enemy):
			continue
		if enemy.global_position.distance_to(center) > radius:
			continue
		result.append(enemy)
	result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center)
	)
	return result

func _is_damageable_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.is_in_group("enemies") or not enemy.has_method("take_damage"):
		return false
	return not bool(enemy.get("is_dead"))

func _effect_parent() -> Node:
	if effect_parent != null and is_instance_valid(effect_parent):
		return effect_parent
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_tree().root

func _after_on(owner: Node, delay: float, callback: Callable) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(delay, 0.01)
	timer.timeout.connect(callback)
	timer.timeout.connect(timer.queue_free)
	owner.add_child(timer)
	timer.start()

func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := float(index) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
