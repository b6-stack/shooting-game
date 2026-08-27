extends Node3D

@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

func flash() -> void:
	visible = true
	rotation.z = randf_range(0, TAU)
	var s = randf_range(0.8, 1.2)
	scale = Vector3(s, s, s)
	if light:
		light.light_energy = 2.0
	await get_tree().create_timer(0.04).timeout
	visible = false
