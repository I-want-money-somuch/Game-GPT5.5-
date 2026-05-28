class_name RoomPresenter
extends Node2D

@onready var floor_rect: ColorRect = $Floor
@onready var title_label: Label = $RoomTitle
@onready var forge_marker: Polygon2D = $ForgeMarker
@onready var reward_marker: Polygon2D = $RewardMarker

var border_nodes: Array[ColorRect] = []

func _ready() -> void:
	border_nodes = [$NorthLine, $SouthLine, $WestLine, $EastLine]

func apply_room(definition: Resource) -> void:
	if definition == null:
		return

	var floor_color: Color = definition.get("floor_color")
	var accent_color: Color = definition.get("accent_color")
	floor_rect.color = floor_color
	for border in border_nodes:
		border.color = accent_color

	title_label.text = definition.display_name
	title_label.modulate = accent_color.lightened(0.35)
	forge_marker.visible = false
	reward_marker.visible = false
	forge_marker.color = accent_color.lightened(0.18)
	reward_marker.color = accent_color.lightened(0.18)
