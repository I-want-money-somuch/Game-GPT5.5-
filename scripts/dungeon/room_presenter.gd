class_name RoomPresenter
extends Node2D

@onready var floor_rect: ColorRect = $Floor
@onready var floor_texture: TextureRect = get_node_or_null("FloorTexture") as TextureRect
@onready var title_label: Label = $RoomTitle
@onready var forge_marker: Polygon2D = $ForgeMarker
@onready var reward_marker: Polygon2D = $RewardMarker

var border_nodes: Array[ColorRect] = []
var wall_texture_nodes: Array[TextureRect] = []
var localization_service: Node
var current_definition: Resource

func _ready() -> void:
	border_nodes = [$NorthLine, $SouthLine, $WestLine, $EastLine]
	wall_texture_nodes = [
		get_node_or_null("NorthWallTexture") as TextureRect,
		get_node_or_null("SouthWallTexture") as TextureRect,
		get_node_or_null("WestWallTexture") as TextureRect,
		get_node_or_null("EastWallTexture") as TextureRect,
	]

func apply_room(definition: Resource) -> void:
	if definition == null:
		return
	current_definition = definition

	var floor_color: Color = definition.get("floor_color")
	var accent_color: Color = definition.get("accent_color")
	floor_rect.color = floor_color
	if floor_texture != null:
		floor_texture.modulate = floor_color.lightened(0.2)
	for border in border_nodes:
		border.color = accent_color
	for wall_texture in wall_texture_nodes:
		if wall_texture != null:
			wall_texture.modulate = accent_color.darkened(0.12)

	title_label.text = _resource_name(definition)
	title_label.modulate = accent_color.lightened(0.35)
	forge_marker.visible = false
	reward_marker.visible = false
	forge_marker.color = accent_color.lightened(0.18)
	reward_marker.color = accent_color.lightened(0.18)

func set_localization_service(service: Node) -> void:
	localization_service = service
	if localization_service != null and localization_service.has_signal("language_changed"):
		var language_callable := Callable(self, "_on_language_changed")
		if not localization_service.language_changed.is_connected(language_callable):
			localization_service.language_changed.connect(language_callable)
	if current_definition != null:
		apply_room(current_definition)

func _on_language_changed(_language: String) -> void:
	if current_definition != null:
		apply_room(current_definition)

func _resource_name(resource: Resource) -> String:
	if localization_service != null and localization_service.has_method("resource_name"):
		return localization_service.resource_name(resource)
	if resource == null:
		return ""
	return str(resource.get("display_name"))
