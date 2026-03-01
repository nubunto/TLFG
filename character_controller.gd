class_name CharacterController
extends RefCounted

const BUFFER_LENIENCY_MS = 16 * 15

# A character controller has the primary function of tracking inputs
# and "driving" the target character body based on that input.
# The character controller might also implement a buffer internally.

var target_character_body: CharacterBody2D

var interface := [
	"make_jump",
	"make_jump_cut",
	"make_dash",
	"make_attack"
]

var bufferable_actions: Array[StringName]

var last_input_axis := 0
var input_device: DeviceInput
var buffer: Array[Dictionary] = []

func _ready() -> void:
	if target_character_body == null:
		push_error("target_character_body must be set")

	for method in interface:
		if not target_character_body.has_method(method):
			push_error("target_character_body does not implement method: ", method)

func _init(device: int, target: CharacterBody2D) -> void:
	input_device = DeviceInput.new(device)
	target_character_body = target

func process_inputs(_delta: float) -> void:
	if not input_device: return

	if input_device.is_action_just_pressed("jump"):
		target_character_body.make_jump()
	
	if input_device.is_action_just_released("jump"):
		target_character_body.make_jump_cut()
	
	if input_device.is_action_pressed("dash"):
		target_character_body.make_dash()
	
	if input_device.is_action_just_pressed("attack"):
		target_character_body.make_attack()
	
	var axis := input_device.get_axis("move_left", "move_right")
	last_input_axis = sign(axis)

func buffer_input(action: InputEvent) -> void:
	for bufferable_action in bufferable_actions:
		if action.is_action_pressed(bufferable_action):
			buffer.append({
				"action": bufferable_action,
				"timestamp": Time.get_ticks_msec(),
			})

func process_buffer() -> void:
	for dict in buffer:
		var current_time = Time.get_ticks_msec()
		if current_time - dict["timestamp"] <= BUFFER_LENIENCY_MS:
			target_character_body.call("make_%s" % dict["action"])
	buffer.clear()
