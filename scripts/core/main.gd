extends Node2D

const PLAYER_CLASS := preload("res://resources/classes/vanguard.tres")
const STARTER_WEAPON := preload("res://resources/weapons/ember_snap.tres")
const PROJECTILE_SCENE := preload("res://scenes/items/Projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/items/Pickup.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const REWARD_CHEST_SCENE := preload("res://scenes/interactables/RewardChest.tscn")
const FORGE_STATION_SCENE := preload("res://scenes/interactables/ForgeStation.tscn")
const AFFIX_EFFECT_SERVICE_SCRIPT := preload("res://scripts/systems/affix_effect_service.gd")
const META_PROGRESSION_SERVICE_SCRIPT := preload("res://scripts/systems/meta_progression_service.gd")
const LOOT_TABLE := preload("res://resources/loot_tables/mvp_loot_table.tres")
const ENHANCEMENT_CURVE := preload("res://resources/progression/basic_enhancement_curve.tres")
const COMBAT_ROOM := preload("res://resources/dungeon/combat_room.tres")
const ELITE_ROOM := preload("res://resources/dungeon/elite_room.tres")
const TREASURE_ROOM := preload("res://resources/dungeon/treasure_room.tres")
const FORGE_ROOM := preload("res://resources/dungeon/forge_room.tres")
const MINI_BOSS_ROOM := preload("res://resources/dungeon/mini_boss_room.tres")
const BOSS_ROOM := preload("res://resources/dungeon/boss_room.tres")
const ELITE_AFFIXES = [
	preload("res://resources/elite_affixes/flaming.tres"),
	preload("res://resources/elite_affixes/swift.tres"),
	preload("res://resources/elite_affixes/juggernaut.tres"),
	preload("res://resources/elite_affixes/phasing.tres"),
	preload("res://resources/elite_affixes/vampiric.tres"),
]

const NORMAL_ENEMIES = [
	preload("res://resources/enemies/ashling.tres"),
	preload("res://resources/enemies/glassmite.tres"),
	preload("res://resources/enemies/iron_husk.tres"),
]
const MINI_BOSS := preload("res://resources/enemies/cinder_bulwark.tres")
const BOSS := preload("res://resources/enemies/depths_warden.tres")

@onready var player: Node = $Player
@onready var dungeon_run: Node = $DungeonRun
@onready var loot_service: Node = $LootService
@onready var enhancement_service: Node = $EnhancementService
@onready var feedback_service: Node = $FeedbackService
var affix_effect_service: Node
var meta_progression_service: Node
var run_stats := {}
var current_run_active := false
var run_settled := false
@onready var enemy_parent: Node2D = $Enemies
@onready var pickup_parent: Node2D = $Pickups
@onready var interactable_parent: Node2D = $Interactables
@onready var effects_parent: Node2D = $Effects
@onready var hud: Node = $HUD
@onready var arena: Node = $Arena
@onready var exit_portal: Node = $ExitPortal
@onready var spawn_points: Array[Marker2D] = [
	$Arena/SpawnPoints/SpawnA,
	$Arena/SpawnPoints/SpawnB,
	$Arena/SpawnPoints/SpawnC,
	$Arena/SpawnPoints/SpawnD,
	$Arena/SpawnPoints/SpawnE,
	$Arena/SpawnPoints/SpawnF,
]
@onready var reward_points: Array[Marker2D] = [
	$Arena/RewardPoints/RewardA,
	$Arena/RewardPoints/RewardB,
	$Arena/RewardPoints/RewardC,
]
@onready var room_sequence := [
	COMBAT_ROOM,
	COMBAT_ROOM,
	TREASURE_ROOM,
	ELITE_ROOM,
	MINI_BOSS_ROOM,
	FORGE_ROOM,
	COMBAT_ROOM,
	ELITE_ROOM,
	TREASURE_ROOM,
	BOSS_ROOM,
]

func _ready() -> void:
	player.initialize(PLAYER_CLASS, STARTER_WEAPON, PROJECTILE_SCENE)
	player.set_input_enabled(false)
	affix_effect_service = AFFIX_EFFECT_SERVICE_SCRIPT.new()
	add_child(affix_effect_service)
	affix_effect_service.configure(effects_parent)
	player.bind_affix_effect_service(affix_effect_service)
	meta_progression_service = META_PROGRESSION_SERVICE_SCRIPT.new()
	meta_progression_service.name = "MetaProgressionService"
	add_child(meta_progression_service)
	loot_service.configure(LOOT_TABLE, PICKUP_SCENE, pickup_parent)
	enhancement_service.curve = ENHANCEMENT_CURVE
	feedback_service.configure($Player/Camera2D, effects_parent)
	dungeon_run.configure({
		"player": player,
		"enemy_scene": ENEMY_SCENE,
		"reward_chest_scene": REWARD_CHEST_SCENE,
		"forge_station_scene": FORGE_STATION_SCENE,
		"enemy_parent": enemy_parent,
		"pickup_parent": pickup_parent,
		"interactable_parent": interactable_parent,
		"loot_service": loot_service,
		"normal_enemy_definitions": NORMAL_ENEMIES,
		"elite_affix_pool": ELITE_AFFIXES,
		"mini_boss_definition": MINI_BOSS,
		"boss_definition": BOSS,
		"spawn_points": spawn_points,
		"reward_points": reward_points,
		"player_start": $Arena/PlayerStart,
		"exit_point": $Arena/ExitPoint,
		"exit_portal": exit_portal,
		"room_sequence": room_sequence,
	})
	hud.bind_player(player)
	hud.bind_run(dungeon_run)
	hud.bind_services(player, enhancement_service, feedback_service)
	hud.bind_meta_progression(meta_progression_service)
	dungeon_run.room_started.connect(_on_room_started)
	dungeon_run.room_cleared.connect(_on_room_cleared)
	dungeon_run.enemy_defeated.connect(_on_enemy_defeated)
	dungeon_run.forge_station_activated.connect(_on_forge_station_activated)
	dungeon_run.run_completed.connect(_on_run_completed)
	player.died.connect(_on_player_died)
	hud.start_run_requested.connect(_on_start_run_requested)
	hud.reset_save_requested.connect(_on_reset_save_requested)
	hud.talent_purchase_requested.connect(_on_talent_purchase_requested)
	hud.camp_requested.connect(_on_camp_requested)
	hud.show_main_menu()

func _on_room_started(_floor: int, _room_type: String) -> void:
	var definition: Resource = dungeon_run.current_room_definition
	if definition != null and arena.has_method("apply_room"):
		arena.apply_room(definition)
	if hud.has_method("set_forge_available"):
		hud.set_forge_available(definition != null and bool(definition.get("forge_available")))
	if current_run_active:
		run_stats["highest_floor"] = maxi(int(run_stats.get("highest_floor", 1)), dungeon_run.current_floor)

func _on_room_cleared(_floor: int) -> void:
	if current_run_active and not run_settled:
		run_stats["rooms_cleared"] = int(run_stats.get("rooms_cleared", 0)) + 1

func _on_enemy_defeated(enemy: Node, definition: Resource) -> void:
	if not current_run_active or run_settled:
		return
	run_stats["kills"] = int(run_stats.get("kills", 0)) + 1
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("is_elite_enemy") and enemy.is_elite_enemy():
		run_stats["elites"] = int(run_stats.get("elites", 0)) + 1
	if definition == MINI_BOSS:
		run_stats["mini_boss"] = 1
	elif definition == BOSS:
		run_stats["final_boss"] = 1

func _on_forge_station_activated() -> void:
	if hud.has_method("open_forge_panel"):
		hud.open_forge_panel()

func _on_player_died() -> void:
	_settle_current_run(false)
	if dungeon_run.has_method("end_run"):
		dungeon_run.end_run()

func _on_run_completed() -> void:
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	_settle_current_run(true)

func _on_start_run_requested() -> void:
	start_run_from_camp()

func _on_reset_save_requested() -> void:
	if current_run_active:
		return
	meta_progression_service.reset_profile()
	hud.show_main_menu()

func _on_talent_purchase_requested(talent_id: StringName) -> void:
	if current_run_active:
		return
	meta_progression_service.purchase_talent(talent_id)
	hud.refresh_meta_progression()

func _on_camp_requested() -> void:
	current_run_active = false
	run_settled = false
	dungeon_run.end_run()
	player.set_input_enabled(false)
	hud.show_main_menu()

func start_run_from_camp() -> void:
	current_run_active = true
	run_settled = false
	run_stats = _new_run_stats()
	player.initialize(PLAYER_CLASS, STARTER_WEAPON, PROJECTILE_SCENE)
	player.set_meta_stat_modifiers(meta_progression_service.stat_modifiers(), true)
	player.set_input_enabled(true)
	loot_service.enemy_drop_chance_bonus = meta_progression_service.drop_chance_bonus()
	hud.hide_main_menu()
	hud.set_forge_available(false)
	dungeon_run.start_run()

func start_run_for_test() -> void:
	start_run_from_camp()

func configure_profile_path_for_test(path: String, reset := true) -> void:
	meta_progression_service.set_profile_path(path, reset)
	hud.refresh_meta_progression()

func purchase_talent_for_test(talent_id: StringName) -> void:
	_on_talent_purchase_requested(talent_id)

func reset_save_for_test() -> void:
	_on_reset_save_requested()

func back_to_camp_for_test() -> void:
	_on_camp_requested()

func _settle_current_run(completed: bool) -> Dictionary:
	if not current_run_active or run_settled:
		return {}
	run_settled = true
	current_run_active = false
	run_stats["completed"] = completed
	run_stats["highest_floor"] = maxi(int(run_stats.get("highest_floor", 1)), dungeon_run.current_floor)
	var rewards: Dictionary = meta_progression_service.award_run(run_stats)
	var title := "Depths Cleared" if completed else "Run Ended"
	hud.show_run_end_summary(title, run_stats, rewards)
	return rewards

func _new_run_stats() -> Dictionary:
	return {
		"highest_floor": 1,
		"rooms_cleared": 0,
		"kills": 0,
		"elites": 0,
		"mini_boss": 0,
		"final_boss": 0,
		"completed": false,
	}
