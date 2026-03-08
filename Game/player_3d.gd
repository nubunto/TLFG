extends CharacterBody3D

const PLATFORM_LAYER = 3
const MIN_HITSTUN_FRAMES = 5
const BASE_TARGET_FPS = 60.0
const JUMPSQUAT_FRAMES = 4
const KO_RADIUS = 24

func create_frame_timer(num_frames: float) -> float:
	return num_frames / BASE_TARGET_FPS

enum State {
	IDLE,
	DASH,
	HITSTUN,
	JUMPSQUAT,
	PLATDROP,
	ATTACK,
}

enum Attack {
	Combo,
	Kill
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
@onready var kill_attack: Hitbox3D = $ModelPivot/Kill
@onready var combo_attack: Hitbox3D = $ModelPivot/Combo

@onready var back_feet: RayCast3D = $Detectors/BackFeet
@onready var center_feet: RayCast3D = $Detectors/CenterFeet
@onready var right_feet: RayCast3D = $Detectors/RightFeet

@onready var ko_anchor: Marker3D = $KOAnchor

func get_ko_anchor() -> Vector3:
	return ko_anchor.global_position

func register_ko() -> void:
	combat_stats.stocks -= 1
	if combat_stats.stocks <= 0:
		queue_free()

	velocity = Vector3.ZERO
	percent = 0.0

var detectors: Array[RayCast3D]

var current_state: State = State.IDLE
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

#region HITSTUN variables
var hitstun_timer: float = 0.0
#endregion

#region JUMPSQUAT variables
var jumpsquat_timer: float = 0.0
var is_shorthopping := false
#endregion

#region PLATDROP variables
var platdrop_timer: float = 0.0
#endregion

#region ATTACK variables
var can_trigger_cstick_attack := true
const C_STICK_ATTACK_THRESHOLD := -0.70
const C_STICK_RESET_THRESHOLD := -0.25
var attack_timer: float = 0.0
var current_attack: Attack = Attack.Combo
#endregion

#region combat variables
var percent: float = 0.0
var current_stocks: int
#endregion

#region hitlag variables
var hitlag_timer: float = 0.0
#endregion

func _ready() -> void:
	jump_timer.timeout.connect(on_jump_timer_timeout)
	movement_stats.compute_jump_values()
	current_stocks = combat_stats.stocks
	detectors = [back_feet, center_feet, right_feet]
	kill_attack.add_exception(self)
	combo_attack.add_exception(self)
	correct_mesh_orientation(initial_direction)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(input_config.jump_action):
		input_buffer.press(input_config.jump_action)
	if event.is_action_released(input_config.jump_action):
		input_buffer.press("release %s".format([input_config.jump_action]))
	if event.is_action_pressed(input_config.down_action):
		input_buffer.press(input_config.down_action)

func _physics_process(delta: float) -> void:
	if is_in_hitlag():
		hitlag_timer -= delta
		return

	is_beside_platform = false
	correct_mesh_orientation(velocity)
	apply_platform_handling()
	apply_landing()


	var input_dir := Input.get_action_strength(input_config.right_action) - Input.get_action_strength(input_config.left_action)
	match current_state:
		State.IDLE:
			idle_state(input_dir)
			try_attack()
			try_fastfall()
			try_platdrop()
			handle_movement(input_dir, delta)
		State.DASH:
			dash_state(input_dir, delta)
			try_attack()
			try_jump()
			try_platdrop()
			apply_gravity(delta)
			apply_slide(delta)
		State.JUMPSQUAT:
			jumpsquat_state(input_dir, delta)
		State.PLATDROP:
			platdrop_state(input_dir, delta)
			apply_gravity(delta)
			apply_slide(delta)
		State.ATTACK:
			attack_state(delta)
			apply_friction(input_dir, delta)
			apply_gravity(delta)
			apply_slide(delta)
		State.HITSTUN:
			hitstun_state(input_dir, delta)
			apply_hitstun_gravity(delta)

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
			if normal.y >= ground_normal_threshold:
				return true
			return false
	return false

func get_ground_collider():
	for d in detectors:
		if d.is_colliding():
			return d.get_collider()
	var col := move_and_collide(Vector3.DOWN, true)
	if not col:
		return null
	return col.get_collider()

func apply_knockback(direction: Vector2, damage: float, base_knockback: float, knockback_scaling: float, hitstun_frames: float) -> void:
	var knockback := base_knockback + (percent * knockback_scaling)
	percent += damage
	var dir_vel := direction.normalized() * knockback
	velocity.x = dir_vel.x
	velocity.y = dir_vel.y
	
	current_state = State.HITSTUN
	hitstun_timer = create_frame_timer(max(((percent/100) + (hitstun_frames)), MIN_HITSTUN_FRAMES))

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
		if Input.is_action_pressed(input_config.down_action):
			set_platform_collision(false)

		model_pivot.scale = Vector3(1.2, 0.7, 1.2)

	model_pivot.scale = model_pivot.scale.lerp(Vector3.ONE, 0.2)

	was_on_floor = on_floor

func try_attack() -> void:
	if current_state == State.ATTACK:
		return

	if Input.is_action_just_pressed(input_config.attack_action):
		current_state = State.ATTACK
		current_attack = Attack.Kill
		attack_timer = create_frame_timer(kill_attack.active_frames)

	var y_right_axis := Input.get_joy_axis(input_config.device_id, JOY_AXIS_RIGHT_Y)
	if y_right_axis > C_STICK_RESET_THRESHOLD:
		can_trigger_cstick_attack = true

