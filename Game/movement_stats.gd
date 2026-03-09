class_name MovementStats
extends Resource

@export_group("Ground movement")
@export var ground_horizontal_speed: float
@export var ground_friction: float
@export var ground_acceleration: float

@export_group("Dash")
@export var dash_speed: float
@export var dash_time_frames: float

@export_group("Air")
@export var air_friction: float
@export var air_max_speed: float
@export var air_acceleration: float
@export var ledge_assist_speed: float
@export var airdodge_speed: float
@export var airdodge_duration_frames: int

@export_group("Jump")
@export var jumpsquat_frames: int = 4
@export var jump_height: float
@export var time_to_apex: float
@export var gravity_up_mult: float
@export var gravity_down_mult: float
@export var fastfall_mult: float
@export var fall_gravity_mult: float
@export var shorthop_mult: float

@export_group("Hit stun")
@export var hitstun_gravity: float

@export_group("Platdrop")
@export var min_platdrop_frames: int = 15

var gravity_up: float
var gravity_down: float
var jump_speed: float

func compute_jump_values() -> void:
	gravity_up = (2.0 * jump_height) / (time_to_apex * time_to_apex)
	jump_speed = gravity_up * time_to_apex
	gravity_down = gravity_up * fall_gravity_mult
	
	print({"gravity_up": gravity_up, "jump_speed": jump_speed, "short_hop": jump_speed * shorthop_mult, "gravity_down": gravity_down})
	
