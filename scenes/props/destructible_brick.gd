extends RigidBody3D

signal brick_broken()

@export var max_health: float = 40.0
var current_health: float = 40.0
var initial_transform: Transform3D
var is_broken: bool = false

func _ready() -> void:
	initial_transform = global_transform
	current_health = max_health
	mass = 4.0
	freeze = true # Freeze initially for high performance

func take_damage(amount: float, hit_pos: Vector3, hit_normal: Vector3) -> void:
	current_health -= amount
	
	# Wake up physics
	if freeze:
		freeze = false
		is_broken = true
		brick_broken.emit()
		
	# Apply local dislodge impulse
	var impulse_dir = -hit_normal if hit_normal.length_squared() > 0.1 else Vector3(0, 0, -1)
	apply_impulse(impulse_dir * (amount * 0.08), hit_pos - global_position)

func reset_brick() -> void:
	freeze = true
	global_transform = initial_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	current_health = max_health
	is_broken = false
