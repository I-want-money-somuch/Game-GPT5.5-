class_name HUD
extends CanvasLayer

const ItemDetailFormatterScript := preload("res://scripts/ui/item_detail_formatter.gd")

signal start_run_requested
signal reset_save_requested
signal talent_purchase_requested(talent_id: StringName)
signal camp_requested
signal settings_requested
signal settings_back_requested
signal language_selected(language: String)

@onready var health_label: Label = %HealthLabel
@onready var armor_label: Label = %ArmorLabel
@onready var floor_label: Label = %FloorLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var message_label: Label = %MessageLabel
@onready var interaction_label: Label = %InteractionLabel
@onready var pickup_preview_panel: PanelContainer = %PickupPreviewPanel
@onready var pickup_preview_text: RichTextLabel = %PickupPreviewText
@onready var equipment_button: Button = %EquipmentButton
@onready var forge_button: Button = %ForgeToggleButton
@onready var settings_button: Button = %SettingsButton
@onready var equipment_panel = %EquipmentPanel
@onready var forge_panel = %ForgePanel
@onready var run_end_overlay: Control = %RunEndOverlay
@onready var run_end_title: Label = %RunEndTitle
@onready var run_end_body: Label = %RunEndBody
@onready var retry_button: Button = %RetryButton
@onready var main_menu_overlay: Control = %MainMenuOverlay
@onready var menu_currency_label: Label = %MenuCurrencyLabel
@onready var menu_last_run_label: Label = %MenuLastRunLabel
@onready var start_run_button: Button = %StartRunButton
@onready var reset_save_button: Button = %ResetSaveButton
@onready var menu_settings_button: Button = %MenuSettingsButton
@onready var settings_overlay: Control = %SettingsOverlay
@onready var settings_title_label: Label = %SettingsTitle
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var settings_back_button: Button = %SettingsBackButton
@onready var talent_buttons := {
	&"vital_core": %VitalCoreButton,
	&"reinforced_plating": %ReinforcedPlatingButton,
	&"weapon_training": %WeaponTrainingButton,
	&"scavenger_instinct": %ScavengerInstinctButton,
}

