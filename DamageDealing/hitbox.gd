extends Area2D
class_name Hitbox

@export var damage := 1.0
@export var hit_effects: Array[HitEffect]

var already_collided: Array[RID]

func _on_body_entered(body: Node2D) -> void:
	on_hit_solid(body)

func _on_area_entered(area: Area2D) -> void:
	if already_collided.has(area.get_rid()): return
	
	already_collided.append(area.get_rid())
	on_hit(area)

func on_hit(_node) -> void:
	for effect in hit_effects:
		effect.trigger(self)

func on_hit_solid(_node) -> void:
	pass
