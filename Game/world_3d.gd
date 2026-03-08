extends Node3D

@onready var player_1: CharacterBody3D = $Player1
@onready var player_2: CharacterBody3D = $Player2
@onready var blastzone: Node3D = $Blastzone
@onready var spawn_point: Marker3D = $SpawnPoint

var ko_protection := {}

func _process(_delta: float) -> void:
	_process_player_ko(player_1)
	_process_player_ko(player_2)

func _process_player_ko(player) -> void:
	if not is_instance_valid(player):
		return

	var player_id = player.get_instance_id()
	if ko_protection.has(player_id):
		return

	if not blastzone.is_ko(player.get_ko_anchor()):
		return

	ko_protection[player_id] = true
	player.register_ko()

	if not is_instance_valid(player):
		ko_protection.erase(player_id)
		return

	player.visible = false
	call_deferred("reset_position", player)

func reset_position(p: CharacterBody3D) -> void:
	await get_tree().create_timer(.9).timeout
	if not is_instance_valid(p):
		return

	p.global_position = spawn_point.global_position
	p.visible = true
	ko_protection.erase(p.get_instance_id())
