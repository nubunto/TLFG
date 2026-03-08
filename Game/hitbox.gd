class_name Hitbox3D
extends Area3D

@export var damage: float = 8.0
@export var launch_angle_deg: float = .0
@export var base_knockback: float = .0
@export var knockback_scaling: float = .25
@export var active_frames: int = 2
@export var hitstun_frames: int = 0
@export var flip_with_side: bool = true

@export var attacker: CharacterBody3D

var active := false
var already_hit := {}
var exceptions := {}

func add_exception(exc) -> void:
	exceptions[exc.get_instance_id()] = true

func activate() -> void:
	if active:
		return

	already_hit.clear()
	active = true
	monitoring = true

func deactivate() -> void:
	monitoring = false
	active = false


func on_hit(body: Area3D):
	if not active:
		return

	if not body.target:
		push_warning("Area (hurtbox?) has no target!")
		return

	var iid = body.target.get_instance_id()
	if exceptions.has(iid):
		return

	if already_hit.has(iid):
		return

	print("OWNER: ", owner, " TARGET: ", body.target)
	if body.target.has_method("apply_knockback"):
		already_hit[iid] = true
		var launch_angle_rad := deg_to_rad(launch_angle_deg)
		var dir := Vector2(cos(launch_angle_rad), sin(launch_angle_rad))
		if owner.global_position.x > body.target.global_position.x and flip_with_side:
			dir.x *= -1
		body.target.apply_knockback(dir, damage, base_knockback, knockback_scaling, hitstun_frames)
	
	const hitlag_frames := 5
	if attacker.has_method("apply_hitlag"):
		attacker.apply_hitlag(hitlag_frames)
	
	if body.target.has_method("apply_hitlag"):
		body.target.apply_hitlag(hitlag_frames)

func _on_area_entered(area: Area3D) -> void:
	on_hit(area)
