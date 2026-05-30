class_name ItemDetailFormatter
extends RefCounted

const RARITIES := ["Common", "Rare", "Epic", "Legendary", "Mythic"]
const WEAPON_FAMILIES := ["Handgun", "Rifle", "Shotgun", "Sniper", "Staff", "Bow", "Spear", "Greatsword", "Dual Blade", "Thrown", "Summon"]
const WEAPON_ELEMENTS := ["Physical", "Fire", "Ice", "Poison", "Lightning", "Arcane"]
const EQUIPMENT_SLOTS := ["Helmet", "Chest", "Gloves", "Boots", "Trinket", "Ring"]
const RARITY_KEYS := ["rarity.common", "rarity.rare", "rarity.epic", "rarity.legendary", "rarity.mythic"]
const WEAPON_FAMILY_KEYS := ["weapon_family.handgun", "weapon_family.rifle", "weapon_family.shotgun", "weapon_family.sniper", "weapon_family.staff", "weapon_family.bow", "weapon_family.spear", "weapon_family.greatsword", "weapon_family.dual_blade", "weapon_family.thrown", "weapon_family.summon"]
const WEAPON_ELEMENT_KEYS := ["element.physical", "element.fire", "element.ice", "element.poison", "element.lightning", "element.arcane"]
const EQUIPMENT_SLOT_KEYS := ["slot.helmet", "slot.chest", "slot.gloves", "slot.boots", "slot.trinket", "slot.ring"]

const STAT_LINES := [
	["max_health", "Max Health", "flat", "stat.max_health"],
	["armor", "Armor", "flat", "stat.armor"],
	["armor_durability", "Armor Durability", "flat", "stat.armor_durability"],
	["armor_damage_reduction", "Armor DR", "percent", "stat.armor_damage_reduction"],
	["damage_multiplier", "Damage", "percent", "stat.damage_multiplier"],
	["crit_chance", "Crit Chance", "percent", "stat.crit_chance"],
	["crit_damage", "Crit Damage", "percent", "stat.crit_damage"],
	["armor_pierce", "Armor Pierce", "percent", "stat.armor_pierce"],
	["attack_speed", "Attack Speed", "decimal", "stat.attack_speed"],
	["move_speed", "Move Speed", "flat", "stat.move_speed"],
	["dodge_chance", "Dodge", "percent", "stat.dodge_chance"],
	["skill_cooldown_reduction", "Skill Cooldown", "percent", "stat.skill_cooldown_reduction"],
	["energy_recovery", "Energy Recovery", "decimal", "stat.energy_recovery"],
]

static func format_item(item: Resource, player: Node = null, localization_service: Node = null) -> String:
	if item == null:
		return _t(localization_service, "item.no_selected", "No item selected.\nPick up or select an item to inspect its build value.")
	if item.has_method("create_damage_packet"):
		return _format_weapon(item, player, localization_service)
	if item.has_method("get_slot_name"):
		return _format_equipment(item, player, localization_service)
	return "%s\n%s" % [_name(item, localization_service), _description(item, localization_service)]

static func format_pickup_comparison(item: Resource, player: Node = null, localization_service: Node = null) -> String:
	if item == null:
		return ""
	if item.has_method("create_damage_packet"):
		return _format_weapon_pickup_comparison(item, player, localization_service)
	if item.has_method("get_slot_name"):
		return _format_equipment_pickup_comparison(item, player, localization_service)
	return format_item(item, player, localization_service)

