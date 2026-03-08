@tool
extends Node3D

@export var half_width: float = 120.0:
	set(value):
		half_width = value
		_rebuild_debug()

@export var half_height: float = 80.0:
	set(value):
		half_height = value
		_rebuild_debug()

@export var ko_margin: float = 16.0:
	set(value):
		ko_margin = value
		_rebuild_debug()

@export var debug_depth: float = 0.0:
	set(value):
		debug_depth = value
		_rebuild_debug()

var _debug_mesh_instance: MeshInstance3D

func _enter_tree() -> void:
	_rebuild_debug()

func _ready() -> void:
	_rebuild_debug()

func _ensure_debug_mesh() -> void:
	if _debug_mesh_instance:
		return

	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.name = "DebugBlastZone"
	add_child(_debug_mesh_instance)
	_debug_mesh_instance.owner = get_tree().edited_scene_root

func _rebuild_debug():
	if not Engine.is_editor_hint():
		return

	_ensure_debug_mesh()

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var z := debug_depth
	var tl := Vector3(-half_width, half_height, z)
	var topr := Vector3(half_width, half_height, z)
	var br := Vector3(half_width, -half_height, z)
	var bl := Vector3(-half_width, -half_height, z)
	
	_add_line(mesh, tl, topr)
	_add_line(mesh, topr, br)
	_add_line(mesh, br, bl)
	_add_line(mesh, bl, tl)
	
	var tlo := Vector3((-half_width - ko_margin), (half_height + ko_margin), z)
	var topro := Vector3((half_width + ko_margin), (half_height + ko_margin), z)
	var bro := Vector3((half_width + ko_margin), (-half_height - ko_margin), z)
	var blo := Vector3((-half_width - ko_margin), (-half_height - ko_margin), z)
	
	_add_line(mesh, tlo, topro)
	_add_line(mesh, topro, bro)
	_add_line(mesh, bro, blo)
	_add_line(mesh, blo, tlo)
	
	mesh.surface_end()
	_debug_mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.917, 0.355, 0.0, 1.0)
	_debug_mesh_instance.material_override = mat
	

func _add_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)

func contains_ko_point(point: Vector3) -> bool:
	var x := point.x
	var y := point.y
	
	return (
		x >= global_position.x - half_width - ko_margin
		and x <= global_position.x + half_width + ko_margin
		and y >= global_position.y - half_height - ko_margin
		and y <= global_position.y + half_height + ko_margin
	)

func is_ko(point: Vector3) -> bool:
	return not contains_ko_point(point)
