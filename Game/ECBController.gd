@tool
class_name ECBController
extends Node3D

const BASE_TARGET_FPS = 60.0

signal landed
signal left_ground
signal hit_wall(normal: Vector3)
signal hit_ceiling

enum State {
	IDLE,
	DASH,
	HITSTUN,
	JUMPSQUAT,
	PLATDROP,
	ATTACK,
	AIRDODGE,
}

enum CastDirection {
	UP,
	DOWN,
}

func create_frame_timer(num_frames: float) -> float:
	return num_frames / BASE_TARGET_FPS

@export_group("ECB Shape")
@export var half_width: float = 0.35:
	set(value):
		half_width = value
		_rebuild_debug_mesh()
@export var half_height: float = 0.9:
	set(value):
		half_height = value
		_rebuild_debug_mesh()
@export var skin_width: float = 0.02:
	set(value):
		skin_width = value
		_rebuild_debug_mesh()

@export_group("Collision")
@export_flags_3d_physics var solid_collision_mask: int = 1
@export_flags_3d_physics var one_way_collision_mask: int = 0
@export var one_way_layer_number: int = 3
@export var floor_snap_distance: float = 0.08:
	set(value):
		floor_snap_distance = value
		_rebuild_debug_mesh()
@export var wall_probe_height_inset: float = 0.08
@export var ground_probe_extra_distance: float = 0.02
@export var ground_normal_threshold: float = 0.4
@export var one_way_landing_tolerance: float = 0.02

@export_group("Debug")
@export var show_debug_mesh: bool = true:
	set(value):
		show_debug_mesh = value
		_rebuild_debug_mesh()
@export var debug_color: Color = Color(0.2, 0.9, 0.4, 1.0):
	set(value):
		debug_color = value
		_rebuild_debug_mesh()

@export_group("Playtesting")
@export var player_input: PlayerInput
@export var input_buffer: InputBuffer
@export var movement_stats: MovementStats

@export_group("Input threshold")
@export var stick_flick_threshold: float = .7
@export var down_threshold: float = .7

var current_state: State = State.IDLE

#region ECB physics variables
var current_floor_hit: Dictionary = {}
var current_floor_is_one_way: bool = false
var velocity: Vector3 = Vector3.ZERO
var is_grounded := false
var ground_normal := Vector3.UP
var wall_normal := Vector3.ZERO
var ceiling_normal := Vector3.ZERO
var was_on_floor := false
#endregion

var _excluded_rids: Array = []
var _platform_drop_timer := 0.0
var _debug_mesh_instance: MeshInstance3D

#region IDLE variables
var is_fastfalling: bool = false
#endregion

#region DASH variables
var dash_direction: int = 0
var dash_timer: float = 0
#endregion

#region JUMPSQUAT variables
var jumpsquat_timer: float = 0.0
var is_shorthopping := false
#endregion

#region AIRDODGE variables
var airdodge_timer: float = 0.0
var can_airdodge: bool = true
var airdodge_direction: Vector2 = Vector2.ZERO
#endregion

func _ready() -> void:
	_rebuild_debug_mesh()
	movement_stats.compute_jump_values()

func _enter_tree() -> void:
	_rebuild_debug_mesh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(player_input.jump_action):
		input_buffer.press(player_input.jump_action)

	if event.is_action_released(player_input.jump_action):
		input_buffer.press("release %s".format([player_input.jump_action]))

	if event.is_action_pressed(player_input.down_action):
		input_buffer.press(player_input.down_action)

	if event.is_action_pressed(player_input.shield_action):
		input_buffer.press(player_input.shield_action)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var input_vector := player_input.get_input_vector()

	match current_state:
		State.IDLE:
			idle_state(input_vector.x, delta)

			try_dash(input_vector.x)
			# try_attack()
			try_fastfall()
			try_platdrop(input_vector.y)
			try_jump()
			try_airdodge()

			apply_gravity(delta)
			# apply_friction(input_dir.x, delta)
		State.DASH:
			dash_state(input_vector.x, delta)
			# try_attack()
			try_jump()
			try_platdrop(input_vector.y)
			try_airdodge()
			apply_gravity(delta)
		State.JUMPSQUAT:
			jumpsquat_state(input_vector.x, delta)
		State.PLATDROP:
			platdrop_state()
			apply_gravity(delta)
		State.AIRDODGE:
			airdodge_state(delta)

	step(delta)
	post_step_updates()

