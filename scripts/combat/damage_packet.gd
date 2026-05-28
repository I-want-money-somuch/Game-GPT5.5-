class_name DamagePacket
extends RefCounted

var amount := 0.0
var element: StringName = &"physical"
var crit_chance := 0.0
var crit_multiplier := 1.5
var armor_pierce := 0.0
var knockback_force := 0.0
var hit_direction := Vector2.ZERO
var hit_position := Vector2.ZERO
var source: Node
var tags: Array[StringName] = []
