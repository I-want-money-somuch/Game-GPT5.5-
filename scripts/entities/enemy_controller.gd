class_name EnemyController
extends CharacterBody2D

const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")
const CombatResolverScript := preload("res://scripts/combat/combat_resolver.gd")
const BossAttackEffectScript := preload("res://scripts/boss/boss_attack_effect.gd")
const BossProjectileScript := preload("res://scripts/boss/boss_projectile.gd")

const NORMAL_STATE_IDLE := &"idle"
const NORMAL_STATE_CHASE := &"chase"
const NORMAL_STATE_WINDUP := &"windup"
const NORMAL_STATE_ATTACK := &"attack"
const NORMAL_STATE_RECOVER := &"recover"
const NORMAL_STATE_STAGGER := &"stagger"
const NORMAL_STATE_DEAD := &"dead"

signal died(enemy: Node, definition: Resource)

@export var definition: Resource

var target: Node2D
var health := 20.0
var max_health := 20.0
var move_speed := 80.0
var attack_cooldown := 0.0
var knockback_velocity := Vector2.ZERO
var is_dead := false
var elite_affixes: Array[Resource] = []
var elite_triggered_affixes := {}
var elite_is_phasing := false
var elite_phase_timer := 0.0
var elite_phase_recovery_timer := 0.0
var status_effects := {}
var behavior_profile: Resource
var normal_state: StringName = NORMAL_STATE_IDLE
var normal_state_timer := 0.0
var normal_attack_cooldown := 0.0
var normal_attack_direction := Vector2.RIGHT
var normal_dash_velocity := Vector2.ZERO
var normal_dash_timer := 0.0
var normal_attack_effect: Node
var visited_normal_states := {}
var boss_skill_profile: Resource
var boss_mechanic_profile: Resource
var boss_skill_timers: Array[float] = []
var boss_casting := false
var phase_two_active := false
var invulnerable_timer := 0.0
var damage_reduction_override := 0.0
var rng := RandomNumberGenerator.new()

@onready var armor_component: Node = $ArmorComponent
@onready var body_shape: Polygon2D = $BodyShape

func _ready() -> void:
	rng.randomize()
	add_to_group("enemies")
	_apply_definition()

func _physics_process(delta: float) -> void:
	if is_dead or definition == null or target == null:
		return

	_tick_status_effects(delta)
	_tick_boss_mechanics(delta)
	if _is_boss_unit():
		_process_boss(delta)
		return

	_tick_elite_affixes(delta)
	_process_normal_ai(delta)

func _process_normal_ai(delta: float) -> void:
	if behavior_profile == null:
		_process_legacy_normal_ai(delta)
		return

	normal_attack_cooldown = maxf(normal_attack_cooldown - delta, 0.0)
	normal_state_timer = maxf(normal_state_timer - delta, 0.0)
	normal_dash_timer = maxf(normal_dash_timer - delta, 0.0)

	match normal_state:
		NORMAL_STATE_IDLE:
			_process_normal_idle()
		NORMAL_STATE_CHASE:
			_process_normal_chase()
		NORMAL_STATE_WINDUP:
			_process_normal_windup()
		NORMAL_STATE_ATTACK:
			_process_normal_attack()
		NORMAL_STATE_RECOVER:
			_process_normal_recover()
		NORMAL_STATE_STAGGER:
			_process_normal_stagger()
		NORMAL_STATE_DEAD:
			velocity = Vector2.ZERO
		_:
			_enter_normal_state(NORMAL_STATE_IDLE)

	velocity += knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 860.0 * delta)

func _process_legacy_normal_ai(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	var to_target := target.global_position - global_position
	if to_target.length() > definition.aggro_range:
		velocity = Vector2.ZERO
	elif to_target.length() > definition.attack_range:
		velocity = to_target.normalized() * move_speed * _status_move_speed_multiplier()
	else:
		velocity = Vector2.ZERO
		_try_attack()

	velocity += knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 860.0 * delta)

func _process_normal_idle() -> void:
	velocity = Vector2.ZERO
	if _distance_to_target() <= _behavior_float("chase_range", definition.aggro_range):
		_enter_normal_state(NORMAL_STATE_CHASE)

