class_name LootService
extends Node

@export var loot_table: Resource
@export var pickup_scene: PackedScene

var pickup_parent: Node
var enemy_drop_chance_bonus := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func configure(table: Resource, scene: PackedScene, parent: Node) -> void:
	loot_table = table
	pickup_scene = scene
	pickup_parent = parent

func drop_for_enemy(enemy_definition: Resource, at_position: Vector2, floor: int) -> void:
	if loot_table == null or pickup_scene == null or pickup_parent == null:
		return
	if enemy_definition != null and enemy_definition.has_method("is_boss") and enemy_definition.is_boss():
		return

	var attempts := 1

	for index in range(attempts):
		var item: Resource = loot_table.roll(rng, floor, enemy_drop_chance_bonus)
		if item == null:
			continue
		var pickup := pickup_scene.instantiate()
		pickup.item_definition = item
		pickup.global_position = at_position + Vector2(18.0 * index, -12.0 * index)
		pickup_parent.add_child(pickup)

func drop_room_reward(at_position: Vector2, floor: int, attempts: int, guaranteed: bool, source_definition: Resource = null) -> void:
	if loot_table == null or pickup_scene == null or pickup_parent == null:
		return

	var table := _loot_table_for_source(source_definition)
	var use_primary_guarantee := guaranteed and source_definition != null and source_definition.get("boss_loot_table") != null
	for index in range(maxi(attempts, 0)):
		var item: Resource
		if index == 0 and use_primary_guarantee and table.has_method("roll_primary_guaranteed"):
			item = table.roll_primary_guaranteed(rng, floor)
		elif guaranteed and table.has_method("roll_guaranteed"):
			item = table.roll_guaranteed(rng, floor)
		else:
			item = table.roll(rng, floor)
		if item == null:
			continue

		var pickup := pickup_scene.instantiate()
		pickup.item_definition = item
		pickup.global_position = at_position + Vector2(34.0 * (index - attempts / 2.0), 0.0)
		pickup_parent.add_child(pickup)

func _loot_table_for_source(source_definition: Resource) -> Resource:
	if source_definition != null and source_definition.get("boss_loot_table") != null:
		return source_definition.get("boss_loot_table")
	return loot_table
