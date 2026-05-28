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
	var run = main.get_node("DungeonRun")
	_require(run.current_room_definition != null, "Run should start in a room definition")
	_require(run.current_room_definition.id == &"combat_room", "Run should start in combat room")
	_assert_equipment_detail_ui(main)
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
	_require(run.current_floor == 2, "Interacting with unlocked exit should advance one floor")

	run.current_floor = 6
	run._start_current_room()
	await process_frame
	_require(run.current_room_definition.id == &"forge_room", "Floor six should be the forge room")
	_require(interactables.get_child_count() == 1, "Forge room should spawn one forge station")
	var station = interactables.get_child(0)
	station.interact(main.get_node("Player"))
	await process_frame
	_require(main.get_node("HUD").forge_panel.visible == true, "Forge station interaction should open forge UI")
	run.advance_to_next_room()
	await process_frame
	_require(main.get_node("HUD").forge_panel.visible == false, "Leaving forge room should close forge UI")
	_require(main.get_node("HUD").forge_button.disabled == true, "Leaving forge room should lock forge UI")

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

	var forge_room := load("res://resources/dungeon/forge_room.tres")
	_require(forge_room != null and forge_room.forge_available, "Forge room should unlock forge UI")
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
	var player = main.get_node("Player")
	var run = main.get_node("DungeonRun")
	var packet = DamagePacketScript.new()
	packet.amount = 10000.0
	packet.hit_position = player.global_position
	player.take_damage(packet)
	await process_frame
	_require(player.is_dead, "Fatal damage should mark the player dead")
	_require(not player.input_enabled, "Fatal damage should disable player input")
	_require(not run.run_active, "Fatal damage should stop the active dungeon run")
	_require(main.get_node("HUD").run_end_overlay.visible == true, "Fatal damage should show the death overlay")
	main.queue_free()
	await process_frame

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _assert_equipment_detail_ui(main: Node) -> void:
	var player = main.get_node("Player")
	var panel = main.get_node("HUD").equipment_panel
	var forge_panel = main.get_node("HUD").forge_panel
	var default_detail: String = panel.get_detail_text_for_test()
	_require(default_detail.contains("Ember Snap"), "Equipment detail should default to current weapon")
	_require(default_detail.contains("Ember Burst"), "Current weapon detail should show its affix")
	_require(default_detail.contains("18% Fire Burst"), "Ember Burst detail should show proc chance")

	var volt := load("res://resources/weapons/volt_spear.tres")
	_require(volt != null, "Volt Spear should load for detail UI")
	panel.select_item_for_test(volt)
	var volt_detail: String = panel.get_detail_text_for_test()
	_require(volt_detail.contains("Volt Spear"), "Selected weapon detail should show name")
	_require(volt_detail.contains("Storm Chain"), "Volt Spear detail should show Storm Chain")
	_require(volt_detail.contains("Armor Piercing"), "Volt Spear detail should show Armor Piercing")
	_require(volt_detail.contains("+0.15 Attack Speed"), "Storm Chain detail should show attack speed modifier")
	_require(volt_detail.contains("+8% Armor Pierce"), "Armor Piercing detail should show armor pierce modifier")
	_require(forge_panel.selected_item == volt, "Forge panel should receive selected weapon from equipment panel")

	var helm := load("res://resources/equipment/ashguard_helm.tres")
	_require(helm != null, "Ashguard Helm should load for detail UI")
	panel.select_item_for_test(helm)
	var helm_detail: String = panel.get_detail_text_for_test()
	_require(helm_detail.contains("Ashguard Helm"), "Selected equipment detail should show name")
	_require(helm_detail.contains("Helmet"), "Selected equipment detail should show slot")
	_require(helm_detail.contains("+10 Max Health"), "Selected equipment detail should show stat modifiers")
	_require(forge_panel.selected_item == helm, "Forge panel should receive selected equipment from equipment panel")

func _assert_boss_definition(definition: Resource, label: String) -> void:
	_require(definition != null, "%s definition should load" % label)
	_require(definition.boss_skill_profile != null, "%s should have a boss skill profile" % label)
	_require(definition.boss_mechanic_profile != null, "%s should have a boss mechanic profile" % label)
	_require(definition.boss_loot_table != null, "%s should have a boss loot table" % label)
	_require(definition.boss_skill_profile.skill_ids.size() == 3, "%s should have three boss skills" % label)

func _assert_normal_enemy_definitions(definitions: Array) -> void:
	_require(definitions.size() == 3, "MVP should load three normal enemy definitions")
	for definition in definitions:
		_require(definition != null, "Normal enemy definition should load")
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
	var run = main.get_node("DungeonRun")
	run.current_floor = 4
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
