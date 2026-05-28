class_name MetaProgressionService
extends Node

signal profile_changed(profile: Dictionary)
signal run_awarded(rewards: Dictionary, stats: Dictionary)

const DEFAULT_PROFILE_PATH := "user://profile_v1.json"
const TALENT_IDS := [&"vital_core", &"reinforced_plating", &"weapon_training", &"scavenger_instinct"]
const TALENT_MAX_LEVEL := 5

const TALENT_DATA := {
	&"vital_core": {
		"display_name": "Vital Core",
		"description": "+10 Max Health per level",
	},
	&"reinforced_plating": {
		"display_name": "Reinforced Plating",
		"description": "+4 Armor and +12 Armor Durability per level",
	},
	&"weapon_training": {
		"display_name": "Weapon Training",
		"description": "+5% Damage per level",
	},
	&"scavenger_instinct": {
		"display_name": "Scavenger Instinct",
		"description": "+3% enemy drop chance per level",
	},
}

@export var profile_path := DEFAULT_PROFILE_PATH

var profile := {}

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if FileAccess.file_exists(profile_path):
		var file := FileAccess.open(profile_path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		profile = parsed if parsed is Dictionary else _default_profile()
	else:
		profile = _default_profile()
	_normalize_profile()
	profile_changed.emit(profile)

func save_profile() -> void:
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save profile to %s" % profile_path)
		return
	file.store_string(JSON.stringify(profile, "\t"))
	profile_changed.emit(profile)

func reset_profile() -> void:
	profile = _default_profile()
	save_profile()

func set_profile_path(path: String, reset := false) -> void:
	profile_path = path
	if reset:
		reset_profile()
	else:
		load_profile()

func talent_level(talent_id: StringName) -> int:
	return int(profile.get("talents", {}).get(str(talent_id), 0))

func talent_cost(talent_id: StringName) -> int:
	return talent_level(talent_id) + 1

func talent_max_level(_talent_id: StringName = &"") -> int:
	return TALENT_MAX_LEVEL

func talent_display_name(talent_id: StringName) -> String:
	return str(TALENT_DATA.get(talent_id, {}).get("display_name", str(talent_id)))

func talent_description(talent_id: StringName) -> String:
	return str(TALENT_DATA.get(talent_id, {}).get("description", ""))

func can_purchase_talent(talent_id: StringName) -> bool:
	if not TALENT_IDS.has(talent_id):
		return false
	if talent_level(talent_id) >= TALENT_MAX_LEVEL:
		return false
	return int(profile.get("talent_points", 0)) >= talent_cost(talent_id)

func purchase_talent(talent_id: StringName) -> bool:
	if not can_purchase_talent(talent_id):
		return false
	var talents: Dictionary = profile.get("talents", {})
	var key := str(talent_id)
	profile["talent_points"] = int(profile.get("talent_points", 0)) - talent_cost(talent_id)
	talents[key] = int(talents.get(key, 0)) + 1
	profile["talents"] = talents
	save_profile()
	return true

func calculate_rewards(stats: Dictionary) -> Dictionary:
	var highest_floor := int(stats.get("highest_floor", 1))
	var rooms_cleared := int(stats.get("rooms_cleared", 0))
	var kills := int(stats.get("kills", 0))
	var elites := int(stats.get("elites", 0))
	var mini_boss := int(stats.get("mini_boss", 0))
	var final_boss := int(stats.get("final_boss", 0))
	var completed := bool(stats.get("completed", false))
	return {
		"gold": 15 * rooms_cleared + 4 * kills + 25 * elites + 60 * mini_boss + 140 * final_boss,
		"souls": maxi(1, floori(float(highest_floor) / 2.0)) + 2 * elites + 6 * mini_boss + 14 * final_boss,
		"talent_points": 1 + floori(float(rooms_cleared) / 3.0) + mini_boss + (2 if completed else 0),
	}

func award_run(stats: Dictionary) -> Dictionary:
	var rewards := calculate_rewards(stats)
	profile["gold"] = int(profile.get("gold", 0)) + int(rewards.get("gold", 0))
	profile["souls"] = int(profile.get("souls", 0)) + int(rewards.get("souls", 0))
	profile["talent_points"] = int(profile.get("talent_points", 0)) + int(rewards.get("talent_points", 0))
	profile["last_run"] = {
		"stats": stats.duplicate(true),
		"rewards": rewards.duplicate(true),
	}
	save_profile()
	run_awarded.emit(rewards, stats)
	return rewards

func stat_modifiers() -> Dictionary:
	return {
		"max_health": talent_level(&"vital_core") * 10.0,
		"armor": talent_level(&"reinforced_plating") * 4.0,
		"armor_durability": talent_level(&"reinforced_plating") * 12.0,
		"damage_multiplier": talent_level(&"weapon_training") * 0.05,
	}

func drop_chance_bonus() -> float:
	return talent_level(&"scavenger_instinct") * 0.03

func profile_snapshot() -> Dictionary:
	return profile.duplicate(true)

func _default_profile() -> Dictionary:
	return {
		"gold": 0,
		"souls": 0,
		"talent_points": 0,
		"talents": {
			"vital_core": 0,
			"reinforced_plating": 0,
			"weapon_training": 0,
			"scavenger_instinct": 0,
		},
		"last_run": {},
	}

func _normalize_profile() -> void:
	var defaults := _default_profile()
	for key in defaults.keys():
		if not profile.has(key):
			profile[key] = defaults[key]
	var talents: Dictionary = profile.get("talents", {})
	for talent_id in TALENT_IDS:
		var key := str(talent_id)
		talents[key] = clampi(int(talents.get(key, 0)), 0, TALENT_MAX_LEVEL)
	profile["talents"] = talents