func _process_normal_chase() -> void:
	var distance := _distance_to_target()
	if distance > _behavior_float("chase_range", definition.aggro_range):
		_enter_normal_state(NORMAL_STATE_IDLE)
		velocity = Vector2.ZERO
		return
	if distance <= _behavior_float("attack_range", definition.attack_range) and normal_attack_cooldown <= 0.0:
		_start_normal_windup()
		return

	velocity = _normal_chase_velocity(distance)

func _process_normal_windup() -> void:
	velocity = normal_attack_direction * move_speed * _behavior_float("windup_move_multiplier", 0.0) * _status_move_speed_multiplier()
	if normal_state_timer <= 0.0:
		_start_normal_attack()

func _process_normal_attack() -> void:
	velocity = normal_dash_velocity if normal_dash_timer > 0.0 else Vector2.ZERO
	if normal_state_timer <= 0.0:
		normal_dash_velocity = Vector2.ZERO
		normal_attack_cooldown = _behavior_float("attack_cooldown", definition.attack_interval)
		_enter_normal_state(NORMAL_STATE_RECOVER)

func _process_normal_recover() -> void:
	velocity = Vector2.ZERO
	if normal_state_timer <= 0.0:
		_enter_normal_state(NORMAL_STATE_CHASE if _distance_to_target() <= _behavior_float("chase_range", definition.aggro_range) else NORMAL_STATE_IDLE)

func _process_normal_stagger() -> void:
	velocity = Vector2.ZERO
	if normal_state_timer <= 0.0:
		_enter_normal_state(NORMAL_STATE_CHASE if _distance_to_target() <= _behavior_float("chase_range", definition.aggro_range) else NORMAL_STATE_IDLE)

func _apply_definition() -> void:
	if definition == null:
		return

	var stats := {}
	if definition.base_stats != null:
		stats = definition.base_stats.to_dictionary()
	stats = _apply_elite_stat_modifiers(stats)
	max_health = maxf(float(stats.get("max_health", 20.0)), 1.0)
	health = max_health
	move_speed = maxf(float(stats.get("move_speed", 80.0)), 1.0)
	armor_component.configure(stats)
	_refresh_elite_visuals()
	behavior_profile = definition.get("behavior_profile")
	if _is_boss_unit():
		visited_normal_states.clear()
	else:
		_initialize_normal_behavior()
	boss_skill_profile = definition.get("boss_skill_profile")
	boss_mechanic_profile = definition.get("boss_mechanic_profile")
	_initialize_boss_skills()
	_initialize_elite_affixes()

func configure_elite_affixes(affixes: Array) -> void:
	elite_affixes.clear()
	for affix in affixes:
		if affix != null:
			elite_affixes.append(affix)
	if is_inside_tree() and definition != null:
		_apply_definition()

func is_elite_enemy() -> bool:
	return not elite_affixes.is_empty()

func get_elite_affix_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for affix in elite_affixes:
		if affix != null:
			ids.append(affix.get("id"))
	return ids

func has_elite_affix(affix_id: StringName) -> bool:
	return get_elite_affix_ids().has(affix_id)

func has_triggered_elite_affix(affix_id: StringName) -> bool:
	return elite_triggered_affixes.has(affix_id)

func is_elite_phasing() -> bool:
	return elite_is_phasing

func force_elite_phasing_for_test() -> void:
	if has_elite_affix(&"phasing"):
		_start_elite_phasing()

func clear_elite_phasing_for_test() -> void:
	_end_elite_phasing()
	elite_phase_timer = _elite_max_float("phasing_interval", 0.0)
	elite_phase_recovery_timer = 0.0

func notify_damage_dealt(packet: RefCounted, damaged_target: Node) -> void:
	if is_dead or not is_elite_enemy() or damaged_target == null or not damaged_target.is_in_group("players"):
		return
	var heal_ratio := _elite_max_float("vampiric_heal_ratio", 0.0)
	if heal_ratio <= 0.0:
		return
	health = minf(health + maxf(packet.amount, 0.0) * heal_ratio, max_health)
	_mark_elite_affix_triggered(&"vampiric")

func apply_status_effect(effect_id: StringName, config: Dictionary) -> void:
	if is_dead or effect_id == &"":
		return
	status_effects[effect_id] = {
		"duration": maxf(float(config.get("duration", 0.0)), 0.0),
		"move_speed_multiplier": maxf(float(config.get("move_speed_multiplier", 1.0)), 0.0),
	}
	_apply_status_visuals()