var meta_progression_service: Node
var localization_service: Node
var bound_player: Node
var current_health := 0.0
var current_max_health := 0.0
var current_armor := 0.0
var current_max_armor := 0.0
var current_weapon: Resource
var current_inventory_count := 0
var current_floor := 1
var current_room_type := ""
var current_interactable: Node
var last_run_end_mode := ""
var last_run_end_title_key := ""
var last_run_end_body_key := ""
var last_run_end_stats := {}
var last_run_end_rewards := {}
var language_option_refreshing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_readable_ui($Root)
	equipment_panel.visible = false
	forge_panel.visible = false
	pickup_preview_panel.visible = false
	run_end_overlay.visible = false
	main_menu_overlay.visible = false
	settings_overlay.visible = false
	forge_button.disabled = true
	equipment_button.pressed.connect(func() -> void: equipment_panel.visible = not equipment_panel.visible)
	forge_button.pressed.connect(func() -> void: forge_panel.visible = not forge_panel.visible if not forge_button.disabled else false)
	retry_button.pressed.connect(func() -> void: camp_requested.emit())
	start_run_button.pressed.connect(func() -> void: start_run_requested.emit())
	reset_save_button.pressed.connect(func() -> void: reset_save_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	menu_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	settings_back_button.pressed.connect(func() -> void: settings_back_requested.emit())
	language_option.item_selected.connect(_on_language_option_selected)
	for talent_id in talent_buttons.keys():
		var button: Button = talent_buttons[talent_id]
		button.pressed.connect(_on_talent_button_pressed.bind(talent_id))
	if equipment_panel.has_signal("item_selected"):
		equipment_panel.item_selected.connect(func(item: Resource) -> void: forge_panel.set_selected_item(item))
	_refresh_language_options()
	_refresh_all_text()

func bind_player(player: Node) -> void:
	bound_player = player
	player.health_changed.connect(_on_health_changed)
	player.armor_changed.connect(_on_armor_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.inventory_changed.connect(_on_inventory_changed)
	if player.has_signal("interaction_prompt_changed"):
		player.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	if player.has_signal("current_interactable_changed"):
		player.current_interactable_changed.connect(_on_current_interactable_changed.bind(player))
	player.died.connect(_on_player_died)
	_on_health_changed(player.health, player.max_health)
	_on_armor_changed(player.armor_component.current_durability, player.armor_component.max_durability)
	_on_weapon_changed(player.active_weapon)
	_on_inventory_changed(player.inventory.size())
	equipment_panel.bind_player(player)

func bind_localization(service: Node) -> void:
	localization_service = service
	if localization_service != null and localization_service.has_signal("language_changed"):
		var language_callable := Callable(self, "_on_localization_language_changed")
		if not localization_service.language_changed.is_connected(language_callable):
			localization_service.language_changed.connect(language_callable)
	if equipment_panel.has_method("set_localization_service"):
		equipment_panel.set_localization_service(localization_service)
	if forge_panel.has_method("set_localization_service"):
		forge_panel.set_localization_service(localization_service)
	_refresh_language_options()
	_refresh_all_text()

func _on_localization_language_changed(_language: String) -> void:
	_refresh_all_text()

func _on_talent_button_pressed(talent_id: StringName) -> void:
	talent_purchase_requested.emit(talent_id)

func bind_run(run: Node) -> void:
	run.room_started.connect(_on_room_started)
	run.room_cleared.connect(func(floor: int) -> void: message_label.text = _lf("run.floor_clear", [floor], "Floor %d clear"))
	run.run_completed.connect(_on_run_completed)

func bind_services(player: Node, enhancement_service: Node, feedback_service: Node) -> void:
	forge_panel.bind_services(player, enhancement_service, feedback_service)

func bind_meta_progression(service: Node) -> void:
	meta_progression_service = service
	if meta_progression_service != null and meta_progression_service.has_signal("profile_changed"):
		meta_progression_service.profile_changed.connect(func(_profile: Dictionary) -> void: refresh_meta_progression())
	refresh_meta_progression()

func set_forge_available(available: bool) -> void:
	forge_button.disabled = not available
	forge_button.text = _t("ui.forge", "Forge") if available else _t("ui.forge_locked", "Forge Locked")
	if not available:
		forge_panel.visible = false

func open_forge_panel() -> void:
	if forge_button.disabled:
		return
	forge_panel.visible = true

func _on_health_changed(current: float, maximum: float) -> void:
	current_health = current
	current_max_health = maximum
	health_label.text = "%s %d/%d" % [_t("ui.hp", "HP"), roundi(current), roundi(maximum)]

func _on_armor_changed(current: float, maximum: float) -> void:
	current_armor = current
	current_max_armor = maximum
	armor_label.text = "%s %d/%d" % [_t("ui.armor", "Armor"), roundi(current), roundi(maximum)]

func _on_weapon_changed(weapon: Resource) -> void:
	current_weapon = weapon
	weapon_label.text = "%s: %s" % [_t("ui.weapon", "Weapon"), _resource_name(weapon) if weapon != null else _t("ui.weapon_none", "none")]

func _on_inventory_changed(count: int) -> void:
	current_inventory_count = count
	inventory_label.text = "%s: %d" % [_t("ui.drops", "Drops"), count]

func _on_interaction_prompt_changed(prompt: String) -> void:
	interaction_label.text = _lf("interact.press_e", [prompt], "Press E - %s") if not prompt.is_empty() else ""

func _on_current_interactable_changed(interactable: Node, player: Node) -> void:
	current_interactable = interactable
	if interactable != null and interactable.has_method("get_preview_item"):
		var item: Resource = interactable.get_preview_item()
		pickup_preview_text.text = ItemDetailFormatterScript.format_pickup_comparison(item, player, localization_service)
		pickup_preview_panel.visible = not pickup_preview_text.text.is_empty()
	else:
		pickup_preview_panel.visible = false
		pickup_preview_text.text = ""

func _on_room_started(floor: int, room_type: String) -> void:
	current_floor = floor
	current_room_type = room_type
	floor_label.text = "%s %d/10" % [_t("ui.floor", "Floor"), floor]
	message_label.text = _t("room_type.%s" % room_type, room_type.capitalize().replace("_", " "))
	run_end_overlay.visible = false
	main_menu_overlay.visible = false
	settings_overlay.visible = false
	pickup_preview_panel.visible = false

func _on_player_died() -> void:
	message_label.text = _t("ui.run_ended", "Run ended")
	_show_run_end_keys("run.end.run_ended", "run.end.death_body")

func _on_run_completed() -> void:
	message_label.text = _t("ui.boss_defeated", "Boss defeated")
	_show_run_end_keys("run.end.depths_cleared", "run.end.complete_body")

func _show_run_end_keys(title_key: String, body_key: String) -> void:
	last_run_end_mode = "body"
	last_run_end_title_key = title_key
	last_run_end_body_key = body_key
	run_end_title.text = _t(title_key, title_key)
	run_end_body.text = _t(body_key, body_key)
	retry_button.text = _t("ui.back", "Back") + " " + _t("ui.camp", "Camp")
	run_end_overlay.visible = true
	main_menu_overlay.visible = false
	settings_overlay.visible = false
	equipment_panel.visible = false
	forge_panel.visible = false
	pickup_preview_panel.visible = false

func show_run_end_summary(title_key: String, stats: Dictionary, rewards: Dictionary) -> void:
	last_run_end_mode = "summary"
	last_run_end_title_key = title_key
	last_run_end_stats = stats.duplicate(true)
	last_run_end_rewards = rewards.duplicate(true)
	_render_run_end_summary()

func _render_run_end_summary() -> void:
	var body := PackedStringArray()
	body.append(_lf("run.summary.highest", [int(last_run_end_stats.get("highest_floor", 1)), int(last_run_end_stats.get("rooms_cleared", 0))], "Highest Floor: %d   Rooms Cleared: %d"))
	body.append(_lf("run.summary.kills", [int(last_run_end_stats.get("kills", 0)), int(last_run_end_stats.get("elites", 0)), int(last_run_end_stats.get("mini_boss", 0)), int(last_run_end_stats.get("final_boss", 0))], "Kills: %d   Elites: %d   Mini Boss: %d   Final Boss: %d"))
	body.append("")
	body.append(_t("run.summary.rewards", "Rewards"))
	body.append(_lf("run.summary.reward_line", [int(last_run_end_rewards.get("gold", 0)), int(last_run_end_rewards.get("souls", 0)), int(last_run_end_rewards.get("talent_points", 0))], "Gold +%d   Souls +%d   Talent Points +%d"))
	run_end_title.text = _t(last_run_end_title_key, last_run_end_title_key)
	run_end_body.text = "\n".join(body)
	retry_button.text = _t("ui.back", "Back") + " " + _t("ui.camp", "Camp")
	run_end_overlay.visible = true
	main_menu_overlay.visible = false
	settings_overlay.visible = false
	equipment_panel.visible = false
	forge_panel.visible = false
	pickup_preview_panel.visible = false

func show_main_menu() -> void:
	refresh_meta_progression()
	main_menu_overlay.visible = true
	run_end_overlay.visible = false
	settings_overlay.visible = false
	equipment_panel.visible = false
	forge_panel.visible = false
	pickup_preview_panel.visible = false
	message_label.text = _t("ui.camp", "Camp")

func hide_main_menu() -> void:
	main_menu_overlay.visible = false

func show_settings() -> void:
	settings_overlay.visible = true
	_refresh_language_options()

func hide_settings() -> void:
	settings_overlay.visible = false

func refresh_meta_progression() -> void:
	if meta_progression_service == null:
		menu_currency_label.text = _lf("camp.currency", [0, 0, 0], "Gold %d   Souls %d   Talent Points %d")
		menu_last_run_label.text = _t("ui.no_run_recorded", "No run recorded")
		return
	var profile: Dictionary = meta_progression_service.profile_snapshot()
	menu_currency_label.text = _lf("camp.currency", [
		int(profile.get("gold", 0)),
		int(profile.get("souls", 0)),
		int(profile.get("talent_points", 0)),
	], "Gold %d   Souls %d   Talent Points %d")
	menu_last_run_label.text = _last_run_text(profile.get("last_run", {}))
	for talent_id in talent_buttons.keys():
		var button: Button = talent_buttons[talent_id]
		var level: int = meta_progression_service.talent_level(talent_id)
		var cost: int = meta_progression_service.talent_cost(talent_id)
		button.text = _lf("camp.talent_button", [
			_t("talent.%s.name" % str(talent_id), meta_progression_service.talent_display_name(talent_id)),
			level,
			meta_progression_service.talent_max_level(talent_id),
			cost,
			_t("talent.%s.desc" % str(talent_id), meta_progression_service.talent_description(talent_id)),
		], "%s  Lv %d/%d\nCost %d TP - %s")
		button.disabled = not meta_progression_service.can_purchase_talent(talent_id)

func _last_run_text(last_run) -> String:
	if not last_run is Dictionary or last_run.is_empty():
		return _t("camp.last_run_none", "Last Run: none")
	var stats: Dictionary = last_run.get("stats", {})
	var rewards: Dictionary = last_run.get("rewards", {})
	return _lf("camp.last_run", [
		int(stats.get("highest_floor", 1)),
		int(stats.get("rooms_cleared", 0)),
		int(rewards.get("gold", 0)),
		int(rewards.get("souls", 0)),
		int(rewards.get("talent_points", 0)),
	], "Last Run: Floor %d, Rooms %d, Gold +%d, Souls +%d, TP +%d")

func _refresh_all_text() -> void:
	equipment_button.text = _t("ui.equipment", "Equipment")
	forge_button.text = _t("ui.forge_locked", "Forge Locked") if forge_button.disabled else _t("ui.forge", "Forge")
	settings_button.text = _t("ui.settings", "Settings")
	menu_settings_button.text = _t("ui.settings", "Settings")
	start_run_button.text = _t("camp.start_run", "Start Run")
	reset_save_button.text = _t("camp.reset_save", "Reset Save")
	settings_title_label.text = _t("settings.title", "Settings")
	language_label.text = _t("settings.language", "Language")
	settings_back_button.text = _t("ui.back", "Back")
	var title_label := main_menu_overlay.get_node_or_null("Panel/MarginContainer/VBoxContainer/Title") as Label
	if title_label != null:
		title_label.text = _t("camp.title", "Forgebound Camp")
	var talent_title := main_menu_overlay.get_node_or_null("Panel/MarginContainer/VBoxContainer/TalentTitle") as Label
	if talent_title != null:
		talent_title.text = _t("camp.talent_title", "Permanent Talents")
	var equipment_title := equipment_panel.get_node_or_null("MarginContainer/VBoxContainer/Title") as Label
	if equipment_title != null:
		equipment_title.text = _t("ui.equipment", "Equipment")
	var detail_title := equipment_panel.get_node_or_null("MarginContainer/VBoxContainer/DetailTitle") as Label
	if detail_title != null:
		detail_title.text = _t("panel.details", "Details")
	var forge_title := forge_panel.get_node_or_null("MarginContainer/VBoxContainer/Title") as Label
	if forge_title != null:
		forge_title.text = _t("ui.forge", "Forge")
	var pickup_title := pickup_preview_panel.get_node_or_null("MarginContainer/VBoxContainer/Title") as Label
	if pickup_title != null:
		pickup_title.text = _t("panel.pickup_compare", "Pickup Compare")
	_on_health_changed(current_health, current_max_health)
	_on_armor_changed(current_armor, current_max_armor)
	_on_weapon_changed(current_weapon)
	_on_inventory_changed(current_inventory_count)
	if current_room_type.is_empty():
		message_label.text = _t("ui.ready", "Ready") if not main_menu_overlay.visible else _t("ui.camp", "Camp")
	else:
		floor_label.text = "%s %d/10" % [_t("ui.floor", "Floor"), current_floor]
		message_label.text = _t("room_type.%s" % current_room_type, current_room_type.capitalize().replace("_", " "))
	_refresh_current_interactable_text()
	refresh_meta_progression()
	if equipment_panel.has_method("refresh_for_language"):
		equipment_panel.refresh_for_language()
	if forge_panel.has_method("refresh_for_language"):
		forge_panel.refresh_for_language()
	if last_run_end_mode == "body" and run_end_overlay.visible:
		run_end_title.text = _t(last_run_end_title_key, last_run_end_title_key)
		run_end_body.text = _t(last_run_end_body_key, last_run_end_body_key)
		retry_button.text = _t("ui.back", "Back") + " " + _t("ui.camp", "Camp")
	elif last_run_end_mode == "summary" and run_end_overlay.visible:
		_render_run_end_summary()
	_refresh_language_options()

func _refresh_current_interactable_text() -> void:
	if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.has_method("get_prompt_text"):
		_on_interaction_prompt_changed(current_interactable.get_prompt_text())
	else:
		_on_interaction_prompt_changed("")
	if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.has_method("get_preview_item") and bound_player != null:
		pickup_preview_text.text = ItemDetailFormatterScript.format_pickup_comparison(current_interactable.get_preview_item(), bound_player, localization_service)
		pickup_preview_panel.visible = not pickup_preview_text.text.is_empty()

func _refresh_language_options() -> void:
	if language_option == null:
		return
	language_option_refreshing = true
	language_option.clear()
	var selected_index := 0
	var languages := _supported_languages()
	for index in range(languages.size()):
		var language: String = languages[index]
		language_option.add_item(_language_display_name(language))
		language_option.set_item_metadata(index, language)
		if language == _current_language():
			selected_index = index
	language_option.select(selected_index)
	language_option_refreshing = false

func _on_language_option_selected(index: int) -> void:
	if language_option_refreshing:
		return
	var language = language_option.get_item_metadata(index)
	if language is String:
		language_selected.emit(language)

func _apply_readable_ui(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			var size := 24 if label.name.contains("Title") else 20
			label.add_theme_font_size_override("font_size", max(label.get_theme_font_size("font_size"), size))
		elif child is Button:
			var button := child as Button
			button.add_theme_font_size_override("font_size", max(button.get_theme_font_size("font_size"), 20))
			button.custom_minimum_size = button.custom_minimum_size.max(Vector2(128, 44))
		elif child is ItemList:
			var list := child as ItemList
			list.add_theme_font_size_override("font_size", max(list.get_theme_font_size("font_size"), 20))
		elif child is RichTextLabel:
			var rich_label := child as RichTextLabel
			rich_label.add_theme_font_size_override("normal_font_size", max(rich_label.get_theme_font_size("normal_font_size"), 18))
		_apply_readable_ui(child)

func is_pickup_preview_visible_for_test() -> bool:
	return pickup_preview_panel.visible

func get_pickup_preview_text_for_test() -> String:
	return pickup_preview_text.text

func is_settings_visible_for_test() -> bool:
	return settings_overlay.visible

func get_language_option_code_for_test() -> String:
	var selected := language_option.selected
	if selected < 0:
		return ""
	return str(language_option.get_item_metadata(selected))

func _t(key: String, fallback := "") -> String:
	if localization_service != null and localization_service.has_method("text"):
		return localization_service.text(key, fallback)
	return fallback if not fallback.is_empty() else key

func _lf(key: String, args: Array = [], fallback := "") -> String:
	if localization_service != null and localization_service.has_method("format_text"):
		return localization_service.format_text(key, args, fallback)
	return fallback % args if not fallback.is_empty() else key % args

func _resource_name(resource: Resource) -> String:
	if localization_service != null and localization_service.has_method("resource_name"):
		return localization_service.resource_name(resource)
	if resource == null:
		return ""
	return str(resource.get("display_name"))

func _supported_languages() -> Array:
	if localization_service != null and localization_service.has_method("supported_languages"):
		return localization_service.supported_languages()
	return ["en", "zh_CN"]

func _language_display_name(language: String) -> String:
	if localization_service != null and localization_service.has_method("language_display_name"):
		return localization_service.language_display_name(language)
	return language

func _current_language() -> String:
	if localization_service != null and localization_service.has_method("language"):
		return localization_service.language()
	return "en"
