class_name HUD
extends CanvasLayer

signal start_run_requested
signal reset_save_requested
signal talent_purchase_requested(talent_id: StringName)
signal camp_requested

@onready var health_label: Label = %HealthLabel
@onready var armor_label: Label = %ArmorLabel
@onready var floor_label: Label = %FloorLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var message_label: Label = %MessageLabel
@onready var interaction_label: Label = %InteractionLabel
@onready var equipment_button: Button = %EquipmentButton
@onready var forge_button: Button = %ForgeToggleButton
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
@onready var talent_buttons := {
	&"vital_core": %VitalCoreButton,
	&"reinforced_plating": %ReinforcedPlatingButton,
	&"weapon_training": %WeaponTrainingButton,
	&"scavenger_instinct": %ScavengerInstinctButton,
}

var meta_progression_service: Node

func _ready() -> void:
	_apply_readable_ui($Root)
	equipment_panel.visible = false
	forge_panel.visible = false
	run_end_overlay.visible = false
	main_menu_overlay.visible = false
	forge_button.disabled = true
	equipment_button.pressed.connect(func() -> void: equipment_panel.visible = not equipment_panel.visible)
	forge_button.pressed.connect(func() -> void: forge_panel.visible = not forge_panel.visible if not forge_button.disabled else false)
	retry_button.pressed.connect(func() -> void: camp_requested.emit())
	start_run_button.pressed.connect(func() -> void: start_run_requested.emit())
	reset_save_button.pressed.connect(func() -> void: reset_save_requested.emit())
	for talent_id in talent_buttons.keys():
		var button: Button = talent_buttons[talent_id]
		button.pressed.connect(_on_talent_button_pressed.bind(talent_id))
	if equipment_panel.has_signal("item_selected"):
		equipment_panel.item_selected.connect(func(item: Resource) -> void: forge_panel.set_selected_item(item))