func post_step_updates():
	# reset airdodge
	if not was_on_floor and is_grounded:
		can_airdodge = true

func apply_gravity(delta: float) -> void:
	var gravity_up_final := movement_stats.gravity_up * movement_stats.gravity_up_mult
	var gravity_down_final := movement_stats.gravity_down * movement_stats.gravity_down_mult
	
	if not is_grounded or current_state == State.PLATDROP:
		if velocity.y > 0:
			velocity.y -= gravity_up_final * delta
		else:
			if is_fastfalling:
				velocity.y -= gravity_down_final * movement_stats.fastfall_mult * delta
			else:
				velocity.y -= gravity_down_final * delta
	else:
		velocity.y = min(velocity.y, 0)

func idle_state(input_dir: float, delta: float) -> void:
	var accel: float
	var max_speed: float
	
	if is_grounded:
		accel = movement_stats.ground_acceleration
		max_speed = movement_stats.ground_horizontal_speed
	else:
		accel = movement_stats.air_acceleration
		max_speed = movement_stats.air_max_speed

	var target := input_dir * max_speed
	velocity.x = move_toward(velocity.x, target, accel * delta)

func dash_state(_input_dir: float, delta: float) -> void:
	if not is_grounded:
		current_state = State.IDLE
		return

	dash_timer -= delta

	if dash_timer <= 0:
		current_state = State.IDLE
		return

	velocity.x = dash_direction * movement_stats.dash_speed

func try_dash(input_dir: float) -> void:
	if abs(input_dir) >= stick_flick_threshold and is_grounded:
		current_state = State.DASH
		dash_timer = create_frame_timer(movement_stats.dash_time_frames)
		dash_direction = sign(input_dir)
		velocity.x = dash_direction * movement_stats.dash_speed

func try_jump() -> void:
	if input_buffer.consume(player_input.jump_action) and is_grounded:
		current_state = State.JUMPSQUAT
		jumpsquat_timer = create_frame_timer(movement_stats.jumpsquat_frames)

func try_fastfall() -> void:
	if is_grounded:
		is_fastfalling = false
		return
	if input_buffer.consume(player_input.down_action) and velocity.y <= 0 and not is_fastfalling:
		is_fastfalling = true

func try_platdrop(input_vector_y: float) -> void:
	if not Input.is_action_just_pressed(player_input.down_action):
		return

	if abs(input_vector_y) < down_threshold:
		return

	if is_grounded and current_floor_is_one_way:
		start_platform_drop(movement_stats.min_platdrop_frames / BASE_TARGET_FPS)
		current_state = State.PLATDROP

func jumpsquat_state(_input_dir: float, delta: float) -> void:
	if Input.is_action_just_released(player_input.jump_action):
		is_shorthopping = true
	if input_buffer.consume("release %s".format([player_input.jump_action])):
		is_shorthopping = true
	
	if Input.is_action_just_pressed(player_input.shield_action):
		input_buffer.press(player_input.shield_action)

	jumpsquat_timer -= delta

	# model_pivot.scale = Vector3(1.2, 0.7, 1.2)

	# model_pivot.scale = model_pivot.scale.lerp(Vector3.ONE, 0.2)
	if jumpsquat_timer <= 0:
		if is_shorthopping:
			velocity.y = movement_stats.jump_speed * movement_stats.shorthop_mult
		else:
			velocity.y = movement_stats.jump_speed
		# jump_timer.start()
		current_state = State.IDLE
		is_shorthopping = false
		# model_pivot.scale = Vector3(.8, 1.2, .8)

func platdrop_state() -> void:
	if _platform_drop_timer <= 0:
		current_state = State.IDLE

func try_airdodge() -> void:
	if not can_airdodge:
		return

	if is_grounded:
		return

	if not input_buffer.consume(player_input.shield_action):
		return

	airdodge_direction = player_input.get_input_vector()

	current_state = State.AIRDODGE
	airdodge_timer = create_frame_timer(movement_stats.airdodge_duration_frames)
	velocity.x = movement_stats.airdodge_speed * airdodge_direction.x
	velocity.y = movement_stats.airdodge_speed * airdodge_direction.y
	can_airdodge = false

