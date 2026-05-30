class_name DungeonRun
extends Node

signal room_started(floor: int, room_type: String)
signal room_cleared(floor: int)
signal run_completed
signal enemy_defeated(enemy: Node, enemy_definition: Resource)
signal forge_station_activated
signal event_station_activated(event_definition: Resource, result: Dictionary)
signal route_choices_requested(next_floor: int, choices: Array)

@export var max_floor := 10

var player: Node2D
var enemy_scene: PackedScene
var reward_chest_scene: PackedScene
var forge_station_scene: PackedScene
var event_station_scene: PackedScene
var enemy_parent: Node
var pickup_parent: Node
var interactable_parent: Node
var loot_service: Node
var event_service: Node
var normal_enemy_definitions: Array = []
var elite_affix_pool: Array = []
var mini_boss_definition: Resource
var boss_definition: Resource
var event_definitions: Array = []
var spawn_points: Array = []
var reward_points: Array = []
var player_start: Marker2D
var exit_point: Marker2D
var exit_portal: Node
var room_sequence: Array = []
var projected_room_sequence: Array = []
var chosen_room_sequence: Array = []
var pending_room_choices: Array = []
var early_route_remaining: Array = []
var late_route_remaining: Array = []
var room_pool: Array = []
var current_room_definition: Resource
var current_floor := 1
var current_run_seed := 0
var live_enemies: Array = []
var exit_unlocked := false
var room_rewarded := false
var reward_chest_spawned := false
var room_cleared_emitted := false
var current_reward_source_definition: Resource
var event_trial_active := false
var event_trial_reward_attempts := 0
var forced_event_definition_for_test: Resource
var run_active := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func configure(config: Dictionary) -> void:
	player = config.get("player")
	enemy_scene = config.get("enemy_scene")
	reward_chest_scene = config.get("reward_chest_scene")
	forge_station_scene = config.get("forge_station_scene")
	event_station_scene = config.get("event_station_scene")
	enemy_parent = config.get("enemy_parent")
	pickup_parent = config.get("pickup_parent")
	interactable_parent = config.get("interactable_parent")
	loot_service = config.get("loot_service")
	event_service = config.get("event_service")
	normal_enemy_definitions = config.get("normal_enemy_definitions", [])
	elite_affix_pool = config.get("elite_affix_pool", [])
	mini_boss_definition = config.get("mini_boss_definition")
	boss_definition = config.get("boss_definition")
	event_definitions = config.get("event_definitions", [])
	spawn_points = config.get("spawn_points", [])
	reward_points = config.get("reward_points", [])
	player_start = config.get("player_start")
	exit_point = config.get("exit_point")
	exit_portal = config.get("exit_portal")
	room_pool = config.get("room_sequence", [])
	room_sequence = room_pool.duplicate()

	if exit_portal != null and exit_portal.has_signal("activated"):
		var exit_callable := Callable(self, "_on_exit_portal_activated")
		if not exit_portal.activated.is_connected(exit_callable):
			exit_portal.activated.connect(exit_callable)

func start_run(seed_value := 0) -> void:
	run_active = true
	current_floor = 1
	current_run_seed = _normalize_seed(seed_value)
	rng.seed = current_run_seed
	_setup_route_state()
	max_floor = projected_room_sequence.size()
	_start_current_room()

func advance_to_next_room() -> void:
	if not run_active or not exit_unlocked or current_floor >= max_floor:
		return
	_ensure_pending_room_choices()
	if pending_room_choices.is_empty():
		return
	choose_route_choice(0)

func choose_route_choice(choice_index: int) -> bool:
	if not run_active or not exit_unlocked or current_floor >= max_floor:
		return false
	_ensure_pending_room_choices()
	if pending_room_choices.is_empty():
		return false

	var index := clampi(choice_index, 0, pending_room_choices.size() - 1)
	var chosen: Resource = pending_room_choices[index]
	if chosen == null:
		return false

	_commit_route_choice(chosen)
	current_floor += 1
	pending_room_choices.clear()
	_start_current_room()
	return true

