class_name BossAttackEffect
extends Node2D

const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")

enum ShapeType {
	CIRCLE,
	LINE
}

var source: Node
var target: Node2D
var shape_type := ShapeType.CIRCLE
var damage := 10.0
var radius := 48.0
var length := 160.0
var width := 44.0
var direction := Vector2.RIGHT
var warning_duration := 0.55
var linger_duration := 0.12
var knockback_force := 120.0
var pull_to_center := false
var color := Color(1.0, 0.25, 0.15, 0.42)

var visual: Polygon2D

func _ready() -> void:
	add_to_group("boss_attack_effects")
	_build_visual()
	get_tree().create_timer(maxf(warning_duration, 0.01)).timeout.connect(_activate)

func configure_circle(config: Dictionary) -> void:
	source = config.get("source")
	target = config.get("target")
	damage = float(config.get("damage", damage))
	radius = float(config.get("radius", radius))
	warning_duration = float(config.get("warning_duration", warning_duration))
	linger_duration = float(config.get("linger_duration", linger_duration))
	knockback_force = float(config.get("knockback_force", knockback_force))
	pull_to_center = bool(config.get("pull_to_center", false))
	color = config.get("color", color)
	shape_type = ShapeType.CIRCLE

func configure_line(config: Dictionary) -> void:
	source = config.get("source")
	target = config.get("target")
	damage = float(config.get("damage", damage))
	length = float(config.get("length", length))
	width = float(config.get("width", width))
	direction = config.get("direction", direction).normalized()
	warning_duration = float(config.get("warning_duration", warning_duration))
	linger_duration = float(config.get("linger_duration", linger_duration))
	knockback_force = float(config.get("knockback_force", knockback_force))
	color = config.get("color", color)
	shape_type = ShapeType.LINE
	rotation = direction.angle()

func _build_visual() -> void:
	visual = Polygon2D.new()
	visual.color = color
	visual.z_index = 18
	if shape_type == ShapeType.CIRCLE:
		visual.polygon = _circle_polygon(radius, 24)
	else:
		visual.polygon = PackedVector2Array([
			Vector2(0, -width * 0.5),
			Vector2(length, -width * 0.5),
			Vector2(length, width * 0.5),
			Vector2(0, width * 0.5),
		])
	add_child(visual)

	var tween := visual.create_tween()
	tween.tween_property(visual, "modulate:a", 0.85, warning_duration).from(0.18)

func _activate() -> void:
	_apply_damage()
	if visual != null:
		visual.color = color.lightened(0.35)
		var tween := visual.create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, maxf(linger_duration, 0.01))
	get_tree().create_timer(maxf(linger_duration, 0.01)).timeout.connect(queue_free)

func _apply_damage() -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	if not _target_inside(target.global_position):
		return

	var valid_source := _valid_source()
	var packet = DamagePacketScript.new()
	packet.amount = damage
	packet.source = valid_source
	packet.element = &"physical"
	packet.hit_position = target.global_position
	packet.hit_direction = _hit_direction(target.global_position)
	packet.knockback_force = knockback_force
	target.take_damage(packet)
	if valid_source != null and valid_source.has_method("notify_damage_dealt"):
		valid_source.notify_damage_dealt(packet, target)

func _valid_source() -> Node:
	return source if source != null and is_instance_valid(source) else null

func _target_inside(point: Vector2) -> bool:
	if shape_type == ShapeType.CIRCLE:
		return global_position.distance_to(point) <= radius

	var local := point - global_position
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var along := local.dot(forward)
	var lateral := absf(local.dot(side))
	return along >= 0.0 and along <= length and lateral <= width * 0.5

func _hit_direction(point: Vector2) -> Vector2:
	if pull_to_center:
		return (global_position - point).normalized()
	if shape_type == ShapeType.LINE:
		return direction.normalized()
	return (point - global_position).normalized()

func _circle_polygon(target_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := float(index) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * target_radius)
	return points
