class_name Hitbox3D
extends Area3D

@export var damage: float = 8.0
@export var knockback_direction: Vector3 = Vector3(1, 0.5, 0)
@export var active_time: float = 0.1

var active := false
var already_hit := {}

func activate() -> void:
	already_hit.clear()
	active = true
	monitoring = true

	await get_tree().create_timer(active_time).timeout

	monitoring = false
	active = false

func _on_body_entered(body: Node3D):
	if body == get_parent():
		return

	if not active:
		return

	if already_hit.has(body.get_instance_id()):
		return

	print("HIT:", body.name)
	if body.has_method("apply_knockback"):
		already_hit[body.get_instance_id()] = true
		var attacker_yaw = owner.model_pivot.rotation.y
		var rotated_direction = knockback_direction.rotated(Vector3.UP, attacker_yaw)
		body.apply_knockback(rotated_direction, damage)
