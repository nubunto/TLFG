extends Resource
class_name AbstractEffect

@export var EffectScene: PackedScene

# Triggers this effect.
# Default behavior: instantiates the EffectScene in the position of the @param node.
# Returns: instance created
func trigger(node: Node2D, global_position_override: Vector2 = Vector2.ZERO) -> Node:
	var main := node.get_tree().root
	var instance := EffectScene.instantiate()
	main.add_child(instance)
	instance.global_position = node.global_position
	if global_position_override.length() > 0:
		instance.global_position = global_position_override
	
	return instance
