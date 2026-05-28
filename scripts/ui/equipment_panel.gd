class_name EquipmentPanel
extends PanelContainer

const ItemDetailFormatterScript := preload("res://scripts/ui/item_detail_formatter.gd")

signal item_selected(item: Resource)

var player
var selected_item: Resource

@onready var inventory_list: ItemList = %InventoryList
@onready var equip_button: Button = %EquipButton
@onready var weapon_label: Label = %CurrentWeaponLabel
@onready var helmet_label: Label = %HelmetLabel
@onready var chest_label: Label = %ChestLabel
@onready var gloves_label: Label = %GlovesLabel
@onready var boots_label: Label = %BootsLabel
@onready var trinket_label: Label = %TrinketLabel
@onready var ring_label: Label = %RingLabel
@onready var detail_text: RichTextLabel = %ItemDetailText

func _ready() -> void:
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	equip_button.pressed.connect(_on_equip_pressed)
	equip_button.disabled = true

func bind_player(target_player: Node) -> void:
	player = target_player
	if player.has_signal("loadout_changed"):
		player.loadout_changed.connect(_on_loadout_changed)
	_refresh()

func _on_loadout_changed(_inventory: Array, _equipped: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	if player == null:
		return
	if selected_item != null and not _player_has_item(selected_item):
		selected_item = null

	inventory_list.clear()
	for item in player.inventory:
		if item == null:
			continue
		var level: int = player.get_enhancement_level(item) if player.has_method("get_enhancement_level") else 0
		var suffix := " +%d" % level if level > 0 else ""
		var index := inventory_list.add_item("%s%s" % [item.display_name, suffix])
		inventory_list.set_item_metadata(index, item)

	weapon_label.text = "Weapon: %s" % player.active_weapon.display_name if player.active_weapon != null else "Weapon: none"
	helmet_label.text = _slot_line("Helmet", 0)
	chest_label.text = _slot_line("Chest", 1)
	gloves_label.text = _slot_line("Gloves", 2)
	boots_label.text = _slot_line("Boots", 3)
	trinket_label.text = _slot_line("Trinket", 4)
	ring_label.text = _slot_line("Ring", 5)
	detail_text.text = ItemDetailFormatterScript.format_item(_detail_item(), player)

	_update_button()

func _slot_line(label: String, slot: int) -> String:
	if player == null or not player.equipped.has(slot):
		return "%s: -" % label
	var item: Resource = player.equipped[slot]
	var level: int = player.get_enhancement_level(item) if player.has_method("get_enhancement_level") else 0
	var suffix := " +%d" % level if level > 0 else ""
	return "%s: %s%s" % [label, item.display_name, suffix]

func _on_inventory_item_selected(index: int) -> void:
	selected_item = inventory_list.get_item_metadata(index)
	item_selected.emit(selected_item)
	detail_text.text = ItemDetailFormatterScript.format_item(_detail_item(), player)
	_update_button()

func _on_equip_pressed() -> void:
	if player == null or selected_item == null:
		return
	if selected_item.has_method("create_damage_packet"):
		player.equip_weapon(selected_item)
	elif selected_item.has_method("get_slot_name"):
		player.equip_equipment(selected_item)
	_refresh()

func _update_button() -> void:
	var can_equip := selected_item != null and (selected_item.has_method("create_damage_packet") or selected_item.has_method("get_slot_name"))
	equip_button.disabled = not can_equip
	if selected_item != null and selected_item.has_method("create_damage_packet"):
		equip_button.text = "Equip Weapon"
	else:
		equip_button.text = "Equip"

func select_item_for_test(item: Resource) -> void:
	selected_item = item
	detail_text.text = ItemDetailFormatterScript.format_item(_detail_item(), player)
	item_selected.emit(selected_item)
	_update_button()

func get_detail_text_for_test() -> String:
	return detail_text.text

func _detail_item() -> Resource:
	if selected_item != null:
		return selected_item
	if player != null:
		return player.active_weapon
	return null

func _player_has_item(item: Resource) -> bool:
	if player == null or item == null:
		return false
	if player.inventory.has(item):
		return true
	if player.active_weapon == item:
		return true
	for equipped_item in player.equipped.values():
		if equipped_item == item:
			return true
	return false
