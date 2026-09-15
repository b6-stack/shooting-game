extends CharacterBody3D

signal robot_defeated(points: int)

@export var max_health: float = 150.0
@export var patrol_distance: float = 8.0
@export var move_speed: float = 2.4
@export var respawn_delay: float = 5.0
@export var patrol_dir_x: float = 1.0 # 1.0 = left/right patrol

var current_health: float = 150.0
var start_pos: Vector3
var target_offset: float = 0.0
var moving_forward: bool = true
var is_dead: bool = false
var walk_time: float = 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var left_leg: Node3D = $VisualRoot/LeftLeg
@onready var right_leg: Node3D = $VisualRoot/RightLeg
@onready var left_arm: Node3D = $VisualRoot/LeftArm
@onready var right_arm: Node3D = $VisualRoot/RightArm
@onready var head: Node3D = $VisualRoot/Head
@onready var eye_light: OmniLight3D = $VisualRoot/Head/EyeLight
@onready var audio_hit: AudioStreamPlayer3D = $AudioHit
@onready var audio_death: AudioStreamPlayer3D = $AudioDeath
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const EXPLOSION_EFFECT = preload("res://scenes/effects/explosion.tscn")
const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	start_pos = global_position
	current_health = max_health
	
	if visual_root:
		visual_root.rotation.y = get_target_rot_y()
	
	if audio_hit and audio_hit.stream == null:
		audio_hit.stream = ProceduralAudio.create_robot_hit_sample()
	if audio_death and audio_death.stream == null:
		audio_death.stream = ProceduralAudio.create_robot_death_sample()

func get_target_rot_y() -> float:
	# Face the direction of movement along the X axis
	var dir_sign = (1.0 if moving_forward else -1.0) * patrol_dir_x
	return -PI * 0.5 if dir_sign > 0.0 else PI * 0.5

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Patrol logic along X axis using native velocity and move_and_slide
	var move_sign = 1.0 if moving_forward else -1.0
	velocity = Vector3(move_sign * move_speed * patrol_dir_x, 0, 0)
	move_and_slide()
	
	target_offset = (global_position.x - start_pos.x) * patrol_dir_x
	if moving_forward and target_offset >= patrol_distance:
		moving_forward = false
		turn_robot(get_target_rot_y())
	elif not moving_forward and target_offset <= -patrol_distance:
		moving_forward = true
		turn_robot(get_target_rot_y())
	
	# Procedural Walking Animation (relative to current facing direction)
	walk_time += delta * move_speed * 3.2
	var leg_angle = sin(walk_time) * 0.45
	var arm_angle = -sin(walk_time) * 0.4
	var bob_y = abs(sin(walk_time)) * 0.04
	
	if left_leg:
		left_leg.rotation.x = leg_angle
	if right_leg:
		right_leg.rotation.x = -leg_angle
	if left_arm:
		left_arm.rotation.x = arm_angle
	if right_arm:
		right_arm.rotation.x = -arm_angle
	if visual_root:
		visual_root.position.y = bob_y

func turn_robot(target_rot_y: float) -> void:
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation:y", target_rot_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func take_damage(amount: float, _hit_pos: Vector3, _hit_normal: Vector3) -> void:
	if is_dead:
		return
		
	current_health -= amount
	
	# Hit sound
	if audio_hit:
		audio_hit.pitch_scale = randf_range(0.92, 1.08)
		audio_hit.play()
		
	# Flash red/white
	flash_damage()
	
	# Check death
	if current_health <= 0:
		die()

func flash_damage() -> void:
	if not visual_root:
		return
	var tween = create_tween()
	tween.tween_property(visual_root, "scale", Vector3(1.15, 0.9, 1.15), 0.06)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.08)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Death audio & explosion
	if audio_death:
		audio_death.play()
		
	var exp_node = EXPLOSION_EFFECT.instantiate()
	get_tree().current_scene.add_child(exp_node)
	exp_node.global_position = global_position + Vector3(0, 0.8, 0)
	
	# Hide robot & disable collision
	if visual_root:
		visual_root.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	# Award points to player
	robot_defeated.emit(250)
	var player = get_tree().get_first_node_in_group("player")
	if player and "hud" in player and player.hud:
		var hud_ctrl = player.hud.get_node_or_null("HUDControl")
		if hud_ctrl and hud_ctrl.has_method("add_score"):
			hud_ctrl.add_score(250)
			hud_ctrl.show_hitmarker()
			
	# Auto-Respawn
	get_tree().create_timer(respawn_delay).timeout.connect(respawn)

func respawn() -> void:
	current_health = max_health
	global_position = start_pos
	target_offset = 0.0
	moving_forward = true
	is_dead = false
	
	if visual_root:
		visual_root.rotation.y = get_target_rot_y()
		visual_root.visible = true
		visual_root.scale = Vector3.ZERO
		var tween = create_tween()
		tween.tween_property(visual_root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
