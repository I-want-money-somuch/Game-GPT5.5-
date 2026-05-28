class_name ItemDetailFormatter
extends RefCounted

const RARITIES := ["Common", "Rare", "Epic", "Legendary", "Mythic"]
const WEAPON_FAMILIES := ["Handgun", "Rifle", "Shotgun", "Sniper", "Staff", "Bow", "Spear", "Greatsword", "Dual Blade", "Thrown", "Summon"]
const WEAPON_ELEMENTS := ["Physical", "Fire", "Ice", "Poison", "Lightning", "Arcane"]
const EQUIPMENT_SLOTS := ["Helmet", "Chest", "Gloves", "Boots", "Trinket", "Ring"]

const STAT_LINES := [
	["max_health", "Max Health", "flat"],
	["armor", "Armor", "flat"],
	["armor_durability", "Armor Durability", "flat"],
	["armor_damage_reduction", "Armor DR", "percent"],
	["damage_multiplier", "Damage", "percent"],
	["crit_chance", "Crit Chance", "percent"],
	["crit_damage", "Crit Damage", "percent"],
	["armor_pierce", "Armor Pierce", "percent"],
	["attack_speed", "Attack Speed", "decimal"],
	["move_speed", "Move Speed", "flat"],
	["dodge_chance", "Dodge", "percent"],
	["skill_cooldown_reduction", "Skill Cooldown", "percent"],
	["energy_recovery", "Energy Recovery", "decimal"],
]

static func format_item(item: Resource, player: Node = null) -> String:
	if item == null:
		return "No item selected.\nPick up or select an item to inspect its build value."
	if item.has_method("create_damage_packet"):
		return _format_weapon(item, player)
	if item.has_method("get_slot_name"):
		return _format_equipment(item, player)
	return "%s\n%s" % [str(item.get("display_name")), str(item.get("description"))]

static func _format_weapon(item: Resource, player: Node) -> String:
	var lines := PackedStringArray()
	lines.append("%s  +%d" % [_name(item), _enhancement_level(item, player)])
	lines.append("%s %s %s" % [_rarity_name(int(item.get("rarity"))), _weapon_family_name(int(item.get("family"))), _weapon_element_name(int(item.get("element")))])
	_append_if_not_empty(lines, str(item.get("description")))
	lines.append("")
	lines.append("Damage: %s" % _number(float(item.get("base_damage"))))
	lines.append("Attack Speed: %s/s" % _decimal(float(item.get("attack_rate"))))
	lines.append("Crit: %s at x%s" % [_percent(float(item.get("crit_chance"))), _decimal(float(item.get("crit_damage")))])
	lines.append("Armor Pierce: %s" % _percent(float(item.get("armor_pierce"))))
	lines.append("Pierce: %d" % int(item.get("pierce")))
	lines.append("Durability: %s" % _number(float(item.get("durability"))))
	_append_affixes(lines, item.get("affixes"))
	return "\n".join(lines)

static func _format_equipment(item: Resource, player: Node) -> String:
	var lines := PackedStringArray()
	lines.append("%s  +%d" % [_name(item), _enhancement_level(item, player)])
	lines.append("%s %s" % [_rarity_name(int(item.get("rarity"))), _equipment_slot_name(int(item.get("slot")))])
	_append_if_not_empty(lines, str(item.get("description")))
	lines.append("")
	var stats := _stat_lines(item.get("stat_modifiers"))
	if stats.is_empty():
		lines.append("Stats: none")
	else:
		lines.append("Stats:")
		for line in stats:
			lines.append("- %s" % line)
	_append_affixes(lines, item.get("affixes"))
	return "\n".join(lines)

static func _append_affixes(lines: PackedStringArray, affixes: Array) -> void:
	lines.append("")
	if affixes.is_empty():
		lines.append("Affixes: none")
		return

	lines.append("Affixes:")
	for affix in affixes:
		if affix == null:
			continue
		lines.append("- %s: %s" % [str(affix.get("display_name")), _affix_effect_line(affix)])
		_append_if_not_empty(lines, "  %s" % str(affix.get("description")))
		for stat_line in _stat_lines(affix.get("stat_modifiers")):
			lines.append("  %s" % stat_line)

static func _affix_effect_line(affix: Resource) -> String:
	var chance := float(affix.get("proc_chance"))
	var effect_id: StringName = affix.get("effect_id")
	match effect_id:
		&"fire_burst":
			return "%s Fire Burst" % _percent(chance)
		&"frostbite":
			return "%s Frostbite Slow" % _percent(chance)
		&"chain_lightning":
			return "%s Chain Lightning" % _percent(chance)
	if chance > 0.0:
		return "%s proc" % _percent(chance)
	return "Passive"

static func _stat_lines(stat_block: Resource) -> PackedStringArray:
	var lines := PackedStringArray()
	if stat_block == null or not stat_block.has_method("to_dictionary"):
		return lines
	var stats: Dictionary = stat_block.to_dictionary()
	for spec in STAT_LINES:
		var key: String = spec[0]
		var value := float(stats.get(key, 0.0))
		if is_zero_approx(value):
			continue
		lines.append("%s %s" % [_signed_value(value, spec[2]), spec[1]])
	return lines

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

static func _name(item: Resource) -> String:
	return str(item.get("display_name")) if item.get("display_name") != null else "Unknown Item"

static func _rarity_name(index: int) -> String:
	return _safe_name(RARITIES, index)

static func _weapon_family_name(index: int) -> String:
	return _safe_name(WEAPON_FAMILIES, index)

static func _weapon_element_name(index: int) -> String:
	return _safe_name(WEAPON_ELEMENTS, index)

static func _equipment_slot_name(index: int) -> String:
	return _safe_name(EQUIPMENT_SLOTS, index)

static func _safe_name(values: Array, index: int) -> String:
	if index < 0 or index >= values.size():
		return "Unknown"
	return str(values[index])

static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return _decimal(value)

static func _decimal(value: float) -> String:
	return "%.2f" % value
