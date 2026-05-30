class_name EquipmentPanel
extends PanelContainer

const ItemDetailFormatterScript := preload("res://scripts/ui/item_detail_formatter.gd")

signal item_selected(item: Resource)
signal send_to_forge_requested(item: Resource)

const SLOT_WEAPON := -1
const FILTER_ALL := "all"
const FILTER_WEAPONS := "weapons"
const FILTER_EQUIPMENT := "equipment"
const SORT_RARITY := "rarity"
const SORT_TYPE := "type"
const SORT_LEVEL := "level"
const SORT_NAME := "name"

var player
var selected_item: Resource
var selected_source := ""
var selected_slot := SLOT_WEAPON
var localization_service: Node
var filter_mode := FILTER_ALL
var sort_mode := SORT_RARITY
var forge_available := false
var visible_inventory_items: Array = []
var slot_buttons := {}

@onready var filter_option: OptionButton = %FilterOption
@onready var sort_option: OptionButton = %SortOption
@onready var inventory_list: ItemList = %InventoryList
@onready var equip_button: Button = %EquipButton
@onready var send_to_forge_button: Button = %SendToForgeButton
@onready var close_button: Button = %EquipmentCloseButton
@onready var detail_title: Label = %DetailTitle
@onready var detail_text: RichTextLabel = %ItemDetailText
@onready var weapon_slot_button: Button = %WeaponSlotButton
@onready var helmet_slot_button: Button = %HelmetSlotButton
@onready var chest_slot_button: Button = %ChestSlotButton
@onready var gloves_slot_button: Button = %GlovesSlotButton
@onready var boots_slot_button: Button = %BootsSlotButton
@onready var trinket_slot_button: Button = %TrinketSlotButton
@onready var ring_slot_button: Button = %RingSlotButton

func _ready() -> void:
	slot_buttons = {
		SLOT_WEAPON: weapon_slot_button,
		0: helmet_slot_button,
		1: chest_slot_button,
		2: gloves_slot_button,
		3: boots_slot_button,
		4: trinket_slot_button,
		5: ring_slot_button,
	}
	_setup_filter_option()
	_setup_sort_option()
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	filter_option.item_selected.connect(_on_filter_selected)
	sort_option.item_selected.connect(_on_sort_selected)
	equip_button.pressed.connect(_on_equip_pressed)
	send_to_forge_button.pressed.connect(_on_send_to_forge_pressed)
	close_button.pressed.connect(func() -> void: visible = false)
	for slot in slot_buttons.keys():
		var button: Button = slot_buttons[slot]
		button.pressed.connect(_on_slot_pressed.bind(slot))
	_refresh()

func bind_player(target_player: Node) -> void:
	player = target_player
	if player.has_signal("loadout_changed"):
		player.loadout_changed.connect(_on_loadout_changed)
	_refresh()

func set_localization_service(service: Node) -> void:
	localization_service = service
	_refresh_filter_option_labels()
	_refresh_sort_option_labels()
	_refresh()

func set_forge_available(available: bool) -> void:
	forge_available = available
	_update_buttons()

func refresh_for_language() -> void:
	_refresh_filter_option_labels()
	_refresh_sort_option_labels()
	_refresh()

func _on_loadout_changed(_inventory: Array, _equipped: Dictionary) -> void:
	_refresh()

func _setup_filter_option() -> void:
	filter_option.clear()
	filter_option.add_item(_t("equipment.filter_all", "All"))
	filter_option.set_item_metadata(0, FILTER_ALL)
	filter_option.add_item(_t("equipment.filter_weapons", "Weapons"))
	filter_option.set_item_metadata(1, FILTER_WEAPONS)
	filter_option.add_item(_t("equipment.filter_equipment", "Equipment"))
	filter_option.set_item_metadata(2, FILTER_EQUIPMENT)
	filter_option.select(0)

func _setup_sort_option() -> void:
	sort_option.clear()
	sort_option.add_item(_t("equipment.sort_rarity", "Rarity"))
	sort_option.set_item_metadata(0, SORT_RARITY)
	sort_option.add_item(_t("equipment.sort_type", "Type"))
	sort_option.set_item_metadata(1, SORT_TYPE)
	sort_option.add_item(_t("equipment.sort_level", "Level"))
	sort_option.set_item_metadata(2, SORT_LEVEL)
	sort_option.add_item(_t("equipment.sort_name", "Name"))
	sort_option.set_item_metadata(3, SORT_NAME)
	sort_option.select(0)

func _refresh_filter_option_labels() -> void:
	var current := filter_mode
	_setup_filter_option()
	_select_option_by_metadata(filter_option, current)

func _refresh_sort_option_labels() -> void:
	var current := sort_mode
	_setup_sort_option()
	_select_option_by_metadata(sort_option, current)

func _select_option_by_metadata(option: OptionButton, value: String) -> void:
	for index in range(option.get_item_count()):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _on_filter_selected(index: int) -> void:
	filter_mode = str(filter_option.get_item_metadata(index))
	_refresh()

