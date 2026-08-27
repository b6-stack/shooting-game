extends Node3D

signal grenade_hit_target(points: int)

@export var speed: float = 40.0
@export var gravity: float = 14.0
@export var explosion_radius: float = 12.0 # Increased blast radius
@export var max_damage: float = 200.0

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 6.0
var has_exploded: bool = false

const EXPLOSION_EFFECT = preload("res://scenes/effects/explosion.tscn")

@onready var area: Area3D = $Area3D

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_impact)
		area.area_entered.connect(_on_impact)

func launch(direction: Vector3, initial_speed: float = -1.0) -> void:
	if initial_speed > 0:
		speed = initial_speed
	velocity = direction.normalized() * speed

func _physics_process(delta: float) -> void:
	if has_exploded:
		return
		
	# Apply gravity to ballistic arc
	velocity.y -= gravity * delta
	
	# Raycast forward along step to prevent tunneling through thin walls/targets
	var step = velocity * delta
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + step)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit = space_state.intersect_ray(query)
	
	if hit:
		global_position = hit.position
		explode()
	else:
		global_position += step
		# Orient grenade along velocity vector
		if velocity.length_squared() > 0.1:
			look_at(global_position + velocity.normalized(), Vector3.UP)
			
	lifetime -= delta
	if lifetime <= 0:
		explode()

func _on_impact(_other: Node) -> void:
	explode()

func explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	
	# Spawn explosion effect
	var exp_node = EXPLOSION_EFFECT.instantiate()
	get_tree().current_scene.add_child(exp_node)
	exp_node.global_position = global_position
	
	# Radial AoE Damage & Target Knockdown
	var space_state = get_world_3d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), global_position)
	shape_query.collide_with_areas = true
	shape_query.collide_with_bodies = true
	
	var hits = space_state.intersect_shape(shape_query, 64)
	var targets_hit = 0
	var processed_roots = {}
	
	for result in hits:
		var collider = result.collider
		var target_obj = null
		if collider.has_method("take_damage"):
			target_obj = collider
		elif collider.has_meta("target_root"):
			target_obj = collider.get_meta("target_root")
		elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
			target_obj = collider.get_parent()
			
		if target_obj and target_obj.has_method("take_damage"):
			# Prevent damaging the same multi-collider target twice
			var obj_id = target_obj.get_instance_id()
			if processed_roots.has(obj_id):
				continue
			processed_roots[obj_id] = true
			
			var dist = global_position.distance_to(result.collider.global_position)
			var falloff = clampf(1.0 - (dist / explosion_radius), 0.25, 1.0)
			target_obj.take_damage(max_damage * falloff, global_position, Vector3.UP)
			targets_hit += 1
			
	if targets_hit > 0:
		grenade_hit_target.emit(targets_hit * 100)
		
	queue_free()
