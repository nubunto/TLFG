extends Area2D
class_name Hurtbox

@export var who_to_damage: CharacterBody2D

func on_damage(damage: float) -> void:
	if who_to_damage == null:
		push_warning("who_to_damage is null, no one to damage!")
		return
	if !who_to_damage.has_method("take_damage"):
		push_warning("node ", who_to_damage, " has no method take_damage")
		return

	who_to_damage.take_damage(damage)