func _on_sort_selected(index: int) -> void:
	sort_mode = str(sort_option.get_item_metadata(index))
	_refresh()

func _refresh() -> void:
	if player == null or inventory_list == null:
		return
	_validate_selection()
	_refresh_inventory_list()
	_refresh_slot_buttons()
	_refresh_detail()
	_update_buttons()

func _refresh_inventory_list() -> void:
	inventory_list.clear()
	visible_inventory_items = _filtered_sorted_inventory()
	for item in visible_inventory_items:
		if item == null:
			continue
		var index := inventory_list.add_item(_list_line(item))
		inventory_list.set_item_metadata(index, item)
		inventory_list.set_item_custom_fg_color(index, _rarity_color(_rarity(item)))
		if item == selected_item and selected_source == "inventory":
			inventory_list.select(index)

func _filtered_sorted_inventory() -> Array:
	var items: Array = []
	for item in player.inventory:
		if item != null and _passes_filter(item):
			items.append(item)
	items.sort_custom(func(a, b) -> bool: return _inventory_item_less(a, b))
	return items

func _passes_filter(item: Resource) -> bool:
	match filter_mode:
		FILTER_WEAPONS:
			return _is_weapon(item)
		FILTER_EQUIPMENT:
			return _is_equipment(item)
		_:
			return _is_weapon(item) or _is_equipment(item)

func _inventory_item_less(a: Resource, b: Resource) -> bool:
	match sort_mode:
		SORT_TYPE:
			if _type_order(a) != _type_order(b):
				return _type_order(a) < _type_order(b)
			return _localized_name(a) < _localized_name(b)
		SORT_LEVEL:
			if _level(a) != _level(b):
				return _level(a) > _level(b)
			return _localized_name(a) < _localized_name(b)
		SORT_NAME:
			return _localized_name(a) < _localized_name(b)
		_:
			if _rarity(a) != _rarity(b):
				return _rarity(a) > _rarity(b)
			if _type_order(a) != _type_order(b):
				return _type_order(a) < _type_order(b)
			return _localized_name(a) < _localized_name(b)

func _refresh_slot_buttons() -> void:
	_set_slot_button(SLOT_WEAPON, "slot.weapon", "Weapon", _slot_item(SLOT_WEAPON))
	_set_slot_button(0, "slot.helmet", "Helmet", _slot_item(0))
	_set_slot_button(1, "slot.chest", "Chest", _slot_item(1))
	_set_slot_button(2, "slot.gloves", "Gloves", _slot_item(2))
	_set_slot_button(3, "slot.boots", "Boots", _slot_item(3))
	_set_slot_button(4, "slot.trinket", "Trinket", _slot_item(4))
	_set_slot_button(5, "slot.ring", "Ring", _slot_item(5))

func _set_slot_button(slot: int, key: String, fallback: String, item: Resource) -> void:
	var button: Button = slot_buttons.get(slot)
	if button == null:
		return
	var label := _t(key, fallback)
	if item == null:
		button.text = _lf("equipment.slot_empty", [label], "%s: -")
	else:
		var suffix := _level_suffix(item)
		button.text = _lf("equipment.slot_line", [label, "%s%s" % [_localized_name(item), suffix]], "%s: %s")
	button.disabled = item == null

func _refresh_detail() -> void:
	var item := _detail_item()
	detail_title.text = _detail_title()
	detail_text.text = ItemDetailFormatterScript.format_equipment_panel_detail(item, player, localization_service)

func _detail_title() -> String:
	if selected_item == null:
		return _t("panel.details", "Details")
	if selected_source == "slot":
		return _t("equipment.current_selection", "Current Equipment")
	return _t("equipment.compare_selection", "Compare Selection")

func _on_inventory_item_selected(index: int) -> void:
	selected_item = inventory_list.get_item_metadata(index)
	selected_source = "inventory"
	selected_slot = _slot_for_item(selected_item)
	item_selected.emit(selected_item)
	_refresh_detail()
	_update_buttons()

func _on_slot_pressed(slot: int) -> void:
	selected_slot = slot
	selected_source = "slot"
	selected_item = _slot_item(slot)
	item_selected.emit(selected_item)
	_refresh()

func _on_equip_pressed() -> void:
	if player == null or selected_item == null or selected_source != "inventory":
		return
	if _is_currently_equipped(selected_item):
		return
	if _is_weapon(selected_item):
		player.equip_weapon(selected_item)
	elif _is_equipment(selected_item):
		player.equip_equipment(selected_item)
	_refresh()

func _on_send_to_forge_pressed() -> void:
	if not _can_send_to_forge():
		return
	send_to_forge_requested.emit(selected_item)

func _update_buttons() -> void:
	if equip_button == null or send_to_forge_button == null:
		return
	var can_equip := _can_equip_selection()
	equip_button.disabled = not can_equip
	if selected_item != null and _is_currently_equipped(selected_item):
		equip_button.text = _t("equipment.equipped", "Equipped")
	elif selected_item != null and _is_weapon(selected_item):
		equip_button.text = _t("panel.equip_weapon", "Equip Weapon")
	else:
		equip_button.text = _t("panel.equip", "Equip")
	send_to_forge_button.disabled = not _can_send_to_forge()
	send_to_forge_button.text = _t("equipment.send_to_forge", "Send to Forge") if forge_available else _t("equipment.forge_unavailable", "Forge Unavailable")