func has_status_effect(effect_id: StringName) -> bool:
	return status_effects.has(effect_id)

func get_status_remaining(effect_id: StringName) -> float:
	if not status_effects.has(effect_id):
		return 0.0
	return float(status_effects[effect_id].get("duration", 0.0))

func status_move_speed_multiplier_for_test() -> float:
	return _status_move_speed_multiplier()

func _initialize_normal_behavior() -> void:
	normal_state = NORMAL_STATE_IDLE
	normal_state_timer = 0.0
	normal_attack_cooldown = 0.0
	normal_attack_direction = Vector2.RIGHT
	normal_dash_velocity = Vector2.ZERO
	normal_dash_timer = 0.0
	visited_normal_states.clear()
	_mark_normal_state(NORMAL_STATE_IDLE)
	if behavior_profile != null:
		normal_attack_cooldown = rng.randf_range(0.0, _behavior_float("attack_cooldown", definition.attack_interval) * 0.35)

func get_normal_state_name() -> StringName:
	return &"boss" if _is_boss_unit() else normal_state

func has_visited_normal_state(state_name: StringName) -> bool:
	return visited_normal_states.has(state_name)

func force_normal_state_for_test(state_name: StringName) -> void:
	if _is_boss_unit() or behavior_profile == null:
		return
	if state_name == NORMAL_STATE_WINDUP:
		_start_normal_windup()
	elif state_name == NORMAL_STATE_ATTACK:
		_start_normal_attack()
	elif state_name == NORMAL_STATE_STAGGER:
		_enter_normal_state(NORMAL_STATE_STAGGER, _behavior_float("stagger_duration", 0.18))
	elif state_name == NORMAL_STATE_RECOVER:
		_enter_normal_state(NORMAL_STATE_RECOVER, _behavior_float("recover_duration", 0.35))
	elif state_name == NORMAL_STATE_DEAD:
		_enter_normal_state(NORMAL_STATE_DEAD)
	elif state_name == NORMAL_STATE_CHASE:
		_enter_normal_state(NORMAL_STATE_CHASE)
	else:
		_enter_normal_state(NORMAL_STATE_IDLE)

func _enter_normal_state(state_name: StringName, duration := -1.0) -> void:
	if _is_boss_unit():
		return
	normal_state = state_name
	_mark_normal_state(state_name)
	match state_name:
		NORMAL_STATE_WINDUP:
			normal_state_timer = duration if duration >= 0.0 else _behavior_float("windup_duration", 0.25)
		NORMAL_STATE_ATTACK:
			normal_state_timer = duration if duration >= 0.0 else _behavior_float("attack_duration", 0.1)
		NORMAL_STATE_RECOVER:
			normal_state_timer = duration if duration >= 0.0 else _behavior_float("recover_duration", 0.35)
			normal_dash_velocity = Vector2.ZERO
			normal_dash_timer = 0.0
		NORMAL_STATE_STAGGER:
			normal_state_timer = duration if duration >= 0.0 else _behavior_float("stagger_duration", 0.18)
			normal_dash_velocity = Vector2.ZERO
			normal_dash_timer = 0.0
			_cancel_normal_attack_effect()
		NORMAL_STATE_DEAD:
			normal_state_timer = 0.0
			normal_dash_velocity = Vector2.ZERO
			normal_dash_timer = 0.0
			_cancel_normal_attack_effect()
		_:
			normal_state_timer = 0.0
			normal_dash_velocity = Vector2.ZERO
			normal_dash_timer = 0.0

func _mark_normal_state(state_name: StringName) -> void:
	visited_normal_states[state_name] = true

func _start_normal_windup() -> void:
	normal_attack_direction = _direction_to_target()
	_spawn_normal_attack_warning(normal_attack_direction)
	_enter_normal_state(NORMAL_STATE_WINDUP, _behavior_float("windup_duration", 0.25))

func _start_normal_attack() -> void:
	_enter_normal_state(NORMAL_STATE_ATTACK, _behavior_float("attack_duration", 0.1))
	var dash_duration := _behavior_float("dash_duration", 0.0)
	var dash_distance := _behavior_float("dash_distance", 0.0)
	if dash_duration > 0.0 and dash_distance > 0.0:
		normal_dash_timer = dash_duration
		normal_dash_velocity = normal_attack_direction * (dash_distance / dash_duration) * _status_move_speed_multiplier()

