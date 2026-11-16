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

func take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return
		
	current_health -= amount
	
	# Slight impact shudder
	if mesh_instance:
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3(1.03, 0.97, 1.03), 0.05)
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.05)
		
	# Determine effective push direction (away from shooter/explosion towards back of wall)
	var push_dir = calculate_push_dir(hit_pos, hit_dir)
	
	# Spawn 1 physical debris chunk on noticeable hits
	if amount >= 25.0:
		spawn_single_debris(hit_pos, push_dir)
		
	if current_health <= 0:
		destroy_section(push_dir)

func calculate_push_dir(hit_pos: Vector3, hit_dir: Vector3) -> Vector3:
	var dir = hit_dir
	if dir.length_squared() < 0.001:
		if hit_pos != Vector3.ZERO and hit_pos.distance_squared_to(global_position) > 0.001:
			dir = (global_position - hit_pos).normalized()
		else:
			dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
		# If direction points back toward the impact point from inside the wall, flip it
		if hit_pos != Vector3.ZERO and hit_pos.distance_squared_to(global_position) > 0.001:
			var to_center = (global_position - hit_pos).normalized()
			if dir.dot(to_center) < -0.2:
				dir = -dir
				
	# Ensure the push direction has forward momentum towards the back of the wall (-Z) if mostly flat
	if abs(dir.z) < 0.1 and abs(dir.x) < 0.1:
		dir.z = -1.0
		dir = dir.normalized()
	return dir

func spawn_single_debris(pos: Vector3, push_dir: Vector3) -> void:
	var debris = WALL_DEBRIS.instantiate()
	var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	spawn_parent.add_child(debris)
	var spawn_pos = pos if pos != Vector3.ZERO else global_position
	debris.global_position = spawn_pos + push_dir * 0.15
	var out_dir = (push_dir + Vector3.UP * randf_range(0.15, 0.45) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))).normalized()
	debris.launch_debris(out_dir * randf_range(4.0, 9.0))

func destroy_section(push_dir: Vector3 = Vector3.FORWARD) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if mesh_instance:
		mesh_instance.visible = false
		
	if rubble_particles:
		rubble_particles.emitting = true
		
	# Spawn bursting cloud of 5 physical debris blocks flying away / through the back
	var base_pos = global_position
	var base_dir = push_dir.normalized() if push_dir.length_squared() > 0.01 else Vector3.FORWARD
	for i in range(5):
		var debris = WALL_DEBRIS.instantiate()
		var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
		spawn_parent.add_child(debris)
		
		# Offset slightly within the section's volume, biased towards the back
		var offset = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.4, 0.4),
			randf_range(-0.1, 0.1)
		) + base_dir * 0.2
		debris.global_position = base_pos + offset
		
		var launch_dir = (base_dir * randf_range(1.0, 1.4) + Vector3.UP * randf_range(0.2, 0.6) + Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.3, 0.3))).normalized()
		debris.launch_debris(launch_dir * randf_range(7.0, 15.0))
		
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
		mesh_instance.scale = Vector3.ONE * 0.001
		var tween = create_tween()
		tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
