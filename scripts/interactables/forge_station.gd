class_name ForgeStation
extends Area2D

signal activated(station: Node)

@onready var core_shape: Node2D = $CoreShape

func _ready() -> void:
	add_to_group("interactables")

func can_interact(_player: Node) -> bool:
	return true

func get_prompt_text() -> String:
	return "Use Forge"

func interact(_player: Node) -> void:
	_pulse()
	activated.emit(self)

func _pulse() -> void:
	core_shape.scale = Vector2.ONE
	var tween := core_shape.create_tween()
	tween.tween_property(core_shape, "scale", Vector2(1.18, 1.18), 0.08)
	tween.tween_property(core_shape, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
