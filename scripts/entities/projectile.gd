class_name Projectile
extends Area2D

const GameConstantsScript := preload("res://scripts/core/game_constants.gd")

var velocity := Vector2.ZERO
var owner_entity: Node
var team := GameConstantsScript.Team.PLAYER
var weapon_definition: Resource
var remaining_pierce := 0
var lifetime := 1.0

func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)

func setup(weapon: Resource, direction: Vector2, source: Node, team_id: int) -> void:
	weapon_definition = weapon
	owner_entity = source
	team = team_id
	remaining_pierce = weapon.pierce
	lifetime = weapon.projectile_lifetime
	velocity = direction.normalized() * weapon.projectile_speed
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == _valid_owner() or weapon_definition == null:
		return

	if team == GameConstantsScript.Team.PLAYER and body.is_in_group("enemies"):
		_hit(body)
	elif team == GameConstantsScript.Team.ENEMY and body.is_in_group("players"):
		_hit(body)

func _hit(body: Node) -> void:
	var valid_owner := _valid_owner()
	var packet = weapon_definition.create_damage_packet(valid_owner)
	packet.hit_direction = velocity.normalized()
	packet.hit_position = global_position
	if valid_owner != null and valid_owner.has_method("modify_outgoing_packet"):
		valid_owner.modify_outgoing_packet(packet, weapon_definition)
	body.take_damage(packet)
	if team == GameConstantsScript.Team.PLAYER and valid_owner != null and valid_owner.has_method("notify_weapon_hit"):
		valid_owner.notify_weapon_hit(packet, weapon_definition, body)
	if remaining_pierce <= 0:
		queue_free()
	else:
		remaining_pierce -= 1

func _valid_owner() -> Node:
	return owner_entity if owner_entity != null and is_instance_valid(owner_entity) else null
