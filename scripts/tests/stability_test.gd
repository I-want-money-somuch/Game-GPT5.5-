extends SceneTree

const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")
const AffixEffectServiceScript := preload("res://scripts/systems/affix_effect_service.gd")
const BossAttackEffectScript := preload("res://scripts/boss/boss_attack_effect.gd")
const BossProjectileScript := preload("res://scripts/boss/boss_projectile.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _assert_freed_damage_sources_are_safe()
	await _assert_elite_room_cadence()
	await _assert_elite_affix_runtime()
	await _assert_weapon_affix_effect_runtime()
	await _assert_event_room_runtime()
	await _assert_boss_room_regression(5, &"cinder_bulwark", [&"cinderplate_core", &"bulwark_ember_ring"], false)
	await _assert_boss_room_regression(10, &"depths_warden", [&"warden_rift_staff", &"abyssal_guard_helm"], true)
	await _assert_ten_room_stress()
	print("STABILITY_OK")
	quit()

func _assert_freed_damage_sources_are_safe() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	player.initialize(load("res://resources/classes/vanguard.tres"), load("res://resources/weapons/ember_snap.tres"), load("res://scenes/items/Projectile.tscn"))
	player.health = player.max_health * 4.0

	var freed_source := Node2D.new()
	root.add_child(freed_source)
	var projectile = BossProjectileScript.new()
	projectile.global_position = Vector2(9000, 9000)
	root.add_child(projectile)
	projectile.configure({
		"source": freed_source,
		"direction": Vector2.RIGHT,
		"damage": 1.0,
		"knockback_force": 0.0,
		"pierce": 1,
	})
	var effect = BossAttackEffectScript.new()
	effect.global_position = player.global_position
	effect.configure_circle({
		"source": freed_source,
		"target": player,
		"radius": 48.0,
		"damage": 1.0,
		"warning_duration": 0.05,
		"knockback_force": 0.0,
	})
	root.add_child(effect)
	freed_source.queue_free()
	await process_frame

	var weapon := load("res://resources/weapons/ember_snap.tres")
	var packet = weapon.create_damage_packet(freed_source)
	_require(packet.source == null, "Weapon damage packets should drop freed sources")
	projectile._on_body_entered(player)
	effect._apply_damage()
	await process_frame
	_require(player.health < player.max_health * 4.0, "Freed-source attacks should still resolve damage")

	projectile.queue_free()
	effect.queue_free()
	player.queue_free()
	await process_frame

func _assert_elite_room_cadence() -> void:
	var main := await _instantiate_main()
	var run = main.get_node("DungeonRun")
	run.current_floor = 4
	run._start_current_room()
	await process_frame
	var elite_count := 0
	var normal_count := 0
	var boss_count := 0
	for enemy in run.live_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.definition != null and enemy.definition.has_method("is_boss") and enemy.definition.is_boss():
			boss_count += 1
		elif enemy.has_method("is_elite_enemy") and enemy.is_elite_enemy():
			elite_count += 1
			_require(enemy.get_elite_affix_ids().size() == 1, "Elite room elite should carry one affix")
		else:
			normal_count += 1
	_require(elite_count == 1, "Elite room should spawn exactly one elite enemy")
	_require(normal_count >= 2 and normal_count <= 3, "Elite room should spawn two to three normal escorts")
	_require(boss_count == 0, "Elite room should not spawn bosses")

	run.current_floor = 10
	run._start_current_room()
	await process_frame
	for enemy in run.live_enemies:
		_require(not enemy.is_elite_enemy(), "Boss room should not mix elite affixes")
	main.queue_free()
	_cleanup_runtime_nodes()
	await process_frame

func _assert_elite_affix_runtime() -> void:
	await _assert_flaming_affix()
	await _assert_swift_affix()
	await _assert_juggernaut_affix()
	await _assert_phasing_affix()
	await _assert_vampiric_affix()

func _assert_flaming_affix() -> void:
	var fixture := await _spawn_elite_fixture(load("res://resources/elite_affixes/flaming.tres"))
	var enemy = fixture["enemy"]
	var player = fixture["player"]
	var before := _runtime_node_count()
	_kill_enemy(enemy, player)
	_require(enemy.has_triggered_elite_affix(&"flaming"), "Flaming affix should mark as triggered")
	await process_frame
	_require(_runtime_node_count() > before, "Flaming elite should spawn a death explosion")
	await create_timer(0.4).timeout
	_cleanup_fixture(fixture)

func _assert_swift_affix() -> void:
	var fixture := await _spawn_elite_fixture(load("res://resources/elite_affixes/swift.tres"))
	var enemy = fixture["enemy"]
	var base_speed := float(enemy.definition.base_stats.get("move_speed"))
	var base_windup := float(enemy.definition.behavior_profile.get("windup_duration"))
	_require(enemy.move_speed > base_speed, "Swift elite should move faster")
	_require(enemy._behavior_float("windup_duration", base_windup) < base_windup, "Swift elite should shorten windup")
	_require(enemy.has_triggered_elite_affix(&"swift"), "Swift affix should apply")
	_cleanup_fixture(fixture)

func _assert_juggernaut_affix() -> void:
	var fixture := await _spawn_elite_fixture(load("res://resources/elite_affixes/juggernaut.tres"), load("res://resources/enemies/iron_husk.tres"))
	var enemy = fixture["enemy"]
	var base_armor := float(enemy.definition.base_stats.get("armor"))
	var base_stagger := float(enemy.definition.behavior_profile.get("stagger_duration"))
	_require(enemy.armor_component.max_armor > base_armor, "Juggernaut elite should gain armor")
	_require(enemy._behavior_float("stagger_duration", base_stagger) < base_stagger, "Juggernaut elite should shorten stagger")
	_require(enemy.has_triggered_elite_affix(&"juggernaut"), "Juggernaut affix should apply")
	_cleanup_fixture(fixture)

func _assert_phasing_affix() -> void:
	var fixture := await _spawn_elite_fixture(load("res://resources/elite_affixes/phasing.tres"))
	var enemy = fixture["enemy"]
	var player = fixture["player"]
	enemy.force_elite_phasing_for_test()
	await process_frame
	_require(enemy.is_elite_phasing(), "Phasing elite should enter phasing")
	var health_before: float = enemy.health
	enemy.take_damage(_damage_packet(player, 30.0, enemy.global_position))
	_require(is_equal_approx(enemy.health, health_before), "Phasing elite should ignore damage while phased")
	await create_timer(float(enemy.elite_affixes[0].get("phasing_duration")) + 0.08).timeout
	_require(not enemy.is_elite_phasing(), "Phasing elite should not stay invulnerable forever")
	enemy.take_damage(_damage_packet(player, 5.0, enemy.global_position))
	_require(enemy.health < health_before, "Phasing elite should take damage after phasing ends")
	_require(enemy.has_triggered_elite_affix(&"phasing"), "Phasing affix should trigger")
	_cleanup_fixture(fixture)

func _assert_vampiric_affix() -> void:
	var fixture := await _spawn_elite_fixture(load("res://resources/elite_affixes/vampiric.tres"))
	var enemy = fixture["enemy"]
	var player = fixture["player"]
	enemy.health = enemy.max_health * 0.5
	var health_before: float = enemy.health
	enemy.notify_damage_dealt(_damage_packet(enemy, 12.0, player.global_position), player)
	_require(enemy.health > health_before, "Vampiric elite should heal after hitting player")
	_require(enemy.has_triggered_elite_affix(&"vampiric"), "Vampiric affix should trigger")
	_cleanup_fixture(fixture)

func _assert_weapon_affix_effect_runtime() -> void:
	await _assert_fire_burst_effect()
	await _assert_frostbite_effect()
	await _assert_chain_lightning_effect()

func _assert_event_room_runtime() -> void:
	await _assert_event_cost_guards()
	await _assert_event_one_shot()
	await _assert_trial_event_flow()

func _assert_event_cost_guards() -> void:
	var ember_fixture := await _spawn_event_fixture(load("res://resources/events/ember_pact.tres"))
	var ember_player = ember_fixture["player"]
	var ember_station = ember_fixture["station"]
	ember_player.health = 10.0
	ember_station.interact(ember_player)
	await process_frame
	_require(is_equal_approx(ember_player.health, 10.0), "Ember Pact should not trigger when it would kill the player")
	_require(ember_station.is_in_group("interactables"), "Failed Ember Pact should remain available")
	_cleanup_event_fixture(ember_fixture)

	var iron_fixture := await _spawn_event_fixture(load("res://resources/events/iron_oath.tres"))
	var iron_player = iron_fixture["player"]
	var iron_station = iron_fixture["station"]
	var armor = iron_player.armor_component
	var armor_before: float = armor.max_armor
	armor.current_durability = 5.0
	iron_station.interact(iron_player)
	await process_frame
	_require(is_equal_approx(armor.current_durability, 5.0), "Iron Oath should not spend insufficient armor durability")
	_require(is_equal_approx(armor.max_armor, armor_before), "Failed Iron Oath should not grant armor")
	_require(iron_station.is_in_group("interactables"), "Failed Iron Oath should remain available")
	_cleanup_event_fixture(iron_fixture)

func _assert_event_one_shot() -> void:
	var fixture := await _spawn_event_fixture(load("res://resources/events/ember_pact.tres"))
	var player = fixture["player"]
	var station = fixture["station"]
	var before_health: float = player.health
	station.interact(player)
	await process_frame
	var after_first: float = player.health
	station.interact(player)
	await process_frame
	_require(is_equal_approx(after_first, before_health - 18.0), "One-shot event should apply its cost once")
	_require(is_equal_approx(player.health, after_first), "Repeating a resolved event should not apply cost twice")
	_require(not station.is_in_group("interactables"), "Resolved one-shot event should leave the interactable group")
	_cleanup_event_fixture(fixture)

func _assert_trial_event_flow() -> void:
	var fixture := await _spawn_event_fixture(load("res://resources/events/trial_altar.tres"))
	var main = fixture["main"]
	var run = fixture["run"]
	var player = fixture["player"]
	var station = fixture["station"]
	_require(run.exit_unlocked, "Trial event room should start with an optional exit")
	station.interact(player)
	await process_frame
	_require(not run.exit_unlocked, "Trial event should lock the exit")
	_require(run.live_enemies.size() == 1, "Trial event should spawn exactly one enemy")
	var enemy = run.live_enemies[0]
	_require(enemy.definition.id == &"iron_husk", "Trial event should spawn Iron Husk")
	_require(enemy.is_elite_enemy(), "Trial event should apply an elite affix")
	_kill_enemy(enemy, player)
	await process_frame
	await process_frame
	_require(run.live_enemies.is_empty(), "Trial event enemy death should not leave stale live enemies")
	_require(run.exit_unlocked, "Trial event completion should unlock the exit")
	var chest = _find_reward_chest(main)
	_require(chest != null, "Trial event completion should spawn a reward chest")
	var pickups_before: int = main.get_node("Pickups").get_child_count()
	chest.interact(player)
	await process_frame
	_require(main.get_node("Pickups").get_child_count() > pickups_before, "Trial reward chest should drop loot")
	await _assert_pickup_can_be_interacted(main, player, "Trial reward")
	station.interact(player)
	await process_frame
	_require(_count_reward_chests(main) == 1, "Resolved Trial Altar should not spawn duplicate chests")
	_cleanup_event_fixture(fixture)

func _assert_fire_burst_effect() -> void:
	var fixture := await _spawn_affix_fixture(3)
	var service: Node = fixture["service"]
	var player: Node = fixture["player"]
	var enemies: Array = fixture["enemies"]
	var primary: Node = enemies[0]
	var splash: Node = enemies[1]
	var dead_target: Node = enemies[2]
	dead_target.is_dead = true
	var splash_health_before: float = splash.health
	var dead_health_before: float = dead_target.health
	var packet := _damage_packet(player, 24.0, primary.global_position)
	var triggered: Array = service.force_weapon_effect(player, load("res://resources/weapons/ember_snap.tres"), primary, packet, &"fire_burst")
	_require(triggered.has(&"fire_burst"), "Fire burst should be force-triggerable")
	_require(_runtime_node_count() > 0, "Fire burst should spawn a visible affix effect")
	await create_timer(0.28).timeout
	_require(splash.health < splash_health_before, "Fire burst should damage nearby living enemies")
	_require(is_equal_approx(dead_target.health, dead_health_before), "Fire burst should not damage already dead enemies")
	_cleanup_affix_fixture(fixture)

func _assert_frostbite_effect() -> void:
	var fixture := await _spawn_affix_fixture(1)
	var service: Node = fixture["service"]
	var player: Node = fixture["player"]
	var enemy: Node = fixture["enemies"][0]
	var packet := _damage_packet(player, 12.0, enemy.global_position)
	var triggered: Array = service.force_weapon_effect(player, load("res://resources/weapons/frostline_staff.tres"), enemy, packet, &"frostbite")
	_require(triggered.has(&"frostbite"), "Frostbite should be force-triggerable")
	_require(enemy.has_status_effect(&"frostbite"), "Frostbite should apply a status")
	_require(enemy.status_move_speed_multiplier_for_test() < 1.0, "Frostbite should reduce move speed")
	await create_timer(1.45).timeout
	_require(not enemy.has_status_effect(&"frostbite"), "Frostbite should expire automatically")
	_cleanup_affix_fixture(fixture)

func _assert_chain_lightning_effect() -> void:
	var fixture := await _spawn_affix_fixture(4)
	var service: Node = fixture["service"]
	var player: Node = fixture["player"]
	var enemies: Array = fixture["enemies"]
	var primary: Node = enemies[0]
	var first_chain: Node = enemies[1]
	var second_chain: Node = enemies[2]
	var third_candidate: Node = enemies[3]
	var first_before: float = first_chain.health
	var second_before: float = second_chain.health
	var third_before: float = third_candidate.health
	var packet := _damage_packet(player, 24.0, primary.global_position)
	var triggered: Array = service.force_weapon_effect(player, load("res://resources/weapons/volt_spear.tres"), primary, packet, &"chain_lightning")
	_require(triggered.has(&"chain_lightning"), "Chain lightning should be force-triggerable")
	await process_frame
	_require(first_chain.health < first_before, "Chain lightning should hit first nearby enemy")
	_require(second_chain.health < second_before, "Chain lightning should hit second nearby enemy")
	_require(is_equal_approx(third_candidate.health, third_before), "Chain lightning should stop after two extra targets")
	_cleanup_affix_fixture(fixture)

func _assert_boss_room_regression(floor: int, boss_id: StringName, exclusive_item_ids: Array, should_complete: bool) -> void:
	var main := await _instantiate_main()
	var run = main.get_node("DungeonRun")
	var player = main.get_node("Player")
	var completed := {"value": false}
	run.run_completed.connect(func() -> void: completed["value"] = true)
	run.current_floor = floor
	run._start_current_room()
	await process_frame

	_require(run.live_enemies.size() == 1, "Boss regression floor %d should spawn one boss" % floor)
	var boss = run.live_enemies[0]
	_require(boss.definition.id == boss_id, "Boss regression floor %d should spawn %s" % [floor, boss_id])
	_require(boss.get_normal_state_name() == &"boss", "%s should stay on boss branch" % boss.definition.display_name)
	boss.force_normal_state_for_test(&"stagger")
	_require(not boss.has_visited_normal_state(&"stagger"), "%s should not accept normal Stagger" % boss.definition.display_name)

	_require(boss.force_phase_two_for_test(), "%s should enter phase two" % boss.definition.display_name)
	_require(not boss.force_phase_two_for_test(), "%s phase two should only trigger once" % boss.definition.display_name)
	var health_before: float = boss.health
	boss.take_damage(_damage_packet(player, 25.0, boss.global_position))
	_require(is_equal_approx(boss.health, health_before), "%s should ignore damage during phase invulnerability" % boss.definition.display_name)
	boss.invulnerable_timer = 0.0
	boss.damage_reduction_override = 0.0

	for skill_id in boss.definition.boss_skill_profile.skill_ids:
		await _assert_boss_skill_runtime(boss, player, skill_id)

	_kill_enemy(boss, player)
	await process_frame
	await process_frame
	_require(run.live_enemies.is_empty(), "%s death should clear live enemy list" % boss_id)
	var chest = _find_reward_chest(main)
	_require(chest != null, "%s death should spawn a boss chest" % boss_id)
	_require(not run.exit_unlocked, "%s chest should gate room completion" % boss_id)
	var pickups_before := main.get_node("Pickups").get_child_count()
	chest.interact(player)
	await process_frame
	_require(main.get_node("Pickups").get_child_count() > pickups_before, "%s chest should drop loot" % boss_id)
	_require(_pickup_ids_include(main, exclusive_item_ids), "%s chest should include exclusive boss loot" % boss_id)
	await _assert_pickup_can_be_interacted(main, player, "%s boss chest" % boss_id)
	_require(bool(completed["value"]) == should_complete, "%s completion state should match room type" % boss_id)
	if should_complete:
		_require(not run.exit_unlocked, "Final boss should complete run instead of unlocking exit")
	else:
		_require(run.exit_unlocked, "Mini boss chest should unlock exit")

	main.queue_free()
	_cleanup_runtime_nodes()
	await process_frame

func _assert_boss_skill_runtime(boss: Node, player: Node2D, skill_id: StringName) -> void:
	_cleanup_runtime_nodes()
	_lock_boss_auto_casts(boss)
	player.global_position = boss.global_position + Vector2(160, 0)
	var before := _runtime_node_count()
	_require(boss.cast_boss_skill(skill_id), "Boss skill %s should start" % skill_id)
	await create_timer(_skill_check_wait_time(skill_id)).timeout
	_require(_runtime_node_count() > before, "Boss skill %s should spawn an effect" % skill_id)
	await create_timer(_skill_finish_wait_time(skill_id)).timeout
	_cleanup_runtime_nodes()
	await process_frame

func _lock_boss_auto_casts(boss: Node) -> void:
	boss.boss_casting = false
	for index in range(boss.boss_skill_timers.size()):
		boss.boss_skill_timers[index] = 99.0

func _assert_ten_room_stress() -> void:
	var main := await _instantiate_main()
	var run = main.get_node("DungeonRun")
	var player = main.get_node("Player")
	var completed := {"value": false}
	run.run_completed.connect(func() -> void: completed["value"] = true)
	player.health = player.max_health * 20.0

	for expected_floor in range(1, 11):
		_require(run.current_floor == expected_floor, "Stress should be on floor %d" % expected_floor)
		await _exercise_current_room(main, run, player)
		_clear_room_by_damage(run, player)
		await process_frame
		await process_frame
		_require(run.live_enemies.is_empty(), "Stress floor %d should clear all enemies" % expected_floor)
		await create_timer(0.75).timeout
		_require(_runtime_node_count() == 0, "Stress floor %d should not leave attack runtime nodes" % expected_floor)

		var chest = _find_reward_chest(main)
		if chest != null:
			chest.interact(player)
			await process_frame
		elif _find_forge_station(main) != null:
			_find_forge_station(main).interact(player)
			await process_frame
			_require(main.get_node("HUD").forge_panel.visible, "Forge room should open forge UI during stress")

		if expected_floor == 10:
			_require(bool(completed["value"]), "Stress should complete the run after final boss chest")
			var meta = main.get_node("MetaProgressionService")
			var profile_before: Dictionary = meta.profile_snapshot()
			main._on_run_completed()
			main.back_to_camp_for_test()
			main.back_to_camp_for_test()
			var profile_after: Dictionary = meta.profile_snapshot()
			_require(int(profile_after.get("gold")) == int(profile_before.get("gold")), "Stress completion should not award gold twice")
			_require(int(profile_after.get("talent_points")) == int(profile_before.get("talent_points")), "Stress completion should not award talent points twice")
			break

		_require(run.exit_unlocked, "Stress floor %d should unlock exit after rewards" % expected_floor)
		run.advance_to_next_room()
		await process_frame
		_require(main.get_node("HUD").forge_panel.visible == false, "Forge UI should close after leaving a room")
		player.health = player.max_health * 20.0

	main.queue_free()
	_cleanup_runtime_nodes()
	await process_frame

func _exercise_current_room(main: Node, run: Node, player: Node2D) -> void:
	if run.live_enemies.is_empty():
		return

	for enemy in run.live_enemies:
		if not is_instance_valid(enemy):
			continue
		player.global_position = enemy.global_position + Vector2(42, 0)
		if enemy.get("normal_attack_cooldown") != null:
			enemy.normal_attack_cooldown = 0.0
		await create_timer(0.24).timeout

	for enemy in run.live_enemies:
		if not is_instance_valid(enemy) or enemy.definition == null:
			continue
		if enemy.definition.has_method("is_boss") and enemy.definition.is_boss():
			_require(enemy.get_normal_state_name() == &"boss", "%s should remain on boss branch during stress" % enemy.definition.display_name)
		elif enemy.behavior_profile != null:
			_require(enemy.has_visited_normal_state(&"chase"), "%s should enter Chase during stress" % enemy.definition.display_name)

func _clear_room_by_damage(run: Node, player: Node2D) -> void:
	for enemy in run.live_enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		_kill_enemy(enemy, player)

func _kill_enemy(enemy: Node, player: Node2D) -> void:
	if enemy.get("invulnerable_timer") != null:
		enemy.invulnerable_timer = 0.0
	if enemy.get("damage_reduction_override") != null:
		enemy.damage_reduction_override = 0.0
	if enemy.has_method("clear_elite_phasing_for_test"):
		enemy.clear_elite_phasing_for_test()
	enemy.take_damage(_damage_packet(player, 99999.0, enemy.global_position))

func _damage_packet(source: Node, amount: float, hit_position: Vector2) -> RefCounted:
	var packet = DamagePacketScript.new()
	packet.amount = amount
	packet.source = source
	packet.element = &"physical"
	packet.crit_chance = 0.0
	packet.armor_pierce = 1.0
	packet.knockback_force = 0.0
	packet.hit_direction = Vector2.RIGHT
	packet.hit_position = hit_position
	return packet

func _find_reward_chest(main: Node) -> Node:
	for child in main.get_node("Interactables").get_children():
		if child.has_method("get_prompt_text") and child.get_prompt_text() == "Open Chest" and child.has_method("interact"):
			return child
	return null

func _find_forge_station(main: Node) -> Node:
	for child in main.get_node("Interactables").get_children():
		if child.has_method("get_prompt_text") and child.get_prompt_text() == "Use Forge" and child.has_method("interact"):
			return child
	return null

func _find_pickup(main: Node) -> Node:
	for child in main.get_node("Pickups").get_children():
		if child.has_method("interact") and child.get("item_definition") != null:
			return child
	return null

func _assert_pickup_can_be_interacted(main: Node, player: Node, label: String) -> void:
	var pickup = _find_pickup(main)
	_require(pickup != null, "%s should leave at least one pickup to inspect" % label)
	_require(pickup.is_in_group("interactables"), "%s pickup should use the interaction group" % label)
	_require(pickup.has_method("get_preview_item") and pickup.get_preview_item() != null, "%s pickup should expose preview item data" % label)
	var inventory_before: int = player.inventory.size()
	player._on_interaction_area_entered(pickup)
	await process_frame
	_require(main.get_node("HUD").is_pickup_preview_visible_for_test(), "%s pickup should show preview UI" % label)
	player.force_interact_with(pickup)
	await process_frame
	_require(player.inventory.size() == inventory_before + 1, "%s pickup should enter inventory after interaction" % label)

func _find_event_station(main: Node) -> Node:
	for child in main.get_node("Interactables").get_children():
		if child.get("event_definition") != null and child.has_method("interact"):
			return child
	return null

func _count_reward_chests(main: Node) -> int:
	var count := 0
	for child in main.get_node("Interactables").get_children():
		if child.has_method("get_prompt_text") and child.get_prompt_text() == "Open Chest":
			count += 1
	return count

func _pickup_ids_include(main: Node, expected_ids: Array) -> bool:
	for pickup in main.get_node("Pickups").get_children():
		var item = pickup.get("item_definition")
		if item != null and expected_ids.has(item.get("id")):
			return true
	return false

func _instantiate_main() -> Node:
	var main_scene := load("res://scenes/main/Main.tscn")
	_require(main_scene != null, "Main scene should load")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.configure_profile_path_for_test("user://stability_profile_v002.json", true)
	main.start_run_for_test()
	await process_frame
	return main

func _spawn_elite_fixture(affix: Resource, definition: Resource = null) -> Dictionary:
	var player_scene := load("res://scenes/player/Player.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var player = player_scene.instantiate()
	var enemy = enemy_scene.instantiate()
	root.add_child(player)
	player.initialize(load("res://resources/classes/vanguard.tres"), load("res://resources/weapons/ember_snap.tres"), load("res://scenes/items/Projectile.tscn"))
	enemy.definition = definition if definition != null else load("res://resources/enemies/ashling.tres")
	enemy.target = player
	enemy.global_position = Vector2(220, 220)
	player.global_position = Vector2(270, 220)
	enemy.configure_elite_affixes([affix])
	root.add_child(enemy)
	await process_frame
	_require(enemy.is_elite_enemy(), "%s should instantiate as elite" % affix.display_name)
	_require(enemy.has_elite_affix(affix.id), "%s should be attached to enemy" % affix.display_name)
	return {
		"player": player,
		"enemy": enemy,
	}

func _cleanup_fixture(fixture: Dictionary) -> void:
	if fixture.has("enemy") and is_instance_valid(fixture["enemy"]):
		fixture["enemy"].queue_free()
	if fixture.has("player") and is_instance_valid(fixture["player"]):
		fixture["player"].queue_free()
	_cleanup_runtime_nodes()

func _skill_check_wait_time(skill_id: StringName) -> float:
	match skill_id:
		&"molten_guard":
			return 1.35
		&"cinder_shard_burst", &"rift_fan":
			return 0.45
		&"ember_charge", &"void_lance", &"gravity_ring":
			return 0.08
		_:
			return 0.2

func _skill_finish_wait_time(skill_id: StringName) -> float:
	return 2.0

func _runtime_node_count() -> int:
	return get_nodes_in_group("boss_attack_effects").size() + get_nodes_in_group("boss_projectiles").size() + get_nodes_in_group("affix_effects").size()

func _cleanup_runtime_nodes() -> void:
	for node in get_nodes_in_group("boss_attack_effects"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_nodes_in_group("boss_projectiles"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_nodes_in_group("affix_effects"):
		if is_instance_valid(node):
			node.queue_free()

func _spawn_affix_fixture(enemy_count: int) -> Dictionary:
	var service = AffixEffectServiceScript.new()
	root.add_child(service)
	service.configure(root)
	var player_scene := load("res://scenes/player/Player.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	player.initialize(load("res://resources/classes/vanguard.tres"), load("res://resources/weapons/ember_snap.tres"), load("res://scenes/items/Projectile.tscn"))
	player.bind_affix_effect_service(service)
	var enemies: Array = []
	for index in range(enemy_count):
		var enemy = enemy_scene.instantiate()
		enemy.definition = load("res://resources/enemies/ashling.tres")
		enemy.target = player
		enemy.global_position = Vector2(300 + index * 42, 240)
		root.add_child(enemy)
		enemies.append(enemy)
	player.global_position = Vector2(220, 240)
	await process_frame
	return {
		"service": service,
		"player": player,
		"enemies": enemies,
	}

func _spawn_event_fixture(event_definition: Resource) -> Dictionary:
	var main := await _instantiate_main()
	var run = main.get_node("DungeonRun")
	run.current_floor = 7
	run.force_next_event_for_test(event_definition)
	run._start_current_room()
	await process_frame
	var station = _find_event_station(main)
	_require(run.current_room_definition.id == &"event_room", "Event fixture should use floor seven event room")
	_require(station != null, "Event fixture should spawn an event station")
	return {
		"main": main,
		"run": run,
		"player": main.get_node("Player"),
		"station": station,
	}

func _cleanup_event_fixture(fixture: Dictionary) -> void:
	if fixture.has("main") and is_instance_valid(fixture["main"]):
		fixture["main"].queue_free()
	_cleanup_runtime_nodes()

func _cleanup_affix_fixture(fixture: Dictionary) -> void:
	if fixture.has("service") and is_instance_valid(fixture["service"]):
		fixture["service"].queue_free()
	if fixture.has("player") and is_instance_valid(fixture["player"]):
		fixture["player"].queue_free()
	if fixture.has("enemies"):
		for enemy in fixture["enemies"]:
			if is_instance_valid(enemy):
				enemy.queue_free()
	_cleanup_runtime_nodes()

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
