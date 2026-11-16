extends StaticBody3D

@export var max_health: float = 40.0
@export var explosion_damage: float = 120.0
@export var explosion_radius: float = 6.0

const EXPLOSION_SCENE = preload("res://scenes/effects/explosion.tscn")
var current_health: float = 40.0
var has_exploded: bool = false

func _ready() -> void:
	add_to_group("target")
	add_to_group("destructible")
	current_health = max_health

func take_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO, _shot_dir: Vector3 = Vector3.ZERO) -> void:
	if has_exploded:
		return
	current_health -= amount
	if current_health <= 0.0:
		explode()

func explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	var parent = get_parent()
	if parent and EXPLOSION_SCENE:
		var exp_inst = EXPLOSION_SCENE.instantiate()
		parent.add_child(exp_inst)
		exp_inst.global_position = global_position + Vector3(0, 0.6, 0)

	# Area blast damage
	var space = get_world_3d().direct_space_state
	var targets = get_tree().get_nodes_in_group("target")
	for t in targets:
		if is_instance_valid(t) and t != self:
			var d = global_position.distance_to(t.global_position)
			if d <= explosion_radius and t.has_method("take_damage"):
				var dmg = explosion_damage * (1.0 - (d / explosion_radius))
				t.take_damage(dmg, t.global_position, (t.global_position - global_position).normalized())

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_on_hit_target"):
		player._on_hit_target(25)

	queue_free()