func _normal_chase_velocity(distance: float) -> Vector2:
	var direction := _direction_to_target()
	var speed := move_speed * _behavior_float("move_speed_multiplier", 1.0) * _status_move_speed_multiplier()
	if _behavior_id() == &"skirmisher":
		var preferred := _behavior_float("preferred_range", _behavior_float("attack_range", definition.attack_range))
		if distance < preferred * 0.65:
			return -direction * speed
		if distance <= preferred:
			return Vector2.ZERO
	return direction * speed

func _spawn_normal_attack_warning(direction: Vector2) -> void:
	if target == null:
		return
	_cancel_normal_attack_effect()
	var effect = BossAttackEffectScript.new()
	var warning := _behavior_float("windup_duration", 0.25)
	if _behavior_is_line_attack():
		effect.global_position = global_position
		effect.configure_line({
			"source": self,
			"target": target,
			"direction": direction,
			"length": _behavior_float("attack_length", 58.0),
			"width": _behavior_float("attack_width", 36.0),
			"damage": _contact_damage(),
			"warning_duration": warning,
			"knockback_force": _behavior_float("knockback_force", 150.0),
			"color": _behavior_color("warning_color", Color(1.0, 0.35, 0.14, 0.38)),
		})
	else:
		effect.global_position = global_position
		effect.configure_circle({
			"source": self,
			"target": target,
			"radius": _behavior_float("attack_radius", 40.0),
			"damage": _contact_damage(),
			"warning_duration": warning,
			"knockback_force": _behavior_float("knockback_force", 150.0),
			"color": _behavior_color("warning_color", Color(1.0, 0.35, 0.14, 0.38)),
		})
	normal_attack_effect = effect
	_boss_effect_parent().add_child(effect)

func _cancel_normal_attack_effect() -> void:
	if normal_attack_effect != null and is_instance_valid(normal_attack_effect):
		normal_attack_effect.queue_free()
	normal_attack_effect = null

func _distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)

func _behavior_id() -> StringName:
	if behavior_profile == null:
		return &""
	return behavior_profile.get("behavior_id")

func _behavior_float(property_name: String, fallback: float) -> float:
	if behavior_profile == null:
		return fallback
	var value = behavior_profile.get(property_name)
	if value == null:
		return fallback
	return float(value) * _elite_behavior_multiplier(property_name)

func _behavior_color(property_name: String, fallback: Color) -> Color:
	if behavior_profile == null:
		return fallback
	var value = behavior_profile.get(property_name)
	if value == null:
		return fallback
	return value

func _behavior_is_line_attack() -> bool:
	if behavior_profile == null:
		return false
	if behavior_profile.has_method("is_line_attack"):
		return behavior_profile.is_line_attack()
	return int(behavior_profile.get("attack_shape")) == 1

func _try_attack() -> void:
	if attack_cooldown > 0.0 or target == null or not target.has_method("take_damage"):
		return

	var packet = DamagePacketScript.new()
	packet.amount = _contact_damage()
	packet.source = self
	packet.element = &"physical"
	packet.hit_direction = (target.global_position - global_position).normalized()
	packet.hit_position = target.global_position
	packet.knockback_force = 150.0
	target.take_damage(packet)
	notify_damage_dealt(packet, target)
	attack_cooldown = definition.attack_interval

func _initialize_boss_skills() -> void:
	boss_skill_timers.clear()
	if boss_skill_profile == null or not boss_skill_profile.has_method("get_skill_count"):
		return
	for index in range(boss_skill_profile.get_skill_count()):
		boss_skill_timers.append(rng.randf_range(0.6, 1.6 + index * 0.2))

func _is_boss_unit() -> bool:
	return definition != null and definition.has_method("is_boss") and definition.is_boss()

func _tick_boss_mechanics(delta: float) -> void:
	invulnerable_timer = maxf(invulnerable_timer - delta, 0.0)
	if invulnerable_timer <= 0.0 and damage_reduction_override >= 1.0:
		damage_reduction_override = 0.0

