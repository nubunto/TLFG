extends Resource
class_name ArrowProps

@export var ProjectileScene: PackedScene = preload("res://Characters/Archer/ArcherArrow.tscn")
@export var speed := 350.0
@export var lifetime_in_seconds := 3.0
@export var min_lifetime := 3.0

func create(extra_props: Dictionary) -> Node:
	var proj := ProjectileScene.instantiate()
	proj.set("speed", speed)
	proj.set("lifetime_in_seconds", lifetime_in_seconds)
	for key in extra_props:
		proj.set(key, extra_props[key])
	return proj
