extends RigidBody3D

@export var lifetime: float = 4.5

func _ready() -> void:
	# Random tumble torque
	angular_velocity = Vector3(
		randf_range(-6.0, 6.0),
		randf_range(-6.0, 6.0),
		randf_range(-6.0, 6.0)
	)
	
	# Lifetime timer for clean despawn
	get_tree().create_timer(lifetime).timeout.connect(despawn)

func launch_debris(impulse: Vector3) -> void:
	apply_impulse(impulse, Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)))

func despawn() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
