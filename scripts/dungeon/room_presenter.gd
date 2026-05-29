class_name RoomPresenter
extends Node2D

@onready var floor_rect: ColorRect = $Floor
@onready var floor_texture: TextureRect = get_node_or_null("FloorTexture") as TextureRect
@onready var title_label: Label = $RoomTitle
@onready var forge_marker: Polygon2D = $ForgeMarker
@onready var reward_marker: Polygon2D = $RewardMarker

var border_nodes: Array[ColorRect] = []
var wall_texture_nodes: Array[TextureRect] = []

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

	title_label.text = definition.display_name
	title_label.modulate = accent_color.lightened(0.35)
	forge_marker.visible = false
	reward_marker.visible = false
	forge_marker.color = accent_color.lightened(0.18)
	reward_marker.color = accent_color.lightened(0.18)