static func _format_weapon(item: Resource, player: Node, localization_service: Node) -> String:
	var lines := PackedStringArray()
	lines.append("%s  +%d" % [_name(item, localization_service), _enhancement_level(item, player)])
	lines.append("%s %s %s" % [_rarity_name(int(item.get("rarity")), localization_service), _weapon_family_name(int(item.get("family")), localization_service), _weapon_element_name(int(item.get("element")), localization_service)])
	_append_if_not_empty(lines, _description(item, localization_service))
	lines.append("")
	lines.append(_lf(localization_service, "item.damage_line", [_number(float(item.get("base_damage")))], "Damage: %s"))
	lines.append(_lf(localization_service, "item.attack_speed_line", [_decimal(float(item.get("attack_rate")))], "Attack Speed: %s/s"))
	lines.append(_lf(localization_service, "item.crit_line", [_percent(float(item.get("crit_chance"))), _decimal(float(item.get("crit_damage")))], "Crit: %s at x%s"))
	lines.append(_lf(localization_service, "item.armor_pierce_line", [_percent(float(item.get("armor_pierce")))], "Armor Pierce: %s"))
	lines.append(_lf(localization_service, "item.pierce_line", [int(item.get("pierce"))], "Pierce: %d"))
	lines.append(_lf(localization_service, "item.durability_line", [_number(float(item.get("durability")))], "Durability: %s"))
	_append_affixes(lines, item.get("affixes"), localization_service)
	return "\n".join(lines)

static func _format_weapon_pickup_comparison(item: Resource, player: Node, localization_service: Node) -> String:
	var current: Resource = player.active_weapon if player != null and player.get("active_weapon") != null else null
	var lines := PackedStringArray()
	lines.append(_lf(localization_service, "item.pickup", [_name(item, localization_service)], "Pickup: %s"))
	lines.append("%s %s %s" % [_rarity_name(int(item.get("rarity")), localization_service), _weapon_family_name(int(item.get("family")), localization_service), _weapon_element_name(int(item.get("element")), localization_service)])
	lines.append(_lf(localization_service, "item.current", [_name(current, localization_service) if current != null else _t(localization_service, "item.none", "None")], "Current: %s"))
	lines.append("")
	lines.append(_t(localization_service, "item.compare", "Compare"))
	lines.append(_compare_line(_t(localization_service, "item.damage", "Damage"), float(item.get("base_damage")), _resource_float(current, "base_damage"), "flat", localization_service))
	lines.append(_compare_line(_t(localization_service, "item.attack_speed", "Attack Speed"), _weapon_attack_rate(item, player), _weapon_attack_rate(current, player), "decimal", localization_service))
	lines.append(_compare_line(_t(localization_service, "item.crit_chance", "Crit Chance"), float(item.get("crit_chance")), _resource_float(current, "crit_chance"), "percent", localization_service))
	lines.append(_compare_line(_t(localization_service, "item.crit_damage", "Crit Damage"), float(item.get("crit_damage")), _resource_float(current, "crit_damage"), "decimal", localization_service))
	lines.append(_compare_line(_t(localization_service, "item.armor_pierce", "Armor Pierce"), float(item.get("armor_pierce")), _resource_float(current, "armor_pierce"), "percent", localization_service))
	lines.append(_compare_line(_t(localization_service, "item.pierce", "Pierce"), float(item.get("pierce")), _resource_float(current, "pierce"), "flat", localization_service))
	lines.append("%s: %s" % [_t(localization_service, "item.element", "Element"), _weapon_element_name(int(item.get("element")), localization_service)])
	lines.append(_lf(localization_service, "item.affixes_inline", [_affix_names(item.get("affixes"), localization_service)], "Affixes: %s"))
	return "\n".join(lines)

static func _format_equipment(item: Resource, player: Node, localization_service: Node) -> String:
	var lines := PackedStringArray()
	lines.append("%s  +%d" % [_name(item, localization_service), _enhancement_level(item, player)])
	lines.append("%s %s" % [_rarity_name(int(item.get("rarity")), localization_service), _equipment_slot_name(int(item.get("slot")), localization_service)])
	_append_if_not_empty(lines, _description(item, localization_service))
	lines.append("")
	var stats := _stat_lines(item.get("stat_modifiers"), localization_service)
	if stats.is_empty():
		lines.append(_t(localization_service, "item.stats_none", "Stats: none"))
	else:
		lines.append(_t(localization_service, "item.stats", "Stats:"))
		for line in stats:
			lines.append("- %s" % line)
	_append_affixes(lines, item.get("affixes"), localization_service)
	return "\n".join(lines)

