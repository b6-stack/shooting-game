extends StaticBody3D

signal section_destroyed()

@export var max_health: float = 80.0
var current_health: float = 80.0
var is_destroyed: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var rubble_particles: GPUParticles3D = $RubbleParticles

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float, _hit_pos: Vector3, _hit_normal: Vector3) -> void:
	if is_destroyed:
		return
		
	current_health -= amount
	
	# Slight impact shudder
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3(1.02, 0.98, 1.02), 0.05)
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.05)
		
	if current_health <= 0:
		destroy_section()

func destroy_section() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if mesh_instance:
		mesh_instance.visible = false
		
	if rubble_particles:
		rubble_particles.emitting = true
		
	section_destroyed.emit()

func reset_section() -> void:
	if not is_destroyed:
		return
	is_destroyed = false
	current_health = max_health
	
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.visible = true
		mesh_instance.scale = Vector3.ZERO
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
