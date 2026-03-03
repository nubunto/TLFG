extends CharacterBody3D

enum State {
	IDLE,
	DASH,
}

@export var ground_normal_threshold: float
@export var movement_stats: MovementStats
@export var combat_stats: CombatStats
@export var input_config: PlayerInput

@onready var ground_detector: ShapeCast3D = $Detectors/GroundDetector
@onready var jump_timer: Timer = $Timers/JumpTimer
@onready var debug_text: Label3D = $DebugText
@onready var hitbox: Hitbox3D = $Hitbox

var current_state: State = State.IDLE
var last_collision_normal: Vector3
var hitstun_timer: float = 0.0

#region IDLE variables
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
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	ground_detector.add_exception(self)
	movement_stats.compute_jump_values()
	current_stocks = combat_stats.stocks

func _on_jump_timer_timeout() -> void:
	ground_detector.enabled = true

func is_ground_detected() -> bool:
	return ground_detector.is_colliding()

func apply_knockback(direction: Vector3, damage: float) -> void:
	percent += damage
	var knockback = combat_stats.base_knockback + percent * combat_stats.knockback_scaling
	velocity = direction.normalized() * knockback
	
	hitstun_timer = knockback * 0.05

func _physics_process(delta: float) -> void:
	if hitstun_timer > 0:
		hitstun_timer -= delta
		apply_gravity(delta)
		apply_slide(delta)
		return

	var input_dir := Input.get_action_strength(input_config.right_action) - Input.get_action_strength(input_config.left_action)
	match current_state:
		State.IDLE:
			debug_text.text = "IDLE"
			idle_state(input_dir)
			try_attack()
			handle_movement(input_dir, delta)
		State.DASH:
			debug_text.text = "DASH"
			dash_state(input_dir, delta)
			try_attack()
			apply_jump()
			apply_gravity(delta)
			apply_slide(delta)

func try_attack() -> void:
	if Input.is_action_just_pressed(input_config.attack_action):
		hitbox.activate()

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
	if not is_ground_detected():
		if velocity.y > 0:
			velocity.y -= movement_stats.gravity_up * delta
		else:
			velocity.y -= movement_stats.gravity_down * delta
	else:
		velocity.y = min(velocity.y, 0)

func apply_jump() -> void:
	if Input.is_action_just_pressed(input_config.jump_action) and is_ground_detected():
		jump_timer.start()
		ground_detector.enabled = false
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

	apply_jump()
	
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
		var col = move_and_collide(motion)
		if not col:
			break

		velocity = velocity.slide(col.get_normal())
		motion = col.get_remainder()
