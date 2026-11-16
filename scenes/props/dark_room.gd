extends Node3D

const DARK_SHADER = preload("res://shaders/dark_interior.gdshader")

@onready var door_controller: Node3D = get_node_or_null("DoorController")

func _ready() -> void:
	# Recursively convert all interior meshes to use dark_interior.gdshader
	# so that Godot's mobile sky ambient light does not light up the dark room.
	_apply_dark_shader_recursive(self)

func _apply_dark_shader_recursive(node: Node) -> void:
	if node is Label3D:
		return
	if node.is_in_group("exterior_mesh"):
		return
	if node is MeshInstance3D and node.mesh:
		var count = node.get_surface_override_material_count()
		if count == 0 and node.mesh:
			count = node.mesh.get_surface_count()
		for s in range(count):
			var cur_mat = node.get_surface_override_material(s)
			if cur_mat == null and node.mesh:
				cur_mat = node.mesh.surface_get_material(s)
			if cur_mat is ShaderMaterial and cur_mat.shader == DARK_SHADER:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = DARK_SHADER
			if cur_mat is StandardMaterial3D:
				var std_mat := cur_mat as StandardMaterial3D
				sm.set_shader_parameter("albedo_color", std_mat.albedo_color)
				sm.set_shader_parameter("roughness", std_mat.roughness)
				sm.set_shader_parameter("metallic", std_mat.metallic)
				if std_mat.albedo_texture:
					sm.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
					sm.set_shader_parameter("use_texture", true)
			node.set_surface_override_material(s, sm)
	for child in node.get_children():
		_apply_dark_shader_recursive(child)
