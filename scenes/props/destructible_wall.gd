extends Node3D

@export var wall_width_bricks: int = 8
@export var wall_height_bricks: int = 6
@export var brick_size: Vector3 = Vector3(0.55, 0.32, 0.28)
@export var auto_rebuild_time: float = 14.0

var bricks: Array[Node3D] = []
var has_started_reset_timer: bool = false

const BrickScript = preload("res://scenes/props/destructible_brick.gd")

func _ready() -> void:
	generate_wall()

func generate_wall() -> void:
	# Clear existing if any
	for c in get_children():
		c.queue_free()
	bricks.clear()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.38, 0.28) # Reddish terracotta brick
	mat.roughness = 0.9
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = brick_size - Vector3(0.01, 0.01, 0.01) # Small mortar gap
	box_mesh.material = mat
	
	var shape = BoxShape3D.new()
	shape.size = brick_size
	
	for y in range(wall_height_bricks):
		var row_offset = (brick_size.x * 0.5) if (y % 2 == 1) else 0.0
		for x in range(wall_width_bricks):
			var brick = RigidBody3D.new()
			brick.set_script(BrickScript)
			brick.name = "Brick_%d_%d" % [x, y]
			
			var posX = (x - (wall_width_bricks * 0.5) + 0.5) * brick_size.x + row_offset
			var posY = (y + 0.5) * brick_size.y
			brick.position = Vector3(posX, posY, 0)
			
			var mi = MeshInstance3D.new()
			mi.mesh = box_mesh
			brick.add_child(mi)
			
			var col = CollisionShape3D.new()
			col.shape = shape
			brick.add_child(col)
			
			add_child(brick)
			bricks.append(brick)
			
			if brick.has_signal("brick_broken"):
				brick.brick_broken.connect(_on_brick_broken)

func _on_brick_broken() -> void:
	if not has_started_reset_timer:
		has_started_reset_timer = true
		get_tree().create_timer(auto_rebuild_time).timeout.connect(rebuild_wall)

func rebuild_wall() -> void:
	has_started_reset_timer = false
	for brick in bricks:
		if is_instance_valid(brick) and brick.has_method("reset_brick"):
			brick.reset_brick()
			
			# Pop animation
			brick.scale = Vector3.ZERO
			var tween = create_tween()
			tween.tween_property(brick, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