func airdodge_state(delta: float) -> void:
	airdodge_timer -= delta
	var airdodge_speed := airdodge_direction * movement_stats.airdodge_speed
	if airdodge_timer <= 0.0:
		current_state = State.IDLE
		can_airdodge = true
		return
	
	if not was_on_floor and (is_grounded or input_buffer.consume(player_input.shield_action)):
		velocity.x = airdodge_speed.x
		current_state = State.IDLE
		if is_grounded:
			can_airdodge = true

		return

#region ECB physics
func step(delta: float) -> void:
	var previous_bottom := get_bottom()

	var was_grounded := is_grounded
	was_on_floor = was_grounded

	wall_normal = Vector3.ZERO
	ceiling_normal = Vector3.ZERO

	if _platform_drop_timer > 0.0:
		_platform_drop_timer -= delta

	var motion := velocity * delta

	_resolve_horizontal(motion.x)
	_resolve_vertical(motion.y, previous_bottom)
	_refresh_ground_state(previous_bottom)

	if not was_grounded and is_grounded:
		landed.emit()
	elif was_grounded and not is_grounded:
		left_ground.emit()

func set_excluded_bodies(bodies: Array[CollisionObject3D]) -> void:
	_excluded_rids.clear()
	for body in bodies:
		if body:
			_excluded_rids.append(body.get_rid())

func start_platform_drop(seconds: float) -> void:
	_platform_drop_timer = max(seconds, 0.0)

func get_bottom() -> float:
	return global_position.y - half_height

func get_top() -> float:
	return global_position.y + half_height

func get_left() -> float:
	return global_position.x - half_width

func get_right() -> float:
	return global_position.x + half_width

func _resolve_horizontal(delta_x: float) -> void:
	if is_zero_approx(delta_x):
		return

	var direction := signf(delta_x)
	var hits := _cast_side(direction, abs(delta_x) + skin_width)
	if hits.is_empty():
		global_position.x += delta_x
		return

	var hit = _pick_closest_hit(hits)
	if direction > 0.0:
		global_position.x = hit.position.x - half_width - skin_width
	else:
		global_position.x = hit.position.x + half_width + skin_width

	velocity.x = 0.0
	wall_normal = hit.normal
	hit_wall.emit(hit.normal)

func _resolve_vertical(delta_y: float, previous_bottom: float) -> void:
	if is_zero_approx(delta_y):
		if velocity.y <= 0.0:
			_snap_to_floor(previous_bottom)
		return

	if delta_y > 0.0:
		var upward_hits := _cast_vertical(CastDirection.UP, delta_y + skin_width, false)
		if upward_hits.is_empty():
			global_position.y += delta_y
			return

		var ceiling_hit = _pick_closest_hit(upward_hits)
		global_position.y = ceiling_hit.position.y - half_height - skin_width
		velocity.y = 0.0
		ceiling_normal = ceiling_hit.normal
		hit_ceiling.emit()
		return

	var downward_hits := _cast_vertical(CastDirection.DOWN, abs(delta_y) + skin_width + floor_snap_distance, true)
	if downward_hits.is_empty():
		global_position.y += delta_y
		return

	var valid_hits := []
	for hit in downward_hits:
		if _is_valid_floor_hit(hit, previous_bottom):
			valid_hits.push_back(hit)
			
	if valid_hits.is_empty():
		global_position.y += delta_y
		return

	var floor_hit = _pick_closest_hit(valid_hits)
	global_position.y = floor_hit.position.y + half_height + skin_width
	velocity.y = 0.0
	ground_normal = floor_hit.normal

func _snap_to_floor(previous_bottom: float) -> void:
	if floor_snap_distance <= 0.0:
		return

	var snap_hits := _cast_vertical(CastDirection.DOWN, floor_snap_distance + skin_width, true)
	if snap_hits.is_empty():
		return

	var valid_hits := []
	for hit in snap_hits:
		if _is_valid_floor_hit(hit, previous_bottom):
			valid_hits.push_back(hit)
			
	if valid_hits.is_empty():
		return

	var floor_hit = _pick_closest_hit(valid_hits)
	global_position.y = floor_hit.position.y + half_height + skin_width
	ground_normal = floor_hit.normal

func _refresh_ground_state(previous_bottom: float) -> void:
	current_floor_hit = {}
	is_grounded = false

	var hits := _cast_vertical(CastDirection.DOWN, floor_snap_distance + skin_width + ground_probe_extra_distance, true)
	if hits.is_empty():
		return

	var valid_hits := []
	for hit in hits:
		if _is_valid_floor_hit(hit, previous_bottom):
			valid_hits.push_back(hit)
			
	if valid_hits.is_empty():
		return

	var floor_hit = _pick_closest_hit(hits)
	is_grounded = floor_hit.normal.y > ground_normal_threshold
	if is_grounded:
		current_floor_hit = floor_hit
		current_floor_is_one_way = _is_one_way(floor_hit)
		ground_normal = floor_hit.normal

