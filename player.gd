extends CharacterBody2D

const DustEffectScene = preload("res://dust_effect.tscn")

@onready var ground_detector: ShapeCast2D = $Detectors/Ground

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state_machine: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var coyote_jump_timer: Timer = $CoyoteJumpTimer

var character_controller: CharacterController

var gravity: float = 0.0
var jump_velocity: float = 0.0
var has_jumped := false

var jump_tween: Tween = null
var jump_variable_height_tween: Tween = null
var was_on_ground := false

var last_direction := 1

@export var max_horizontal_move_speed := 45.0
@export var falling_speed_modifier := 1.4
@export var ground_friction_deceleration := 135.0 # px/s²
@export var ground_acceleration := 1200.0 # px/s²

@export_group("Jump")
@export var jump_height := 90.0:
	set(value):
		jump_height = value
		calculate_gravity_and_jump_velocity()

@export var time_to_jump_apex := .3:
	set(value):
		time_to_jump_apex = value
		calculate_gravity_and_jump_velocity()

@export var jump_height_modifier := .4
@export var min_jump_velocity_modifier := .5

func create_dust_effect() -> void:
	if not is_on_ground():
		return
	var dust_effect := DustEffectScene.instantiate()
	var main := get_tree().current_scene
	main.add_child(dust_effect)
	dust_effect.global_position = global_position

func is_on_ground() -> bool:
	var result := ground_detector.get_collision_result()
	return result.size() > 0

func _ready() -> void:
	character_controller = CharacterController.new(-1, self)
	animation_state_machine.travel("idle")
	calculate_gravity_and_jump_velocity()

func _process(delta: float) -> void:
	character_controller.process_inputs(delta)

func calculate_gravity_and_jump_velocity():
	gravity = (2 * jump_height) / pow(time_to_jump_apex, 2)
	jump_velocity = -(2 * jump_height) / time_to_jump_apex

func make_dash() -> void:
	pass

func make_jump() -> void:
	if is_on_ground() or coyote_jump_timer.time_left > 0:
		velocity.y = jump_velocity
		if jump_tween and jump_tween.is_running():
			return
		jump_tween = create_tween()
		jump_tween.tween_property(self, "has_jumped", true, 0)
		jump_tween.tween_property(self, "has_jumped", false, 0.1)

func make_jump_cut() -> void:
	if velocity.y > 0:
		return
	var current_velocity_in_threshold := velocity.y < (jump_velocity * min_jump_velocity_modifier)
	if  current_velocity_in_threshold and not is_on_ground():
		var new_jump_height = jump_height_modifier * jump_height
		if jump_variable_height_tween and jump_variable_height_tween.is_running():
			return
		jump_variable_height_tween = create_tween()
		jump_variable_height_tween.tween_property(self, "jump_height", jump_height, .5)
		jump_height = new_jump_height
		velocity.y = jump_velocity

func _physics_process(delta: float) -> void:
	var just_left_ledge := not is_on_ground() and was_on_ground
	if just_left_ledge:
		coyote_jump_timer.start()

	was_on_ground = is_on_ground()

	if not is_on_ground():
		if velocity.y != 0:
			velocity.y += gravity * delta
		else:
			velocity.y += (falling_speed_modifier * gravity) * delta
	
	var input_dir := character_controller.last_input_axis

	if input_dir == 0:
		velocity.x = move_toward(velocity.x, 0, ground_friction_deceleration * delta)
	else:
		flip_sprite(input_dir)
		velocity.x = move_toward(velocity.x, input_dir * max_horizontal_move_speed, ground_acceleration * delta)

	move_and_slide()

func flip_sprite(input_dir: float) -> void:
	sprite_2d.flip_h = input_dir == -1

func is_moving():
	var input_dir = character_controller.last_input_axis
	return input_dir != 0
