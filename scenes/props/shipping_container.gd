extends StaticBody3D

@export var container_color: Color = Color(0.22, 0.38, 0.55) # Default Navy blue

@onready var mesh_node: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _ready() -> void:
	if mesh_node:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = container_color
		mat.roughness = 0.8
		mat.metallic = 0.4
		mesh_node.material_override = mat