func end_run() -> void:
	run_active = false
	exit_unlocked = false
	event_trial_active = false
	event_trial_reward_attempts = 0
	pending_room_choices.clear()
	_set_exit(false)
	_clear_room_state()

func _start_current_room() -> void:
	if not run_active or enemy_scene == null or enemy_parent == null:
		return

	_clear_room_state()
	_move_player_to_start()

	current_room_definition = _room_definition_for_floor(current_floor)
	exit_unlocked = false
	room_rewarded = false
	reward_chest_spawned = false
	room_cleared_emitted = false
	current_reward_source_definition = null
	event_trial_active = false
	event_trial_reward_attempts = 0
	_set_exit(false)

	var room_type: String = current_room_definition.room_type_name() if current_room_definition != null else "combat"
	room_started.emit(current_floor, room_type)
	_spawn_forge_station_if_needed()
	_spawn_event_station_if_needed()
	if _should_unlock_exit_on_room_start():
		_unlock_exit()

	var spawn_plans := _spawn_plans_for_current_room()
	if spawn_plans.is_empty():
		_complete_room()
		return

	for index in range(spawn_plans.size()):
		var spawn_position := _spawn_position(index)
		_spawn_enemy(spawn_plans[index].get("definition"), spawn_position, spawn_plans[index].get("affixes", []))

func _room_definition_for_floor(floor: int) -> Resource:
	if floor > 0 and floor <= chosen_room_sequence.size():
		return chosen_room_sequence[floor - 1]
	if not projected_room_sequence.is_empty():
		return projected_room_sequence[clampi(floor - 1, 0, projected_room_sequence.size() - 1)]
	if not room_sequence.is_empty():
		return room_sequence[clampi(floor - 1, 0, room_sequence.size() - 1)]
	return null

func _setup_route_state() -> void:
	var combat := _room_definition_for_id(&"combat_room")
	early_route_remaining = _rooms_for_ids([&"combat_room", &"treasure_room", &"elite_room"])
	late_route_remaining = _rooms_for_ids([&"forge_room", &"event_room", &"elite_room", &"treasure_room"])
	chosen_room_sequence.clear()
	pending_room_choices.clear()
	if combat != null:
		chosen_room_sequence.append(combat)
	projected_room_sequence = _generate_projected_room_sequence()
	room_sequence = projected_room_sequence.duplicate()

func _generate_projected_room_sequence() -> Array:
	var combat := _room_definition_for_id(&"combat_room")
	var history := []
	if combat != null:
		history.append(combat)
	var early_remaining := _rooms_for_ids([&"combat_room", &"treasure_room", &"elite_room"])
	var late_remaining := _rooms_for_ids([&"forge_room", &"event_room", &"elite_room", &"treasure_room"])
	for next_floor in range(2, 11):
		var choices := _route_choices_for_state(next_floor, history, early_remaining, late_remaining)
		if choices.is_empty():
			continue
		var chosen: Resource = choices[0]
		history.append(chosen)
		if next_floor >= 2 and next_floor <= 4:
			_remove_room_from_route_pool(chosen, early_remaining)
		elif next_floor >= 6 and next_floor <= 9:
			_remove_room_from_route_pool(chosen, late_remaining)
	return history

func _generate_room_sequence() -> Array:
	var combat := _room_definition_for_id(&"combat_room")
	var treasure := _room_definition_for_id(&"treasure_room")
	var elite := _room_definition_for_id(&"elite_room")
	var mini_boss := _room_definition_for_id(&"mini_boss_room")
	var forge := _room_definition_for_id(&"forge_room")
	var event := _room_definition_for_id(&"event_room")
	var boss := _room_definition_for_id(&"boss_room")
	var generated := []
	generated.append(combat)
	generated.append_array(_shuffled_rooms([combat, treasure, elite]))
	generated.append(mini_boss)
	generated.append_array(_shuffled_rooms([forge, event, elite, treasure]))
	generated.append(boss)
	return generated.filter(func(room) -> bool: return room != null)

