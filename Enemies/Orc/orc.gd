extends CharacterBody2D

enum EnemyState {
	Idle,
	Walking,
	PlayerDetected,
	Attacking,
	Attacking2,
	Dead,
}

@export var gravity := 1000.0
@export var move_speed := 10.0
@export var max_wandering_limit := 50.0
@export var action_wait_time := 6.0

@onready var action_timer: Timer = $ActionTimer
@onready var sprite: Sprite2D = $Sprite
@onready var hurtbox: Hurtbox = $Hurtbox

var state: EnemyState = EnemyState.Idle
var player_position: Vector2
var next_target_position: Vector2
var anim_took_damage := false

func _ready() -> void:
	action_timer.wait_time = randf_range(0.0, action_wait_time)
	hurtbox.who_to_damage = self

func _on_player_sensor_body_entered(_body: Node2D) -> void:
	state = EnemyState.PlayerDetected

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		EnemyState.Idle:
			velocity.x = 0
		EnemyState.Walking:
			velocity.x = sign(next_target_position.x) * move_speed
			if sign(velocity.x) < 0:
				sprite.flip_h = true
			elif sign(velocity.x) > 0:
				sprite.flip_h = false

	move_and_slide()
	
	if is_on_wall():
		# flip it to the other side on the next frame
		next_target_position.x *= sign(next_target_position.x)

func after_attack2() -> void:
	state = EnemyState.Walking

func pick_next_state() -> EnemyState:
	var possible_states := [
		EnemyState.Idle,
		EnemyState.Walking,
		EnemyState.Attacking,
	]

	var pick = possible_states.pick_random()
	if pick != EnemyState.Walking: return pick

	var next_direction := randi_range(-1, 1)
	var wander := randf_range(0.0, max_wandering_limit)
	next_target_position.x = (sign(next_direction) * wander)
	return pick

func is_moving() -> bool:
	return velocity.x != 0

func is_attacking() -> bool:
	return state == EnemyState.Attacking

func take_damage(_damage: float) -> void:
	anim_took_damage = true

func took_damage() -> bool:
	return anim_took_damage

func reset_took_damage() -> void:
	anim_took_damage = false

func _on_action_timer_timeout() -> void:
	state = pick_next_state()
	action_timer.wait_time = randf_range(3, 5)