func bind_player(player: Node) -> void:
	player.health_changed.connect(_on_health_changed)
	player.armor_changed.connect(_on_armor_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.inventory_changed.connect(_on_inventory_changed)
	if player.has_signal("interaction_prompt_changed"):
		player.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	player.died.connect(_on_player_died)
	_on_health_changed(player.health, player.max_health)
	_on_armor_changed(player.armor_component.current_durability, player.armor_component.max_durability)
	_on_weapon_changed(player.active_weapon)
	_on_inventory_changed(player.inventory.size())
	equipment_panel.bind_player(player)

func _on_talent_button_pressed(talent_id: StringName) -> void:
	talent_purchase_requested.emit(talent_id)

func bind_run(run: Node) -> void:
	run.room_started.connect(_on_room_started)
	run.room_cleared.connect(func(floor: int) -> void: message_label.text = "Floor %d clear" % floor)
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
	forge_button.text = "Forge" if available else "Forge Locked"
	if not available:
		forge_panel.visible = false

func open_forge_panel() -> void:
	if forge_button.disabled:
		return
	forge_panel.visible = true

func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP %d/%d" % [roundi(current), roundi(maximum)]

func _on_armor_changed(current: float, maximum: float) -> void:
	armor_label.text = "Armor %d/%d" % [roundi(current), roundi(maximum)]

func _on_weapon_changed(weapon: Resource) -> void:
	weapon_label.text = "Weapon: %s" % weapon.display_name if weapon != null else "Weapon: none"

func _on_inventory_changed(count: int) -> void:
	inventory_label.text = "Drops: %d" % count

func _on_interaction_prompt_changed(prompt: String) -> void:
	interaction_label.text = "Press E - %s" % prompt if not prompt.is_empty() else ""

func _on_room_started(floor: int, room_type: String) -> void:
	floor_label.text = "Floor %d/10" % floor
	message_label.text = room_type.capitalize().replace("_", " ")
	run_end_overlay.visible = false
	main_menu_overlay.visible = false

func _on_player_died() -> void:
	message_label.text = "Run ended"
	_show_run_end("Run Ended", "Your build collapsed in the depths. Start a fresh run and try a different drop path.")

func _on_run_completed() -> void:
	message_label.text = "Boss defeated"
	_show_run_end("Depths Cleared", "Boss defeated. The current vertical slice is complete.")

func _show_run_end(title: String, body: String) -> void:
	run_end_title.text = title
	run_end_body.text = body
	retry_button.text = "Back to Camp"
	run_end_overlay.visible = true
	main_menu_overlay.visible = false
	equipment_panel.visible = false
	forge_panel.visible = false

func show_run_end_summary(title: String, stats: Dictionary, rewards: Dictionary) -> void:
	var body := PackedStringArray()
	body.append("Highest Floor: %d   Rooms Cleared: %d" % [int(stats.get("highest_floor", 1)), int(stats.get("rooms_cleared", 0))])
	body.append("Kills: %d   Elites: %d   Mini Boss: %d   Final Boss: %d" % [int(stats.get("kills", 0)), int(stats.get("elites", 0)), int(stats.get("mini_boss", 0)), int(stats.get("final_boss", 0))])
	body.append("")
	body.append("Rewards")
	body.append("Gold +%d   Souls +%d   Talent Points +%d" % [int(rewards.get("gold", 0)), int(rewards.get("souls", 0)), int(rewards.get("talent_points", 0))])
	_show_run_end(title, "\n".join(body))

func show_main_menu() -> void:
	refresh_meta_progression()
	main_menu_overlay.visible = true
	run_end_overlay.visible = false
	equipment_panel.visible = false
	forge_panel.visible = false
	message_label.text = "Camp"

func hide_main_menu() -> void:
	main_menu_overlay.visible = false

func refresh_meta_progression() -> void:
	if meta_progression_service == null:
		menu_currency_label.text = "Gold 0   Souls 0   Talent Points 0"
		menu_last_run_label.text = "No run recorded"
		return
	var profile: Dictionary = meta_progression_service.profile_snapshot()
	menu_currency_label.text = "Gold %d   Souls %d   Talent Points %d" % [
		int(profile.get("gold", 0)),
		int(profile.get("souls", 0)),
		int(profile.get("talent_points", 0)),
	]
	menu_last_run_label.text = _last_run_text(profile.get("last_run", {}))
	for talent_id in talent_buttons.keys():
		var button: Button = talent_buttons[talent_id]
		var level: int = meta_progression_service.talent_level(talent_id)
		var cost: int = meta_progression_service.talent_cost(talent_id)
		button.text = "%s  Lv %d/%d\nCost %d TP - %s" % [
			meta_progression_service.talent_display_name(talent_id),
			level,
			meta_progression_service.talent_max_level(talent_id),
			cost,
			meta_progression_service.talent_description(talent_id),
		]
		button.disabled = not meta_progression_service.can_purchase_talent(talent_id)

func _last_run_text(last_run) -> String:
	if not last_run is Dictionary or last_run.is_empty():
		return "Last Run: none"
	var stats: Dictionary = last_run.get("stats", {})
	var rewards: Dictionary = last_run.get("rewards", {})
	return "Last Run: Floor %d, Rooms %d, Gold +%d, Souls +%d, TP +%d" % [
		int(stats.get("highest_floor", 1)),
		int(stats.get("rooms_cleared", 0)),
		int(rewards.get("gold", 0)),
		int(rewards.get("souls", 0)),
		int(rewards.get("talent_points", 0)),
	]

func _apply_readable_ui(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label := child as Label
			var size := 20 if label.name.contains("Title") else 18
			label.add_theme_font_size_override("font_size", max(label.get_theme_font_size("font_size"), size))
		elif child is Button:
			var button := child as Button
			button.add_theme_font_size_override("font_size", max(button.get_theme_font_size("font_size"), 18))
			button.custom_minimum_size = button.custom_minimum_size.max(Vector2(108, 36))
		elif child is ItemList:
			var list := child as ItemList
			list.add_theme_font_size_override("font_size", max(list.get_theme_font_size("font_size"), 18))
		_apply_readable_ui(child)