	if y_right_axis <= C_STICK_ATTACK_THRESHOLD and can_trigger_cstick_attack:
		current_state = State.ATTACK
		current_attack = Attack.Combo
		attack_timer = create_frame_timer(combo_attack.active_frames)
		can_trigger_cstick_attack = false

func try_fastfall() -> void:
	if is_ground_detected():
		is_fastfalling = false
		return
	if input_buffer.consume(input_config.down_action) and velocity.y <= 0 and not is_fastfalling:
		is_fastfalling = true

func jumpsquat_state(_input_dir: float, delta: float) -> void:
	if Input.is_action_just_released(input_config.jump_action):
		is_shorthopping = true
	if input_buffer.consume("release %s".format([input_config.jump_action])):
		is_shorthopping = true

	jumpsquat_timer -= delta

	model_pivot.scale = Vector3(1.2, 0.7, 1.2)

	model_pivot.scale = model_pivot.scale.lerp(Vector3.ONE, 0.2)
	if jumpsquat_timer <= 0:
		if is_shorthopping:
			velocity.y = movement_stats.jump_speed * movement_stats.shorthop_mult
		else:
			velocity.y = movement_stats.jump_speed
		jump_timer.start()
		current_state = State.IDLE
		is_shorthopping = false
		model_pivot.scale = Vector3(.8, 1.2, .8)


func hitstun_state(_input_dir: float, delta: float) -> void:
	hitstun_timer -= delta

	if hitstun_timer <= 0:
		current_state = State.IDLE

func dash_state(input_dir: float, delta: float) -> void:
	if not is_ground_detected():
		current_state = State.IDLE
		return

	dash_timer -= delta

	var direction := 0.0
	if input_dir != 0:
		direction = sign(input_dir)

	if dash_timer <= 0 and direction == 0:
		current_state = State.IDLE
		return

	velocity.x = dash_direction * movement_stats.dash_speed
	
	# dash dancing
	# reset timer, move to new direction

	if direction != 0:
		dash_timer = create_frame_timer(movement_stats.dash_time_frames)
		dash_direction = sign(direction)

func idle_state(input_dir: float) -> void:
	if input_dir != 0 and is_ground_detected():
		current_state = State.DASH
		dash_timer = create_frame_timer(movement_stats.dash_time_frames)
		dash_direction = sign(input_dir)
		velocity.x = dash_direction * movement_stats.dash_speed

func attack_state(delta: float) -> void:
	attack_timer -= delta
	var current_attack_ref
	match current_attack:
		Attack.Combo:
			current_attack_ref = combo_attack
		Attack.Kill:
			current_attack_ref = kill_attack

	if attack_timer <= 0:
		current_state = State.IDLE
		current_attack_ref.deactivate()
		return

	if not current_attack_ref.active:
		current_attack_ref.activate()

func platdrop_state(_input_dir: float, delta: float) -> void:
	set_platform_collision(false)
	platdrop_timer -= delta
	if platdrop_timer <= 0:
		set_platform_collision(true)
		current_state = State.IDLE

func apply_hitstun_gravity(delta: float) -> void:
	var gravity := movement_stats.gravity_down * movement_stats.hitstun_gravity
	velocity.y -= gravity * delta
	move_and_slide()

func apply_gravity(delta: float) -> void:
	var gravity_up_final := movement_stats.gravity_up * movement_stats.gravity_up_mult
	var gravity_down_final := movement_stats.gravity_down * movement_stats.gravity_down_mult
	
	if not is_ground_detected() or current_state == State.PLATDROP:
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
		current_state = State.JUMPSQUAT
		jumpsquat_timer = create_frame_timer(JUMPSQUAT_FRAMES)

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

	var horizontal_vel = Vector3(velocity.x, 0, 0)
	if horizontal_vel.length() == 0:
		return

	var friction_amount: float = movement_stats.ground_friction
	var friction_force = friction_amount * delta

	if horizontal_vel.length() <= friction_force:
		horizontal_vel = Vector3.ZERO
	else:
		horizontal_vel -= horizontal_vel.normalized() * friction_force

	velocity.x = horizontal_vel.x

func apply_slide(delta: float) -> void:
	# no Z velocity allowed
	if velocity.z != 0:
		velocity.z = 0

	var motion = velocity * delta
	for i in max_slides:
		var col := move_and_collide(motion, true)
		if not col:
			move_and_collide(motion)
			break

		var normal := col.get_normal()
		if abs(normal.x) >= wall_normal_threshold:
			if is_platform(col.get_collider()):
				set_platform_collision(false)
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
	
func is_in_hitlag() -> bool:
	return hitlag_timer > 0.0

func apply_hitlag(frames: float) -> void:
	hitlag_timer = max(hitlag_timer, create_frame_timer(frames))

func try_platdrop() -> void:
	if is_ground_detected() and Input.is_action_pressed(input_config.down_action):
		var collider = get_ground_collider()
		if not collider:
			return
		
		if is_platform(collider):
			platdrop_timer = create_frame_timer(movement_stats.min_platdrop_frames)
			current_state = State.PLATDROP

func apply_platform_handling() -> void:
	if current_state == State.PLATDROP:
		return

	if velocity.y <= 0 and not is_beside_platform:
		set_platform_collision(true)
	else:
		set_platform_collision(false)

func set_platform_collision(should: bool) -> void:
	set_collision_mask_value(PLATFORM_LAYER, should)