func _can_equip_selection() -> bool:
	return player != null and selected_item != null and selected_source == "inventory" and not _is_currently_equipped(selected_item) and (_is_weapon(selected_item) or _is_equipment(selected_item))

func _can_send_to_forge() -> bool:
	return forge_available and player != null and selected_item != null and _player_has_item(selected_item) and (_is_weapon(selected_item) or _is_equipment(selected_item))

func _validate_selection() -> void:
	if selected_item == null:
		return
	if selected_source == "slot":
		selected_item = _slot_item(selected_slot)
		if selected_item == null:
			selected_source = ""
		return
	if not _player_has_item(selected_item):
		selected_item = null
		selected_source = ""

func _detail_item() -> Resource:
	if selected_item != null:
		return selected_item
	if player != null:
		return player.active_weapon
	return null

func _slot_item(slot: int) -> Resource:
	if player == null:
		return null
	if slot == SLOT_WEAPON:
		return player.active_weapon
	return player.equipped.get(slot)

func _slot_for_item(item: Resource) -> int:
	if _is_weapon(item):
		return SLOT_WEAPON
	if _is_equipment(item):
		return int(item.get("slot"))
	return SLOT_WEAPON

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

func _is_currently_equipped(item: Resource) -> bool:
	if player == null or item == null:
		return false
	if player.active_weapon == item:
		return true
	for equipped_item in player.equipped.values():
		if equipped_item == item:
			return true
	return false

func _is_weapon(item: Resource) -> bool:
	return item != null and item.has_method("create_damage_packet")

func _is_equipment(item: Resource) -> bool:
	return item != null and item.has_method("get_slot_name")

func _type_order(item: Resource) -> int:
	if _is_weapon(item):
		return 0
	if _is_equipment(item):
		return 1 + int(item.get("slot"))
	return 99

func _rarity(item: Resource) -> int:
	if item == null:
		return 0
	return int(item.get("rarity"))

func _level(item: Resource) -> int:
	return player.get_enhancement_level(item) if player != null and player.has_method("get_enhancement_level") else 0

func _level_suffix(item: Resource) -> String:
	var item_level := _level(item)
	return " +%d" % item_level if item_level > 0 else ""

func _list_line(item: Resource) -> String:
	return "%s%s  -  %s" % [_localized_name(item), _level_suffix(item), _item_kind_name(item)]

func _item_kind_name(item: Resource) -> String:
	if _is_weapon(item):
		return _t("equipment.kind_weapon", "Weapon")
	if _is_equipment(item):
		return _t("equipment.kind_equipment", "Equipment")
	return _t("item.unknown", "Unknown")

func _rarity_color(rarity: int) -> Color:
	match rarity:
		1:
			return Color(0.42, 0.78, 1.0)
		2:
			return Color(0.78, 0.55, 1.0)
		3:
			return Color(1.0, 0.76, 0.28)
		4:
			return Color(1.0, 0.42, 0.58)
		_:
			return Color.WHITE

func _localized_name(resource: Resource) -> String:
	if localization_service != null and localization_service.has_method("resource_name"):
		return localization_service.resource_name(resource)
	if resource == null:
		return ""
	return str(resource.get("display_name"))

func _t(key: String, fallback := "") -> String:
	if localization_service != null and localization_service.has_method("text"):
		return localization_service.text(key, fallback)
	return fallback if not fallback.is_empty() else key

func _lf(key: String, args: Array = [], fallback := "") -> String:
	if localization_service != null and localization_service.has_method("format_text"):
		return localization_service.format_text(key, args, fallback)
	return fallback % args if not fallback.is_empty() else key % args

func select_item_for_test(item: Resource) -> void:
	selected_item = item
	selected_source = "inventory"
	selected_slot = _slot_for_item(item)
	item_selected.emit(selected_item)
	_refresh()

func select_slot_for_test(slot: int) -> void:
	_on_slot_pressed(slot)

func set_filter_for_test(value: String) -> void:
	filter_mode = value
	_select_option_by_metadata(filter_option, value)
	_refresh()

func set_sort_for_test(value: String) -> void:
	sort_mode = value
	_select_option_by_metadata(sort_option, value)
	_refresh()

func get_visible_item_names_for_test() -> Array:
	var names := []
	for item in visible_inventory_items:
		names.append(_localized_name(item))
	return names

func get_detail_text_for_test() -> String:
	return detail_text.text

func is_equip_disabled_for_test() -> bool:
	return equip_button.disabled

func is_send_to_forge_disabled_for_test() -> bool:
	return send_to_forge_button.disabled

func send_selected_to_forge_for_test() -> void:
	_on_send_to_forge_pressed()

func equip_selected_for_test() -> void:
	_on_equip_pressed()
