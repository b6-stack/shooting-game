extends Node3D

signal target_hit(points: int)

@export var max_health: float = 100.0
@export var reset_time: float = 3.0
@export var target_score: int = 100

var current_health: float = 100.0
var is_down: bool = false

@onready var hinge: Node3D = $Hinge
@onready var collision_shape: CollisionShape3D = $Hinge/StaticBody3D/CollisionShape3D
@onready var plate_mesh: MeshInstance3D = $Hinge/StaticBody3D/PlateMesh

var default_rotation_x: float = 0.0

func _ready() -> void:
	current_health = max_health
	if hinge:
		default_rotation_x = hinge.rotation.x
	# Assign self to the body metadata for easy reference
	if $Hinge/StaticBody3D:
		$Hinge/StaticBody3D.set_meta("target_root", self)

func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.ZERO) -> void:
	if is_down:
		return
	
	current_health -= amount
	
	# Flash white on hit
	if plate_mesh and plate_mesh.get_active_material(0):
		var mat: StandardMaterial3D = plate_mesh.get_active_material(0)
		var original_color = mat.albedo_color
		var flash_tween = create_tween()
		flash_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.05)
		flash_tween.tween_property(mat, "albedo_color", original_color, 0.1)
	
	if current_health <= 0:
		knock_down()

func knock_down() -> void:
	if is_down:
		return
	is_down = true
	target_hit.emit(target_score)
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	# Fall backward animation
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(hinge, "rotation:x", default_rotation_x - deg_to_rad(85.0), 0.35)
	
	# Schedule auto-reset
	get_tree().create_timer(reset_time).timeout.connect(pop_up)

func pop_up() -> void:
	if not is_down:
		return
	
	current_health = max_health
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hinge, "rotation:x", default_rotation_x, 0.4)
	
	await tween.finished
	is_down = false
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
