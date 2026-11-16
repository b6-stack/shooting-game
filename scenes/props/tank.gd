extends StaticBody3D

@export var tank_name: String = "M1A2 Abrams MBT"
@export var max_health: float = 600.0
@export var camo_color: Color = Color(0.36, 0.38, 0.32) # Olive drab / woodland
@export var tracks_color: Color = Color(0.14, 0.15, 0.16)
@export var turret_turn_speed: float = 0.4
@export var idle_scan: bool = false

var current_health: float = 600.0
var is_smoking: bool = false

@onready var turret_node: Node3D = get_node_or_null("Turret")
@onready var cannon_node: Node3D = get_node_or_null("Turret/Cannon")
@onready var smoke_particles: CPUParticles3D = get_node_or_null("SmokeParticles")
@onready var spark_particles: CPUParticles3D = get_node_or_null("SparkParticles")
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")

const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")
var _idle_time: float = 0.0

func _ready() -> void:
	add_to_group("target")
	add_to_group("tank")
	current_health = max_health
	if audio_player == null:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioStreamPlayer3D"
		audio_player.max_distance = 45.0
		add_child(audio_player)
	_ensure_particles()

func _ensure_particles() -> void:
	if spark_particles == null:
		spark_particles = CPUParticles3D.new()
		spark_particles.name = "SparkParticles"
		spark_particles.emitting = false
		spark_particles.one_shot = true
		spark_particles.explosiveness = 0.95
		spark_particles.amount = 16
		spark_particles.lifetime = 0.35
		spark_particles.direction = Vector3.UP
		spark_particles.spread = 75.0
		spark_particles.initial_velocity_min = 4.0
		spark_particles.initial_velocity_max = 9.0
		spark_particles.scale_amount_min = 0.05
		spark_particles.scale_amount_max = 0.12
		spark_particles.color = Color(1.0, 0.85, 0.3)
		add_child(spark_particles)

	if smoke_particles == null:
		smoke_particles = CPUParticles3D.new()
		smoke_particles.name = "SmokeParticles"
		smoke_particles.emitting = false
		smoke_particles.amount = 24
		smoke_particles.lifetime = 1.4
		smoke_particles.direction = Vector3.UP
		smoke_particles.spread = 25.0
		smoke_particles.initial_velocity_min = 1.5
		smoke_particles.initial_velocity_max = 3.5
		smoke_particles.gravity = Vector3(0, 0.8, 0)
		smoke_particles.scale_amount_min = 0.3
		smoke_particles.scale_amount_max = 0.9
		smoke_particles.color = Color(0.2, 0.2, 0.22, 0.75)
		if turret_node:
			turret_node.add_child(smoke_particles)
			smoke_particles.position = Vector3(0, 1.2, 0)
		else:
			add_child(smoke_particles)
			smoke_particles.position = Vector3(0, 2.4, 0)

func _process(delta: float) -> void:
	if idle_scan and turret_node:
		_idle_time += delta * turret_turn_speed
		turret_node.rotation.y = sin(_idle_time) * 0.45

func take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO, _shot_dir: Vector3 = Vector3.ZERO) -> void:
	current_health = maxf(0.0, current_health - amount)

	# Position spark emitter at hit point
	if spark_particles:
		if hit_pos != Vector3.ZERO:
			spark_particles.global_position = hit_pos
		spark_particles.restart()
		spark_particles.emitting = true

	# Play heavy armor ricochet / impact sound
	if audio_player:
		audio_player.stream = ProceduralAudio.get_cached("hitmarker")
		audio_player.pitch_scale = randf_range(0.55, 0.75) # Deep metallic thud
		audio_player.volume_db = 0.0
		audio_player.play()

	# Notify player score if shot by player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_on_hit_target"):
		var pts = int(clampf(amount * 0.5, 5.0, 50.0))
		player._on_hit_target(pts)

	# Heavy damage triggers engine/turret smoke
	if current_health <= max_health * 0.5 and not is_smoking:
		is_smoking = true
		if smoke_particles:
			smoke_particles.emitting = true
