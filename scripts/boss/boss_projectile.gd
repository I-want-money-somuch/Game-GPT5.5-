class_name BossProjectile
extends Area2D

const DamagePacketScript := preload("res://scripts/combat/damage_packet.gd")
const PROJECTILE_TEXTURE := preload("res://assets/sprites/effects/boss_projectile.png")

var source: Node
var velocity := Vector2.ZERO
var damage := 10.0
var knockback_force := 100.0
var pierce := 0
var lifetime := 2.0
var color := Color(0.75, 0.2, 1.0, 1.0)
var projectile_sprite: Sprite2D

func _ready() -> void:
	add_to_group("boss_projectiles")
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_shape()

func configure(config: Dictionary) -> void:
	source = config.get("source")
	var direction: Vector2 = config.get("direction", Vector2.RIGHT)
	velocity = direction.normalized() * float(config.get("speed", 360.0))
	damage = float(config.get("damage", damage))
	knockback_force = float(config.get("knockback_force", knockback_force))
	pierce = int(config.get("pierce", pierce))
	lifetime = float(config.get("lifetime", lifetime))
	color = config.get("color", color)
	rotation = direction.angle()
	if projectile_sprite != null:
		projectile_sprite.modulate = color

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	var valid_source := _valid_source()
	if body == valid_source or not body.is_in_group("players") or not body.has_method("take_damage"):
		return

	var packet = DamagePacketScript.new()
	packet.amount = damage
	packet.source = valid_source
	packet.element = &"physical"
	packet.hit_position = global_position
	packet.hit_direction = velocity.normalized()
	packet.knockback_force = knockback_force
	body.take_damage(packet)
	if valid_source != null and valid_source.has_method("notify_damage_dealt"):
		valid_source.notify_damage_dealt(packet, body)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1

func _valid_source() -> Node:
	return source if source != null and is_instance_valid(source) else null

func _build_shape() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = PROJECTILE_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = color
	sprite.scale = Vector2(0.62, 0.62)
	projectile_sprite = sprite
	add_child(sprite)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	collision.shape = circle
	add_child(collision)
