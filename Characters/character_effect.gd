extends Resource
class_name CharacterEffect

@export var EffectScene: PackedScene

func trigger(node: Node2D, global_position_override: Vector2 = Vector2.ZERO) -> Variant:
	var main := node.get_tree().current_scene
	var instance = EffectScene.instantiate()
	main.add_child(instance)
	instance.global_position = node.global_position
	if global_position_override.length() > 0:
		instance.global_position = global_position_override
	
	return instance
