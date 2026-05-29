class_name SettingsService
extends Node

signal settings_changed(settings: Dictionary)
signal language_changed(language: String)

const DEFAULT_SETTINGS_PATH := "user://settings_v1.json"
const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["en", "zh_CN"]

@export var settings_path := DEFAULT_SETTINGS_PATH

var settings := {}

func _ready() -> void:
	add_to_group("settings_service")
	load_settings()

func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var file := FileAccess.open(settings_path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		settings = parsed if parsed is Dictionary else _default_settings()
	else:
		settings = _default_settings()
	_normalize_settings()
	settings_changed.emit(settings)
	language_changed.emit(get_language())

func save_settings() -> void:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save settings to %s" % settings_path)
		return
	file.store_string(JSON.stringify(settings, "\t"))
	settings_changed.emit(settings)

func set_settings_path(path: String, reset := false) -> void:
	settings_path = path
	if reset:
		reset_settings()
	else:
		load_settings()

func reset_settings() -> void:
	settings = _default_settings()
	save_settings()
	language_changed.emit(get_language())

func get_language() -> String:
	return _normalize_language(str(settings.get("language", DEFAULT_LANGUAGE)))

func set_language(language: String) -> void:
	var normalized := _normalize_language(language)
	if get_language() == normalized:
		return
	settings["language"] = normalized
	save_settings()
	language_changed.emit(normalized)

func settings_snapshot() -> Dictionary:
	return settings.duplicate(true)

func _default_settings() -> Dictionary:
	return {
		"language": DEFAULT_LANGUAGE,
	}

func _normalize_settings() -> void:
	var defaults := _default_settings()
	for key in defaults.keys():
		if not settings.has(key):
			settings[key] = defaults[key]
	settings["language"] = _normalize_language(str(settings.get("language", DEFAULT_LANGUAGE)))

func _normalize_language(language: String) -> String:
	return language if SUPPORTED_LANGUAGES.has(language) else DEFAULT_LANGUAGE
