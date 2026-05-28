extends Node2D

const PLAYER_CLASS := preload("res://resources/classes/vanguard.tres")
const STARTER_WEAPON := preload("res://resources/weapons/ember_snap.tres")
const PROJECTILE_SCENE := preload("res://scenes/items/Projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/items/Pickup.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const REWARD_CHEST_SCENE := preload("res://scenes/interactables/RewardChest.tscn")
const FORGE_STATION_SCENE := preload("res://scenes/interactables/ForgeStation.tscn")
const AFFIX_EFFECT_SERVICE_SCRIPT := preload("res://scripts/systems/affix_effect_service.gd")
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
	affix_effect_service = AFFIX_EFFECT_SERVICE_SCRIPT.new()
	add_child(affix_effect_service)
	affix_effect_service.configure(effects_parent)
	player.bind_affix_effect_service(affix_effect_service)
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
	dungeon_run.room_started.connect(_on_room_started)
	dungeon_run.forge_station_activated.connect(_on_forge_station_activated)
	dungeon_run.run_completed.connect(_on_run_completed)
	player.died.connect(_on_player_died)
	if hud.has_signal("retry_requested"):
		hud.retry_requested.connect(_on_retry_requested)
	dungeon_run.start_run()

func _on_room_started(_floor: int, _room_type: String) -> void:
	var definition: Resource = dungeon_run.current_room_definition
	if definition != null and arena.has_method("apply_room"):
		arena.apply_room(definition)
	if hud.has_method("set_forge_available"):
		hud.set_forge_available(definition != null and bool(definition.get("forge_available")))

func _on_forge_station_activated() -> void:
	if hud.has_method("open_forge_panel"):
		hud.open_forge_panel()

func _on_player_died() -> void:
	if dungeon_run.has_method("end_run"):
		dungeon_run.end_run()

func _on_run_completed() -> void:
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

func _on_retry_requested() -> void:
	get_tree().reload_current_scene()
