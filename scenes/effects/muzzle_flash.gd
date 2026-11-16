extends Node3D

@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var is_suppressed: bool = false
var _flash_id: int = 0

func set_suppressed(suppressed: bool) -> void:
	is_suppressed = suppressed

func flash() -> void:
	_flash_id += 1
	var my_id = _flash_id
	visible = true
	rotation.z = randf_range(0, TAU)
	var s = randf_range(0.24, 0.36) if is_suppressed else randf_range(0.8, 1.2)
	scale = Vector3(s, s, s)
	if light:
		light.light_energy = 0.35 if is_suppressed else 2.0
	var dur = 0.022 if is_suppressed else 0.04
	await get_tree().create_timer(dur).timeout
	if is_inside_tree() and my_id == _flash_id:
		visible = false