func _shuffled_rooms(rooms: Array) -> Array:
	var result := rooms.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temp
	return result

func _rooms_for_ids(ids: Array) -> Array:
	var rooms := []
	for room_id in ids:
		var definition := _room_definition_for_id(room_id)
		if definition != null:
			rooms.append(definition)
	return rooms

func _room_definition_for_id(room_id: StringName) -> Resource:
	for definition in room_pool:
		if definition != null and definition.get("id") == room_id:
			return definition
	return null

func _normalize_seed(seed_value) -> int:
	var parsed := int(seed_value)
	if parsed <= 0:
		rng.randomize()
		parsed = rng.randi_range(100000, 999999999)
	return parsed

func _spawn_plans_for_current_room() -> Array:
	if current_room_definition == null:
		return _normal_plans(clampi(2 + current_floor / 2, 2, 4))

	var enemy_group: StringName = current_room_definition.get("enemy_group")
	if enemy_group == &"none":
		return []
	if enemy_group == &"boss":
		return [_spawn_plan(boss_definition)]
	if enemy_group == &"mini_boss":
		return [_spawn_plan(mini_boss_definition)]

	var count: int = int(current_room_definition.get("enemy_count")) + current_floor / 3
	if enemy_group == &"elite":
		return _elite_plans(maxi(count, 1))
	return _normal_plans(clampi(count, 1, 4), _should_promote_pressure_elite())

func _normal_plans(count: int, promote_elite := false) -> Array:
	var plans: Array = []
	var elite_used := false
	for _index in range(count):
		if normal_enemy_definitions.is_empty():
			break
		var definition: Resource = normal_enemy_definitions[rng.randi_range(0, normal_enemy_definitions.size() - 1)]
		if promote_elite and not elite_used:
			plans.append(_spawn_plan(definition, [_roll_elite_affix()]))
			elite_used = true
		else:
			plans.append(_spawn_plan(definition))
	return plans

func _elite_plans(count: int) -> Array:
	var plans: Array = []
	if normal_enemy_definitions.is_empty():
		return plans

	plans.append(_spawn_plan(normal_enemy_definitions[normal_enemy_definitions.size() - 1], [_roll_elite_affix()]))
	var normal_count := clampi(count - 1, 2, 3)
	for _index in range(normal_count):
		if normal_enemy_definitions.size() <= 1:
			break
		var pick_index := rng.randi_range(0, maxi(normal_enemy_definitions.size() - 2, 0))
		plans.append(_spawn_plan(normal_enemy_definitions[pick_index]))
	return plans

func _spawn_plan(definition: Resource, affixes: Array = []) -> Dictionary:
	return {
		"definition": definition,
		"affixes": affixes,
	}

func _roll_elite_affix() -> Resource:
	if elite_affix_pool.is_empty():
		return null
	return elite_affix_pool[rng.randi_range(0, elite_affix_pool.size() - 1)]

func _should_promote_pressure_elite() -> bool:
	if elite_affix_pool.is_empty() or current_room_definition == null:
		return false
	if not _next_floor_is_boss_like():
		return false
	return rng.randf() < 0.75

func _next_floor_is_boss_like() -> bool:
	var next_floor := current_floor + 1
	return next_floor == 5 or next_floor == 10

func _spawn_position(index: int) -> Vector2:
	if spawn_points.is_empty():
		return Vector2(300 + index * 48, 240)
	return spawn_points[index % spawn_points.size()].global_position

func _spawn_enemy(definition: Resource, at_position: Vector2, affixes: Array = []) -> void:
	if definition == null:
		return

	var enemy: Node2D = enemy_scene.instantiate()
	enemy.definition = definition
	enemy.target = player
	enemy.global_position = at_position
	if not affixes.is_empty() and enemy.has_method("configure_elite_affixes"):
		enemy.configure_elite_affixes(affixes)
	enemy.died.connect(_on_enemy_died)
	live_enemies.append(enemy)
	enemy_parent.add_child(enemy)

