extends CharacterBody3D

var percent := 0.0

func apply_knockback(direction: Vector3, damage: float) -> void:
	percent += damage
	velocity = direction.normalized() * 10.0
	print("Dummy hit. Percent:", percent)
