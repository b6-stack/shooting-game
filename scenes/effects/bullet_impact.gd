extends Node3D

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	if particles:
		particles.emitting = true
	if light:
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.2)
	await get_tree().create_timer(0.6).timeout
	queue_free()
