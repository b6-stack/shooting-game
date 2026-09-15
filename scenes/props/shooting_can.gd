extends RigidBody3D

signal can_shot(points: int)

@export var respawn_delay: float = 5.0
@export var max_dist_from_spawn: float = 25.0
@export var can_color: Color = Color(0.85, 0.15, 0.15) # Default Cola Red

var initial_transform: Transform3D
var has_been_hit: bool = false
var respawn_timer: float = 0.0
var is_respawning: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

func _ready() -> void:
	initial_transform = global_transform
	mass = 0.35
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	
	if audio_player and audio_player.stream == null:
		audio_player.stream = ProceduralAudio.create_can_ding_sample()
		
	setup_material()

func setup_material() -> void:
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = can_color
		mat.metallic = 0.8
		mat.roughness = 0.3
		mesh_instance.material_override = mat

func take_damage(_dmg: float, _hit_pos: Vector3, _hit_normal: Vector3) -> void:
	if is_respawning:
		return
		
	has_been_hit = true
	respawn_timer = 0.0
	
	if audio_player:
		audio_player.pitch_scale = randf_range(0.9, 1.25)
		audio_player.play()
		
	can_shot.emit(50)
	
	# Try awarding score to player HUD if connected
	var player = get_tree().get_first_node_in_group("player")
	if player and "hud" in player and player.hud:
		var hud_ctrl = player.hud.get_node_or_null("HUDControl")
		if hud_ctrl and hud_ctrl.has_method("add_score"):
			hud_ctrl.add_score(50)
			hud_ctrl.show_hitmarker()

func _physics_process(delta: float) -> void:
	if is_respawning:
		return
		
	if has_been_hit:
		respawn_timer += delta
		if respawn_timer >= respawn_delay:
			respawn()
			return
			
	var dist = global_position.distance_to(initial_transform.origin)
	if dist > max_dist_from_spawn or global_position.y < -2.0:
		respawn()

func respawn() -> void:
	is_respawning = true
	has_been_hit = false
	respawn_timer = 0.0
	
	# Shrink out
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	
	# Reset Physics state safely
	freeze = true
	global_transform = initial_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	
	# Pop in
	scale = Vector3.ZERO
	var pop_tween = create_tween()
	pop_tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop_tween.finished
	
	is_respawning = false
