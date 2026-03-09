class_name PlayerInput
extends Resource

@export var device_id: int = -1
@export var down_action: String
@export var up_action: String
@export var left_action: String
@export var right_action: String
@export var jump_action: String
@export var attack_action: String
@export var shield_action: String

func get_input_vector() -> Vector2:
	if device_id == -1:
		return Input.get_vector(left_action, right_action, down_action, up_action)
	return Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)