func _on_enemy_died(enemy: Node, definition: Resource) -> void:
	if not run_active:
		return
	live_enemies.erase(enemy)
	enemy_defeated.emit(enemy, definition)
	if definition != null and definition.has_method("is_boss") and definition.is_boss():
		current_reward_source_definition = definition
	if loot_service != null:
		loot_service.drop_for_enemy(definition, enemy.global_position, current_floor)

	if live_enemies.is_empty():
		if event_trial_active:
			_complete_event_trial()
			return
		_complete_room()

func _complete_room() -> void:
	if not run_active:
		return
	if not room_cleared_emitted:
		room_cleared.emit(current_floor)
		room_cleared_emitted = true
	if _spawn_room_reward_chest():
		return

	_finish_room_after_rewards()

func _spawn_room_reward_chest() -> bool:
	if reward_chest_spawned or room_rewarded or current_room_definition == null:
		return false

	var attempts := int(current_room_definition.get("reward_attempts"))
	if attempts <= 0:
		return false

	reward_chest_spawned = true
	if reward_chest_scene == null or interactable_parent == null:
		_drop_room_reward_now(attempts)
		_finish_room_after_rewards()
		return true

	var chest := reward_chest_scene.instantiate()
	chest.global_position = _reward_position()
	if chest.has_method("configure"):
		chest.configure(loot_service, current_floor, attempts, bool(current_room_definition.get("guaranteed_reward")), current_reward_source_definition)
	if chest.has_signal("opened"):
		chest.opened.connect(_on_reward_chest_opened)
	interactable_parent.add_child(chest)
	return true

func _on_reward_chest_opened(_chest: Node) -> void:
	room_rewarded = true
	_finish_room_after_rewards()

func _finish_room_after_rewards() -> void:
	if current_floor >= max_floor:
		run_active = false
		run_completed.emit()
		_set_exit(false)
		return
	_unlock_exit()

func _drop_room_reward_now(attempts: int) -> void:
	if loot_service == null:
		return
	room_rewarded = true
	if loot_service.has_method("drop_room_reward"):
		loot_service.drop_room_reward(_reward_position(), current_floor, attempts, bool(current_room_definition.get("guaranteed_reward")), current_reward_source_definition)

func _spawn_forge_station_if_needed() -> void:
	if current_room_definition == null or not bool(current_room_definition.get("forge_available")):
		return
	if forge_station_scene == null or interactable_parent == null:
		return

	var station := forge_station_scene.instantiate()
	station.global_position = _reward_position()
	if station.has_signal("activated"):
		station.activated.connect(func(_station: Node) -> void: forge_station_activated.emit())
	interactable_parent.add_child(station)

func _spawn_event_station_if_needed() -> void:
	if current_room_definition == null or int(current_room_definition.get("room_type")) != RoomDefinition.RoomType.EVENT:
		return
	if event_station_scene == null or interactable_parent == null:
		return

	var definition := _pick_event_definition()
	if definition == null:
		return

	var station := event_station_scene.instantiate()
	station.global_position = _reward_position()
	if station.has_method("configure"):
		station.configure(event_service, definition)
	if station.has_signal("activated"):
		station.activated.connect(_on_event_station_activated)
	interactable_parent.add_child(station)

func _pick_event_definition() -> Resource:
	if forced_event_definition_for_test != null:
		var definition := forced_event_definition_for_test
		forced_event_definition_for_test = null
		return definition
	if event_definitions.is_empty():
		return null
	return event_definitions[rng.randi_range(0, event_definitions.size() - 1)]

