extends HitEffect
class_name ScreenshakeEffect

@export var event_bus: EventBus

func trigger(node: Node2D, _global_position_override: Vector2 = Vector2.ZERO) -> Node:
	event_bus.screen.screen_shake.emit()
	return null