func _process_boss(delta: float) -> void:
	for index in range(boss_skill_timers.size()):
		boss_skill_timers[index] = maxf(float(boss_skill_timers[index]) - delta, 0.0)

	if invulnerable_timer > 0.0 and damage_reduction_override >= 1.0:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 860.0 * delta)
		return

	if not boss_casting:
		_try_boss_skill()

	var preferred_distance := 120.0 if definition.id == &"cinder_bulwark" else 210.0
	var to_target := target.global_position - global_position
	if boss_casting:
		velocity = knockback_velocity
	elif to_target.length() > preferred_distance:
		velocity = to_target.normalized() * move_speed * _status_move_speed_multiplier()
	elif to_target.length() < preferred_distance * 0.55:
		velocity = -to_target.normalized() * move_speed * 0.45 * _status_move_speed_multiplier()
	else:
		velocity = Vector2.ZERO

	velocity += knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 860.0 * delta)

func _try_boss_skill() -> void:
	if boss_skill_profile == null or boss_skill_timers.is_empty():
		_try_attack()
		return

	var candidates: Array[int] = []
	var total_weight := 0.0
	for index in range(boss_skill_timers.size()):
		if float(boss_skill_timers[index]) > 0.0:
			continue
		candidates.append(index)
		total_weight += boss_skill_profile.get_weight(index)

	if candidates.is_empty():
		return

	var pick := rng.randf_range(0.0, maxf(total_weight, 0.01))
	var cursor := 0.0
	var chosen := candidates[0]
	for index in candidates:
		cursor += boss_skill_profile.get_weight(index)
		if pick <= cursor:
			chosen = index
			break

	var skill_id: StringName = boss_skill_profile.get_skill_id(chosen)
	if cast_boss_skill(skill_id):
		boss_skill_timers[chosen] = boss_skill_profile.get_cooldown(chosen, phase_two_active)

func cast_boss_skill(skill_id: StringName) -> bool:
	if not _is_boss_unit() or boss_casting or skill_id == &"":
		return false
	boss_casting = true
	var duration := _run_boss_skill(skill_id)
	_after(duration, func() -> void:
		boss_casting = false
	)
	return true

func _run_boss_skill(skill_id: StringName) -> float:
	match skill_id:
		&"ember_charge":
			return _skill_ember_charge()
		&"molten_guard":
			return _skill_molten_guard()
		&"cinder_shard_burst":
			return _skill_cinder_shard_burst()
		&"void_lance":
			return _skill_void_lance()
		&"gravity_ring":
			return _skill_gravity_ring()
		&"rift_fan":
			return _skill_rift_fan()
		_:
			return 0.2

