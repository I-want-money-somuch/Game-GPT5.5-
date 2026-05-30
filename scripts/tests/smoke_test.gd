extends SceneTree

const ArmorComponentScript := preload("res://scripts/combat/armor_component.gd")
const CombatResolverScript := preload("res://scripts/combat/combat_resolver.gd")
const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")
const FeedbackServiceScript := preload("res://scripts/systems/feedback_service.gd")
const EnhancementServiceScript := preload("res://scripts/systems/enhancement_service.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	_require(main_scene != null, "Main scene should load")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	_assert_pixel_art_assets()
	main.configure_settings_path_for_test("user://smoke_settings_v006.json", true)
	main.configure_profile_path_for_test("user://smoke_profile_v002.json", true)
	await process_frame
	var run = main.get_node("DungeonRun")
	var player_main = main.get_node("Player")
	var hud_main = main.get_node("HUD")
	_require(main.get_node("HUD").main_menu_overlay.visible, "Main scene should start at the camp menu")
	_require(not run.run_active, "Dungeon run should not start before Start Run")
	_require(not player_main.input_enabled, "Player input should be disabled at camp")
	_require(hud_main.seed_line_edit != null, "Camp menu should expose a run seed input")
	await _assert_settings_menu_localization(main)
	_assert_localization_coverage(main.get_node("LocalizationService"))
	_assert_player_mouse_facing(player_main)
	_assert_meta_menu_and_talents(main)
	await _assert_seeded_room_generation()
	main.start_run_for_test()
	await process_frame
	await _assert_sprite_scene_visuals(main)
	_require(run.current_room_definition != null, "Run should start in a room definition")
	_require(run.current_room_definition.id == &"combat_room", "Run should start in combat room")
	_require(run.current_run_seed > 0, "Blank seed should generate a positive run seed")
	_require(hud_main.run_seed_label.text.contains("Seed:"), "HUD should show the active run seed")
	_require(player_main.max_health >= 130.0, "Vital Core should increase starting health")
	_require(player_main.armor_component.max_armor >= 16.0, "Reinforced Plating should increase armor")
	_require(main.get_node("LootService").enemy_drop_chance_bonus >= 0.03, "Scavenger Instinct should increase enemy drop chance")
	var starter_weapon_for_meta := load("res://resources/weapons/ember_snap.tres")
	var meta_damage_packet = starter_weapon_for_meta.create_damage_packet(player_main)
	player_main.modify_outgoing_packet(meta_damage_packet, starter_weapon_for_meta)
	_require(meta_damage_packet.amount > starter_weapon_for_meta.base_damage * 1.04, "Weapon Training should increase outgoing damage")
	_assert_equipment_detail_ui(main)
	await _assert_pickup_preview_and_interaction(main)
	await _assert_runtime_localization(main)
	await _assert_void_arcana_content(main)
	await _assert_readable_ui_thresholds(main)
	_require(main.get_node("ExitPortal").visible == false, "Exit should start locked in combat rooms")
	for enemy in run.live_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	run.live_enemies.clear()
	run._complete_room()
	await process_frame
	var interactables: Node = main.get_node("Interactables")
	_require(interactables.get_child_count() == 1, "Cleared reward rooms should spawn one chest")
	var chest = interactables.get_child(0)
	_require(chest.has_method("interact"), "Reward chest should be interactable")
	_require(main.get_node("ExitPortal").visible == false, "Exit should stay locked until chest opens")
	chest.interact(main.get_node("Player"))
	await process_frame
	_require(main.get_node("Pickups").get_child_count() > 0, "Opening chest should create reward drops")
	_require(main.get_node("ExitPortal").visible == true, "Exit should unlock after chest opens")
	_require(main.get_node("ExitPortal").is_in_group("interactables"), "Unlocked exit should require interaction")
	main.get_node("Player").force_interact_with(main.get_node("ExitPortal"))
	await process_frame
	_require(hud_main.is_route_choice_visible_for_test(), "Interacting with the exit should open route choices")
	_require(hud_main.route_choice_count_for_test() == 2, "First route choice should offer two next rooms")
	var first_choice_ids: Array = run.pending_room_choice_ids_for_test()
	_require(first_choice_ids.size() == 2, "DungeonRun should expose two pending route choices")
	hud_main.choose_route_for_test(0)
	await process_frame
	_require(run.current_floor == 2, "Interacting with unlocked exit should advance one floor")
	_require(run.chosen_room_sequence_ids_for_test()[1] == first_choice_ids[0], "Chosen route should record the selected room")

	var forge_floor: int = run.floor_for_room_id_for_test(&"forge_room")
	_require(forge_floor >= 6 and forge_floor <= 9, "Generated sequence should include a forge room between floors 6 and 9")
	run.current_floor = forge_floor
	run._start_current_room()
	await process_frame
	_require(run.current_room_definition.id == &"forge_room", "Generated forge floor should be the forge room")
	_require(interactables.get_child_count() == 1, "Forge room should spawn one forge station")
	var station = interactables.get_child(0)
	station.interact(main.get_node("Player"))
	await process_frame
	_require(main.get_node("HUD").forge_panel.visible == true, "Forge station interaction should open forge UI")
	run.advance_to_next_room()
	await process_frame
	_require(run.current_floor == forge_floor + 1, "Leaving forge room should advance one floor")
	_require(main.get_node("HUD").forge_panel.visible == false, "Leaving forge room should close forge UI")
	_require(main.get_node("HUD").forge_button.disabled == true, "Leaving forge room should lock forge UI")

	var event_floor: int = run.floor_for_room_id_for_test(&"event_room")
	_require(event_floor >= 6 and event_floor <= 9, "Generated sequence should include an event room between floors 6 and 9")
	run.current_floor = event_floor
	run._start_current_room()
	await process_frame
	_require(run.current_room_definition.id == &"event_room", "Generated event floor should be the event room")
	_require(_find_event_station(main) != null, "Event room should spawn one event station")
	_require(main.get_node("ExitPortal").visible == true, "Event room should unlock the exit by default")

	run.current_floor = 10
	run._start_current_room()
	await process_frame
	_require(run.current_room_definition.id == &"boss_room", "Floor ten should be the boss room")
	for enemy in run.live_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	run.live_enemies.clear()
	run.current_reward_source_definition = run.boss_definition
	var completed := {"value": false}
	run.run_completed.connect(func() -> void: completed["value"] = true)
	run._complete_room()
	await process_frame
	var boss_chest = interactables.get_child(0)
	boss_chest.interact(main.get_node("Player"))
	await process_frame
	_require(bool(completed["value"]), "Final boss chest should complete the run")
	_require(main.get_node("HUD").run_end_overlay.visible == true, "Run completion should show the end overlay")
	main.queue_free()
	await process_frame

	await _assert_player_death_state()
	await _assert_event_room_effects()

	var forge_room := load("res://resources/dungeon/forge_room.tres")
	_require(forge_room != null and forge_room.forge_available, "Forge room should unlock forge UI")
	var event_room := load("res://resources/dungeon/event_room.tres")
	_require(event_room != null and event_room.room_type == RoomDefinition.RoomType.EVENT, "Event room resource should use EVENT type")
	var treasure_room := load("res://resources/dungeon/treasure_room.tres")
	_require(treasure_room != null and treasure_room.guaranteed_reward, "Treasure room should guarantee rewards")

	var weapon := load("res://resources/weapons/ember_snap.tres")
	_require(weapon != null, "Starter weapon should load")
	var packet = weapon.create_damage_packet(null)
	_require(packet.amount > 0.0, "Starter weapon should create damage")

	var armor = ArmorComponentScript.new()
	armor.configure({
		"armor": 20.0,
		"armor_durability": 40.0,
		"armor_damage_reduction": 0.08,
	})
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = CombatResolverScript.resolve(packet, armor, rng)
	_require(float(result["final_damage"]) > 0.0, "Combat should resolve positive damage")
	armor.free()

	var loot_table := load("res://resources/loot_tables/mvp_loot_table.tres")
	_require(loot_table != null, "Loot table should load")
	var rolled := false
	for _index in range(50):
		if loot_table.roll(rng, 5) != null:
			rolled = true
			break
	_require(rolled, "Loot table should be able to roll a drop")

	var cinder_boss := load("res://resources/enemies/cinder_bulwark.tres")
	var warden_boss := load("res://resources/enemies/depths_warden.tres")
	_assert_boss_definition(cinder_boss, "Cinder Bulwark")
	_assert_boss_definition(warden_boss, "Depths Warden")
	_require(cinder_boss.boss_loot_table.roll_guaranteed(rng, 5) != null, "Cinder boss table should roll guaranteed loot")
	_require(warden_boss.boss_loot_table.roll_guaranteed(rng, 10) != null, "Warden boss table should roll guaranteed loot")
	var normal_enemy_definitions := [
		load("res://resources/enemies/ashling.tres"),
		load("res://resources/enemies/glassmite.tres"),
		load("res://resources/enemies/iron_husk.tres"),
	]
	_assert_normal_enemy_definitions(normal_enemy_definitions)

	var player_scene := load("res://scenes/player/Player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	player.initialize(load("res://resources/classes/vanguard.tres"), weapon, load("res://scenes/items/Projectile.tscn"))
	_require(player.inventory.size() == 1, "Player should start with one weapon in inventory")
	_assert_weapon_affix_stats(player)
	await _assert_normal_enemy_runtime(normal_enemy_definitions, player)
	await _assert_elite_room_contains_iron_husk()
	await _assert_boss_runtime(cinder_boss, player)
	await _assert_boss_runtime(warden_boss, player)

	var enhancement_service = EnhancementServiceScript.new()
	enhancement_service.curve = load("res://resources/progression/basic_enhancement_curve.tres")
	root.add_child(enhancement_service)
	player.apply_enhancement_result(weapon, {"success": true, "level": 1})
	_require(player.get_enhancement_level(weapon) == 1, "Enhancement level should update")

	var effects := Node2D.new()
	var camera := Camera2D.new()
	var feedback = FeedbackServiceScript.new()
	root.add_child(effects)
	root.add_child(camera)
	root.add_child(feedback)
	feedback.configure(camera, effects)
	feedback.weapon_fired(Vector2.ZERO)
	feedback.enemy_hit(Vector2.ZERO, {"final_damage": 10.0, "critical": true})
	feedback.enemy_died(Vector2.ZERO, Color.RED)
	feedback.forge_result(true)
	_require(effects.get_child_count() > 0, "Feedback should spawn visual effects")

	await create_timer(0.7).timeout
	player.queue_free()
	enhancement_service.queue_free()
	feedback.queue_free()
	effects.queue_free()
	camera.queue_free()
	await process_frame

	print("SMOKE_OK")
	quit()

func _assert_player_death_state() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.configure_settings_path_for_test("user://smoke_death_settings_v006.json", true)
	main.configure_profile_path_for_test("user://smoke_death_profile_v002.json", true)
	main.start_run_for_test("77777")
	await process_frame
	var player = main.get_node("Player")
	var run = main.get_node("DungeonRun")
	var meta = main.get_node("MetaProgressionService")
	var packet = DamagePacketScript.new()
	packet.amount = 10000.0
	packet.hit_position = player.global_position
	player.take_damage(packet)
	await process_frame
	_require(player.is_dead, "Fatal damage should mark the player dead")
	_require(not player.input_enabled, "Fatal damage should disable player input")
	_require(not run.run_active, "Fatal damage should stop the active dungeon run")
	_require(main.get_node("HUD").run_end_overlay.visible == true, "Fatal damage should show the death overlay")
	_require(main.get_node("HUD").run_end_body.text.contains("77777"), "Run summary should include the run seed")
	_require(int(meta.profile_snapshot().get("souls", 0)) >= 1, "Fatal damage should still award souls")
	_require(int(meta.profile_snapshot().get("talent_points", 0)) >= 1, "Fatal damage should still award talent points")
	main.back_to_camp_for_test()
	_require(main.get_node("HUD").main_menu_overlay.visible == true, "Back to Camp should return to the main menu")
	_require(main.get_node("HUD").menu_last_run_label.text.contains("77777"), "Last run text should include the run seed")
	main.queue_free()
	await process_frame

func _assert_seeded_room_generation() -> void:
	var first := await _start_seeded_main("24680")
	var first_run = first.get_node("DungeonRun")
	var first_ids: Array = first_run.room_sequence_ids_for_test()
	_assert_seeded_room_rules(first_ids, "Seed 24680")
	_require(first_run.current_run_seed == 24680, "Manual seed should be used as the current run seed")
	_require(first.get_node("HUD").run_seed_label.text.contains("24680"), "HUD should show the manual seed")
	var first_choices: Array = first_run.pending_room_choice_ids_for_test()
	_require(first_choices.size() == 2, "Seed 24680 should offer two choices for floor two")
	_require(_ids_from_pool(first_choices, [&"combat_room", &"treasure_room", &"elite_room"]), "Floor two choices should come from the early route pool")

	var second := await _start_seeded_main("24680")
	var second_ids: Array = second.get_node("DungeonRun").room_sequence_ids_for_test()
	_require(first_ids == second_ids, "The same seed should generate the same room sequence")
	_require(first_choices == second.get_node("DungeonRun").pending_room_choice_ids_for_test(), "The same seed should preserve the first route offers")

	var route_a := await _chosen_route_for_seed("24680", [0, 0, 0])
	var route_b := await _chosen_route_for_seed("24680", [0, 0, 0])
	var route_c := await _chosen_route_for_seed("24680", [1, 0, 0])
	_require(route_a == route_b, "Same seed and same route choices should preserve chosen room history")
	_require(route_a != route_c, "Same seed with a different route choice should change chosen room history")

	var found_different := false
	for seed_text in ["13579", "97531", "86420"]:
		var candidate := await _start_seeded_main(seed_text)
		var candidate_ids: Array = candidate.get_node("DungeonRun").room_sequence_ids_for_test()
		_assert_seeded_room_rules(candidate_ids, "Seed %s" % seed_text)
		if candidate_ids != first_ids:
			found_different = true
		candidate.queue_free()
		await process_frame
	_require(found_different, "Different seeds should usually generate a different room sequence")

	first.queue_free()
	second.queue_free()
	await process_frame

func _ids_from_pool(ids: Array, pool: Array) -> bool:
	for id in ids:
		if not pool.has(id):
			return false
	return true

func _chosen_route_for_seed(seed_text: String, choices: Array) -> Array:
	var main := await _start_seeded_main(seed_text)
	var run = main.get_node("DungeonRun")
	for choice in choices:
		run._unlock_exit()
		run.choose_route_choice_for_test(int(choice))
		await process_frame
	var ids: Array = run.chosen_room_sequence_ids_for_test()
	main.queue_free()
	await process_frame
	return ids

func _start_seeded_main(seed_text: String) -> Node:
	var main_scene := load("res://scenes/main/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.configure_settings_path_for_test("user://smoke_seed_settings_%s.json" % seed_text, true)
	main.configure_profile_path_for_test("user://smoke_seed_profile_%s.json" % seed_text, true)
	main.get_node("HUD").set_seed_text_for_test(seed_text)
	main.start_run_for_test(main.get_node("HUD").get_seed_text_for_test())
	await process_frame
	return main

func _assert_seeded_room_rules(ids: Array, label: String) -> void:
	_require(ids.size() == 10, "%s should generate ten rooms" % label)
	_require(ids[0] == &"combat_room", "%s floor 1 should be Combat" % label)
	_require(ids[4] == &"mini_boss_room", "%s floor 5 should be Mini Boss" % label)
	_require(ids[9] == &"boss_room", "%s floor 10 should be Boss" % label)
	_require(_ids_contain_all(ids, 1, 3, [&"combat_room", &"treasure_room", &"elite_room"]), "%s floors 2-4 should contain Combat/Treasure/Elite" % label)
	_require(_ids_contain_all(ids, 5, 8, [&"forge_room", &"event_room", &"elite_room", &"treasure_room"]), "%s floors 6-9 should contain Forge/Event/Elite/Treasure" % label)

func _ids_contain_all(ids: Array, start_index: int, end_index: int, expected: Array) -> bool:
	var present := []
	for index in range(start_index, end_index + 1):
		present.append(ids[index])
	for id in expected:
		if not present.has(id):
			return false
	return true

func _assert_event_room_effects() -> void:
	await _assert_ember_pact_event()
	await _assert_iron_oath_event()
	await _assert_trial_altar_event()

func _assert_ember_pact_event() -> void:
	var event_definition := load("res://resources/events/ember_pact.tres")
	var main := await _start_event_room_fixture(event_definition)
	var player = main.get_node("Player")
	var run = main.get_node("DungeonRun")
	var station = _find_event_station(main)
	var weapon := load("res://resources/weapons/ember_snap.tres")
	var before_health: float = player.health
	var packet_before = weapon.create_damage_packet(player)
	player.modify_outgoing_packet(packet_before, weapon)
	station.interact(player)
	await process_frame
	var packet_after = weapon.create_damage_packet(player)
	player.modify_outgoing_packet(packet_after, weapon)
	_require(is_equal_approx(player.health, before_health - 18.0), "Ember Pact should spend current health")
	_require(packet_after.amount > packet_before.amount * 1.14, "Ember Pact should increase run damage")
	_require(not station.is_in_group("interactables"), "Resolved Ember Pact should become non-interactable")
	await _assert_event_exit_advances(main, run, player, "Ember Pact")
	main.queue_free()
	await process_frame

func _assert_iron_oath_event() -> void:
	var event_definition := load("res://resources/events/iron_oath.tres")
	var main := await _start_event_room_fixture(event_definition)
	var player = main.get_node("Player")
	var run = main.get_node("DungeonRun")
	var station = _find_event_station(main)
	var weapon := load("res://resources/weapons/ember_snap.tres")
	var armor = player.armor_component
	var before_durability: float = armor.current_durability
	var before_armor: float = armor.max_armor
	var packet_before = weapon.create_damage_packet(player)
	player.modify_outgoing_packet(packet_before, weapon)
	station.interact(player)
	await process_frame
	var packet_after = weapon.create_damage_packet(player)
	player.modify_outgoing_packet(packet_after, weapon)
	_require(armor.max_armor > before_armor, "Iron Oath should increase armor for the run")
	_require(is_equal_approx(armor.current_durability, before_durability - 25.0), "Iron Oath should spend armor durability")
	_require(packet_after.armor_pierce >= packet_before.armor_pierce + 0.09, "Iron Oath should increase armor pierce")
	await _assert_event_exit_advances(main, run, player, "Iron Oath")
	main.queue_free()
	await process_frame

func _assert_trial_altar_event() -> void:
	var event_definition := load("res://resources/events/trial_altar.tres")
	var main := await _start_event_room_fixture(event_definition)
	var run = main.get_node("DungeonRun")
	var player = main.get_node("Player")
	var station = _find_event_station(main)
	_require(run.exit_unlocked, "Trial fixture should start with an unlocked event room exit")
	station.interact(player)
	await process_frame
	_require(not run.exit_unlocked, "Trial Altar should lock the exit while the trial enemy lives")
	_require(run.live_enemies.size() == 1, "Trial Altar should spawn one trial enemy")
	var enemy = run.live_enemies[0]
	_require(enemy.definition.id == &"iron_husk", "Trial Altar should spawn an Iron Husk")
	_require(enemy.is_elite_enemy(), "Trial Altar enemy should carry an elite affix")
	_kill_enemy_for_test(enemy, player)
	await process_frame
	await process_frame
	_require(run.live_enemies.is_empty(), "Trial enemy death should clear the trial")
	_require(run.exit_unlocked, "Trial completion should unlock the exit")
	_require(_find_reward_chest(main) != null, "Trial completion should spawn a reward chest")
	await _assert_event_exit_advances(main, run, player, "Trial Altar")
	main.queue_free()
	await process_frame

func _assert_event_exit_advances(main: Node, run: Node, player: Node, label: String) -> void:
	var exit_portal = main.get_node("ExitPortal")
	_require(run.exit_unlocked, "%s should leave the event-room exit unlocked after completion" % label)
	_require(exit_portal.visible and exit_portal.is_in_group("interactables"), "%s should expose an interactable exit portal" % label)
	player.global_position = exit_portal.global_position
	await physics_frame
	player.refresh_interaction_target()
	await process_frame
	_require(player.current_interactable == exit_portal, "%s should select the exit through real overlap refresh" % label)
	_require(main.get_node("HUD").interaction_label.text.contains("Enter Next Room"), "%s should show the exit prompt near the portal" % label)
	var before_floor: int = run.current_floor
	player.force_interact_with(player.current_interactable)
	await process_frame
	if main.get_node("HUD").is_route_choice_visible_for_test():
		main.get_node("HUD").choose_route_for_test(0)
		await process_frame
	_require(run.current_floor == before_floor + 1, "%s should allow the player to leave through the exit" % label)

func _start_event_room_fixture(event_definition: Resource) -> Node:
	var main_scene := load("res://scenes/main/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.configure_settings_path_for_test("user://smoke_event_settings_v006.json", true)
	main.configure_profile_path_for_test("user://smoke_event_profile_v003.json", true)
	main.start_run_for_test()
	await process_frame
	var run = main.get_node("DungeonRun")
	var event_floor: int = run.floor_for_room_id_for_test(&"event_room")
	_require(event_floor >= 6 and event_floor <= 9, "Event fixture should locate the generated event room")
	run.current_floor = event_floor
	run.force_next_event_for_test(event_definition)
	run._start_current_room()
	await process_frame
	_require(run.current_room_definition.id == &"event_room", "Event fixture should start on the generated event room")
	_require(_find_event_station(main) != null, "Event fixture should spawn an event station")
	return main

func _find_event_station(main: Node) -> Node:
	for child in main.get_node("Interactables").get_children():
		if child.get("event_definition") != null and child.has_method("interact"):
			return child
	return null

func _find_reward_chest(main: Node) -> Node:
	for child in main.get_node("Interactables").get_children():
		if child.has_method("get_prompt_text") and child.get_prompt_text() == "Open Chest":
			return child
	return null

func _kill_enemy_for_test(enemy: Node, player: Node) -> void:
	var packet = DamagePacketScript.new()
	packet.amount = 99999.0
	packet.source = player
	packet.element = &"physical"
	packet.armor_pierce = 1.0
	packet.hit_position = enemy.global_position
	packet.hit_direction = Vector2.RIGHT
	enemy.take_damage(packet)

func _assert_pixel_art_assets() -> void:
	var assets := [
		["res://assets/sprites/characters/player_vanguard.png", 32, 32],
		["res://assets/sprites/enemies/ashling.png", 32, 32],
		["res://assets/sprites/enemies/glassmite.png", 32, 32],
		["res://assets/sprites/enemies/iron_husk.png", 32, 32],
		["res://assets/sprites/enemies/cinder_bulwark.png", 48, 48],
		["res://assets/sprites/enemies/depths_warden.png", 64, 64],
		["res://assets/sprites/items/pickup_weapon.png", 32, 32],
		["res://assets/sprites/items/pickup_equipment.png", 32, 32],
		["res://assets/sprites/effects/player_projectile.png", 32, 32],
		["res://assets/sprites/effects/boss_projectile.png", 32, 32],
		["res://assets/sprites/interactables/chest_body.png", 32, 32],
		["res://assets/sprites/interactables/chest_lid.png", 32, 32],
		["res://assets/sprites/interactables/forge_station.png", 32, 32],
		["res://assets/sprites/interactables/forge_core.png", 32, 32],
		["res://assets/sprites/interactables/event_station.png", 32, 32],
		["res://assets/sprites/interactables/event_core.png", 32, 32],
		["res://assets/sprites/interactables/exit_portal.png", 32, 32],
		["res://assets/sprites/environment/dungeon_floor_tile.png", 16, 16],
		["res://assets/sprites/environment/dungeon_wall_tile.png", 16, 16],
		["res://assets/sprites/environment/dungeon_floor_panel.png", 960, 540],
		["res://assets/sprites/environment/dungeon_wall_horizontal.png", 960, 32],
		["res://assets/sprites/environment/dungeon_wall_vertical.png", 32, 540],
	]
	for asset in assets:
		_assert_png_asset(asset[0], asset[1], asset[2])

func _assert_png_asset(path: String, width: int, height: int) -> void:
	var texture := load(path)
	_require(texture is Texture2D, "%s should import as a Texture2D" % path)
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	_require(error == OK, "%s should load as an Image" % path)
	_require(image.get_width() == width and image.get_height() == height, "%s should be %dx%d" % [path, width, height])
	_require(_image_has_visible_pixel(image), "%s should not be fully transparent" % path)

func _image_has_visible_pixel(image: Image) -> bool:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				return true
	return false

func _assert_sprite_scene_visuals(main: Node) -> void:
	_assert_sprite_node(main.get_node("Player"), "BodySprite", "Player should use a pixel sprite")
	var arena = main.get_node("Arena")
	_assert_texture_rect(arena, "FloorTexture", "Arena should use a pixel floor texture")
	_assert_texture_rect(arena, "NorthWallTexture", "Arena should use pixel wall textures")
	_assert_sprite_node(main.get_node("ExitPortal"), "Ring", "Exit portal should use a pixel sprite")

	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var player = main.get_node("Player")
	for definition in [
		load("res://resources/enemies/ashling.tres"),
		load("res://resources/enemies/glassmite.tres"),
		load("res://resources/enemies/iron_husk.tres"),
		load("res://resources/enemies/cinder_bulwark.tres"),
		load("res://resources/enemies/depths_warden.tres"),
	]:
		var enemy = enemy_scene.instantiate()
		enemy.definition = definition
		enemy.target = player
		root.add_child(enemy)
		await process_frame
		var sprite := _assert_sprite_node(enemy, "BodySprite", "%s should use a pixel sprite" % definition.display_name)
		_require(sprite.texture == definition.visual_texture, "%s should apply its definition texture" % definition.display_name)
		enemy.queue_free()
		await process_frame

	for scene_info in [
		["res://scenes/items/Pickup.tscn", ["Shape"]],
		["res://scenes/items/Projectile.tscn", ["Shape"]],
		["res://scenes/interactables/RewardChest.tscn", ["BodyShape", "LidShape"]],
		["res://scenes/interactables/ForgeStation.tscn", ["BaseShape", "CoreShape"]],
		["res://scenes/interactables/EventStation.tscn", ["BaseShape", "CoreShape"]],
	]:
		var scene: PackedScene = load(scene_info[0])
		var instance = scene.instantiate()
		root.add_child(instance)
		await process_frame
		for node_path in scene_info[1]:
			_assert_sprite_node(instance, node_path, "%s should expose %s as a pixel sprite" % [scene_info[0], node_path])
		instance.queue_free()
		await process_frame

func _assert_sprite_node(parent: Node, node_path: NodePath, message: String) -> Sprite2D:
	var sprite := parent.get_node_or_null(node_path) as Sprite2D
	_require(sprite != null, message)
	_require(sprite.texture != null, "%s should have a texture" % message)
	_require(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s should use nearest filtering" % message)
	return sprite

func _assert_texture_rect(parent: Node, node_path: NodePath, message: String) -> TextureRect:
	var texture_rect := parent.get_node_or_null(node_path) as TextureRect
	_require(texture_rect != null, message)
	_require(texture_rect.texture != null, "%s should have a texture" % message)
	_require(texture_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s should use nearest filtering" % message)
	return texture_rect

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _assert_settings_menu_localization(main: Node) -> void:
	var hud = main.get_node("HUD")
	var localization = main.get_node("LocalizationService")
	_require(localization.language() == "en", "Default settings language should be English")
	main.open_settings_for_test()
	await process_frame
	_require(hud.is_settings_visible_for_test(), "Settings overlay should open from camp")
	main.select_language_for_test("zh_CN")
	await process_frame
	_require(localization.language() == "zh_CN", "Settings should switch to Chinese immediately")
	_require(hud.get_language_option_code_for_test() == "zh_CN", "Language option should select zh_CN")
	_require(hud.start_run_button.text.contains("开始"), "Camp Start Run button should localize to Chinese")
	_require(hud.menu_currency_label.text.contains("金币"), "Camp currencies should localize to Chinese")
	_require(hud.talent_buttons[&"vital_core"].text.contains("生命核心"), "Talent button should localize to Chinese")
	main.select_language_for_test("en")
	await process_frame
	_require(localization.language() == "en", "Settings should switch back to English")
	_require(hud.start_run_button.text == "Start Run", "Camp Start Run button should return to English")
	main.close_settings_for_test()
	await process_frame
	_require(not hud.is_settings_visible_for_test(), "Settings overlay should close")
	await _assert_settings_persistence(main)

func _assert_settings_persistence(main: Node) -> void:
	var settings_path := "user://smoke_settings_persist_v006.json"
	main.configure_settings_path_for_test(settings_path, true)
	main.select_language_for_test("zh_CN")
	await process_frame
	var main_scene := load("res://scenes/main/Main.tscn")
	var clone = main_scene.instantiate()
	root.add_child(clone)
	await process_frame
	clone.configure_settings_path_for_test(settings_path, false)
	await process_frame
	_require(clone.get_node("LocalizationService").language() == "zh_CN", "Settings language should persist after re-instancing Main")
	clone.queue_free()
	await process_frame
	main.configure_settings_path_for_test("user://smoke_settings_v006.json", true)
	await process_frame

func _assert_localization_coverage(localization: Node) -> void:
	var resources_with_desc := [
		"res://resources/classes/vanguard.tres",
		"res://resources/weapons/ember_snap.tres",
		"res://resources/weapons/frostline_staff.tres",
		"res://resources/weapons/volt_spear.tres",
		"res://resources/weapons/boss/warden_rift_staff.tres",
		"res://resources/weapons/rift_needle.tres",
		"res://resources/weapons/null_orbit_staff.tres",
		"res://resources/weapons/astral_repeater.tres",
		"res://resources/weapons/phase_halberd.tres",
		"res://resources/equipment/ashguard_helm.tres",
		"res://resources/equipment/rivet_chestplate.tres",
		"res://resources/equipment/quickspark_gloves.tres",
		"res://resources/equipment/trailblazer_boots.tres",
		"res://resources/equipment/lumen_ring.tres",
		"res://resources/equipment/riftseer_hood.tres",
		"res://resources/equipment/voidglass_mantle.tres",
		"res://resources/equipment/astral_weave_grips.tres",
		"res://resources/equipment/phasewalk_soles.tres",
		"res://resources/equipment/singularity_charm.tres",
		"res://resources/equipment/orbit_signet.tres",
		"res://resources/equipment/boss/cinderplate_core.tres",
		"res://resources/equipment/boss/bulwark_ember_ring.tres",
		"res://resources/equipment/boss/abyssal_guard_helm.tres",
		"res://resources/affixes/armor_piercing.tres",
		"res://resources/affixes/ember_burst.tres",
		"res://resources/affixes/frostbite.tres",
		"res://resources/affixes/storm_chain.tres",
		"res://resources/affixes/rift_echo.tres",
		"res://resources/affixes/gravity_well.tres",
		"res://resources/enemies/ashling.tres",
		"res://resources/enemies/glassmite.tres",
		"res://resources/enemies/iron_husk.tres",
		"res://resources/enemies/cinder_bulwark.tres",
		"res://resources/enemies/depths_warden.tres",
		"res://resources/elite_affixes/flaming.tres",
		"res://resources/elite_affixes/swift.tres",
		"res://resources/elite_affixes/juggernaut.tres",
		"res://resources/elite_affixes/phasing.tres",
		"res://resources/elite_affixes/vampiric.tres",
		"res://resources/events/ember_pact.tres",
		"res://resources/events/iron_oath.tres",
		"res://resources/events/trial_altar.tres",
		"res://resources/events/starless_lens.tres",
		"res://resources/events/rift_anchor.tres",
	]
	var room_resources := [
		"res://resources/dungeon/combat_room.tres",
		"res://resources/dungeon/elite_room.tres",
		"res://resources/dungeon/treasure_room.tres",
		"res://resources/dungeon/forge_room.tres",
		"res://resources/dungeon/event_room.tres",
		"res://resources/dungeon/mini_boss_room.tres",
		"res://resources/dungeon/boss_room.tres",
	]
	for path in resources_with_desc:
		var resource := load(path)
		_require(resource != null, "%s should load for localization coverage" % path)
		for language in ["en", "zh_CN"]:
			_require(localization.has_resource_translation(resource, "name", language), "%s should have %s name localization" % [path, language])
			_require(localization.has_resource_translation(resource, "desc", language), "%s should have %s description localization" % [path, language])
		if resource.has_method("get_prompt"):
			for language in ["en", "zh_CN"]:
				_require(localization.has_resource_translation(resource, "prompt", language), "%s should have %s prompt localization" % [path, language])
	for path in room_resources:
		var resource := load(path)
		_require(resource != null, "%s should load for room localization coverage" % path)
		for language in ["en", "zh_CN"]:
			_require(localization.has_resource_translation(resource, "name", language), "%s should have %s room name localization" % [path, language])
	for key in [
		"talent.vital_core.name",
		"talent.vital_core.desc",
		"talent.reinforced_plating.name",
		"talent.reinforced_plating.desc",
		"talent.weapon_training.name",
		"talent.weapon_training.desc",
		"talent.scavenger_instinct.name",
		"talent.scavenger_instinct.desc",
	]:
		_require(localization.has_text(key, "en") and localization.has_text(key, "zh_CN"), "%s should have English and Chinese text" % key)

func _assert_player_mouse_facing(player: Node2D) -> void:
	var target := player.global_position + Vector2(180.0, 0.0)
	player.face_position_for_test(target, 1.0)
	var expected: float = player.target_facing_rotation_for_test(target)
	_require(_angle_distance(player.body_rotation_for_test(), expected) < 0.02, "Player BodySprite should rotate toward a target point")

func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))

func _assert_meta_menu_and_talents(main: Node) -> void:
	var meta = main.get_node("MetaProgressionService")
	var hud = main.get_node("HUD")
	meta.profile["talent_points"] = 20
	meta.save_profile()
	main.purchase_talent_for_test(&"vital_core")
	main.purchase_talent_for_test(&"reinforced_plating")
	main.purchase_talent_for_test(&"weapon_training")
	main.purchase_talent_for_test(&"scavenger_instinct")
	_require(meta.talent_level(&"vital_core") == 1, "Vital Core should be purchasable")
	_require(meta.talent_level(&"reinforced_plating") == 1, "Reinforced Plating should be purchasable")
	_require(meta.talent_level(&"weapon_training") == 1, "Weapon Training should be purchasable")
	_require(meta.talent_level(&"scavenger_instinct") == 1, "Scavenger Instinct should be purchasable")
	_require(int(meta.profile_snapshot().get("talent_points")) == 16, "Talent purchases should spend one point each at level zero")
	_require(hud.menu_currency_label.text.contains("Talent Points 16"), "Camp menu should refresh currencies after talent purchases")
	main.reset_save_for_test()
	_require(meta.talent_level(&"vital_core") == 0, "Reset Save should clear talents")
	_require(int(meta.profile_snapshot().get("talent_points")) == 0, "Reset Save should clear talent points")
	meta.profile["talent_points"] = 20
	meta.save_profile()
	main.purchase_talent_for_test(&"vital_core")
	main.purchase_talent_for_test(&"reinforced_plating")
	main.purchase_talent_for_test(&"weapon_training")
	main.purchase_talent_for_test(&"scavenger_instinct")

func _assert_equipment_detail_ui(main: Node) -> void:
	var player = main.get_node("Player")
	var hud = main.get_node("HUD")
	var panel = hud.equipment_panel
	var forge_panel = hud.forge_panel
	var default_detail: String = panel.get_detail_text_for_test()
	_require(default_detail.contains("Ember Snap"), "Equipment detail should default to current weapon")
	_require(default_detail.contains("Ember Burst"), "Current weapon detail should show its affix")
	_require(default_detail.contains("18% Fire Burst"), "Ember Burst detail should show proc chance")

	var volt := load("res://resources/weapons/volt_spear.tres")
	_require(volt != null, "Volt Spear should load for detail UI")
	_add_inventory_item_for_test(player, volt)
	panel.select_item_for_test(volt)
	var volt_detail: String = panel.get_detail_text_for_test()
	_require(volt_detail.contains("Volt Spear"), "Selected weapon detail should show name")
	_require(volt_detail.contains("Compare"), "Selected weapon detail should include comparison text")
	_require(volt_detail.contains("Storm Chain"), "Volt Spear detail should show Storm Chain")
	_require(volt_detail.contains("Armor Piercing"), "Volt Spear detail should show Armor Piercing")
	_require(volt_detail.contains("+0.15 Attack Speed"), "Storm Chain detail should show attack speed modifier")
	_require(volt_detail.contains("+8% Armor Pierce"), "Armor Piercing detail should show armor pierce modifier")
	_require(forge_panel.selected_item == null, "Forge panel should not change until Send to Forge is used")
	_require(panel.is_send_to_forge_disabled_for_test(), "Send to Forge should be disabled outside forge rooms")

	var helm := load("res://resources/equipment/ashguard_helm.tres")
	_require(helm != null, "Ashguard Helm should load for detail UI")
	_add_inventory_item_for_test(player, helm)
	panel.set_filter_for_test("weapons")
	var weapon_names: Array = panel.get_visible_item_names_for_test()
	_require(weapon_names.has("Volt Spear"), "Weapons filter should include weapons")
	_require(not weapon_names.has("Ashguard Helm"), "Weapons filter should hide equipment")
	panel.set_filter_for_test("equipment")
	var equipment_names: Array = panel.get_visible_item_names_for_test()
	_require(equipment_names.has("Ashguard Helm"), "Equipment filter should include equipment")
	_require(not equipment_names.has("Volt Spear"), "Equipment filter should hide weapons")
	panel.set_filter_for_test("all")
	panel.set_sort_for_test("name")
	var sorted_names: Array = panel.get_visible_item_names_for_test()
	_require(sorted_names.size() >= 3 and sorted_names[0] == "Ashguard Helm", "Name sorting should be stable and alphabetical")
	panel.select_item_for_test(helm)
	var helm_detail: String = panel.get_detail_text_for_test()
	_require(helm_detail.contains("Ashguard Helm"), "Selected equipment detail should show name")
	_require(helm_detail.contains("Compare"), "Selected equipment detail should include comparison text")
	_require(helm_detail.contains("Helmet"), "Selected equipment detail should show slot")
	_require(helm_detail.contains("+10 Max Health"), "Selected equipment detail should show stat modifiers")
	_require(not panel.is_equip_disabled_for_test(), "Equip should be enabled for unequipped inventory equipment")
	panel.equip_selected_for_test()
	_require(player.equipped.has(0) and player.equipped[0] == helm, "Equip should place selected equipment into its slot")
	panel.select_slot_for_test(0)
	_require(panel.get_detail_text_for_test().contains("Currently equipped"), "Clicking an equipped slot should show current equipment state")
	_require(panel.is_equip_disabled_for_test(), "Equip should disable for already equipped slot selections")

	hud.set_forge_available(true)
	panel.select_item_for_test(volt)
	_require(not panel.is_send_to_forge_disabled_for_test(), "Send to Forge should enable in forge rooms for valid selections")
	panel.send_selected_to_forge_for_test()
	_require(forge_panel.selected_item == volt, "Forge panel should receive selected weapon only from Send to Forge")
	forge_panel.set_selected_item(volt)
	player.apply_enhancement_result(volt, {"success": false, "level": -1})
	_require(forge_panel.selected_item == null, "Forge panel should clear a broken or removed item")
	_require(forge_panel.forge_button.disabled, "Forge button should disable after selected item is removed")
	hud.set_forge_available(false)

func _add_inventory_item_for_test(player: Node, item: Resource) -> void:
	if player.inventory.has(item):
		return
	player.inventory.append(item)
	player.inventory_changed.emit(player.inventory.size())
	player.loadout_changed.emit(player.inventory, player.equipped)

func _assert_pickup_preview_and_interaction(main: Node) -> void:
	var pickup_scene := load("res://scenes/items/Pickup.tscn")
	var player = main.get_node("Player")
	var hud = main.get_node("HUD")
	var pickups = main.get_node("Pickups")
	var before_inventory: int = player.inventory.size()

	var weapon_pickup = pickup_scene.instantiate()
	weapon_pickup.item_definition = load("res://resources/weapons/volt_spear.tres")
	weapon_pickup.global_position = player.global_position
	pickups.add_child(weapon_pickup)
	await process_frame
	_require(player.inventory.size() == before_inventory, "Touching a pickup should not auto-collect it")
	_require(weapon_pickup.is_in_group("interactables"), "Pickup should join the interaction group")
	player._on_interaction_area_entered(weapon_pickup)
	await process_frame
	_require(hud.interaction_label.text.contains("Pick Up Volt Spear"), "Pickup should drive the interaction prompt")
	_require(hud.is_pickup_preview_visible_for_test(), "Weapon pickup should show the preview panel")
	var weapon_preview: String = hud.get_pickup_preview_text_for_test()
	_require(weapon_preview.contains("Pickup: Volt Spear"), "Weapon preview should name the pickup")
	_require(weapon_preview.contains("Current: Ember Snap"), "Weapon preview should compare against the current weapon")
	_require(weapon_preview.contains("Attack Speed"), "Weapon preview should include attack speed comparison")
	_require(weapon_preview.contains("Armor Piercing"), "Weapon preview should include affix names")
	player.force_interact_with(weapon_pickup)
	await process_frame
	_require(player.inventory.size() == before_inventory + 1, "Interacting with pickup should add it to inventory")
	_require(not is_instance_valid(weapon_pickup), "Interacting with pickup should remove it from the scene")
	_require(not hud.is_pickup_preview_visible_for_test(), "Pickup preview should hide after collecting")

	var equipment_pickup = pickup_scene.instantiate()
	equipment_pickup.item_definition = load("res://resources/equipment/ashguard_helm.tres")
	equipment_pickup.global_position = player.global_position
	pickups.add_child(equipment_pickup)
	await process_frame
	player._on_interaction_area_entered(equipment_pickup)
	await process_frame
	_require(hud.is_pickup_preview_visible_for_test(), "Equipment pickup should show the preview panel")
	var equipment_preview: String = hud.get_pickup_preview_text_for_test()
	_require(equipment_preview.contains("Pickup: Ashguard Helm"), "Equipment preview should name the pickup")
	_require(equipment_preview.contains("Current: Ashguard Helm"), "Equipment preview should compare against the matching equipped slot")
	_require(equipment_preview.contains("Max Health"), "Equipment preview should include stat comparison")
	player.force_interact_with(equipment_pickup)
	await process_frame
	_require(player.equipped.has(0), "Equipment pickup interaction should equip the item")

func _assert_runtime_localization(main: Node) -> void:
	var hud = main.get_node("HUD")
	var player = main.get_node("Player")
	var pickups = main.get_node("Pickups")
	var pickup_scene := load("res://scenes/items/Pickup.tscn")
	main.select_language_for_test("zh_CN")
	await process_frame
	_require(hud.health_label.text.contains("生命"), "HUD health label should localize in-run")
	_require(hud.armor_label.text.contains("护甲"), "HUD armor label should localize in-run")
	_require(hud.equipment_button.text == "装备", "Equipment button should localize in-run")
	_require(hud.settings_button.text == "设置", "Settings button should localize in-run")
	hud.show_route_choices(2, [load("res://resources/dungeon/combat_room.tres"), load("res://resources/dungeon/elite_room.tres")])
	_require(hud.is_route_choice_visible_for_test(), "Route choice overlay should be visible for localization")
	_require(hud.get_route_choice_text_for_test(0).contains("第 2 层"), "Route choice buttons should localize floor labels")
	_require(hud.get_route_choice_text_for_test(0).contains("战斗房"), "Route choice buttons should localize room names")
	hud.hide_route_choices()
	hud.equipment_panel.select_item_for_test(player.active_weapon)
	_require(hud.equipment_panel.get_detail_text_for_test().contains("伏特长矛"), "Equipment panel item details should localize")
	hud.forge_panel.set_selected_item(load("res://resources/weapons/ember_snap.tres"))
	_require(hud.forge_panel.selected_label.text.contains("已选"), "Forge panel labels should localize")

	var pickup = pickup_scene.instantiate()
	pickup.item_definition = load("res://resources/weapons/volt_spear.tres")
	pickup.global_position = player.global_position
	pickups.add_child(pickup)
	await process_frame
	player._on_interaction_area_entered(pickup)
	await process_frame
	_require(hud.interaction_label.text.contains("拾取 伏特长矛"), "Pickup interaction prompt should localize")
	_require(hud.get_pickup_preview_text_for_test().contains("拾取：伏特长矛"), "Pickup preview should localize")
	player.force_interact_with(pickup)
	await process_frame
	main.select_language_for_test("en")
	await process_frame
	_require(hud.health_label.text.contains("HP"), "HUD health label should return to English")

func _assert_void_arcana_content(main: Node) -> void:
	var hud = main.get_node("HUD")
	var player = main.get_node("Player")
	var localization = main.get_node("LocalizationService")
	var loot_table := load("res://resources/loot_tables/mvp_loot_table.tres")
	_require(loot_table != null, "Loot table should load for void arcana content")

	var weapon_paths := [
		"res://resources/weapons/rift_needle.tres",
		"res://resources/weapons/null_orbit_staff.tres",
		"res://resources/weapons/astral_repeater.tres",
		"res://resources/weapons/phase_halberd.tres",
	]
	var equipment_paths := [
		"res://resources/equipment/riftseer_hood.tres",
		"res://resources/equipment/voidglass_mantle.tres",
		"res://resources/equipment/astral_weave_grips.tres",
		"res://resources/equipment/phasewalk_soles.tres",
		"res://resources/equipment/singularity_charm.tres",
		"res://resources/equipment/orbit_signet.tres",
	]
	var affix_paths := [
		"res://resources/affixes/rift_echo.tres",
		"res://resources/affixes/gravity_well.tres",
	]
	var event_paths := [
		"res://resources/events/starless_lens.tres",
		"res://resources/events/rift_anchor.tres",
	]
	var loot_ids := []
	for entry in loot_table.entries:
		if entry != null and entry.get("item") != null:
			loot_ids.append(entry.get("item").get("id"))

	for path in weapon_paths + equipment_paths:
		var item: Resource = load(path)
		_require(item != null, "%s should load" % path)
		_require(loot_ids.has(item.get("id")), "%s should be present in the global loot table" % item.get("id"))
	for path in affix_paths:
		var affix: Resource = load(path)
		_require(affix != null and not str(affix.get("effect_id")).is_empty(), "%s should load with an effect id" % path)
	for path in event_paths:
		var event: Resource = load(path)
		_require(event != null and event.has_method("get_prompt"), "%s should load as an event definition" % path)

	var null_staff := load("res://resources/weapons/null_orbit_staff.tres")
	_add_inventory_item_for_test(player, null_staff)
	hud.equipment_panel.select_item_for_test(null_staff)
	var staff_detail: String = hud.equipment_panel.get_detail_text_for_test()
	_require(staff_detail.contains("Null Orbit Staff"), "Void arcana weapon detail should show weapon name")
	_require(staff_detail.contains("Gravity Well"), "Void arcana weapon detail should show Gravity Well")
	_require(staff_detail.contains("14% Gravity Well"), "Gravity Well detail should show proc chance")

	var charm := load("res://resources/equipment/singularity_charm.tres")
	_add_inventory_item_for_test(player, charm)
	hud.equipment_panel.select_item_for_test(charm)
	var charm_detail: String = hud.equipment_panel.get_detail_text_for_test()
	_require(charm_detail.contains("Singularity Charm"), "Void arcana equipment detail should show equipment name")
	_require(charm_detail.contains("+8% Damage"), "Singularity Charm should show damage modifier")
	_require(charm_detail.contains("+0.26 Energy Recovery"), "Singularity Charm should show energy recovery modifier")

	main.select_language_for_test("zh_CN")
	await process_frame
	var rift_needle := load("res://resources/weapons/rift_needle.tres")
	_add_inventory_item_for_test(player, rift_needle)
	hud.equipment_panel.select_item_for_test(rift_needle)
	var zh_detail: String = hud.equipment_panel.get_detail_text_for_test()
	_require(zh_detail.contains("裂隙针"), "Void arcana weapon name should localize to Chinese")
	_require(zh_detail.contains("裂隙回响"), "Rift Echo affix should localize to Chinese")
	_require(localization.resource_name(load("res://resources/events/starless_lens.tres")) == "无星透镜", "Void arcana event should localize to Chinese")
	main.select_language_for_test("en")
	await process_frame

func _assert_readable_ui_thresholds(main: Node) -> void:
	var hud = main.get_node("HUD")
	_require(hud.health_label.get_theme_font_size("font_size") >= 20, "HUD labels should use readable font sizes")
	_require(hud.equipment_button.get_theme_font_size("font_size") >= 20, "HUD buttons should use readable font sizes")
	_require(hud.equipment_button.custom_minimum_size.y >= 44.0, "HUD buttons should have larger touch targets")
	_require(hud.equipment_panel.detail_text.custom_minimum_size.y >= 240.0, "Equipment v2 detail area should be readable and scrollable")
	_require(hud.equipment_panel.inventory_list.auto_height == false, "Equipment inventory list should keep a fixed scrollable height")
	_require(hud.equipment_panel.close_button != null, "Equipment panel should expose an internal close button")
	_require(hud.equipment_panel.send_to_forge_button != null, "Equipment panel should expose Send to Forge")
	_require(hud.pickup_preview_text.get_theme_font_size("normal_font_size") >= 18, "Pickup preview text should be readable")

	var pickup_scene := load("res://scenes/items/Pickup.tscn")
	var pickup = pickup_scene.instantiate()
	root.add_child(pickup)
	await process_frame
	_require(pickup.label.get_theme_font_size("font_size") >= 16, "Pickup labels should be larger than the original tiny label")
	pickup.queue_free()

func _assert_boss_definition(definition: Resource, label: String) -> void:
	_require(definition != null, "%s definition should load" % label)
	_require(definition.visual_texture != null, "%s should have a pixel visual texture" % label)
	_require(definition.boss_skill_profile != null, "%s should have a boss skill profile" % label)
	_require(definition.boss_mechanic_profile != null, "%s should have a boss mechanic profile" % label)
	_require(definition.boss_loot_table != null, "%s should have a boss loot table" % label)
	_require(definition.boss_skill_profile.skill_ids.size() == 3, "%s should have three boss skills" % label)

func _assert_normal_enemy_definitions(definitions: Array) -> void:
	_require(definitions.size() == 3, "MVP should load three normal enemy definitions")
	for definition in definitions:
		_require(definition != null, "Normal enemy definition should load")
		_require(definition.visual_texture != null, "%s should have a pixel visual texture" % definition.display_name)
		_require(definition.behavior_profile != null, "%s should have a behavior profile" % definition.display_name)
		_require(float(definition.behavior_profile.get("attack_range")) > 0.0, "%s behavior should define attack range" % definition.display_name)

func _assert_weapon_affix_stats(player: Node) -> void:
	var weapon := load("res://resources/weapons/volt_spear.tres")
	_require(weapon != null, "Affix stat weapon should load")
	var packet = weapon.create_damage_packet(player)
	player.modify_outgoing_packet(packet, weapon)
	_require(packet.armor_pierce >= 0.2, "Armor Piercing affix should modify outgoing armor pierce")
	_require(player.attack_rate_for_weapon(weapon) > weapon.attack_rate, "Storm Chain affix should modify attack speed")

func _assert_normal_enemy_runtime(definitions: Array, player: Node2D) -> void:
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	for definition in definitions:
		_cleanup_boss_runtime_nodes()
		var enemy = enemy_scene.instantiate()
		enemy.definition = definition
		enemy.target = player
		enemy.global_position = Vector2(220, 220)
		var attack_range: float = float(definition.behavior_profile.get("attack_range"))
		player.global_position = enemy.global_position + Vector2(attack_range + 72.0, 0)
		root.add_child(enemy)
		await process_frame
		await create_timer(0.08).timeout
		_require(enemy.has_visited_normal_state(&"chase"), "%s should enter Chase" % definition.display_name)

		player.global_position = enemy.global_position + Vector2(maxf(attack_range * 0.55, 24.0), 0)
		enemy.force_normal_state_for_test(&"windup")
		_require(enemy.get_normal_state_name() == &"windup", "%s should enter Windup" % definition.display_name)
		var wait_time: float = float(definition.behavior_profile.get("windup_duration")) + float(definition.behavior_profile.get("attack_duration")) + 0.14
		await create_timer(wait_time).timeout
		_require(enemy.has_visited_normal_state(&"attack"), "%s should enter Attack" % definition.display_name)
		_require(enemy.has_visited_normal_state(&"recover"), "%s should enter Recover" % definition.display_name)

		var packet = load("res://resources/weapons/ember_snap.tres").create_damage_packet(player)
		packet.amount = 3.0
		packet.crit_chance = 0.0
		packet.hit_direction = Vector2.RIGHT
		packet.hit_position = enemy.global_position
		packet.knockback_force = 80.0
		enemy.take_damage(packet)
		_require(enemy.get_normal_state_name() == &"stagger", "%s should enter Stagger after hit" % definition.display_name)
		enemy.queue_free()
		_cleanup_boss_runtime_nodes()
		await process_frame

func _assert_elite_room_contains_iron_husk() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.configure_settings_path_for_test("user://smoke_elite_settings_v006.json", true)
	main.configure_profile_path_for_test("user://smoke_elite_profile_v002.json", true)
	main.start_run_for_test()
	await process_frame
	var run = main.get_node("DungeonRun")
	var elite_floor: int = run.floor_for_room_id_for_test(&"elite_room")
	_require(elite_floor > 0, "Elite cadence fixture should locate a generated elite room")
	run.current_floor = elite_floor
	run._start_current_room()
	await process_frame
	var has_iron_husk := false
	for enemy in run.live_enemies:
		if is_instance_valid(enemy) and enemy.definition != null and enemy.definition.id == &"iron_husk":
			has_iron_husk = true
			break
	_require(has_iron_husk, "Elite rooms should include Iron Husk as the pressure core")
	main.queue_free()
	await process_frame

func _assert_boss_runtime(definition: Resource, player: Node2D) -> void:
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var boss = enemy_scene.instantiate()
	boss.definition = definition
	boss.target = player
	root.add_child(boss)
	await process_frame
	boss.force_normal_state_for_test(&"stagger")
	_require(boss.get_normal_state_name() == &"boss", "%s should stay outside normal enemy state machine" % definition.display_name)
	_require(not boss.has_visited_normal_state(&"stagger"), "%s should not enter normal Stagger" % definition.display_name)
	_require(boss.force_phase_two_for_test(), "%s should enter phase two" % definition.display_name)
	_require(not boss.force_phase_two_for_test(), "%s phase two should trigger only once" % definition.display_name)
	var packet = load("res://resources/weapons/ember_snap.tres").create_damage_packet(player)
	var health_before: float = boss.health
	boss.take_damage(packet)
	_require(is_equal_approx(boss.health, health_before), "%s should ignore damage during invulnerable window" % definition.display_name)
	boss.queue_free()
	await process_frame

	for skill_id in definition.boss_skill_profile.skill_ids:
		await _assert_boss_skill_spawns(definition, player, skill_id)

func _assert_boss_skill_spawns(definition: Resource, player: Node2D, skill_id: StringName) -> void:
	_cleanup_boss_runtime_nodes()
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var boss = enemy_scene.instantiate()
	boss.definition = definition
	boss.target = player
	boss.global_position = Vector2(240, 240)
	player.global_position = Vector2(380, 240)
	root.add_child(boss)
	await process_frame
	var before := _boss_runtime_node_count()
	_require(boss.cast_boss_skill(skill_id), "Boss skill %s should start" % skill_id)
	await create_timer(_skill_check_wait_time(skill_id)).timeout
	_require(_boss_runtime_node_count() > before, "Boss skill %s should spawn runtime effect nodes" % skill_id)
	await create_timer(_skill_finish_wait_time(skill_id)).timeout
	boss.queue_free()
	_cleanup_boss_runtime_nodes()
	await process_frame

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

func _boss_runtime_node_count() -> int:
	return get_nodes_in_group("boss_attack_effects").size() + get_nodes_in_group("boss_projectiles").size()

func _cleanup_boss_runtime_nodes() -> void:
	for node in get_nodes_in_group("boss_attack_effects"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_nodes_in_group("boss_projectiles"):
		if is_instance_valid(node):
			node.queue_free()
