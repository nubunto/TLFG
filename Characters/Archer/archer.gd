extends AbstractCharacter

@export var arrow_props: ArrowProps

@onready var arrow_pivot: Node2D = $ArrowPivot
@onready var fire_cast: RayCast2D = $ArrowPivot/FireCast
@onready var audio_stream: AudioStreamPlayer2D = $AudioStreamPlayer2D

var attacking := false
var damaged := false

func _ready() -> void:
	super._ready()
	character_controller.bufferable_actions = ["attack"]
	DamageDirector.damage.connect(_on_damage)

func make_attack() -> void:
	super.make_attack()
	if fire_cast.is_colliding(): return
	attacking = true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if self.last_direction != 0:
		flip_arrow_pivot()

func flip_arrow_pivot() -> void:
	var current_pos = sign(arrow_pivot.position.x)
	if current_pos != last_direction:
		arrow_pivot.position.x *= -1
		arrow_pivot.rotate(deg_to_rad(-180))
	else:
		arrow_pivot.rotate(deg_to_rad(0))

func fire_arrow() -> void:
	if not attacking: return
	var arrow = arrow_props.create({ "direction": self.last_direction })
	get_tree().root.add_child(arrow)
	arrow.global_position = self.arrow_pivot.global_position

func disable_attacking() -> void:
	attacking = false
	character_controller.process_buffer()

func is_attacking() -> bool:
	return attacking

func is_dead() -> bool:
	return false

func took_damage() -> bool:
	return damaged

func _on_damage(_damage: int) -> void:
	damaged = true

func reset_damaged() -> void:
	damaged = false