func _skill_ember_charge() -> float:
	var direction := _direction_to_target()
	_spawn_line_warning(direction, 230.0, 50.0, 26.0 * _boss_power(), 0.58, Color(1.0, 0.28, 0.08, 0.42), 280.0)
	_after(0.58, func() -> void:
		var tween := create_tween()
		tween.tween_property(self, "global_position", global_position + direction * 135.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	return 0.82

func _skill_molten_guard() -> float:
	var duration := float(boss_mechanic_profile.parameter(&"golden_body_duration", 1.25)) if boss_mechanic_profile != null else 1.25
	damage_reduction_override = 0.85
	body_shape.modulate = Color(1.0, 0.72, 0.28)
	_after(duration, func() -> void:
		damage_reduction_override = 0.0
		body_shape.modulate = Color.WHITE
		_spawn_circle_warning(global_position, 72.0, 20.0 * _boss_power(), 0.22, Color(1.0, 0.34, 0.08, 0.45), 210.0)
	)
	return duration + 0.32

func _skill_cinder_shard_burst() -> float:
	_after(0.38, func() -> void:
		var count := 12 if phase_two_active else 8
		for index in range(count):
			var direction := Vector2.RIGHT.rotated(float(index) / float(count) * TAU)
			_spawn_boss_projectile(direction, 340.0, 14.0 * _boss_power(), Color(1.0, 0.44, 0.12), 1.35)
	)
	return 0.55

func _skill_void_lance() -> float:
	var direction := _direction_to_target()
	_spawn_line_warning(direction, 300.0, 34.0, 28.0 * _boss_power(), 0.5, Color(0.52, 0.2, 1.0, 0.42), 190.0)
	_after(0.5, func() -> void:
		_spawn_boss_projectile(direction, 520.0, 20.0 * _boss_power(), Color(0.55, 0.22, 1.0), 1.35, 2)
	)
	return 0.68

func _skill_gravity_ring() -> float:
	var center := target.global_position if target != null else global_position + Vector2.RIGHT * 100.0
	_spawn_circle_warning(center, 86.0, 22.0 * _boss_power(), 0.78, Color(0.45, 0.2, 0.95, 0.4), 230.0, true)
	return 0.9

func _skill_rift_fan() -> float:
	_after(0.36, func() -> void:
		var base_direction := _direction_to_target()
		var count := 7 if phase_two_active else 5
		var spread := deg_to_rad(64.0 if phase_two_active else 48.0)
		for index in range(count):
			var t := 0.0 if count <= 1 else float(index) / float(count - 1)
			var angle := lerpf(-spread * 0.5, spread * 0.5, t)
			_spawn_boss_projectile(base_direction.rotated(angle), 430.0, 16.0 * _boss_power(), Color(0.36, 0.82, 1.0), 1.25)
	)
	return 0.55

func trigger_phase_two() -> bool:
	if phase_two_active or boss_mechanic_profile == null:
		return false
	phase_two_active = true
	invulnerable_timer = maxf(float(boss_mechanic_profile.get("phase_transition_invulnerable_duration")), 0.0)
	damage_reduction_override = clampf(float(boss_mechanic_profile.get("phase_transition_damage_reduction")), 0.0, 1.0)
	boss_casting = false
	body_shape.scale = Vector2(1.25, 1.25)
	body_shape.modulate = definition.color.lightened(0.35)
	_feedback_call("boss_phase_transition", global_position, definition.color.lightened(0.2))
	var tween := body_shape.create_tween()
	tween.tween_property(body_shape, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body_shape, "modulate", Color.WHITE, 0.35)
	return true

func force_phase_two_for_test() -> bool:
	return trigger_phase_two()

func _maybe_trigger_phase_two() -> void:
	if phase_two_active or boss_mechanic_profile == null:
		return
	var threshold := clampf(float(boss_mechanic_profile.get("phase_two_threshold")), 0.05, 0.95)
	if health / maxf(max_health, 1.0) <= threshold:
		trigger_phase_two()

func _boss_power() -> float:
	if boss_skill_profile != null and boss_skill_profile.has_method("get_power_multiplier"):
		return boss_skill_profile.get_power_multiplier(phase_two_active)
	return 1.0

func _direction_to_target() -> Vector2:
	if target == null or global_position.distance_squared_to(target.global_position) <= 1.0:
		return Vector2.RIGHT
	return (target.global_position - global_position).normalized()

func _spawn_line_warning(direction: Vector2, length: float, width: float, damage: float, warning: float, warning_color: Color, knockback: float) -> void:
	var effect = BossAttackEffectScript.new()
	effect.global_position = global_position
	effect.configure_line({
		"source": self,
		"target": target,
		"direction": direction,
		"length": length,
		"width": width,
		"damage": damage,
		"warning_duration": warning,
		"knockback_force": knockback,
		"color": warning_color,
	})
	_boss_effect_parent().add_child(effect)

func _spawn_circle_warning(center: Vector2, radius: float, damage: float, warning: float, warning_color: Color, knockback: float, pull := false) -> void:
	var effect = BossAttackEffectScript.new()
	effect.global_position = center
	effect.configure_circle({
		"source": self,
		"target": target,
		"radius": radius,
		"damage": damage,
		"warning_duration": warning,
		"knockback_force": knockback,
		"pull_to_center": pull,
		"color": warning_color,
	})
	_boss_effect_parent().add_child(effect)

func _spawn_boss_projectile(direction: Vector2, speed: float, damage: float, projectile_color: Color, lifetime: float, pierce := 0) -> void:
	var projectile = BossProjectileScript.new()
	projectile.global_position = global_position + direction.normalized() * 24.0
	projectile.configure({
		"source": self,
		"direction": direction,
		"speed": speed,
		"damage": damage,
		"knockback_force": 145.0,
		"lifetime": lifetime,
		"color": projectile_color,
		"pierce": pierce,
	})
	_boss_effect_parent().add_child(projectile)

func _boss_effect_parent() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	return get_parent() if get_parent() != null else get_tree().root

func _after(delay: float, callback: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(delay, 0.01)
	timer.timeout.connect(callback)
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start()

func take_damage(packet: RefCounted) -> void:
	if is_dead:
		return

	if elite_is_phasing and not _is_boss_unit():
		_feedback_call("enemy_hit", packet.hit_position if packet.hit_position != Vector2.ZERO else global_position, {"final_damage": 0.0, "critical": false})
		_mark_elite_affix_triggered(&"phasing")
		return

	if invulnerable_timer > 0.0 and damage_reduction_override >= 1.0:
		_play_hit_feedback(packet, {"final_damage": 0.0, "critical": false})
		return

	var result: Dictionary = CombatResolverScript.resolve(packet, armor_component, rng)
	var final_damage: float = float(result["final_damage"]) * (1.0 - clampf(damage_reduction_override, 0.0, 0.95))
	if elite_phase_recovery_timer > 0.0:
		final_damage *= _elite_max_float("phasing_recovery_damage_taken_multiplier", 1.0)
	result["final_damage"] = final_damage
	health -= final_damage
	_apply_knockback(packet)
	_play_hit_feedback(packet, result)
	_maybe_trigger_phase_two()
	if health <= 0.0:
		is_dead = true
		if not _is_boss_unit():
			_enter_normal_state(NORMAL_STATE_DEAD)
			_trigger_elite_death_effects()
		_play_death_feedback()
		died.emit(self, definition)
		queue_free()
	elif final_damage > 0.0 and not _is_boss_unit() and behavior_profile != null:
		_enter_normal_state(NORMAL_STATE_STAGGER, _behavior_float("stagger_duration", 0.18))

func _apply_knockback(packet: RefCounted) -> void:
	if packet.hit_direction.length_squared() <= 0.01:
		return
	knockback_velocity += packet.hit_direction.normalized() * maxf(packet.knockback_force, 0.0)

func _play_hit_feedback(packet: RefCounted, result: Dictionary) -> void:
	body_shape.modulate = Color(1.7, 1.7, 1.7)
	body_shape.scale = Vector2(1.18, 0.86)
	var tween := body_shape.create_tween()
	tween.tween_property(body_shape, "modulate", Color.WHITE, 0.09)
	tween.parallel().tween_property(body_shape, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_call("enemy_hit", packet.hit_position if packet.hit_position != Vector2.ZERO else global_position, result)

func _play_death_feedback() -> void:
	_feedback_call("enemy_died", global_position, body_shape.color)

func _tick_status_effects(delta: float) -> void:
	if status_effects.is_empty():
		return
	var expired: Array[StringName] = []
	for effect_id in status_effects.keys():
		var data: Dictionary = status_effects[effect_id]
		data["duration"] = maxf(float(data.get("duration", 0.0)) - delta, 0.0)
		status_effects[effect_id] = data
		if float(data["duration"]) <= 0.0:
			expired.append(effect_id)
	for effect_id in expired:
		status_effects.erase(effect_id)
	if expired.is_empty():
		_apply_status_visuals()
	else:
		_refresh_elite_visuals()

func _status_move_speed_multiplier() -> float:
	var multiplier := 1.0
	for data in status_effects.values():
		multiplier *= float(data.get("move_speed_multiplier", 1.0))
	return multiplier

func _apply_status_visuals() -> void:
	if status_effects.has(&"frostbite") and body_shape != null:
		body_shape.modulate = Color(0.62, 0.88, 1.35, 1.0)

func _apply_elite_stat_modifiers(stats: Dictionary) -> Dictionary:
	if elite_affixes.is_empty():
		return stats
	var result := stats.duplicate(true)
	for affix in elite_affixes:
		if affix == null:
			continue
		result["max_health"] = float(result.get("max_health", 20.0)) * float(affix.get("max_health_multiplier"))
		result["move_speed"] = float(result.get("move_speed", 80.0)) * float(affix.get("move_speed_multiplier"))
		result["armor"] = float(result.get("armor", 0.0)) * float(affix.get("armor_multiplier")) + float(affix.get("armor_bonus"))
		result["armor_durability"] = float(result.get("armor_durability", 0.0)) * float(affix.get("armor_durability_multiplier"))
		result["armor_damage_reduction"] = float(result.get("armor_damage_reduction", 0.0)) + float(affix.get("armor_damage_reduction_bonus"))
		_mark_elite_affix_triggered(affix.get("id"))
	return result

func _initialize_elite_affixes() -> void:
	elite_is_phasing = false
	elite_phase_recovery_timer = 0.0
	elite_phase_timer = _elite_max_float("phasing_interval", 0.0)
	if is_elite_enemy():
		add_to_group("elite_enemies")
	else:
		remove_from_group("elite_enemies")

func _tick_elite_affixes(delta: float) -> void:
	if not is_elite_enemy():
		return
	if elite_phase_recovery_timer > 0.0:
		elite_phase_recovery_timer = maxf(elite_phase_recovery_timer - delta, 0.0)
		if elite_phase_recovery_timer <= 0.0:
			_refresh_elite_visuals()
	if elite_is_phasing:
		elite_phase_timer = maxf(elite_phase_timer - delta, 0.0)
		if elite_phase_timer <= 0.0:
			_end_elite_phasing()
		return

	var interval := _elite_max_float("phasing_interval", 0.0)
	if interval <= 0.0:
		return
	elite_phase_timer -= delta
	if elite_phase_timer <= 0.0:
		_start_elite_phasing()

func _start_elite_phasing() -> void:
	if elite_is_phasing:
		return
	var duration := _elite_max_float("phasing_duration", 0.0)
	if duration <= 0.0:
		return
	elite_is_phasing = true
	elite_phase_timer = duration
	_mark_elite_affix_triggered(&"phasing")
	body_shape.modulate = Color(0.72, 0.58, 1.0, 0.42)
	body_shape.scale = Vector2(1.16, 0.86)

func _end_elite_phasing() -> void:
	if not elite_is_phasing:
		return
	elite_is_phasing = false
	elite_phase_timer = _elite_max_float("phasing_interval", 0.0)
	elite_phase_recovery_timer = _elite_max_float("phasing_recovery_duration", 0.0)
	body_shape.modulate = Color(1.18, 0.84, 1.25, 1.0)
	var tween := body_shape.create_tween()
	tween.tween_property(body_shape, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _trigger_elite_death_effects() -> void:
	if not is_elite_enemy() or target == null:
		return
	for affix in elite_affixes:
		if affix == null:
			continue
		var radius := float(affix.get("death_explosion_radius"))
		var damage := float(affix.get("death_explosion_damage"))
		if radius <= 0.0 or damage <= 0.0:
			continue
		var effect = BossAttackEffectScript.new()
		effect.global_position = global_position
		effect.configure_circle({
			"source": self,
			"target": target,
			"radius": radius,
			"damage": damage,
			"warning_duration": float(affix.get("death_explosion_warning")),
			"knockback_force": float(affix.get("death_explosion_knockback")),
			"color": affix.get("death_explosion_color"),
		})
		_boss_effect_parent().add_child(effect)
		_mark_elite_affix_triggered(affix.get("id"))

func _refresh_elite_visuals() -> void:
	if body_shape == null or definition == null:
		return
	if elite_affixes.is_empty():
		body_shape.color = definition.color
		body_shape.scale = Vector2.ONE
		body_shape.modulate = Color.WHITE
		return
	body_shape.color = definition.color.lerp(_elite_marker_color(), 0.42)
	body_shape.scale = Vector2(1.12, 1.12)
	body_shape.modulate = Color.WHITE

func _elite_marker_color() -> Color:
	var result := Color(1.0, 0.55, 0.18, 1.0)
	var count := 0
	for affix in elite_affixes:
		if affix == null:
			continue
		result = result.lerp(affix.get("marker_color"), 1.0 / float(count + 1))
		count += 1
	return result

func _contact_damage() -> float:
	var multiplier := 1.0
	for affix in elite_affixes:
		if affix != null:
			multiplier *= float(affix.get("contact_damage_multiplier"))
	return definition.contact_damage * multiplier

func _elite_behavior_multiplier(property_name: String) -> float:
	var multiplier := 1.0
	for affix in elite_affixes:
		if affix == null:
			continue
		match property_name:
			"windup_duration":
				multiplier *= float(affix.get("windup_duration_multiplier"))
			"attack_cooldown":
				multiplier *= float(affix.get("attack_cooldown_multiplier"))
			"stagger_duration":
				multiplier *= float(affix.get("stagger_duration_multiplier"))
	return multiplier

func _elite_max_float(property_name: String, fallback: float) -> float:
	var result := fallback
	for affix in elite_affixes:
		if affix == null:
			continue
		result = maxf(result, float(affix.get(property_name)))
	return result

func _mark_elite_affix_triggered(affix_id: StringName) -> void:
	if affix_id == &"":
		return
	elite_triggered_affixes[affix_id] = true

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
