extends StaticBody3D

signal section_destroyed()

@export var max_health: float = 80.0
var current_health: float = 80.0
var is_destroyed: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var rubble_particles: GPUParticles3D = $RubbleParticles

const WALL_DEBRIS = preload("res://scenes/props/wall_debris.tscn")

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if is_destroyed:
		return
		
	current_health -= amount
	
	# Slight impact shudder
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3(1.03, 0.97, 1.03), 0.05)
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.05)
		
	# Spawn 1 physical debris chunk on noticeable hits
	if amount >= 25.0:
		spawn_single_debris(hit_pos, hit_normal)
		
	if current_health <= 0:
		destroy_section(hit_normal)

func spawn_single_debris(pos: Vector3, normal: Vector3) -> void:
	var debris = WALL_DEBRIS.instantiate()
	get_tree().current_scene.add_child(debris)
	debris.global_position = pos + normal * 0.1
	var out_dir = (normal + Vector3.UP * randf_range(0.2, 0.6) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))).normalized()
	debris.launch_debris(out_dir * randf_range(4.0, 9.0))

func destroy_section(hit_normal: Vector3 = Vector3.BACK) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if mesh_instance:
		mesh_instance.visible = false
		
	if rubble_particles:
		rubble_particles.emitting = true
		
	# Spawn bursting cloud of 5 physical debris blocks
	var base_pos = global_position
	var normal = hit_normal if hit_normal.length_squared() > 0.01 else Vector3.BACK
	for i in range(5):
		var debris = WALL_DEBRIS.instantiate()
		get_tree().current_scene.add_child(debris)
		
		# Offset slightly within the section's volume
		var offset = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.4, 0.4),
			randf_range(-0.1, 0.1)
		)
		debris.global_position = base_pos + offset
		
		var launch_dir = (normal + Vector3.UP * randf_range(0.3, 0.8) + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))).normalized()
		debris.launch_debris(launch_dir * randf_range(6.0, 14.0))
		
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