func _on_event_station_activated(_station: Node, event_definition: Resource, result: Dictionary) -> void:
	event_station_activated.emit(event_definition, result)
	if not bool(result.get("success", false)) or event_definition == null:
		return
	if event_definition.get("event_type") == &"trial":
		_start_event_trial(event_definition)
	else:
		_unlock_exit()

func _start_event_trial(event_definition: Resource) -> void:
	if event_trial_active:
		return
	event_trial_active = true
	event_trial_reward_attempts = maxi(int(event_definition.get("reward_attempts")), 0)
	if bool(event_definition.get("exit_lock_during_trial")):
		_lock_exit()

	var definition := _normal_enemy_definition_for_id(event_definition.get("trial_enemy_id"))
	if definition == null and not normal_enemy_definitions.is_empty():
		definition = normal_enemy_definitions.back()
	if definition == null:
		_complete_event_trial()
		return

	var affixes := []
	if bool(event_definition.get("trial_uses_elite_affix")):
		affixes.append(_roll_elite_affix())
	_spawn_enemy(definition, _spawn_position(live_enemies.size()), affixes)

func _complete_event_trial() -> void:
	event_trial_active = false
	if event_trial_reward_attempts > 0:
		_spawn_event_reward_chest(event_trial_reward_attempts)
	event_trial_reward_attempts = 0
	_unlock_exit()

func _spawn_event_reward_chest(attempts: int) -> void:
	if reward_chest_scene == null or interactable_parent == null:
		if loot_service != null and loot_service.has_method("drop_room_reward"):
			loot_service.drop_room_reward(_reward_position(), current_floor, attempts, true, null)
		return

	var chest := reward_chest_scene.instantiate()
	chest.global_position = _reward_position() + Vector2(0, 42)
	if chest.has_method("configure"):
		chest.configure(loot_service, current_floor, attempts, true, null)
	interactable_parent.add_child(chest)

func _normal_enemy_definition_for_id(enemy_id: StringName) -> Resource:
	for definition in normal_enemy_definitions:
		if definition != null and definition.get("id") == enemy_id:
			return definition
	return null

func _should_unlock_exit_on_room_start() -> bool:
	if current_room_definition == null:
		return false
	if not bool(current_room_definition.get("exit_unlocked_on_start")):
		return false
	return not current_room_definition.has_encounter() and int(current_room_definition.get("reward_attempts")) <= 0

func _unlock_exit() -> void:
	exit_unlocked = true
	pending_room_choices.clear()
	_set_exit(true)

func _lock_exit() -> void:
	exit_unlocked = false
	pending_room_choices.clear()
	_set_exit(false)

func _set_exit(available: bool) -> void:
	if exit_portal == null or not exit_portal.has_method("set_available"):
		return
	if exit_point != null:
		exit_portal.global_position = exit_point.global_position
	exit_portal.set_available(available, "Next Room")
	if player != null and player.has_method("refresh_interaction_target"):
		player.refresh_interaction_target()

func _reward_position() -> Vector2:
	if reward_points.is_empty():
		return Vector2(480, 270)
	var point: Marker2D = reward_points[(current_floor - 1) % reward_points.size()]
	return point.global_position

func _move_player_to_start() -> void:
	if player != null and player_start != null:
		player.global_position = player_start.global_position

func _clear_room_state() -> void:
	for enemy in live_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	live_enemies.clear()

	if pickup_parent != null:
		for child in pickup_parent.get_children():
			child.queue_free()

	if interactable_parent != null:
		for child in interactable_parent.get_children():
			child.queue_free()

	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()

func _on_exit_portal_activated() -> void:
	if not run_active or not exit_unlocked or current_floor >= max_floor:
		return
	_ensure_pending_room_choices()
	if pending_room_choices.size() <= 1:
		choose_route_choice(0)
		return
	route_choices_requested.emit(current_floor + 1, pending_room_choices.duplicate())

func _ensure_pending_room_choices() -> void:
	if not pending_room_choices.is_empty():
		return
	pending_room_choices = _generate_next_room_choices()