static func _format_equipment_pickup_comparison(item: Resource, player: Node, localization_service: Node) -> String:
	var slot := int(item.get("slot"))
	var current: Resource
	if player != null and player.get("equipped") != null:
		current = player.equipped.get(slot)
	var lines := PackedStringArray()
	lines.append(_lf(localization_service, "item.pickup", [_name(item, localization_service)], "Pickup: %s"))
	lines.append("%s %s" % [_rarity_name(int(item.get("rarity")), localization_service), _equipment_slot_name(slot, localization_service)])
	lines.append(_lf(localization_service, "item.current", [_name(current, localization_service) if current != null else _t(localization_service, "item.none", "None")], "Current: %s"))
	lines.append("")
	lines.append(_t(localization_service, "item.compare", "Compare"))
	var incoming_stats := _stats_dictionary(item.get("stat_modifiers"))
	var current_stats := _stats_dictionary(current.get("stat_modifiers") if current != null else null)
	var wrote_stat := false
	for spec in STAT_LINES:
		var key: String = spec[0]
		var incoming_value := float(incoming_stats.get(key, 0.0))
		var current_value := float(current_stats.get(key, 0.0))
		if is_zero_approx(incoming_value) and is_zero_approx(current_value):
			continue
		lines.append(_compare_line(_t(localization_service, spec[3], spec[1]), incoming_value, current_value, spec[2], localization_service))
		wrote_stat = true
	if not wrote_stat:
		lines.append(_t(localization_service, "item.no_direct_change", "Stats: no direct stat change"))
	lines.append(_lf(localization_service, "item.affixes_inline", [_affix_names(item.get("affixes"), localization_service)], "Affixes: %s"))
	return "\n".join(lines)

static func _append_affixes(lines: PackedStringArray, affixes: Array, localization_service: Node) -> void:
	lines.append("")
	if affixes.is_empty():
		lines.append(_t(localization_service, "item.affixes_none", "Affixes: none"))
		return

	lines.append(_t(localization_service, "item.affixes", "Affixes:"))
	for affix in affixes:
		if affix == null:
			continue
		lines.append("- %s: %s" % [_name(affix, localization_service), _affix_effect_line(affix, localization_service)])
		_append_if_not_empty(lines, "  %s" % _description(affix, localization_service))
		for stat_line in _stat_lines(affix.get("stat_modifiers"), localization_service):
			lines.append("  %s" % stat_line)

static func _affix_effect_line(affix: Resource, localization_service: Node) -> String:
	var chance := float(affix.get("proc_chance"))
	var effect_id: StringName = affix.get("effect_id")
	match effect_id:
		&"fire_burst":
			return _lf(localization_service, "affix.fire_burst_effect", [_percent(chance)], "%s Fire Burst")
		&"frostbite":
			return _lf(localization_service, "affix.frostbite_effect", [_percent(chance)], "%s Frostbite Slow")
		&"chain_lightning":
			return _lf(localization_service, "affix.chain_lightning_effect", [_percent(chance)], "%s Chain Lightning")
		&"rift_echo":
			return _lf(localization_service, "affix.rift_echo_effect", [_percent(chance)], "%s Rift Echo")
		&"gravity_well":
			return _lf(localization_service, "affix.gravity_well_effect", [_percent(chance)], "%s Gravity Well")
	if chance > 0.0:
		return _lf(localization_service, "affix.proc_effect", [_percent(chance)], "%s proc")
	return _t(localization_service, "affix.passive", "Passive")

