extends CharacterBody3D

const PLATFORM_LAYER = 3

enum State {
	IDLE,
	DASH,
}

@export var ground_normal_threshold: float
@export var wall_normal_threshold: float
@export var initial_direction: Vector3 = Vector3(-1, 0, 0)
@export var movement_stats: MovementStats
@export var combat_stats: CombatStats
@export var input_config: PlayerInput
@export var input_buffer: InputBuffer

@onready var model_pivot: Node3D = $ModelPivot
@onready var jump_timer: Timer = $Timers/JumpTimer
@onready var hitbox: Hitbox3D = $ModelPivot/Hitbox

@onready var back_feet: RayCast3D = $Detectors/BackFeet
@onready var center_feet: RayCast3D = $Detectors/CenterFeet
@onready var right_feet: RayCast3D = $Detectors/RightFeet

var detectors: Array[RayCast3D]

var current_state: State = State.IDLE
var hitstun_timer: float = 0.0
var was_on_floor: bool = false
var is_beside_platform: bool = false

var ground_detection_enabled: bool = false:
	set(value):
		for d in detectors:
			d.enabled = value
		ground_detection_enabled = value

#region IDLE variables
var is_fastfalling: bool = false
#endregion

#region DASH variables
var dash_direction: int = 0
var dash_timer: float = 0
#endregion

#region combat variables
var percent: float = 0.0
var current_stocks: int
#endregion

func _ready() -> void:
	jump_timer.timeout.connect(on_jump_timer_timeout)
	movement_stats.compute_jump_values()
	current_stocks = combat_stats.stocks
	detectors = [back_feet, center_feet, right_feet]
	correct_mesh_orientation(initial_direction)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action(input_config.down_action):
		input_buffer.press(input_config.down_action)
	if event.is_action(input_config.jump_action):
		input_buffer.press(input_config.jump_action)

func _physics_process(delta: float) -> void:
	is_beside_platform = false
	correct_mesh_orientation(velocity)
	apply_platform_handling()
	apply_landing()
	if hitstun_timer > 0:
		hitstun_timer -= delta
		apply_gravity(delta)
		apply_slide(delta)
		return

	var input_dir := Input.get_action_strength(input_config.right_action) - Input.get_action_strength(input_config.left_action)
	match current_state:
		State.IDLE:
			idle_state(input_dir)
			try_attack()
			try_fastfall()
			handle_movement(input_dir, delta)
		State.DASH:
			dash_state(input_dir, delta)
			try_attack()
			try_jump()
			apply_gravity(delta)
			apply_slide(delta)

func on_jump_timer_timeout() -> void:
	ground_detection_enabled = true

func is_ground_detected() -> bool:
	if velocity.y > 0:
		# ground detection only happens when moving down
		return false

	for d in detectors:
		if d == null:
			continue
		if d.is_colliding():
			var normal := d.get_collision_normal()
			if normal.length() >= ground_normal_threshold:
				return true
			return false
	return false

func apply_knockback(direction: Vector3, damage: float) -> void:
	percent += damage
	var knockback = combat_stats.base_knockback + percent * combat_stats.knockback_scaling
	velocity = direction.normalized() * knockback
	print(">> ", percent)
	
	hitstun_timer = knockback * 0.05

func correct_mesh_orientation(dir: Vector3):
	dir.y = 0
	if dir.length() > .1:
		var yaw := atan2(dir.x, -dir.z)
		model_pivot.rotation.y = yaw

func apply_landing():
	var on_floor := is_ground_detected()
	if on_floor:
		is_fastfalling = false
		is_beside_platform = false

	if was_on_floor and not on_floor:
		model_pivot.scale = Vector3(.8, 1.2, .8)

	if not was_on_floor and on_floor:
		model_pivot.scale = Vector3(1.2, 0.7, 1.2)

	model_pivot.scale = model_pivot.scale.lerp(Vector3.ONE, 0.2)

	was_on_floor = on_floor