func _cast_side(direction: float, distance: float) -> Array:
	var hits: Array = []
	var x_offset := half_width * direction
	var y_offsets := [
		-half_height + wall_probe_height_inset,
		0.0,
		half_height - wall_probe_height_inset
	]

	for y_offset in y_offsets:
		var from := global_position + Vector3(x_offset, y_offset, 0.0)
		var to := from + Vector3(direction * distance, 0.0, 0.0)
		var hit = _raycast(from, to, solid_collision_mask)
		if not hit.is_empty():
			hits.append(hit)

	return hits

func _cast_vertical(cast_direction: CastDirection, distance: float, allow_one_way: bool) -> Array:
	var hits: Array = []
	var cast_up: bool

	match cast_direction:
		CastDirection.UP:
			cast_up = true
		_:
			cast_up = false

	var direction := 1.0 if cast_up else -1.0
	var y_offset := half_height * direction
	var x_offsets := [-half_width, 0.0, half_width]

	for x_offset in x_offsets:
		var from := global_position + Vector3(x_offset, y_offset, 0.0)
		var to := from + Vector3(0.0, direction * distance, 0.0)

		var solid_hit = _raycast(from, to, solid_collision_mask)
		if not solid_hit.is_empty():
			hits.append(solid_hit)

		if allow_one_way and not cast_up and _platform_drop_timer <= 0.0 and one_way_collision_mask != 0:
			var one_way_hit = _raycast(from, to, one_way_collision_mask)
			if not one_way_hit.is_empty() and _is_one_way(one_way_hit):
				hits.append(one_way_hit)

	return hits

func _raycast(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, _excluded_rids)
	query.hit_from_inside = false
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)

func _is_one_way(hit: Dictionary) -> bool:
	if not hit.has("collider"):
		return false

	var collider = hit["collider"]
	if collider is CollisionObject3D:
		return collider.get_collision_layer_value(one_way_layer_number)

	return false

func _pick_closest_hit(hits: Array) -> Dictionary:
	var best_hit: Dictionary = hits[0]
	var best_distance := _hit_distance(best_hit)

	for i in range(1, hits.size()):
		var candidate: Dictionary = hits[i]
		var distance := _hit_distance(candidate)
		if distance < best_distance:
			best_hit = candidate
			best_distance = distance

	return best_hit

func _hit_distance(hit: Dictionary) -> float:
	if not hit.has("position"):
		return INF
	return global_position.distance_squared_to(hit.position)

func _is_valid_floor_hit(hit: Dictionary, previous_bottom: float) -> bool:
	if not _is_one_way(hit):
		return true
	
	var platform_top = hit.position.y
	return previous_bottom >= platform_top - one_way_landing_tolerance
#endregion

#region debugging
func _ensure_debug_mesh() -> void:
	if _debug_mesh_instance:
		return

	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.name = "ECBDebug"
	add_child(_debug_mesh_instance)
	if Engine.is_editor_hint() and get_tree():
		_debug_mesh_instance.owner = get_tree().edited_scene_root

func _rebuild_debug_mesh() -> void:
	if not is_inside_tree():
		return

	_ensure_debug_mesh()
	_debug_mesh_instance.visible = show_debug_mesh
	if not show_debug_mesh:
		return

	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = debug_color

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	_add_debug_line(mesh, Vector3(-half_width, -half_height, 0.0), Vector3(half_width, -half_height, 0.0))
	_add_debug_line(mesh, Vector3(half_width, -half_height, 0.0), Vector3(half_width, half_height, 0.0))
	_add_debug_line(mesh, Vector3(half_width, half_height, 0.0), Vector3(-half_width, half_height, 0.0))
	_add_debug_line(mesh, Vector3(-half_width, half_height, 0.0), Vector3(-half_width, -half_height, 0.0))
	_add_debug_line(mesh, Vector3(0.0, -half_height, 0.0), Vector3(0.0, -half_height - floor_snap_distance, 0.0))
	mesh.surface_end()

	_debug_mesh_instance.mesh = mesh

func _add_debug_line(mesh: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
#endregion