func _generate_next_room_choices() -> Array:
	if current_floor >= max_floor:
		return []
	return _route_choices_for_state(current_floor + 1, chosen_room_sequence, early_route_remaining, late_route_remaining)

func _route_choices_for_state(next_floor: int, history: Array, early_remaining: Array, late_remaining: Array) -> Array:
	if next_floor == 5:
		return _single_room_choice(&"mini_boss_room")
	if next_floor == 10:
		return _single_room_choice(&"boss_room")

	var pool := []
	if next_floor >= 2 and next_floor <= 4:
		pool = early_remaining.duplicate()
	elif next_floor >= 6 and next_floor <= 9:
		pool = late_remaining.duplicate()
	if pool.size() <= 2:
		return pool

	var route_rng := RandomNumberGenerator.new()
	route_rng.seed = _route_choice_seed(next_floor, history)
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := route_rng.randi_range(0, index)
		var temp = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temp
	return pool.slice(0, 2)

func _single_room_choice(room_id: StringName) -> Array:
	var definition := _room_definition_for_id(room_id)
	return [definition] if definition != null else []

func _commit_route_choice(room: Resource) -> void:
	chosen_room_sequence.append(room)
	room_sequence = chosen_room_sequence.duplicate()
	if current_floor + 1 >= 2 and current_floor + 1 <= 4:
		_remove_room_from_route_pool(room, early_route_remaining)
	elif current_floor + 1 >= 6 and current_floor + 1 <= 9:
		_remove_room_from_route_pool(room, late_route_remaining)

func _remove_room_from_route_pool(room: Resource, pool: Array) -> void:
	if room == null:
		return
	var room_id: StringName = room.get("id")
	for index in range(pool.size() - 1, -1, -1):
		var candidate: Resource = pool[index]
		if candidate != null and candidate.get("id") == room_id:
			pool.remove_at(index)
			return

func _route_choice_seed(next_floor: int, history: Array) -> int:
	var value := int(current_run_seed) * 1009 + next_floor * 9176
	for definition in history:
		if definition != null:
			value += _stable_text_hash(str(definition.get("id"))) * 37
	return absi(value) + 1

func _stable_text_hash(text: String) -> int:
	var value := 17
	for index in range(text.length()):
		value = int(value * 31 + text.unicode_at(index)) & 0x7fffffff
	return value

func force_next_event_for_test(event_definition: Resource) -> void:
	forced_event_definition_for_test = event_definition

func room_sequence_ids_for_test() -> Array:
	var ids := []
	for definition in projected_room_sequence:
		ids.append(definition.get("id") if definition != null else &"")
	return ids

func chosen_room_sequence_ids_for_test() -> Array:
	var ids := []
	for definition in chosen_room_sequence:
		ids.append(definition.get("id") if definition != null else &"")
	return ids

func pending_room_choice_ids_for_test() -> Array:
	_ensure_pending_room_choices()
	var ids := []
	for definition in pending_room_choices:
		ids.append(definition.get("id") if definition != null else &"")
	return ids

func choose_route_choice_for_test(choice_index: int) -> bool:
	return choose_route_choice(choice_index)

func choose_route_choice_by_room_id_for_test(room_id: StringName) -> bool:
	_ensure_pending_room_choices()
	for index in range(pending_room_choices.size()):
		var definition: Resource = pending_room_choices[index]
		if definition != null and definition.get("id") == room_id:
			return choose_route_choice(index)
	return false

func floor_for_room_id_for_test(room_id: StringName) -> int:
	for index in range(projected_room_sequence.size()):
		var definition: Resource = projected_room_sequence[index]
		if definition != null and definition.get("id") == room_id:
			return index + 1
	return -1

func floor_for_room_type_for_test(room_type: int) -> int:
	for index in range(projected_room_sequence.size()):
		var definition: Resource = projected_room_sequence[index]
		if definition != null and int(definition.get("room_type")) == room_type:
			return index + 1
	return -1