func try_attack() -> void:
	if Input.is_action_just_pressed(input_config.attack_action):
		hitbox.activate()

func try_fastfall() -> void:
	if is_ground_detected():
		is_fastfalling = false
		return
	if input_buffer.consume(input_config.down_action) and velocity.y <= 0 and not is_fastfalling:
		is_fastfalling = true

func dash_state(input_dir: float, delta: float) -> void:
	if not is_ground_detected():
		current_state = State.IDLE
		return

	dash_timer -= delta

	if dash_timer <= 0 and input_dir == 0:
		current_state = State.IDLE
		return

	velocity.x = dash_direction * movement_stats.dash_speed
	
	# dash dancing
	# reset timer, move to new direction
	if input_dir != 0 and dash_timer > 0:
		dash_timer = movement_stats.dash_time
		dash_direction = sign(input_dir)

func idle_state(input_dir: float) -> void:
	if input_dir != 0 and is_ground_detected():
		current_state = State.DASH
		dash_timer = movement_stats.dash_time
		dash_direction = sign(input_dir)
		velocity.x = dash_direction * movement_stats.dash_speed
	
func apply_gravity(delta: float) -> void:
	var gravity_up_final := movement_stats.gravity_up * movement_stats.gravity_up_mult
	var gravity_down_final := movement_stats.gravity_down * movement_stats.gravity_down_mult
	
	if not is_ground_detected():
		if velocity.y > 0:
			velocity.y -= gravity_up_final * delta
		else:
			if is_fastfalling:
				velocity.y -= gravity_down_final * movement_stats.fastfall_mult * delta
			else:
				velocity.y -= gravity_down_final * delta
	else:
		velocity.y = min(velocity.y, 0)

func try_jump() -> void:
	if input_buffer.consume(input_config.jump_action) and is_ground_detected():
		jump_timer.start()
		ground_detection_enabled = false
		velocity.y = movement_stats.jump_speed

func handle_movement(input_dir: float, delta: float) -> void:
	var accel: float
	var max_speed: float
	
	if is_ground_detected():
		accel = movement_stats.ground_acceleration
		max_speed = movement_stats.ground_horizontal_speed
	else:
		accel = movement_stats.air_acceleration
		max_speed = movement_stats.air_max_speed

	var target = input_dir * max_speed
	velocity.x = move_toward(velocity.x, target, accel * delta)

	apply_gravity(delta)

	try_jump()
	
	apply_friction(input_dir, delta)
	apply_slide(delta)


func apply_friction(input_dir: float, delta: float) -> void:
	if not is_ground_detected():
		return
	if input_dir != 0:
		return

	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	if horizontal_vel.length() == 0:
		return

	var friction_amount: float = movement_stats.ground_friction
	var friction_force = friction_amount * delta

	if horizontal_vel.length() <= friction_force:
		horizontal_vel = Vector3.ZERO
	else:
		horizontal_vel -= horizontal_vel.normalized() * friction_force

	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z

func apply_slide(delta: float) -> void:
	var motion = velocity * delta
	for i in max_slides:
		var col := move_and_collide(motion, true)
		if not col:
			move_and_collide(motion)
			break

		var normal := col.get_normal()
		if abs(normal.x) >= wall_normal_threshold:
			if is_platform(col.get_collider()):
				set_collision_mask_value(3, false)
				is_beside_platform = true
				motion = col.get_remainder()
				move_and_collide(motion)

				break

		col = move_and_collide(motion)
		if normal.y >= ground_normal_threshold:
			velocity.y = max(velocity.y, 0)
		else:
			velocity = velocity.slide(normal)

		motion = col.get_remainder()

func is_platform(collider) -> bool:
	return collider.get_collision_layer_value(PLATFORM_LAYER)

func apply_platform_handling() -> void:
	if velocity.y <= 0 and not is_beside_platform:
		set_collision_mask_value(PLATFORM_LAYER, true)
	else:
		set_collision_mask_value(PLATFORM_LAYER, false)
