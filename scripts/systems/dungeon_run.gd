class_name DungeonRun
extends Node

signal room_started(floor: int, room_type: String)
signal room_cleared(floor: int)
signal run_completed
signal enemy_defeated(enemy: Node, enemy_definition: Resource)
signal forge_station_activated
signal event_station_activated(event_definition: Resource, result: Dictionary)

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
var current_room_definition: Resource
var current_floor := 1
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
	room_sequence = config.get("room_sequence", [])

	if exit_portal != null and exit_portal.has_signal("activated"):
		var advance_callable := Callable(self, "advance_to_next_room")
		if not exit_portal.activated.is_connected(advance_callable):
			exit_portal.activated.connect(advance_callable)

func start_run() -> void:
	run_active = true
	current_floor = 1
	_start_current_room()

func advance_to_next_room() -> void:
	if not run_active or not exit_unlocked or current_floor >= max_floor:
		return

	current_floor += 1
	_start_current_room()

func end_run() -> void:
	run_active = false
	exit_unlocked = false
	event_trial_active = false
	event_trial_reward_attempts = 0
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
	if not room_sequence.is_empty():
		return room_sequence[clampi(floor - 1, 0, room_sequence.size() - 1)]
	return null

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
	if not _next_room_is_boss_like():
		return false
	return rng.randf() < 0.75

func _next_room_is_boss_like() -> bool:
	if room_sequence.is_empty() or current_floor >= room_sequence.size():
		return false
	var next_room: Resource = room_sequence[current_floor]
	if next_room == null:
		return false
	var group: StringName = next_room.get("enemy_group")
	return group == &"mini_boss" or group == &"boss"

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
	_set_exit(true)

func _lock_exit() -> void:
	exit_unlocked = false
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

func force_next_event_for_test(event_definition: Resource) -> void:
	forced_event_definition_for_test = event_definition