static func _stat_lines(stat_block: Resource, localization_service: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	var stats := _stats_dictionary(stat_block)
	for spec in STAT_LINES:
		var key: String = spec[0]
		var value := float(stats.get(key, 0.0))
		if is_zero_approx(value):
			continue
		lines.append("%s %s" % [_signed_value(value, spec[2]), _t(localization_service, spec[3], spec[1])])
	return lines

static func _stats_dictionary(stat_block: Resource) -> Dictionary:
	if stat_block == null or not stat_block.has_method("to_dictionary"):
		return {}
	return stat_block.to_dictionary()

static func _compare_line(label: String, incoming: float, current: float, mode: String, localization_service: Node) -> String:
	var delta := incoming - current
	return "%s: %s  (%s)" % [label, _value(incoming, mode), _delta(delta, mode, localization_service)]

static func _value(value: float, mode: String) -> String:
	match mode:
		"percent":
			return _percent(value)
		"decimal":
			return _decimal(value)
		_:
			return _number(value)

static func _delta(value: float, mode: String, localization_service: Node) -> String:
	if is_zero_approx(value):
		return _t(localization_service, "item.same", "same")
	return _lf(localization_service, "item.vs_current", [_signed_value(value, mode)], "%s vs current")

static func _signed_value(value: float, mode: String) -> String:
	var sign := "+" if value > 0.0 else ""
	match mode:
		"percent":
			return "%s%s" % [sign, _percent(value)]
		"decimal":
			return "%s%s" % [sign, _decimal(value)]
		_:
			return "%s%s" % [sign, _number(value)]

static func _enhancement_level(item: Resource, player: Node) -> int:
	if player != null and player.has_method("get_enhancement_level"):
		return player.get_enhancement_level(item)
	return 0

static func _append_if_not_empty(lines: PackedStringArray, value: String) -> void:
	if not value.strip_edges().is_empty():
		lines.append(value)

static func _name(item: Resource, localization_service: Node) -> String:
	if item == null:
		return _t(localization_service, "item.none", "None")
	if localization_service != null and localization_service.has_method("resource_name"):
		return localization_service.resource_name(item)
	return str(item.get("display_name")) if item.get("display_name") != null else _t(localization_service, "item.unknown", "Unknown Item")

static func _description(item: Resource, localization_service: Node) -> String:
	if item == null:
		return ""
	if localization_service != null and localization_service.has_method("resource_description"):
		return localization_service.resource_description(item)
	return str(item.get("description")) if item.get("description") != null else ""

static func _resource_float(item: Resource, property_name: String) -> float:
	if item == null:
		return 0.0
	return float(item.get(property_name))

static func _weapon_attack_rate(item: Resource, player: Node) -> float:
	if item == null:
		return 0.0
	if player != null and player.has_method("attack_rate_for_weapon"):
		return player.attack_rate_for_weapon(item)
	return float(item.get("attack_rate"))

static func _affix_names(affixes: Array, localization_service: Node) -> String:
	if affixes.is_empty():
		return _t(localization_service, "item.none_inline", "none")
	var names := PackedStringArray()
	for affix in affixes:
		if affix != null:
			names.append(_name(affix, localization_service))
	return ", ".join(names) if not names.is_empty() else _t(localization_service, "item.none_inline", "none")

static func _rarity_name(index: int, localization_service: Node) -> String:
	return _safe_name(RARITIES, RARITY_KEYS, index, localization_service)

static func _weapon_family_name(index: int, localization_service: Node) -> String:
	return _safe_name(WEAPON_FAMILIES, WEAPON_FAMILY_KEYS, index, localization_service)

static func _weapon_element_name(index: int, localization_service: Node) -> String:
	return _safe_name(WEAPON_ELEMENTS, WEAPON_ELEMENT_KEYS, index, localization_service)

static func _equipment_slot_name(index: int, localization_service: Node) -> String:
	return _safe_name(EQUIPMENT_SLOTS, EQUIPMENT_SLOT_KEYS, index, localization_service)

static func _safe_name(values: Array, keys: Array, index: int, localization_service: Node) -> String:
	if index < 0 or index >= values.size():
		return _t(localization_service, "item.unknown", "Unknown")
	return _t(localization_service, str(keys[index]), str(values[index]))

static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return _decimal(value)

static func _decimal(value: float) -> String:
	return "%.2f" % value

static func _t(localization_service: Node, key: String, fallback := "") -> String:
	if localization_service != null and localization_service.has_method("text"):
		return localization_service.text(key, fallback)
	return fallback if not fallback.is_empty() else key

static func _lf(localization_service: Node, key: String, args: Array = [], fallback := "") -> String:
	if localization_service != null and localization_service.has_method("format_text"):
		return localization_service.format_text(key, args, fallback)
	return fallback % args if not fallback.is_empty() else key % args
